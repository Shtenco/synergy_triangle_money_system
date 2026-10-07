// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SoftToken.sol";
import "./Treasury.sol";

interface IERC20HardRevenue {
    function transferFrom(address,address,uint256) external returns (bool);
    function approve(address,uint256) external returns (bool);
}

interface IHardNavSource {
    function hardNav() external view returns (uint256);
}

contract HardRevenueEngine {
    uint256 public constant BPS = 10_000;

    address public owner;
    address public immutable hardToken;
    SoftToken public immutable rubx;
    SoftToken public immutable rubz;
    Treasury public immutable treasury;
    IHardNavSource public immutable navSource;

    uint16 public deployBps = 8_000;
    uint16 public collateralFactorBps = 8_000;
    uint16 public reuseBps = 6_500;

    mapping(address => bool) public approvedBorrower;
    uint256 public outstandingSoftPrincipal;

    struct Loan {
        address softToken;
        uint256 principal;
        uint256 hardInterestDue;
        bool open;
    }

    mapping(address => Loan) public loanOf;

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER");
        _;
    }

    constructor(
        address hard_,
        address rubx_,
        address rubz_,
        address treasury_,
        address navSource_
    ) {
        owner = msg.sender;
        hardToken = hard_;
        rubx = SoftToken(rubx_);
        rubz = SoftToken(rubz_);
        treasury = Treasury(treasury_);
        navSource = IHardNavSource(navSource_);
    }

    function setBorrower(address borrower, bool on) external onlyOwner {
        approvedBorrower[borrower] = on;
    }

    function setRisk(uint16 deploy_, uint16 cf_, uint16 reuse_) external onlyOwner {
        require(deploy_ <= 8_000, "DEPLOY");
        require(cf_ <= 8_000, "CF");
        require(reuse_ <= 6_500, "REUSE");
        deployBps = deploy_;
        collateralFactorBps = cf_;
        reuseBps = reuse_;
    }

    function creditCapacity() public view returns (uint256) {
        uint256 h = navSource.hardNav();
        return h * deployBps / BPS * collateralFactorBps / BPS * reuseBps / BPS;
    }

    function availableCredit() public view returns (uint256) {
        uint256 cap = creditCapacity();
        return cap > outstandingSoftPrincipal ? cap - outstandingSoftPrincipal : 0;
    }

    function borrowSoft(address soft, uint256 principal, uint16 interestBps) external {
        require(approvedBorrower[msg.sender], "BORROWER");
        require(!loanOf[msg.sender].open, "LOAN_OPEN");
        require(soft == address(rubx) || soft == address(rubz), "SOFT");
        require(principal > 0 && principal <= availableCredit(), "CAPACITY");

        uint256 hardInterest = principal * interestBps / BPS;
        outstandingSoftPrincipal += principal;
        loanOf[msg.sender] = Loan(soft, principal, hardInterest, true);
        SoftToken(soft).mint(msg.sender, principal);
    }

    function repay() external {
        Loan memory loan = loanOf[msg.sender];
        require(loan.open, "NO_LOAN");

        SoftToken soft = SoftToken(loan.softToken);
        require(soft.transferFrom(msg.sender, address(this), loan.principal), "SOFT_PULL");
        soft.burn(loan.principal);

        require(
            IERC20HardRevenue(hardToken).transferFrom(
                msg.sender,
                address(this),
                loan.hardInterestDue
            ),
            "HARD_INTEREST"
        );

        require(
            IERC20HardRevenue(hardToken).approve(
                address(treasury),
                loan.hardInterestDue
            ),
            "APPROVE_TREASURY"
        );

        treasury.depositExternalRevenue(hardToken, loan.hardInterestDue);

        outstandingSoftPrincipal -= loan.principal;
        delete loanOf[msg.sender];
    }

    function accrueExternalYield(uint256 hardAmount) external {
        require(hardAmount > 0, "ZERO");
        require(
            IERC20HardRevenue(hardToken).transferFrom(
                msg.sender,
                address(this),
                hardAmount
            ),
            "YIELD_PULL"
        );
        require(
            IERC20HardRevenue(hardToken).approve(
                address(treasury),
                hardAmount
            ),
            "APPROVE_TREASURY"
        );
        treasury.depositExternalRevenue(hardToken, hardAmount);
    }
}
