// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../v9/src/Token.sol";

contract MockExternalSettlement {
    Token public immutable x;
    Token public immutable z;
    Token public immutable u;

    uint256 public immutable priceXWad;
    uint256 public immutable priceZWad;

    constructor(
        address x_,
        address z_,
        address u_,
        uint256 px_,
        uint256 pz_
    ) {
        x = Token(x_);
        z = Token(z_);
        u = Token(u_);
        priceXWad = px_;
        priceZWad = pz_;
    }

    function sellXForUSDC(uint256 xAmount, address receiver)
        external
        returns (uint256 usdcOut)
    {
        require(x.transferFrom(msg.sender, address(this), xAmount), "X_PULL");
        usdcOut = xAmount * priceXWad / 1e18;
        require(u.transfer(receiver, usdcOut), "USDC_OUT");
    }

    function sellZForUSDC(uint256 zAmount, address receiver)
        external
        returns (uint256 usdcOut)
    {
        require(z.transferFrom(msg.sender, address(this), zAmount), "Z_PULL");
        usdcOut = zAmount * priceZWad / 1e18;
        require(u.transfer(receiver, usdcOut), "USDC_OUT");
    }
}
