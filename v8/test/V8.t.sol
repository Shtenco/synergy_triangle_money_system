// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/Token.sol";
import "../src/Pool.sol";
import "../src/MM.sol";

contract V8Test {
    uint256 constant W=1e18;

    struct S{
        Token x;Token z;Token u;
        Pool xu;Pool zu;Pool xz;
        MM mm;
        uint256 extIn;
        uint256 extOut;
    }

    event Result(
        string name,
        uint256 grossTVL,
        uint256 hardNav,
        uint256 netIn,
        uint256 deltaMultipleWad,
        uint256 px,
        uint256 pz,
        uint256 pxz,
        uint256 mintedX,
        uint256 mintedZ,
        uint256 burnedX,
        uint256 burnedZ
    );

    function testCompare() public {
        S memory a=_deploy(8500,1000);
        S memory b=_deploy(5000,5000);
        S memory c=_deploy(10000,10000);

        _run(a);_run(b);_run(c);

        _check(a);_check(b);_check(c);
        _emit("85/10",a);_emit("50/50",b);_emit("100/100",c);

        uint256 ma=_m(a);uint256 mb=_m(b);uint256 mc=_m(c);
        require(ma>mb,"85/10 <= 50/50");
        require(ma>mc,"85/10 <= 100/100");
    }

    function testDownBlockBurns() public {
        S memory s=_deploy(8500,1000);
        _buy(s,2e16,1e16);
        s.mm.step();
        uint256 beforeBurn=s.mm.burnedX()+s.mm.burnedZ();

        uint256 sx=s.x.balanceOf(address(this))/40;
        uint256 sz=s.z.balanceOf(address(this))/40;
        s.x.approve(address(s.xu),sx);
        s.extOut+=s.xu.swapExactIn(address(s.x),sx,address(this));
        s.z.approve(address(s.zu),sz);
        s.extOut+=s.zu.swapExactIn(address(s.z),sz,address(this));

        s.mm.step();
        require(s.mm.burnedX()+s.mm.burnedZ()>beforeBurn,"NO_BURN");
    }

    function _deploy(uint16 e,uint16 b) internal returns(S memory s){
        s.x=new Token("RUBX","RUBX");
        s.z=new Token("RUBZ","RUBZ");
        s.u=new Token("USDC","USDC");
        s.xu=new Pool(address(s.x),address(s.u),30);
        s.zu=new Pool(address(s.z),address(s.u),30);
        s.xz=new Pool(address(s.x),address(s.z),30);
        s.mm=new MM(address(s.x),address(s.z),address(s.u),address(s.xu),address(s.zu),address(s.xz),e,b);
        s.x.setMinter(address(s.mm),true);
        s.z.setMinter(address(s.mm),true);
        s.x.mint(address(this),10e18);s.z.mint(address(this),10e18);s.u.mint(address(this),20e18);
        _seed(s.xu,s.x,s.u,4e17,4e17);
        _seed(s.zu,s.z,s.u,4e17,4e17);
        _seed(s.xz,s.x,s.z,4e17,4e17);
        s.u.transfer(address(s.mm),2e17);
        s.mm.initialize();
    }

    function _run(S memory s) internal {
        for(uint256 i=1;i<=100;i++){
            uint256 ux=i%4==0?65e14:55e14;
            uint256 uz=1e16-ux;
            _buy(s,ux,uz);
            if(i%10==0)_shock(s);
            _cross(s);
            s.mm.step();
        }
    }

    function _buy(S memory s,uint256 ux,uint256 uz) internal {
        s.u.approve(address(s.xu),ux);
        s.xu.swapExactIn(address(s.u),ux,address(this));
        s.u.approve(address(s.zu),uz);
        s.zu.swapExactIn(address(s.u),uz,address(this));
        s.extIn+=ux+uz;
    }

    function _shock(S memory s) internal {
        uint256 sx=s.x.balanceOf(address(this))/300;
        uint256 sz=s.z.balanceOf(address(this))/300;
        if(sx>0){s.x.approve(address(s.xu),sx);s.extOut+=s.xu.swapExactIn(address(s.x),sx,address(this));}
        if(sz>0){s.z.approve(address(s.zu),sz);s.extOut+=s.zu.swapExactIn(address(s.z),sz,address(this));}
    }

    function _cross(S memory s) internal {
        uint256 px=s.xu.spotPrice1Per0Wad();
        uint256 pz=s.zu.spotPrice1Per0Wad();
        uint256 target=px*W/pz;
        uint256 cur=s.xz.spotPrice1Per0Wad();
        if(target>cur){
            uint256 zin=s.xz.reserve1()/200;
            s.z.approve(address(s.xz),zin);
            s.xz.swapExactIn(address(s.z),zin,address(this));
        } else if(target<cur){
            uint256 xin=s.xz.reserve0()/200;
            s.x.approve(address(s.xz),xin);
            s.xz.swapExactIn(address(s.x),xin,address(this));
        }
    }

    function _check(S memory s) internal view {
        uint256 net=s.extIn-s.extOut;
        uint256 expected=1e18+net;
        uint256 actual=s.mm.hardNav();
        uint256 d=expected>actual?expected-actual:actual-expected;
        require(d<1e6,"HARDNAV");
        require(s.xu.reserve0()>0&&s.xu.reserve1()>0,"XU");
        require(s.zu.reserve0()>0&&s.zu.reserve1()>0,"ZU");
        require(s.xz.reserve0()>0&&s.xz.reserve1()>0,"XZ");
    }

    function _m(S memory s) internal view returns(uint256){
        uint256 g=s.mm.grossTVL();
        if(g<=24e17)return 0;
        return (g-24e17)*W/(s.extIn-s.extOut);
    }

    function _emit(string memory n,S memory s) internal {
        emit Result(
            n,s.mm.grossTVL(),s.mm.hardNav(),s.extIn-s.extOut,_m(s),
            s.xu.spotPrice1Per0Wad(),s.zu.spotPrice1Per0Wad(),s.xz.spotPrice1Per0Wad(),
            s.mm.mintedX(),s.mm.mintedZ(),s.mm.burnedX(),s.mm.burnedZ()
        );
    }

    function _seed(Pool p,Token a,Token b,uint256 aa,uint256 bb) internal{
        a.approve(address(p),aa);b.approve(address(p),bb);p.addLiquidity(aa,bb);
    }
}
