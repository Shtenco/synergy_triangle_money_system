// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Treasury.sol";

interface IERC20Atomic {
    function balanceOf(address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
}

interface IMorphoFlashSource {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IAaveFlashPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

/// @notice Owner-triggered atomic strategy executor.
/// Targets must be allowlisted. A strategy reverts unless realised hard-token profit
/// remains after external flash-loan repayment/premium.
contract AtomicRevenueExecutor {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    address public owner;
    Treasury public immutable treasury;
    mapping(address => bool) public allowedTarget;

    address private activeMorpho;
    address private activeAavePool;
    address private activeToken;
    uint256 private activeAmount;
    uint256 private activeMinProfit;
    bytes32 private activePlanHash;
    bool private entered;

    event RevenueRealised(
        bytes32 indexed strategyId,
        address indexed token,
        uint256 profit
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

    receive() external payable {}

    function setAllowedTarget(address target, bool allowed) external onlyOwner {
        allowedTarget[target] = allowed;
    }

    function executeMorpho(
        address morpho,
        address token,
        uint256 amount,
        Call[] calldata calls,
        uint256 minProfit,
        bytes32 strategyId
    ) external onlyOwner nonReentrant returns (uint256 profit) {
        _activate(morpho, address(0), token, amount, minProfit, calls);
        uint256 beforeBalance = IERC20Atomic(token).balanceOf(address(this));

        IMorphoFlashSource(morpho).flashLoan(
            token,
            amount,
            abi.encode(calls, strategyId)
        );

        _clear();
        uint256 afterBalance = IERC20Atomic(token).balanceOf(address(this));
        require(afterBalance >= beforeBalance + minProfit, "PROFIT");
        profit = afterBalance - beforeBalance;
        _book(token, profit, strategyId);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == activeMorpho, "MORPHO");
        require(assets == activeAmount, "AMOUNT");

        (Call[] memory calls,) = abi.decode(data, (Call[], bytes32));
        require(keccak256(abi.encode(calls)) == activePlanHash, "PLAN");

        _executeCalls(calls);

        uint256 bal = IERC20Atomic(activeToken).balanceOf(address(this));
        require(bal >= activeAmount + activeMinProfit, "MIN_PROFIT");
        require(
            IERC20Atomic(activeToken).approve(activeMorpho, activeAmount),
            "APPROVE_MORPHO"
        );
    }

    function executeAave(
        address pool,
        address token,
        uint256 amount,
        Call[] calldata calls,
        uint256 minProfit,
        bytes32 strategyId
    ) external onlyOwner nonReentrant returns (uint256 profit) {
        _activate(address(0), pool, token, amount, minProfit, calls);
        uint256 beforeBalance = IERC20Atomic(token).balanceOf(address(this));

        IAaveFlashPool(pool).flashLoanSimple(
            address(this),
            token,
            amount,
            abi.encode(calls, strategyId),
            0
        );

        _clear();
        uint256 afterBalance = IERC20Atomic(token).balanceOf(address(this));
        require(afterBalance >= beforeBalance + minProfit, "PROFIT");
        profit = afterBalance - beforeBalance;
        _book(token, profit, strategyId);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == activeAavePool, "AAVE");
        require(initiator == address(this), "INITIATOR");
        require(asset == activeToken && amount == activeAmount, "ASSET");

        (Call[] memory calls,) = abi.decode(params, (Call[], bytes32));
        require(keccak256(abi.encode(calls)) == activePlanHash, "PLAN");

        _executeCalls(calls);

        uint256 repay = amount + premium;
        uint256 bal = IERC20Atomic(asset).balanceOf(address(this));
        require(bal >= repay + activeMinProfit, "MIN_PROFIT");
        require(IERC20Atomic(asset).approve(msg.sender, repay), "APPROVE_AAVE");
        return true;
    }

    function _activate(
        address morpho,
        address aavePool,
        address token,
        uint256 amount,
        uint256 minProfit,
        Call[] calldata calls
    ) internal {
        require(activeToken == address(0), "ACTIVE");
        activeMorpho = morpho;
        activeAavePool = aavePool;
        activeToken = token;
        activeAmount = amount;
        activeMinProfit = minProfit;
        activePlanHash = keccak256(abi.encode(calls));
    }

    function _clear() internal {
        activeMorpho = address(0);
        activeAavePool = address(0);
        activeToken = address(0);
        activeAmount = 0;
        activeMinProfit = 0;
        activePlanHash = bytes32(0);
    }

    function _executeCalls(Call[] memory calls) internal {
        for (uint256 i = 0; i < calls.length; i++) {
            require(allowedTarget[calls[i].target], "TARGET");
            (bool ok,) = calls[i].target.call{value: calls[i].value}(calls[i].data);
            require(ok, "CALL_FAILED");
        }
    }

    function _book(address token, uint256 profit, bytes32 strategyId) internal {
        if (profit == 0) return;
        require(IERC20Atomic(token).approve(address(treasury), profit), "APPROVE_TREASURY");
        treasury.depositExternalRevenue(token, profit);
        emit RevenueRealised(strategyId, token, profit);
    }
}
