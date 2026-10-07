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

contract SystemTest {
    uint256 constant W=1e18;

    SoftToken x; SoftToken z;
    MockHardToken wpol; MockHardToken coll;
    Treasury treasury; RiskOracle oracle; CollateralVault vault; RecursiveEngine engine; EconomicModel model;
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

        engine=new RecursiveEngine(address(x),address(z),address(wpol),address(coll),address(treasury),address(vault),address(xw),address(zw),address(xz),address(xc),address(zc));
        model=new EconomicModel();

        x.setMinter(address(engine),true);
        z.setMinter(address(engine),true);
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
    }

    function testInitialHardNavIs50() public { require(engine.hardNav()==50e18,"HNAV_50"); }

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

    function testBaseLiquidityMultiplier() public {
        (uint256 m,uint256 credit)=model.baseline();
        require(m>2165e15 && m<2167e15,"BASE_M");
        require(credit>282e15 && credit<284e15,"BASE_C");
    }

    function testAggressiveStressSafeLiquidityMultiplier() public {
        (uint256 m,uint256 credit)=model.aggressiveStressSafe();
        require(m>2556e15 && m<2557e15,"AGG_M");
        require(credit>478e15 && credit<479e15,"AGG_C");
    }

    function testHardNavYieldIsSeparateFromLiquidityMultiplier() public {
        require(model.hardNavAfterRetainedInput(50e18,50e18)==100e18,"INPUT");
        require(model.hardNavAfterYield(100e18,1000)==110e18,"YIELD");
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
