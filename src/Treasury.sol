// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Treasury {
    function transfer(address,uint256) external returns(bool);
    function transferFrom(address,address,uint256) external returns(bool);
}

contract Treasury {
    address public owner;
    mapping(address=>bool) public operator;
    mapping(address=>uint256) public realizedRevenue;

    modifier onlyOwner(){require(msg.sender==owner,"OWNER");_;}
    modifier onlyOperator(){require(operator[msg.sender],"OP");_;}

    constructor(){owner=msg.sender;operator[msg.sender]=true;}

    function setOperator(address a,bool on) external onlyOwner { operator[a]=on; }

    function depositCapital(address token,uint256 amount) external {
        require(IERC20Treasury(token).transferFrom(msg.sender,address(this),amount),"PULL");
    }

    function depositExternalRevenue(address token,uint256 amount) external {
        require(IERC20Treasury(token).transferFrom(msg.sender,address(this),amount),"PULL");
        realizedRevenue[token]+=amount;
    }

    function move(address token,address to,uint256 amount) external onlyOperator {
        require(IERC20Treasury(token).transfer(to,amount),"MOVE");
    }

    function payDividend(address token,address to,uint256 amount) external onlyOperator {
        require(realizedRevenue[token]>=amount,"NO_REVENUE");
        realizedRevenue[token]-=amount;
        require(IERC20Treasury(token).transfer(to,amount),"PAY");
    }
}
