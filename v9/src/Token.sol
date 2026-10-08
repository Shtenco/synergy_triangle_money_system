// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Token {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;
    mapping(address => bool) public minter;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    modifier onlyOwner() { require(msg.sender == owner, "OWNER"); _; }
    modifier onlyMinter() { require(minter[msg.sender], "MINTER"); _; }

    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
        owner = msg.sender;
        minter[msg.sender] = true;
    }

    function setMinter(address a, bool on) external onlyOwner { minter[a] = on; }
    function mint(address to, uint256 v) external onlyMinter { totalSupply += v; balanceOf[to] += v; }
    function burn(uint256 v) external { require(balanceOf[msg.sender] >= v, "BAL"); balanceOf[msg.sender] -= v; totalSupply -= v; }
    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s] = v; return true; }
    function transfer(address to, uint256 v) external returns (bool) { _transfer(msg.sender, to, v); return true; }

    function transferFrom(address f, address to, uint256 v) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        require(a >= v, "ALLOW");
        if (a != type(uint256).max) allowance[f][msg.sender] = a - v;
        _transfer(f, to, v);
        return true;
    }

    function _transfer(address f, address to, uint256 v) internal {
        require(to != address(0) && balanceOf[f] >= v, "TRANSFER");
        balanceOf[f] -= v;
        balanceOf[to] += v;
    }
}
