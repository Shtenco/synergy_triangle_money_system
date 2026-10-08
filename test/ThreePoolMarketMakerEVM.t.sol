// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/SoftToken.sol";
import "../src/MockHardToken.sol";
import "../src/CPMMPool.sol";
import "../src/ThreePoolMarketMaker.sol";

contract ThreePoolMarketMakerEVMTest {
    uint256 constant W = 1e18;

    struct S {
        SoftToken x;
        SoftToken z;
        MockHardToken u;
        CPMMPool xu;
        CPMMPool zu;
        CPMMPool xz;
        ThreePoolMarketMaker mm;
        uint256 externalIn;
        uint256 externalOut;
    }

    event Scenario(
        string name,
        uint256 grossTVL,
        uint256 hardNav,
        uint256 netExternalIn,
        uint256 deltaTVLPerDollarWad,
        uint256 priceX,
        uint256 priceZ,
        uint256 priceXZ,
        uint256 mintedX,
        uint256 mintedZ,
        uint256 burnedX,
        uint256 burnedZ
    );

    function testAsymmetric8510HundredBlocks() public {
        S memory s = _deploy(8500, 1000);
        _run100(s);
        _assertCoreInvariants(s);
        _emitResult("85/10", s);

        uint256 netIn = s.externalIn - s.externalOut;
        uint256 delta = s.mm.grossTVL() - 24e17;
        require(delta * W / netIn > 1e18, "TVL_MULT_LT_1");
        require(s.xu.spotPrice1Per0Wad() <= 115e16, "PX_HIGH");
        require(s.zu.spotPrice1Per0Wad() <= 115e16, "PZ_HIGH");
    }

    function testCompare8510Vs5050Vs100100() public {
        S memory a = _deploy(8500, 1000);
        S memory b = _deploy(5000, 5000);
        S memory c = _deploy(10000, 10000);

        _run100(a);
        _run100(b);
        _run100(c);

        _assertCoreInvariants(a);
        _assertCoreInvariants(b);
        _assertCoreInvariants(c);

        _emitResult("85/10", a);
        _emitResult("50/50", b);
        _emitResult("100/100", c);

        uint256 ma = _deltaMultiple(a);
        uint256 mb = _deltaMultiple(b);
        uint256 mc = _deltaMultiple(c);

        // This is intentionally a comparative EVM assertion, not a model-only claim.
        require(ma > mb, "85_10_NOT_ABOVE_50_50");
        require(ma > mc, "85_10_NOT_ABOVE_100_100");
    }

    function testDownBlockActuallyBuysAndBurns() public {
        S memory s = _deploy(8500, 1000);

        _externalBuy(s, 2e16, 1e16);
        s.mm.step();

        uint256 beforeBurn = s.mm.burnedX() + s.mm.burnedZ();

        // Sell previously acquired soft tokens back into the hard pools.
        uint256 sx = s.x.balanceOf(address(this)) / 50;
        uint256 sz = s.z.balanceOf(address(this)) / 50;
        if (sx > 0) {
            s.x.approve(address(s.xu), sx);
            uint256 outX = s.xu.swapExactIn(address(s.x), sx, 0, address(this));
            s.externalOut += outX;
        }
        if (sz > 0) {
            s.z.approve(address(s.zu), sz);
            uint256 outZ = s.zu.swapExactIn(address(s.z), sz, 0, address(this));
            s.externalOut += outZ;
        }

        s.mm.step();
        uint256 afterBurn = s.mm.burnedX() + s.mm.burnedZ();
        require(afterBurn > beforeBurn, "NO_BURN");
    }

    function _deploy(uint16 emitBps, uint16 buybackBps) internal returns (S memory s) {
        s.x = new SoftToken("RUBX", "RUBX");
        s.z = new SoftToken("RUBZ", "RUBZ");
        s.u = new MockHardToken("USDC", "USDC");

        s.xu = new CPMMPool(address(s.x), address(s.u), 30);
        s.zu = new CPMMPool(address(s.z), address(s.u), 30);
        s.xz = new CPMMPool(address(s.x), address(s.z), 30);

        s.mm = new ThreePoolMarketMaker(
            address(s.x),
            address(s.z),
            address(s.u),
            address(s.xu),
            address(s.zu),
            address(s.xz),
            emitBps,
            buybackBps
        );

        s.x.setMinter(address(s.mm), true);
        s.z.setMinter(address(s.mm), true);

        s.x.mint(address(this), 10e18);
        s.z.mint(address(this), 10e18);
        s.u.mint(address(this), 20e18);

        _seed(s.xu, address(s.x), address(s.u), 4e17, 4e17);
        _seed(s.zu, address(s.z), address(s.u), 4e17, 4e17);
        _seed(s.xz, address(s.x), address(s.z), 4e17, 4e17);

        s.u.transfer(address(s.mm), 2e17);
        s.mm.initializePrices();
    }

    function _run100(S memory s) internal {
        for (uint256 i = 1; i <= 100; i++) {
            uint256 ux = i % 4 == 0 ? 65e14 : 55e14;
            uint256 uz = 1e16 - ux;
            _externalBuy(s, ux, uz);

            if (i % 10 == 0) {
                _externalSoftSellShock(s);
            }

            _crossArbTowardHardRatio(s);
            s.mm.step();
        }
    }

    function _externalBuy(S memory s, uint256 ux, uint256 uz) internal {
        s.u.approve(address(s.xu), ux);
        s.xu.swapExactIn(address(s.u), ux, 0, address(this));

        s.u.approve(address(s.zu), uz);
        s.zu.swapExactIn(address(s.u), uz, 0, address(this));

        s.externalIn += ux + uz;
    }

    function _externalSoftSellShock(S memory s) internal {
        uint256 sx = s.x.balanceOf(address(this)) / 300;
        uint256 sz = s.z.balanceOf(address(this)) / 300;

        if (sx > 0) {
            s.x.approve(address(s.xu), sx);
            uint256 outX = s.xu.swapExactIn(address(s.x), sx, 0, address(this));
            s.externalOut += outX;
        }
        if (sz > 0) {
            s.z.approve(address(s.zu), sz);
            uint256 outZ = s.zu.swapExactIn(address(s.z), sz, 0, address(this));
            s.externalOut += outZ;
        }
    }

    function _crossArbTowardHardRatio(S memory s) internal {
        uint256 pX = s.xu.spotPrice1Per0Wad();
        uint256 pZ = s.zu.spotPrice1Per0Wad();
        uint256 target = pX * W / pZ;
        uint256 current = s.xz.spotPrice1Per0Wad();

        // Move the cross pool only part way toward implied parity.
        if (target > current) {
            uint256 zIn = s.xz.reserve1() / 200;
            if (s.z.balanceOf(address(this)) >= zIn && zIn > 0) {
                s.z.approve(address(s.xz), zIn);
                s.xz.swapExactIn(address(s.z), zIn, 0, address(this));
            }
        } else if (target < current) {
            uint256 xIn = s.xz.reserve0() / 200;
            if (s.x.balanceOf(address(this)) >= xIn && xIn > 0) {
                s.x.approve(address(s.xz), xIn);
                s.xz.swapExactIn(address(s.x), xIn, 0, address(this));
            }
        }
    }

    function _assertCoreInvariants(S memory s) internal view {
        uint256 netIn = s.externalIn - s.externalOut;
        require(netIn > 0, "NO_NET_INPUT");

        // Initial hard NAV is 1 USDC; internal MM actions cannot invent hard assets.
        uint256 expectedHard = 1e18 + netIn;
        uint256 actualHard = s.mm.hardNav();
        uint256 diff = expectedHard > actualHard
            ? expectedHard - actualHard
            : actualHard - expectedHard;

        require(diff <= 10, "HARDNAV_ACCOUNTING");
        require(s.xu.reserve0() > 0 && s.xu.reserve1() > 0, "XU_EMPTY");
        require(s.zu.reserve0() > 0 && s.zu.reserve1() > 0, "ZU_EMPTY");
        require(s.xz.reserve0() > 0 && s.xz.reserve1() > 0, "XZ_EMPTY");
    }

    function _deltaMultiple(S memory s) internal view returns (uint256) {
        uint256 initialTVL = 24e17;
        uint256 gross = s.mm.grossTVL();
        uint256 netIn = s.externalIn - s.externalOut;
        if (gross <= initialTVL) return 0;
        return (gross - initialTVL) * W / netIn;
    }

    function _emitResult(string memory name, S memory s) internal {
        emit Scenario(
            name,
            s.mm.grossTVL(),
            s.mm.hardNav(),
            s.externalIn - s.externalOut,
            _deltaMultiple(s),
            s.xu.spotPrice1Per0Wad(),
            s.zu.spotPrice1Per0Wad(),
            s.xz.spotPrice1Per0Wad(),
            s.mm.mintedX(),
            s.mm.mintedZ(),
            s.mm.burnedX(),
            s.mm.burnedZ()
        );
    }

    function _seed(
        CPMMPool p,
        address a0,
        address a1,
        uint256 amount0,
        uint256 amount1
    ) internal {
        (bool ok0,) = a0.call(
            abi.encodeWithSignature("approve(address,uint256)", address(p), amount0)
        );
        (bool ok1,) = a1.call(
            abi.encodeWithSignature("approve(address,uint256)", address(p), amount1)
        );
        require(ok0 && ok1, "APPROVE");
        p.addLiquidity(amount0, amount1, address(this));
    }
}
