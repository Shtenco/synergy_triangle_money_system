// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EconomicModel {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    function hardCreditCapacityWad(
        uint256 deployBps,
        uint256 collateralFactorBps,
        uint256 reuseBps
    ) public pure returns (uint256) {
        require(deployBps <= 8_000, "DEPLOY");
        require(collateralFactorBps <= 8_000, "CF");
        require(reuseBps <= 6_500, "REUSE");

        return WAD
            * deployBps / BPS
            * collateralFactorBps / BPS
            * reuseBps / BPS;
    }

    function primaryLpTvlMultiplierWad(
        uint256 deployBps
    ) public pure returns (uint256) {
        require(deployBps <= 8_000, "DEPLOY");
        return 2 * WAD * deployBps / BPS;
    }

    function oneCycleHardNavMultiplierWad(
        uint256 yieldBps,
        uint256 utilizationBps,
        uint256 creditInterestBps,
        uint256 deployBps,
        uint256 collateralFactorBps,
        uint256 reuseBps
    ) public pure returns (uint256) {
        require(yieldBps <= 5_000, "YIELD");
        require(utilizationBps <= BPS, "UTIL");
        require(creditInterestBps <= 10_000, "INTEREST");

        uint256 creditCap = hardCreditCapacityWad(
            deployBps,
            collateralFactorBps,
            reuseBps
        );

        uint256 yieldIncome = WAD * yieldBps / BPS;
        uint256 creditIncome = creditCap
            * utilizationBps / BPS
            * creditInterestBps / BPS;

        return WAD + yieldIncome + creditIncome;
    }

    function aggressiveStressSafeCreditCapacityWad()
        external
        pure
        returns (uint256)
    {
        return hardCreditCapacityWad(8_000, 8_000, 6_500);
    }

    function baseOneCycleMultiplierWad()
        external
        pure
        returns (uint256)
    {
        // Scenario only:
        // 1% realized hard yield per economic cycle,
        // 80% credit utilization,
        // 5% hard-denominated interest per credit cycle.
        return oneCycleHardNavMultiplierWad(
            100,
            8_000,
            500,
            8_000,
            8_000,
            6_500
        );
    }

    function hardNavAfterRetainedInput(
        uint256 initialHard,
        uint256 incomingHard
    ) external pure returns (uint256) {
        return initialHard + incomingHard;
    }
}
