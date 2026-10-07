// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Rescue {
    function balanceOf(address account) external view returns (uint256);
}

library SafeToken {
    error TokenCallFailed();

    function safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TokenCallFailed();
    }

    function safeApprove(address token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("approve(address,uint256)", spender, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TokenCallFailed();
    }
}

abstract contract OwnerRobotControl {
    using SafeToken for address;

    address public owner;
    address public pendingOwner;
    bool public paused;

    mapping(address => bool) public robots;

    uint256 private _entered;

    event OwnershipTransferStarted(address indexed oldOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event RobotSet(address indexed robot, bool allowed);
    event Paused(bool value);
    event OwnerTokenWithdrawal(address indexed token, address indexed to, uint256 amount);
    event OwnerNativeWithdrawal(address indexed to, uint256 amount);

    error NotOwner();
    error NotRobot();
    error ZeroAddress();
    error PausedError();
    error Reentrancy();
    error NativeTransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRobot() {
        if (!robots[msg.sender]) revert NotRobot();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier nonReentrant() {
        if (_entered == 1) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
    }

    receive() external payable {}

    function setRobot(address robot, bool allowed) external onlyOwner {
        if (robot == address(0)) revert ZeroAddress();
        robots[robot] = allowed;
        emit RobotSet(robot, allowed);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit Paused(value);
    }

    function startOwnershipTransfer(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotOwner();
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    // Emergency withdrawal is owner-only and auto-pauses the contract.
    function ownerWithdrawToken(address token, address to, uint256 amount)
        public
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        paused = true;
        emit Paused(true);
        token.safeTransfer(to, amount);
        emit OwnerTokenWithdrawal(token, to, amount);
    }

    function ownerWithdrawAllToken(address token, address to)
        external
        onlyOwner
        returns (uint256 amount)
    {
        amount = IERC20Rescue(token).balanceOf(address(this));
        ownerWithdrawToken(token, to, amount);
    }

    function ownerWithdrawNative(address payable to, uint256 amount)
        public
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        paused = true;
        emit Paused(true);
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert NativeTransferFailed();
        emit OwnerNativeWithdrawal(to, amount);
    }

    function ownerWithdrawAllNative(address payable to)
        external
        onlyOwner
        returns (uint256 amount)
    {
        amount = address(this).balance;
        ownerWithdrawNative(to, amount);
    }
}
