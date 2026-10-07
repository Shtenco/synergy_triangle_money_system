// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MockHardToken.sol";
import "../src/Treasury.sol";
import "../src/FlashLiquidityLender.sol";

contract Mock3156Borrower is IERC3156FlashBorrower {
    address public immutable lender;

    constructor(address lender_) {
        lender = lender_;
    }

    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        require(msg.sender == lender, "LENDER");
        MockHardToken(token).approve(lender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract FlashLiquidityLenderTest {
    MockHardToken wpol;
    Treasury treasury;
    FlashLiquidityLender lender;
    Mock3156Borrower borrower;

    function setUp() public {
        wpol = new MockHardToken("Wrapped POL", "WPOL");
        treasury = new Treasury();
        lender = new FlashLiquidityLender(address(treasury));
        borrower = new Mock3156Borrower(address(lender));

        treasury.setOperator(address(lender), true);
        lender.setToken(address(wpol), true, 5); // 5 bps

        wpol.mint(address(treasury), 100 ether);
        wpol.mint(address(borrower), 1 ether); // fee buffer
    }

    function testMaxFlashLoanUsesTreasuryBalance() public {
        require(lender.maxFlashLoan(address(wpol)) == 95 ether, "MAX");
    }

    function testFlashLoanReturnsPrincipalAndBooksFee() public {
        uint256 beforeTreasury = wpol.balanceOf(address(treasury));
        uint256 amount = 10 ether;
        uint256 fee = lender.flashFee(address(wpol), amount);

        bool ok = lender.flashLoan(
            borrower,
            address(wpol),
            amount,
            ""
        );
        require(ok, "LOAN");
        require(
            wpol.balanceOf(address(treasury)) == beforeTreasury + fee,
            "TREASURY_FEE"
        );
        require(
            treasury.realizedRevenue(address(wpol)) == fee,
            "REALIZED_FEE"
        );
    }

    function testUnsupportedTokenReturnsZeroMax() public {
        MockHardToken other = new MockHardToken("Other", "OTHER");
        require(lender.maxFlashLoan(address(other)) == 0, "ZERO");
    }
}
