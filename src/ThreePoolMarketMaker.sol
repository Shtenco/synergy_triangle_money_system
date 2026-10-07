// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SoftToken.sol";
import "./MockHardToken.sol";
import "./CPMMPool.sol";

contract ThreePoolMarketMaker {
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS = 10_000;

    SoftToken public immutable x;
    SoftToken public immutable z;
    MockHardToken public immutable usdc;
    CPMMPool public immutable xu;
    CPMMPool public immutable zu;
    CPMMPool public immutable xz;

    uint16 public immutable emitCorrectionBps;
    uint16 public immutable buybackCorrectionBps;
    uint16 public immutable hardRecycleBps;
    uint16 public immutable crossRecycleBps;

    uint256 public prevPX;
    uint256 public prevPZ;
    uint256 public prevPXZ;

    uint256 public mintedX;
    uint256 public mintedZ;
    uint256 public burnedX;
    uint256 public burnedZ;

    constructor(
        address x_,
        address z_,
        address usdc_,
        address xu_,
        address zu_,
        address xz_,
        uint16 emitBps_,
        uint16 buybackBps_
    ) {
        require(emitBps_ <= 10_000 && buybackBps_ <= 10_000, "BPS");
        x = SoftToken(x_);
        z = SoftToken(z_);
        usdc = MockHardToken(usdc_);
        xu = CPMMPool(xu_);
        zu = CPMMPool(zu_);
        xz = CPMMPool(xz_);
        emitCorrectionBps = emitBps_;
        buybackCorrectionBps = buybackBps_;
        hardRecycleBps = 7_000;
        crossRecycleBps = 5_000;
    }

    function initializePrices() external {
        require(prevPX == 0, "INIT");
        prevPX = xu.spotPrice1Per0Wad();
        prevPZ = zu.spotPrice1Per0Wad();
        prevPXZ = xz.spotPrice1Per0Wad();
    }

    function step() external {
        require(prevPX > 0, "NOT_INIT");

        _controlHard(xu, x, true, prevPX);
        _controlHard(zu, z, false, prevPZ);
        _controlCross(prevPXZ);

        prevPX = xu.spotPrice1Per0Wad();
        prevPZ = zu.spotPrice1Per0Wad();
        prevPXZ = xz.spotPrice1Per0Wad();
    }

    function _controlHard(
        CPMMPool pool,
        SoftToken soft,
        bool isX,
        uint256 previousPrice
    ) internal {
        uint256 currentPrice = pool.spotPrice1Per0Wad();

        if (currentPrice > previousPrice) {
            uint256 target = currentPrice
                - (currentPrice - previousPrice) * emitCorrectionBps / BPS;
            uint256 amountSoft = _softInToTarget(pool, target);
            if (amountSoft == 0) return;

            soft.mint(address(this), amountSoft);
            if (isX) mintedX += amountSoft;
            else mintedZ += amountSoft;

            soft.approve(address(pool), amountSoft);
            uint256 hardOut = pool.swapExactIn(
                address(soft),
                amountSoft,
                0,
                address(this)
            );

            uint256 reinvest = hardOut * hardRecycleBps / BPS;
            if (reinvest > 0) {
                uint256 rSoft = pool.reserve0();
                uint256 rHard = pool.reserve1();
                uint256 softNeeded = reinvest * rSoft / rHard;
                soft.mint(address(this), softNeeded);
                if (isX) mintedX += softNeeded;
                else mintedZ += softNeeded;

                soft.approve(address(pool), softNeeded);
                usdc.approve(address(pool), reinvest);
                pool.addLiquidity(softNeeded, reinvest, address(this));
            }
        } else if (currentPrice < previousPrice) {
            uint256 treasury = usdc.balanceOf(address(this));
            if (treasury == 0) return;

            uint256 target = currentPrice
                + (previousPrice - currentPrice) * buybackCorrectionBps / BPS;
            uint256 hardIn = _hardInToTarget(pool, target);
            if (hardIn > treasury) hardIn = treasury;
            if (hardIn == 0) return;

            usdc.approve(address(pool), hardIn);
            uint256 softOut = pool.swapExactIn(
                address(usdc),
                hardIn,
                0,
                address(this)
            );
            soft.burn(softOut);

            if (isX) burnedX += softOut;
            else burnedZ += softOut;
        }
    }

    function _controlCross(uint256 previousPrice) internal {
        uint256 currentPrice = xz.spotPrice1Per0Wad();

        if (currentPrice > previousPrice) {
            uint256 target = currentPrice
                - (currentPrice - previousPrice) * emitCorrectionBps / BPS;
            uint256 amountX = _softInToTarget(xz, target);
            if (amountX == 0) return;

            x.mint(address(this), amountX);
            mintedX += amountX;
            x.approve(address(xz), amountX);
            uint256 zOut = xz.swapExactIn(
                address(x),
                amountX,
                0,
                address(this)
            );

            uint256 reinvest = zOut * crossRecycleBps / BPS;
            if (reinvest > 0) {
                uint256 rX = xz.reserve0();
                uint256 rZ = xz.reserve1();
                uint256 xNeeded = reinvest * rX / rZ;
                x.mint(address(this), xNeeded);
                mintedX += xNeeded;

                x.approve(address(xz), xNeeded);
                z.approve(address(xz), reinvest);
                xz.addLiquidity(xNeeded, reinvest, address(this));
            }
        } else if (currentPrice < previousPrice) {
            uint256 treasuryZ = z.balanceOf(address(this));
            if (treasuryZ == 0) return;

            uint256 target = currentPrice
                + (previousPrice - currentPrice) * buybackCorrectionBps / BPS;
            uint256 zIn = _hardInToTarget(xz, target);
            if (zIn > treasuryZ) zIn = treasuryZ;
            if (zIn == 0) return;

            z.approve(address(xz), zIn);
            uint256 xOut = xz.swapExactIn(
                address(z),
                zIn,
                0,
                address(this)
            );
            x.burn(xOut);
            burnedX += xOut;
        }
    }

    /// @dev Approximate amount of token0 input required to lower token1/token0 price to target.
    function _softInToTarget(
        CPMMPool pool,
        uint256 targetPrice
    ) internal view returns (uint256) {
        uint256 r0 = pool.reserve0();
        uint256 r1 = pool.reserve1();
        uint256 current = r1 * WAD / r0;
        if (targetPrice >= current || targetPrice == 0) return 0;

        uint256 k = r0 * r1;
        uint256 targetR0 = _sqrt(k * WAD / targetPrice);
        if (targetR0 <= r0) return 0;

        uint256 delta = targetR0 - r0;
        uint256 fee = pool.feeBps();
        return delta * BPS / (BPS - fee);
    }

    /// @dev Approximate amount of token1 input required to raise token1/token0 price to target.
    function _hardInToTarget(
        CPMMPool pool,
        uint256 targetPrice
    ) internal view returns (uint256) {
        uint256 r0 = pool.reserve0();
        uint256 r1 = pool.reserve1();
        uint256 current = r1 * WAD / r0;
        if (targetPrice <= current) return 0;

        uint256 k = r0 * r1;
        uint256 targetR1 = _sqrt(k * targetPrice / WAD);
        if (targetR1 <= r1) return 0;

        uint256 delta = targetR1 - r1;
        uint256 fee = pool.feeBps();
        return delta * BPS / (BPS - fee);
    }

    function hardNav() public view returns (uint256) {
        return xu.reserve1() + zu.reserve1() + usdc.balanceOf(address(this));
    }

    function grossTVL() public view returns (uint256) {
        uint256 pX = xu.spotPrice1Per0Wad();
        uint256 pZ = zu.spotPrice1Per0Wad();

        uint256 hardPools =
            2 * xu.reserve1()
            + 2 * zu.reserve1();

        uint256 crossValue =
            xz.reserve0() * pX / WAD
            + xz.reserve1() * pZ / WAD;

        return hardPools + crossValue;
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
