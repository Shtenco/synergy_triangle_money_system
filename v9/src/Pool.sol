// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Pool {
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
}

contract Pool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable feeBps;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address a, address b, uint24 f) {
        require(a != b && a != address(0) && b != address(0), "TOKENS");
        require(f < 10_000, "FEE");
        token0 = a;
        token1 = b;
        feeBps = f;
    }

    function addLiquidity(uint256 a0, uint256 a1) external {
        require(a0 > 0 && a1 > 0, "AMOUNT");
        require(IERC20Pool(token0).transferFrom(msg.sender, address(this), a0), "PULL0");
        require(IERC20Pool(token1).transferFrom(msg.sender, address(this), a1), "PULL1");
        _sync();
    }

    function swapExactIn(address inToken, uint256 amountIn, address to) external returns (uint256 out) {
        bool zeroForOne = inToken == token0;
        require(zeroForOne || inToken == token1, "TOKEN");
        uint256 rIn = zeroForOne ? reserve0 : reserve1;
        uint256 rOut = zeroForOne ? reserve1 : reserve0;
        require(rIn > 0 && rOut > 0 && amountIn > 0, "LIQ");
        uint256 inFee = amountIn * (10_000 - feeBps);
        out = rOut * inFee / (rIn * 10_000 + inFee);
        require(IERC20Pool(inToken).transferFrom(msg.sender, address(this), amountIn), "PULL");
        require(IERC20Pool(zeroForOne ? token1 : token0).transfer(to, out), "OUT");
        _sync();
    }

    function spotPrice1Per0Wad() external view returns (uint256) {
        require(reserve0 > 0, "LIQ");
        return reserve1 * 1e18 / reserve0;
    }

    function _sync() internal {
        reserve0 = IERC20Pool(token0).balanceOf(address(this));
        reserve1 = IERC20Pool(token1).balanceOf(address(this));
    }
}
