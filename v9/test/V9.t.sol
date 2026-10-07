// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/Token.sol";
import "../src/Pool.sol";
import "../src/AdaptiveMM.sol";

contract V9AdaptiveTest {
    uint256 constant W = 1e18;

    struct S {
        Token x;
        Token z;
        Token u;
        Pool xu;
        Pool zu;
        Pool xz;
        AdaptiveMM mm;
        uint256 extIn;
        uint256 extOut;
    }

    event Result(
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
        uint256 burnedZ,
        uint256 treasuryUSDC
    );

    function testAdaptive100Blocks() public {
        S memory s = _deploy();
        _run(s);
        _check(s);
        _emit(s);

        uint256 m = _multiple(s);
        require(m > 3_770e15, "ADAPTIVE_MULTIPLIER_TOO_LOW");

        uint256 px = s.xu.spotPrice1Per0Wad();
        uint256 pz = s.zu.spotPrice1Per0Wad();
        uint256 pxz = s.xz.spotPrice1Per0Wad();

        require(px >= 85e16 && px <= 115e16, "PX_OUTSIDE_CORRIDOR");
        require(pz >= 85e16 && pz <= 115e16, "PZ_OUTSIDE_CORRIDOR");
        require(pxz >= 85e16 && pxz <= 115e16, "PXZ_OUTSIDE_CORRIDOR");

        require(s.mm.grossTVL() > 3_740e15, "TVL_TOO_LOW");
    }

    function testPolicyRespondsToMoveSize() public {
        S memory s = _deploy();

        (uint256 eSmall, uint256 bSmall) =
            s.mm.policyForState(10, 24e17, 2_000);
        (uint256 eLarge, uint256 bLarge) =
            s.mm.policyForState(400, 24e17, 2_000);

        require(eLarge > eSmall, "EMIT_NOT_ADAPTIVE");
        require(bLarge > bSmall, "BUY_NOT_ADAPTIVE");
    }

    function testHighTvlHardReducesEmission() public {
        S memory s = _deploy();

        (uint256 eLow,,) = _emitOnly(s, 100, 24e17, 2_000);
        (uint256 eHigh,,) = _emitOnly(s, 100, 40e17, 2_000);

        require(eLow > eHigh, "TVL_FEEDBACK_NOT_WORKING");
    }

    function testLowTreasuryReducesBuyback() public {
        S memory s = _deploy();

        (,uint256 bLow) = s.mm.policyForState(300, 27e17, 2);
        (,uint256 bHigh) = s.mm.policyForState(300, 27e17, 2_000);

        require(bHigh > bLow, "TREASURY_FEEDBACK_NOT_WORKING");
    }

    function testDownBlockBurns() public {
        S memory s = _deploy();

        _buy(s, 2e16, 1e16);
        s.mm.step();

        uint256 beforeBurn = s.mm.burnedX() + s.mm.burnedZ();

        uint256 sx = s.x.balanceOf(address(this)) / 40;
        uint256 sz = s.z.balanceOf(address(this)) / 40;

        s.x.approve(address(s.xu), sx);
        s.extOut += s.xu.swapExactIn(address(s.x), sx, address(this));

        s.z.approve(address(s.zu), sz);
        s.extOut += s.zu.swapExactIn(address(s.z), sz, address(this));

        s.mm.step();

        require(
            s.mm.burnedX() + s.mm.burnedZ() > beforeBurn,
            "NO_BUY_BURN"
        );
    }

    function _emitOnly(
        S memory s,
        uint256 moveBps,
        uint256 tvlHard,
        uint256 treasuryRatio
    ) internal pure returns (uint256 emitBps, uint256 buyBps, uint256 marker) {
        (emitBps, buyBps) = s.mm.policyForState(moveBps, tvlHard, treasuryRatio);
        marker = 1;
    }

    function _deploy() internal returns (S memory s) {
        s.x = new Token("RUBX", "RUBX");
        s.z = new Token("RUBZ", "RUBZ");
        s.u = new Token("USDC", "USDC");

        s.xu = new Pool(address(s.x), address(s.u), 30);
        s.zu = new Pool(address(s.z), address(s.u), 30);
        s.xz = new Pool(address(s.x), address(s.z), 30);

        s.mm = new AdaptiveMM(
            address(s.x),
            address(s.z),
            address(s.u),
            address(s.xu),
            address(s.zu),
            address(s.xz)
        );

        s.x.setMinter(address(s.mm), true);
        s.z.setMinter(address(s.mm), true);

        s.x.mint(address(this), 10e18);
        s.z.mint(address(this), 10e18);
        s.u.mint(address(this), 20e18);

        _seed(s.xu, s.x, s.u, 4e17, 4e17);
        _seed(s.zu, s.z, s.u, 4e17, 4e17);
        _seed(s.xz, s.x, s.z, 4e17, 4e17);

        s.u.transfer(address(s.mm), 2e17);
        s.mm.initialize();
    }

    function _run(S memory s) internal {
        for (uint256 i = 1; i <= 100; i++) {
            uint256 ux = i % 4 == 0 ? 65e14 : 55e14;
            uint256 uz = 1e16 - ux;

            _buy(s, ux, uz);

            if (i % 10 == 0) _shock(s);

            _cross(s);
            s.mm.step();
        }
    }

    function _buy(S memory s, uint256 ux, uint256 uz) internal {
        s.u.approve(address(s.xu), ux);
        s.xu.swapExactIn(address(s.u), ux, address(this));

        s.u.approve(address(s.zu), uz);
        s.zu.swapExactIn(address(s.u), uz, address(this));

        s.extIn += ux + uz;
    }

    function _shock(S memory s) internal {
        uint256 sx = s.x.balanceOf(address(this)) / 300;
        uint256 sz = s.z.balanceOf(address(this)) / 300;

        if (sx > 0) {
            s.x.approve(address(s.xu), sx);
            s.extOut += s.xu.swapExactIn(address(s.x), sx, address(this));
        }

        if (sz > 0) {
            s.z.approve(address(s.zu), sz);
            s.extOut += s.zu.swapExactIn(address(s.z), sz, address(this));
        }
    }

    function _cross(S memory s) internal {
        uint256 px = s.xu.spotPrice1Per0Wad();
        uint256 pz = s.zu.spotPrice1Per0Wad();
        uint256 target = px * W / pz;
        uint256 current = s.xz.spotPrice1Per0Wad();

        if (target > current) {
            uint256 zIn = s.xz.reserve1() / 200;
            s.z.approve(address(s.xz), zIn);
            s.xz.swapExactIn(address(s.z), zIn, address(this));
        } else if (target < current) {
            uint256 xIn = s.xz.reserve0() / 200;
            s.x.approve(address(s.xz), xIn);
            s.xz.swapExactIn(address(s.x), xIn, address(this));
        }
    }

    function _check(S memory s) internal view {
        uint256 net = s.extIn - s.extOut;
        uint256 expectedHard = 1e18 + net;
        uint256 actualHard = s.mm.hardNav();

        uint256 diff = expectedHard > actualHard
            ? expectedHard - actualHard
            : actualHard - expectedHard;

        require(diff < 1e6, "HARDNAV_ACCOUNTING");
        require(s.xu.reserve0() > 0 && s.xu.reserve1() > 0, "XU_EMPTY");
        require(s.zu.reserve0() > 0 && s.zu.reserve1() > 0, "ZU_EMPTY");
        require(s.xz.reserve0() > 0 && s.xz.reserve1() > 0, "XZ_EMPTY");
    }

    function _multiple(S memory s) internal view returns (uint256) {
        uint256 gross = s.mm.grossTVL();
        if (gross <= 24e17) return 0;
        return (gross - 24e17) * W / (s.extIn - s.extOut);
    }

    function _emit(S memory s) internal {
        emit Result(
            s.mm.grossTVL(),
            s.mm.hardNav(),
            s.extIn - s.extOut,
            _multiple(s),
            s.xu.spotPrice1Per0Wad(),
            s.zu.spotPrice1Per0Wad(),
            s.xz.spotPrice1Per0Wad(),
            s.mm.mintedX(),
            s.mm.mintedZ(),
            s.mm.burnedX(),
            s.mm.burnedZ(),
            s.u.balanceOf(address(s.mm))
        );
    }

    function _seed(Pool p, Token a, Token b, uint256 aa, uint256 bb) internal {
        a.approve(address(p), aa);
        b.approve(address(p), bb);
        p.addLiquidity(aa, bb);
    }
}
