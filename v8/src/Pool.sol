// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20P{
    function balanceOf(address) external view returns(uint256);
    function transfer(address,uint256) external returns(bool);
    function transferFrom(address,address,uint256) external returns(bool);
}

contract Pool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable feeBps;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address a,address b,uint24 f){token0=a;token1=b;feeBps=f;}

    function addLiquidity(uint256 a0,uint256 a1) external{
        require(IERC20P(token0).transferFrom(msg.sender,address(this),a0),"P0");
        require(IERC20P(token1).transferFrom(msg.sender,address(this),a1),"P1");
        _sync();
    }

    function swapExactIn(address inToken,uint256 amountIn,address to) external returns(uint256 out){
        bool z=inToken==token0;require(z || inToken==token1,"TOKEN");
        uint256 rIn=z?reserve0:reserve1;
        uint256 rOut=z?reserve1:reserve0;
        uint256 inFee=amountIn*(10000-feeBps);
        out=rOut*inFee/(rIn*10000+inFee);
        require(IERC20P(inToken).transferFrom(msg.sender,address(this),amountIn),"PULL");
        require(IERC20P(z?token1:token0).transfer(to,out),"OUT");
        _sync();
    }

    function spotPrice1Per0Wad() external view returns(uint256){
        return reserve1*1e18/reserve0;
    }

    function _sync() internal{
        reserve0=IERC20P(token0).balanceOf(address(this));
        reserve1=IERC20P(token1).balanceOf(address(this));
    }
}
