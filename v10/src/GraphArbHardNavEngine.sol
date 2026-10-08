// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../v9/src/Token.sol";
import "../v9/src/Pool.sol";

interface IExternalSettlement {
    function sellXForUSDC(uint256 xAmount, address receiver) external returns (uint256 usdcOut);
    function sellZForUSDC(uint256 zAmount, address receiver) external returns (uint256 usdcOut);
}

contract GraphArbHardNavEngine {
    uint256 public constant WAD = 1e18;

    Token public immutable x;
    Token public immutable z;
    Token public immutable u;
    Pool public immutable xu;
    Pool public immutable zu;
    Pool public immutable xz;

    uint256 public internalArbProfitUSDC;
    uint256 public externalSettlementUSDC;

    constructor(
        address x_,
        address z_,
        address u_,
        address xu_,
        address zu_,
        address xz_
    ) {
        x = Token(x_);
        z = Token(z_);
        u = Token(u_);
        xu = Pool(xu_);
        zu = Pool(zu_);
        xz = Pool(xz_);
    }

    function executeInternalUZXU(uint256 amountUSDC)
        external
        returns (uint256 profit)
    {
        require(amountUSDC > 0, "AMOUNT");
        uint256 beforeU = u.balanceOf(address(this));

        u.approve(address(zu), amountUSDC);
        uint256 zOut = zu.swapExactIn(address(u), amountUSDC, address(this));

        z.approve(address(xz), zOut);
        uint256 xOut = xz.swapExactIn(address(z), zOut, address(this));

        x.approve(address(xu), xOut);
        xu.swapExactIn(address(x), xOut, address(this));

        uint256 afterU = u.balanceOf(address(this));
        require(afterU > beforeU, "NO_INTERNAL_PROFIT");

        profit = afterU - beforeU;
        internalArbProfitUSDC += profit;
    }

    function executeInternalUXZU(uint256 amountUSDC)
        external
        returns (uint256 profit)
    {
        require(amountUSDC > 0, "AMOUNT");
        uint256 beforeU = u.balanceOf(address(this));

        u.approve(address(xu), amountUSDC);
        uint256 xOut = xu.swapExactIn(address(u), amountUSDC, address(this));

        x.approve(address(xz), xOut);
        uint256 zOut = xz.swapExactIn(address(x), xOut, address(this));

        z.approve(address(zu), zOut);
        zu.swapExactIn(address(z), zOut, address(this));

        uint256 afterU = u.balanceOf(address(this));
        require(afterU > beforeU, "NO_INTERNAL_PROFIT");

        profit = afterU - beforeU;
        internalArbProfitUSDC += profit;
    }


    function crystallizeUZXToExternal(
        uint256 internalUSDC,
        address settlement,
        uint256 minExternalUSDC
    ) external returns (uint256 externalUSDC) {
        require(internalUSDC > 0, "AMOUNT");

        uint256 beforeHard = hardNav();

        u.approve(address(zu), internalUSDC);
        uint256 zOut = zu.swapExactIn(
            address(u),
            internalUSDC,
            address(this)
        );

        z.approve(address(xz), zOut);
        uint256 xOut = xz.swapExactIn(
            address(z),
            zOut,
            address(this)
        );

        x.approve(settlement, xOut);
        externalUSDC = IExternalSettlement(settlement)
            .sellXForUSDC(xOut, address(this));

        require(externalUSDC >= minExternalUSDC, "SETTLEMENT_TOO_LOW");
        externalSettlementUSDC += externalUSDC;

        require(
            hardNav() >= beforeHard + externalUSDC,
            "HARDNAV_DID_NOT_CAPTURE_EXTERNAL"
        );
    }

    function crystallizeXToExternal(
        uint256 internalUSDC,
        address settlement,
        uint256 minExternalUSDC
    ) external returns (uint256 hardNavGain) {
        require(internalUSDC > 0, "AMOUNT");

        uint256 beforeU = u.balanceOf(address(this));

        u.approve(address(xu), internalUSDC);
        uint256 xOut = xu.swapExactIn(
            address(u),
            internalUSDC,
            address(this)
        );

        x.approve(settlement, xOut);
        uint256 externalUSDC = IExternalSettlement(settlement)
            .sellXForUSDC(xOut, address(this));

        require(externalUSDC >= minExternalUSDC, "SETTLEMENT_TOO_LOW");
        require(u.balanceOf(address(this)) >= beforeU - internalUSDC + externalUSDC, "BAD_SETTLEMENT");

        externalSettlementUSDC += externalUSDC;
        hardNavGain = externalUSDC;
    }

    function crystallizeZToExternal(
        uint256 internalUSDC,
        address settlement,
        uint256 minExternalUSDC
    ) external returns (uint256 hardNavGain) {
        require(internalUSDC > 0, "AMOUNT");

        uint256 beforeU = u.balanceOf(address(this));

        u.approve(address(zu), internalUSDC);
        uint256 zOut = zu.swapExactIn(
            address(u),
            internalUSDC,
            address(this)
        );

        z.approve(settlement, zOut);
        uint256 externalUSDC = IExternalSettlement(settlement)
            .sellZForUSDC(zOut, address(this));

        require(externalUSDC >= minExternalUSDC, "SETTLEMENT_TOO_LOW");
        require(u.balanceOf(address(this)) >= beforeU - internalUSDC + externalUSDC, "BAD_SETTLEMENT");

        externalSettlementUSDC += externalUSDC;
        hardNavGain = externalUSDC;
    }

    function hardNav() public view returns (uint256) {
        return
            xu.reserve1()
            + zu.reserve1()
            + u.balanceOf(address(this));
    }

    function prices()
        external
        view
        returns (uint256 px, uint256 pz, uint256 pxz)
    {
        px = xu.spotPrice1Per0Wad();
        pz = zu.spotPrice1Per0Wad();
        pxz = xz.spotPrice1Per0Wad();
    }
}
