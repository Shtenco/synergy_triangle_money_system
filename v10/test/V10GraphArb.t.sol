// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../v9/src/Token.sol";
import "../v9/src/Pool.sol";
import "../src/GraphArbHardNavEngine.sol";
import "../src/MockExternalSettlement.sol";

contract V10GraphArbTest {
    Token x;
    Token z;
    Token u;
    Pool xu;
    Pool zu;
    Pool xz;
    GraphArbHardNavEngine arb;
    MockExternalSettlement venue;

    function setUp() public {
        x = new Token("RUBX", "RUBX");
        z = new Token("RUBZ", "RUBZ");
        u = new Token("USDC", "USDC");

        xu = new Pool(address(x), address(u), 30);
        zu = new Pool(address(z), address(u), 30);
        xz = new Pool(address(x), address(z), 30);

        arb = new GraphArbHardNavEngine(
            address(x), address(z), address(u),
            address(xu), address(zu), address(xz)
        );

        venue = new MockExternalSettlement(
            address(x), address(z), address(u), 1e18, 1e18
        );

        x.mint(address(this), 10e18);
        z.mint(address(this), 10e18);
        u.mint(address(this), 20e18);

        _seed(xu, x, u, 4e17, 4e17);
        _seed(zu, z, u, 4e17, 4e17);
        _seed(xz, x, z, 4e17, 4e17);

        u.transfer(address(arb), 2e17);
        u.transfer(address(venue), 5e18);
    }

    function testClosedTriangleDoesNotCreateConsolidatedHard() public {
        u.approve(address(xu), 1e17);
        xu.swapExactIn(address(u), 1e17, address(this));

        uint256 beforeHard = arb.hardNav();
        uint256 beforeTreasury = u.balanceOf(address(arb));

        uint256 profit = arb.executeInternalUZXU(3025e13);

        require(profit > 7e15, "NO_WALLET_ARB_PROFIT");
        require(u.balanceOf(address(arb)) > beforeTreasury, "TREASURY_NOT_UP");

        uint256 afterHard = arb.hardNav();
        uint256 diff = afterHard > beforeHard
            ? afterHard - beforeHard
            : beforeHard - afterHard;

        require(diff < 1e7, "CLOSED_GRAPH_CREATED_HARD");
    }

    function testPrimaryFlowCanUnlockExtraExternalHardSettlement() public {
        uint256 startHard = arb.hardNav();
        require(startHard == 1e18, "START");

        // Primary outside demand: 0.10 USDC enters X/USDC.
        u.approve(address(xu), 1e17);
        xu.swapExactIn(address(u), 1e17, address(this));

        uint256 afterPrimary = arb.hardNav();
        require(afterPrimary == 11e17, "PRIMARY_INPUT");

        // Graph route uses only protocol-owned USDC internally:
        // U -> Z -> X, then the final X is sold to an OUTSIDE RFQ at 1 USDC/X.
        // Internal U movement is HardNAV-neutral; only RFQ settlement adds hard value.
        uint256 externalHard = arb.crystallizeUZXToExternal(
            28995e12,
            address(venue),
            2518e13
        );

        uint256 finalHard = arb.hardNav();

        require(externalHard > 2518e13, "EXTERNAL_HARD_TOO_SMALL");
        require(finalHard > 1125e15, "FINAL_HARD_TOO_LOW");

        uint256 primaryInput = 1e17;
        uint256 totalGain = finalHard - startHard;
        uint256 multiplierWad = totalGain * 1e18 / primaryInput;

        require(multiplierWad > 125e16, "MULTIPLIER_LT_1_25X");

        // The extra >1.0 multiplier is explicitly paid by the external RFQ.
        uint256 accountingDiff = totalGain - primaryInput - externalHard;
        require(accountingDiff < 1e7, "FLOW_ACCOUNTING");
    }

    function _seed(
        Pool p,
        Token a,
        Token b,
        uint256 aa,
        uint256 bb
    ) internal {
        a.approve(address(p), aa);
        b.approve(address(p), bb);
        p.addLiquidity(aa, bb);
    }
}
