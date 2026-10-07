// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Token.sol";
import "./Pool.sol";

contract MM {
    uint256 constant WAD=1e18;
    uint256 constant BPS=10000;

    Token public immutable x;
    Token public immutable z;
    Token public immutable u;
    Pool public immutable xu;
    Pool public immutable zu;
    Pool public immutable xz;

    uint16 public immutable emitBps;
    uint16 public immutable buyBps;

    uint256 public prevPX;
    uint256 public prevPZ;
    uint256 public prevPXZ;

    uint256 public mintedX;
    uint256 public mintedZ;
    uint256 public burnedX;
    uint256 public burnedZ;

    constructor(address X,address Z,address U,address XU,address ZU,address XZ,uint16 e,uint16 b){
        x=Token(X);z=Token(Z);u=Token(U);xu=Pool(XU);zu=Pool(ZU);xz=Pool(XZ);
        emitBps=e;buyBps=b;
    }

    function initialize() external {
        require(prevPX==0,"INIT");
        prevPX=xu.spotPrice1Per0Wad();
        prevPZ=zu.spotPrice1Per0Wad();
        prevPXZ=xz.spotPrice1Per0Wad();
    }

    function step() external {
        _hard(xu,x,true,prevPX);
        _hard(zu,z,false,prevPZ);
        _cross(prevPXZ);
        prevPX=xu.spotPrice1Per0Wad();
        prevPZ=zu.spotPrice1Per0Wad();
        prevPXZ=xz.spotPrice1Per0Wad();
    }

    function _hard(Pool p,Token soft,bool isX,uint256 prev) internal {
        uint256 cur=p.spotPrice1Per0Wad();
        if(cur>prev){
            uint256 target=cur-(cur-prev)*emitBps/BPS;
            uint256 amt=_token0InToTarget(p,target);
            if(amt==0)return;
            soft.mint(address(this),amt);
            if(isX) mintedX+=amt; else mintedZ+=amt;
            soft.approve(address(p),amt);
            uint256 hardOut=p.swapExactIn(address(soft),amt,address(this));
            uint256 rein=hardOut*7000/BPS;
            if(rein>0){
                uint256 softNeed=rein*p.reserve0()/p.reserve1();
                soft.mint(address(this),softNeed);
                if(isX) mintedX+=softNeed; else mintedZ+=softNeed;
                soft.approve(address(p),softNeed);
                u.approve(address(p),rein);
                p.addLiquidity(softNeed,rein);
            }
        } else if(cur<prev){
            uint256 bal=u.balanceOf(address(this));
            if(bal==0)return;
            uint256 target=cur+(prev-cur)*buyBps/BPS;
            uint256 amt=_token1InToTarget(p,target);
            if(amt>bal)amt=bal;
            if(amt==0)return;
            u.approve(address(p),amt);
            uint256 softOut=p.swapExactIn(address(u),amt,address(this));
            soft.burn(softOut);
            if(isX) burnedX+=softOut; else burnedZ+=softOut;
        }
    }

    function _cross(uint256 prev) internal {
        uint256 cur=xz.spotPrice1Per0Wad();
        if(cur>prev){
            uint256 target=cur-(cur-prev)*emitBps/BPS;
            uint256 amt=_token0InToTarget(xz,target);
            if(amt==0)return;
            x.mint(address(this),amt); mintedX+=amt;
            x.approve(address(xz),amt);
            uint256 zOut=xz.swapExactIn(address(x),amt,address(this));
            uint256 rein=zOut*5000/BPS;
            if(rein>0){
                uint256 xNeed=rein*xz.reserve0()/xz.reserve1();
                x.mint(address(this),xNeed); mintedX+=xNeed;
                x.approve(address(xz),xNeed);
                z.approve(address(xz),rein);
                xz.addLiquidity(xNeed,rein);
            }
        } else if(cur<prev){
            uint256 bal=z.balanceOf(address(this));
            if(bal==0)return;
            uint256 target=cur+(prev-cur)*buyBps/BPS;
            uint256 zin=_token1InToTarget(xz,target);
            if(zin>bal)zin=bal;
            if(zin==0)return;
            z.approve(address(xz),zin);
            uint256 xOut=xz.swapExactIn(address(z),zin,address(this));
            x.burn(xOut);burnedX+=xOut;
        }
    }

    function hardNav() public view returns(uint256){
        return xu.reserve1()+zu.reserve1()+u.balanceOf(address(this));
    }

    function grossTVL() public view returns(uint256){
        uint256 px=xu.spotPrice1Per0Wad();
        uint256 pz=zu.spotPrice1Per0Wad();
        return 2*xu.reserve1()+2*zu.reserve1()+xz.reserve0()*px/WAD+xz.reserve1()*pz/WAD;
    }

    function _token0InToTarget(Pool p,uint256 target) internal view returns(uint256){
        uint256 r0=p.reserve0();uint256 r1=p.reserve1();
        uint256 cur=r1*WAD/r0;
        if(target>=cur || target==0)return 0;
        uint256 tr0=_sqrt(r0*r1*WAD/target);
        if(tr0<=r0)return 0;
        return (tr0-r0)*BPS/(BPS-p.feeBps());
    }

    function _token1InToTarget(Pool p,uint256 target) internal view returns(uint256){
        uint256 r0=p.reserve0();uint256 r1=p.reserve1();
        uint256 cur=r1*WAD/r0;
        if(target<=cur)return 0;
        uint256 tr1=_sqrt(r0*r1*target/WAD);
        if(tr1<=r1)return 0;
        return (tr1-r1)*BPS/(BPS-p.feeBps());
    }

    function _sqrt(uint256 y) internal pure returns(uint256 z_){
        if(y==0)return 0;
        z_=y;uint256 x_=y/2+1;
        while(x_<z_){z_=x_;x_=(y/x_+x_)/2;}
    }
}
