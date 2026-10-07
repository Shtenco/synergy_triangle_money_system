// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EconomicModel {
    uint256 internal constant WAD=1e18;
    uint256 internal constant BPS=10000;

    function liquidityMultiplierWad(
        uint256 deployBps,
        uint256 collateralFactorBps,
        uint256 reuseBps,
        uint256 recursiveTierValueBps
    ) public pure returns(uint256 multiplierWad,uint256 recursiveCreditWad){
        require(deployBps<=8000,"DEPLOY");
        require(collateralFactorBps<=8000,"CF");
        require(reuseBps<=6500,"REUSE");
        require(recursiveTierValueBps<=5000,"TIER");

        uint256 deployed=deployBps*WAD/BPS;
        uint256 firstCredit=deployed*collateralFactorBps/BPS*reuseBps/BPS;
        uint256 q=collateralFactorBps*reuseBps*recursiveTierValueBps*WAD/(BPS*BPS*BPS);
        require(q<WAD,"UNSTABLE");

        recursiveCreditWad=firstCredit*WAD/(WAD-q);
        multiplierWad=2*(deployed+recursiveCreditWad);
    }

    function baseline() external pure returns(uint256 m,uint256 credit){
        return liquidityMultiplierWad(8000,6500,5000,2500);
    }

    function aggressiveStressSafe() external pure returns(uint256 m,uint256 credit){
        return liquidityMultiplierWad(8000,8000,6500,2500);
    }

    function hardNavAfterRetainedInput(uint256 initialHard,uint256 incomingHard) external pure returns(uint256){
        return initialHard+incomingHard;
    }

    function hardNavAfterYield(uint256 hardNav,uint256 yieldBps) external pure returns(uint256){
        return hardNav + hardNav*yieldBps/BPS;
    }
}
