// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Token.sol";
import "./Pool.sol";

contract AdaptiveMM {
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS = 10_000;

    uint256 public constant MOVE_SCALE_BPS = 500;       // 5% block move -> full move factor
    uint256 public constant EMIT_MIN_BPS = 5_800;       // 58%
    uint256 public constant EMIT_MAX_BPS = 7_480;       // 74.8% before TVL feedback
    uint256 public constant BUY_MIN_BPS = 200;          // 2%
    uint256 public constant BUY_MAX_BPS = 6_000;        // 60% before treasury feedback
    uint256 public constant TARGET_TVL_HARD_WAD = 3_55e16 * 100; // 3.55e18
    uint256 public constant TVL_GAIN_WAD = 8e17;        // 0.80
    uint256 public constant TARGET_TREASURY_BPS = 40;   // 0.40% of HardNAV
    uint256 public constant TREASURY_BOOST_WAD = 3e17;  // 0.30
    uint256 public constant SCALE_MIN_WAD = 4e17;       // 0.40
    uint256 public constant SCALE_MAX_WAD = 125e16;     // 1.25
    uint256 public constant MAX_POLICY_BPS = 9_800;

    Token public immutable x;
    Token public immutable z;
    Token public immutable u;
    Pool public immutable xu;
    Pool public immutable zu;
    Pool public immutable xz;

    uint256 public prevPX;
    uint256 public prevPZ;
    uint256 public prevPXZ;

    uint256 public mintedX;
    uint256 public mintedZ;
    uint256 public burnedX;
    uint256 public burnedZ;

    event PolicyApplied(
        bytes32 indexed poolId,
        uint256 currentPrice,
        uint256 previousPrice,
        uint256 emitBps,
        uint256 buyBps,
        uint256 tvlHardWad,
        uint256 treasuryRatioBps
    );

    constructor(address X,address Z,address U,address XU,address ZU,address XZ) {
        x = Token(X);
        z = Token(Z);
        u = Token(U);
        xu = Pool(XU);
        zu = Pool(ZU);
        xz = Pool(XZ);
    }

    function initialize() external {
        require(prevPX == 0, "INIT");
        prevPX = xu.spotPrice1Per0Wad();
        prevPZ = zu.spotPrice1Per0Wad();
        prevPXZ = xz.spotPrice1Per0Wad();
    }

    function step() external {
        _hard(xu, x, true, prevPX, keccak256("XU"));
        _hard(zu, z, false, prevPZ, keccak256("ZU"));
        _cross(prevPXZ);
        prevPX = xu.spotPrice1Per0Wad();
        prevPZ = zu.spotPrice1Per0Wad();
        prevPXZ = xz.spotPrice1Per0Wad();
    }

    function adaptiveBps(uint256 currentPrice, uint256 previousPrice)
        public
        view
        returns (uint256 emitBps, uint256 buyBps)
    {
        require(previousPrice > 0, "PREV");
        uint256 moveBps = _absDiff(currentPrice, previousPrice) * BPS / previousPrice;
        uint256 h = hardNav();
        uint256 tvlHard = h == 0 ? 0 : grossTVL() * WAD / h;
        uint256 treasuryRatio = h == 0 ? 0 : u.balanceOf(address(this)) * BPS / h;
        return policyForState(moveBps, tvlHard, treasuryRatio);
    }

    function policyForState(
        uint256 moveBps,
        uint256 tvlHardWad,
        uint256 treasuryRatioBps
    ) public pure returns (uint256 emitBps, uint256 buyBps) {
        uint256 moveFactor = moveBps >= MOVE_SCALE_BPS
            ? WAD
            : moveBps * WAD / MOVE_SCALE_BPS;

        uint256 emitBase =
            EMIT_MIN_BPS
            + (EMIT_MAX_BPS - EMIT_MIN_BPS) * moveFactor / WAD;

        uint256 tvlScale;
        if (tvlHardWad <= TARGET_TVL_HARD_WAD) {
            uint256 gap = TARGET_TVL_HARD_WAD - tvlHardWad;
            tvlScale = WAD + TVL_GAIN_WAD * gap / TARGET_TVL_HARD_WAD;
        } else {
            uint256 excess = tvlHardWad - TARGET_TVL_HARD_WAD;
            uint256 reduction = TVL_GAIN_WAD * excess / TARGET_TVL_HARD_WAD;
            tvlScale = reduction >= WAD ? 0 : WAD - reduction;
        }
        tvlScale = _clamp(tvlScale, SCALE_MIN_WAD, SCALE_MAX_WAD);

        emitBps = emitBase * tvlScale / WAD;
        if (emitBps > MAX_POLICY_BPS) emitBps = MAX_POLICY_BPS;

        uint256 buyBase =
            BUY_MIN_BPS
            + (BUY_MAX_BPS - BUY_MIN_BPS) * moveFactor / WAD;

        uint256 treasuryScale;
        if (treasuryRatioBps < TARGET_TREASURY_BPS) {
            treasuryScale = treasuryRatioBps * WAD / TARGET_TREASURY_BPS;
        } else {
            uint256 excess = treasuryRatioBps - TARGET_TREASURY_BPS;
            treasuryScale =
                WAD
                + TREASURY_BOOST_WAD * excess / TARGET_TREASURY_BPS;
            if (treasuryScale > SCALE_MAX_WAD) treasuryScale = SCALE_MAX_WAD;
        }

        buyBps = buyBase * treasuryScale / WAD;
        if (buyBps > MAX_POLICY_BPS) buyBps = MAX_POLICY_BPS;
    }

    function _hard(Pool p, Token soft, bool isX, uint256 prev, bytes32 poolId) internal {
        uint256 cur = p.spotPrice1Per0Wad();
        (uint256 emitBps, uint256 buyBps) = adaptiveBps(cur, prev);

        uint256 h = hardNav();
        uint256 tvlHard = h == 0 ? 0 : grossTVL() * WAD / h;
        uint256 treasuryRatio = h == 0 ? 0 : u.balanceOf(address(this)) * BPS / h;
        emit PolicyApplied(poolId, cur, prev, emitBps, buyBps, tvlHard, treasuryRatio);

        if (cur > prev) {
            uint256 target = cur - (cur - prev) * emitBps / BPS;
            uint256 amt = _token0InToTarget(p, target);
            if (amt == 0) return;

            soft.mint(address(this), amt);
            if (isX) mintedX += amt; else mintedZ += amt;

            soft.approve(address(p), amt);
            uint256 hardOut = p.swapExactIn(address(soft), amt, address(this));

            uint256 reinvest = hardOut * 7_000 / BPS;
            if (reinvest > 0) {
                uint256 softNeeded = reinvest * p.reserve0() / p.reserve1();
                soft.mint(address(this), softNeeded);
                if (isX) mintedX += softNeeded; else mintedZ += softNeeded;

                soft.approve(address(p), softNeeded);
                u.approve(address(p), reinvest);
                p.addLiquidity(softNeeded, reinvest);
            }
        } else if (cur < prev) {
            uint256 treasury = u.balanceOf(address(this));
            if (treasury == 0 || buyBps == 0) return;

            uint256 target = cur + (prev - cur) * buyBps / BPS;
            uint256 hardIn = _token1InToTarget(p, target);
            if (hardIn > treasury) hardIn = treasury;
            if (hardIn == 0) return;

            u.approve(address(p), hardIn);
            uint256 softOut = p.swapExactIn(address(u), hardIn, address(this));
            soft.burn(softOut);

            if (isX) burnedX += softOut; else burnedZ += softOut;
        }
    }

    function _cross(uint256 prev) internal {
        uint256 cur = xz.spotPrice1Per0Wad();
        (uint256 emitBps, uint256 buyBps) = adaptiveBps(cur, prev);

        uint256 h = hardNav();
        uint256 tvlHard = h == 0 ? 0 : grossTVL() * WAD / h;
        uint256 treasuryRatio = h == 0 ? 0 : u.balanceOf(address(this)) * BPS / h;
        emit PolicyApplied(keccak256("XZ"), cur, prev, emitBps, buyBps, tvlHard, treasuryRatio);

        if (cur > prev) {
            uint256 target = cur - (cur - prev) * emitBps / BPS;
            uint256 amountX = _token0InToTarget(xz, target);
            if (amountX == 0) return;

            x.mint(address(this), amountX);
            mintedX += amountX;
            x.approve(address(xz), amountX);

            uint256 zOut = xz.swapExactIn(address(x), amountX, address(this));
            uint256 reinvest = zOut * 5_000 / BPS;

            if (reinvest > 0) {
                uint256 xNeeded = reinvest * xz.reserve0() / xz.reserve1();
                x.mint(address(this), xNeeded);
                mintedX += xNeeded;
                x.approve(address(xz), xNeeded);
                z.approve(address(xz), reinvest);
                xz.addLiquidity(xNeeded, reinvest);
            }
        } else if (cur < prev) {
            uint256 zBalance = z.balanceOf(address(this));
            if (zBalance == 0 || buyBps == 0) return;

            uint256 target = cur + (prev - cur) * buyBps / BPS;
            uint256 zIn = _token1InToTarget(xz, target);
            if (zIn > zBalance) zIn = zBalance;
            if (zIn == 0) return;

            z.approve(address(xz), zIn);
            uint256 xOut = xz.swapExactIn(address(z), zIn, address(this));
            x.burn(xOut);
            burnedX += xOut;
        }
    }

    function hardNav() public view returns (uint256) {
        return xu.reserve1() + zu.reserve1() + u.balanceOf(address(this));
    }

    function grossTVL() public view returns (uint256) {
        uint256 px = xu.spotPrice1Per0Wad();
        uint256 pz = zu.spotPrice1Per0Wad();

        return
            2 * xu.reserve1()
            + 2 * zu.reserve1()
            + xz.reserve0() * px / WAD
            + xz.reserve1() * pz / WAD;
    }

    function _token0InToTarget(Pool p, uint256 target) internal view returns (uint256) {
        uint256 r0 = p.reserve0();
        uint256 r1 = p.reserve1();
        uint256 cur = r1 * WAD / r0;
        if (target >= cur || target == 0) return 0;

        uint256 targetR0 = _sqrt(r0 * r1 * WAD / target);
        if (targetR0 <= r0) return 0;

        return (targetR0 - r0) * BPS / (BPS - p.feeBps());
    }

    function _token1InToTarget(Pool p, uint256 target) internal view returns (uint256) {
        uint256 r0 = p.reserve0();
        uint256 r1 = p.reserve1();
        uint256 cur = r1 * WAD / r0;
        if (target <= cur) return 0;

        uint256 targetR1 = _sqrt(r0 * r1 * target / WAD);
        if (targetR1 <= r1) return 0;

        return (targetR1 - r1) * BPS / (BPS - p.feeBps());
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }

    function _clamp(uint256 v, uint256 lo, uint256 hi) internal pure returns (uint256) {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return v;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z_) {
        if (y == 0) return 0;
        z_ = y;
        uint256 x_ = y / 2 + 1;
        while (x_ < z_) {
            z_ = x_;
            x_ = (y / x_ + x_) / 2;
        }
    }
}
