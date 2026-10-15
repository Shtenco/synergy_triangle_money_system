// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Research-only helper for pre- and post-swap oracle-bound execution.
/// @dev Never use the same pool as both oracle and exchange. No price feed means
///      this cannot provide arbitrage protection. NOT AUDITED.
interface IExternalPriceV6 {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256 startedAt,
        uint256 updatedAt, uint80 answeredInRound
    );
}

library OracleBandPolicyV6 {
    error InvalidOracle();
    error StaleOracle();
    error OutsideBand(uint256 poolSpotWad, uint256 externalWad);

    function readPriceWad(IExternalPriceV6 feed, uint256 maxAge)
        internal view returns (uint256 result)
    {
        uint8 d = feed.decimals();
        if (d > 18 || maxAge == 0) revert InvalidOracle();
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();
        if (updatedAt == 0 || updatedAt > block.timestamp
            || block.timestamp - updatedAt > maxAge
            || answeredInRound < roundId) revert StaleOracle();
        if (answer <= 0 || uint256(answer) > 1e30) revert InvalidOracle();
        result = uint256(answer) * (10 ** (18 - d));
    }

    /// @dev For a 1.5% sell fee a 1% premium band gives
    ///      1.01 * (1 - .015) = .99485 <= 1 market quote,
    ///      assuming an honest, executable independent market reference.
    ///      Trade is rejected unless BOTH current and resulting spots fit.
    function enforce(IExternalPriceV6 feed, uint256 maxAge,
                     uint256 bps, uint256 beforeSpotWad,
                     uint256 afterSpotWad) internal view {
        if (bps == 0 || bps > 100) revert InvalidOracle();
        uint256 externalPrice = readPriceWad(feed, maxAge);
        uint256 floor = externalPrice * (10000 - bps) / 10000;
        uint256 ceiling = externalPrice * (10000 + bps) / 10000;
        if (beforeSpotWad < floor || beforeSpotWad > ceiling)
            revert OutsideBand(beforeSpotWad, externalPrice);
        if (afterSpotWad < floor || afterSpotWad > ceiling)
            revert OutsideBand(afterSpotWad, externalPrice);
    }
}
