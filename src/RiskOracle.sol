// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RiskOracle {
    address public owner;
    mapping(address=>uint256) public pricesWad;
    modifier onlyOwner(){require(msg.sender==owner,"OWNER");_;}
    constructor(){owner=msg.sender;}
    function setPrice(address token,uint256 priceWad) external onlyOwner {require(priceWad>0,"PRICE");pricesWad[token]=priceWad;}
    function price(address token) external view returns(uint256){uint256 p=pricesWad[token];require(p>0,"NO_PRICE");return p;}
}
