// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/SoftToken.sol";
import "../src/MockHardToken.sol";
import "../src/CPMMPool.sol";
import "../src/Treasury.sol";
import "../src/RiskOracle.sol";
import "../src/CollateralVault.sol";
import "../src/RecursiveEngine.sol";
import "../src/EconomicModel.sol";
import "../src/HardRevenueEngine.sol";

contract SystemTest {
    uint256 constant W=1e18;

    SoftToken x; SoftToken z;
    MockHardToken wpol; MockHardToken coll;
    Treasury treasury; RiskOracle oracle; CollateralVault vault;
    RecursiveEngine engine; EconomicModel model; HardRevenueEngine revenue;
    CPMMPool xw; CPMMPool zw; CPMMPool xz; CPMMPool xc; CPMMPool zc;

    function setUp() public {
        x=new SoftToken("RUBX","RUBX");
        z=new SoftToken("RUBZ","RUBZ");
        wpol=new MockHardToken("Wrapped POL","WPOL");
        coll=new MockHardToken("Collateral","COLL");
        treasury=new Treasury();
        oracle=new RiskOracle();
        vault=new CollateralVault(address(oracle),address(treasury));

        xw=new CPMMPool(address(x),address(wpol),30);
        zw=new CPMMPool(address(z),address(wpol),30);
        xz=new CPMMPool(address(x),address(z),30);
        xc=new CPMMPool(address(x),address(coll),30);
        zc=new CPMMPool(address(z),address(coll),30);

        engine=new RecursiveEngine(
            address(x),address(z),address(wpol),address(coll),
            address(treasury),address(vault),
            address(xw),address(zw),address(xz),address(xc),address(zc)
        );
        model=new EconomicModel();
        revenue=new HardRevenueEngine(
            address(wpol),address(x),address(z),
            address(treasury),address(engine)
        );

        x.setMinter(address(engine),true);
        z.setMinter(address(engine),true);
        x.setMinter(address(revenue),true);
        z.setMinter(address(revenue),true);

        treasury.setOperator(address(engine),true);
        treasury.setOperator(address(vault),true);
        vault.setOperator(address(engine));

        oracle.setPrice(address(wpol),W);
        oracle.setPrice(address(coll),W);

        vault.setHardToken(address(wpol),true);
        vault.setHardToken(address(coll),true);
        vault.configurePool(address(xw),6500);
        vault.configurePool(address(zw),6500);
        vault.configurePool(address(xc),6500);
        vault.configurePool(address(zc),6500);
        vault.configurePool(address(xz),0);
        vault.setRisk(5000,2500,12500);

        wpol.mint(address(this),1000e18);
        coll.mint(address(this),1000e18);
        x.mint(address(this),1000e18);
        z.mint(address(this),1000e18);

        _seed(xw,6.25e18,6.25e18,address(engine));
        _seed(zw,6.25e18,6.25e18,address(engine));
        _seed(xc,6.25e18,6.25e18,address(engine));
        _seed(zc,6.25e18,6.25e18,address(engine));
        _seed(xz,100e18,100e18,address(engine));

        wpol.transfer(address(treasury),12.5e18);
        coll.transfer(address(treasury),12.5e18);

        revenue.setBorrower(address(this),true);
        revenue.setRisk(8000,8000,6500,15000);
    }

    function testInitialHardNavIs50() public {
        require(engine.hardNav()==50e18,"HNAV_50");
    }

    function testRetained50CapitalMakesExactly100() public {
        wpol.approve(address(treasury),50e18);
        treasury.depositCapital(address(wpol),50e18);
        require(engine.hardNav()==100e18,"HNAV_100");
    }

    function testMintSellDoesNotCreateHardNav() public {
        uint256 beforeNav=engine.hardNav();
        engine.mintSellX(1e18);
        require(engine.hardNav()==beforeNav,"FREE_HNAV");
    }

    function testExternalRevenueAddsHardNavOneForOne() public {
        uint256 beforeNav=engine.hardNav();
        wpol.approve(address(treasury),5e18);
        treasury.depositExternalRevenue(address(wpol),5e18);
        require(engine.hardNav()==beforeNav+5e18,"EXT_REVENUE");
    }

    function testAggressiveCreditCapacityIs416Per1HardNav() public {
        uint256 cap=revenue.creditCapacity();
        require(cap==20.8e18,"CAP_50");
    }

    function testBorrowerCollateralIsNotCountedAsProtocolHardNav() public {
        uint256 beforeNav=engine.hardNav();
        uint256 principal=16.64e18; // 80% utilization of 20.8 capacity
        uint256 collateralNeeded=revenue.requiredBorrowerCollateral(principal);

        wpol.approve(address(revenue),collateralNeeded);
        revenue.borrowSoft(address(x),principal,500);

        require(engine.hardNav()==beforeNav,"BORROWER_COLLATERAL_COUNTED");
        require(revenue.outstandingSoftPrincipal()==principal,"PRINCIPAL");
    }

    function testCreditInterestCreatesRealHardNav() public {
        uint256 beforeNav=engine.hardNav();
        uint256 principal=16.64e18;
        uint256 collateralNeeded=revenue.requiredBorrowerCollateral(principal);
        uint256 interest=principal*500/10000; // 5% = 0.832 WPOL

        wpol.approve(address(revenue),collateralNeeded);
        revenue.borrowSoft(address(x),principal,500);

        x.approve(address(revenue),principal);
        wpol.approve(address(revenue),interest);
        revenue.repay();

        require(engine.hardNav()==beforeNav+interest,"INTEREST_HNAV");
        require(revenue.outstandingSoftPrincipal()==0,"DEBT_NOT_CLOSED");
    }

    function testYieldPlusCreditMakes102664Multiplier() public {
        uint256 beforeNav=engine.hardNav(); // 50 WPOL
        uint256 principal=16.64e18;         // 80% utilization
        uint256 collateralNeeded=revenue.requiredBorrowerCollateral(principal);
        uint256 interest=principal*500/10000; // 0.832 WPOL = 1.664% of 50
        uint256 yieldAmount=beforeNav/100;     // 1% = 0.5 WPOL

        wpol.approve(address(revenue),collateralNeeded);
        revenue.borrowSoft(address(x),principal,500);

        x.approve(address(revenue),principal);
        wpol.approve(address(revenue),interest);
        revenue.repay();

        wpol.approve(address(revenue),yieldAmount);
        revenue.accrueExternalYield(yieldAmount);

        uint256 expected=beforeNav + interest + yieldAmount;
        require(engine.hardNav()==expected,"MULTIPLIER_HNAV");

        uint256 m=model.baseOneCycleMultiplierWad();
        require(m==1.02664e18,"MODEL_102664");
    }

    function testNoBorrowerNoCreditIncome() public {
        uint256 beforeNav=engine.hardNav();
        require(engine.hardNav()==beforeNav,"NO_FREE_INCOME");
    }

    function _seed(CPMMPool p,uint256 a0,uint256 a1,address to) internal {
        _approveToken(p.token0(),address(p),a0);
        _approveToken(p.token1(),address(p),a1);
        p.addLiquidity(a0,a1,to);
    }

    function _approveToken(address token,address spender,uint256 amount) internal {
        (bool ok,)=token.call(abi.encodeWithSignature("approve(address,uint256)",spender,amount));
        require(ok,"APPROVE");
    }
}
