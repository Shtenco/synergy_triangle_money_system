// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EconomicModel {
    uint256 internal constant WAD=1e18;
    uint256 internal constant BPS=10000;

    function baselineDeployedWad() public pure returns(uint256 deployed,uint256 secondary){
        uint256 primary=0.5e18;
        uint256 first=primary*6500/BPS*5000/BPS;
        uint256 ratio=WAD*6500/BPS*5000/BPS*2500/BPS;
        secondary=first*WAD/(WAD-ratio);
        deployed=primary+secondary;
        uint256 maxDeploy=0.8e18;
        if(deployed>maxDeploy)deployed=maxDeploy;
    }

    function multiplierWad(uint256 turnoverXWad) public pure returns(uint256){
        (uint256 deployed,)=baselineDeployedWad();
        uint256 tvlPerHard=2*deployed;
        uint256 volumePerHard=tvlPerHard*turnoverXWad/WAD;
        uint256 q=volumePerHard*27/BPS;
        require(q<WAD,"UNSTABLE");
        return WAD*WAD/(WAD-q);
    }

    function scenario50Plus50At75x() external pure returns(uint256 finalHardNavWad){
        uint256 m=multiplierWad(75e18);
        finalHardNavWad=50e18+50e18*m/WAD;
    }
}
