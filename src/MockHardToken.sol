// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockHardToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s) { name = n; symbol = s; }

    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s] = v; return true; }
    function transfer(address to, uint256 v) external returns (bool) { _transfer(msg.sender, to, v); return true; }
    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        uint256 a = allowance[f][msg.sender]; require(a >= v, "ALLOW");
        if (a != type(uint256).max) allowance[f][msg.sender] = a - v;
        _transfer(f, t, v); return true;
    }
    function mint(address to, uint256 v) external { totalSupply += v; balanceOf[to] += v; }
    function _transfer(address f, address t, uint256 v) internal {
        require(t != address(0) && balanceOf[f] >= v, "TRANSFER");
        balanceOf[f] -= v; balanceOf[t] += v;
    }
}
