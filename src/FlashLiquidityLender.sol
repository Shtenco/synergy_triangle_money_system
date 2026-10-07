// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Treasury.sol";

interface IERC20FlashLenderToken {
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function approve(address,uint256) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

/// @notice ERC-3156-compatible flash lender backed by free Treasury hard liquidity.
/// Principal leaves Treasury only intra-transaction and must be returned in the same tx.
/// Only the fee is booked as realised external revenue.
contract FlashLiquidityLender {
    bytes32 public constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    address public owner;
    Treasury public immutable treasury;

    mapping(address => bool) public supportedToken;
    mapping(address => uint16) public feeBps;

    uint16 public maxLoanBps = 9500;
    bool private entered;

    event FlashLoanExecuted(
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER");
        _;
    }

    modifier nonReentrant() {
        require(!entered, "REENTRANCY");
        entered = true;
        _;
        entered = false;
    }

    constructor(address treasury_) {
        owner = msg.sender;
        treasury = Treasury(treasury_);
    }

    function setToken(address token, bool enabled, uint16 feeBps_) external onlyOwner {
        require(feeBps_ <= 100, "FEE_TOO_HIGH"); // <= 1%
        supportedToken[token] = enabled;
        feeBps[token] = feeBps_;
    }

    function setMaxLoanBps(uint16 bps) external onlyOwner {
        require(bps <= 10000, "BPS");
        maxLoanBps = bps;
    }

    function maxFlashLoan(address token) public view returns (uint256) {
        if (!supportedToken[token]) return 0;
        uint256 treasuryBalance =
            IERC20FlashLenderToken(token).balanceOf(address(treasury));
        return treasuryBalance * maxLoanBps / 10_000;
    }

    function flashFee(address token, uint256 amount) public view returns (uint256) {
        require(supportedToken[token], "UNSUPPORTED");
        return amount * feeBps[token] / 10_000;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(supportedToken[token], "UNSUPPORTED");
        require(amount > 0 && amount <= maxFlashLoan(token), "AMOUNT");

        uint256 fee = flashFee(token, amount);

        treasury.move(token, address(receiver), amount);

        bytes32 result = receiver.onFlashLoan(
            msg.sender,
            token,
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "CALLBACK");

        require(
            IERC20FlashLenderToken(token).transferFrom(
                address(receiver),
                address(this),
                amount + fee
            ),
            "REPAY"
        );

        require(
            IERC20FlashLenderToken(token).transfer(
                address(treasury),
                amount
            ),
            "RETURN_PRINCIPAL"
        );

        if (fee > 0) {
            require(
                IERC20FlashLenderToken(token).approve(
                    address(treasury),
                    fee
                ),
                "APPROVE_FEE"
            );
            treasury.depositExternalRevenue(token, fee);
        }

        emit FlashLoanExecuted(address(receiver), token, amount, fee);
        return true;
    }
}
