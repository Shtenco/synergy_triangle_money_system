// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20CPMM {
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
}

contract CPMMPool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable feeBps;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address a, address b, uint24 f) {
        require(a != b && a != address(0) && b != address(0), "TOKENS");
        require(f < 10000, "FEE");
        token0 = a; token1 = b; feeBps = f;
    }

    function approve(address s,uint256 v) external returns(bool){allowance[msg.sender][s]=v;return true;}
    function transfer(address to,uint256 v) external returns(bool){_lpTransfer(msg.sender,to,v);return true;}

    function transferFrom(address f,address to,uint256 v) external returns(bool){
        uint256 a=allowance[f][msg.sender]; require(a>=v,"ALLOW");
        if(a!=type(uint256).max) allowance[f][msg.sender]=a-v;
        _lpTransfer(f,to,v); return true;
    }

    function addLiquidity(uint256 a0,uint256 a1,address to) external returns(uint256 shares){
        require(a0>0 && a1>0,"AMOUNT");
        require(IERC20CPMM(token0).transferFrom(msg.sender,address(this),a0),"PULL0");
        require(IERC20CPMM(token1).transferFrom(msg.sender,address(this),a1),"PULL1");
        if(totalSupply==0) shares=_sqrt(a0*a1);
        else {
            uint256 s0=a0*totalSupply/reserve0;
            uint256 s1=a1*totalSupply/reserve1;
            shares=s0<s1?s0:s1;
        }
        require(shares>0,"SHARES");
        totalSupply+=shares; balanceOf[to]+=shares; _sync();
    }

    function quoteOut(address inToken,uint256 amountIn) public view returns(uint256 out){
        bool zeroForOne=inToken==token0;
        require(zeroForOne || inToken==token1,"TOKEN");
        uint256 rIn=zeroForOne?reserve0:reserve1;
        uint256 rOut=zeroForOne?reserve1:reserve0;
        require(rIn>0 && rOut>0 && amountIn>0,"LIQ");
        uint256 inWithFee=amountIn*(10000-feeBps);
        out=(rOut*inWithFee)/(rIn*10000+inWithFee);
    }

    function swapExactIn(address inToken,uint256 amountIn,uint256 minOut,address to) external returns(uint256 out){
        bool zeroForOne=inToken==token0;
        require(zeroForOne || inToken==token1,"TOKEN");
        address outToken=zeroForOne?token1:token0;
        out=quoteOut(inToken,amountIn);
        require(out>=minOut,"MIN_OUT");
        require(IERC20CPMM(inToken).transferFrom(msg.sender,address(this),amountIn),"PULL");
        require(IERC20CPMM(outToken).transfer(to,out),"OUT");
        _sync();
    }

    function spotPrice1Per0Wad() external view returns(uint256){
        require(reserve0>0,"LIQ");
        return reserve1*1e18/reserve0;
    }

    function _sync() internal {
        reserve0=IERC20CPMM(token0).balanceOf(address(this));
        reserve1=IERC20CPMM(token1).balanceOf(address(this));
    }

    function _lpTransfer(address f,address t,uint256 v) internal {
        require(t!=address(0) && balanceOf[f]>=v,"LP");
        balanceOf[f]-=v; balanceOf[t]+=v;
    }

    function _sqrt(uint256 y) internal pure returns(uint256 z){
        if(y==0)return 0;
        z=y; uint256 x=y/2+1;
        while(x<z){z=x;x=(y/x+x)/2;}
    }
}
