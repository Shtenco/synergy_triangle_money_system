// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SoftToken.sol";
import "./CPMMPool.sol";
import "./Treasury.sol";
import "./CollateralVault.sol";

interface IERC20Engine {
    function balanceOf(address) external view returns(uint256);
    function approve(address,uint256) external returns(bool);
}

contract RecursiveEngine {
    address public owner;
    SoftToken public immutable rubx;
    SoftToken public immutable rubz;
    address public immutable wpol;
    address public immutable coll;
    Treasury public immutable treasury;
    CollateralVault public immutable vault;

    CPMMPool public immutable xwpol;
    CPMMPool public immutable zwpol;
    CPMMPool public immutable xz;
    CPMMPool public immutable xcoll;
    CPMMPool public immutable zcoll;

    uint16 public reserveFloorBps=2000;

    modifier onlyOwner(){require(msg.sender==owner,"OWNER");_;}

    constructor(
        address x,address z,address w,address c,address t,address v,
        address pXW,address pZW,address pXZ,address pXC,address pZC
    ){
        owner=msg.sender; rubx=SoftToken(x); rubz=SoftToken(z); wpol=w; coll=c;
        treasury=Treasury(t); vault=CollateralVault(v);
        xwpol=CPMMPool(pXW); zwpol=CPMMPool(pZW); xz=CPMMPool(pXZ); xcoll=CPMMPool(pXC); zcoll=CPMMPool(pZC);
    }

    function setReserveFloor(uint16 bps) external onlyOwner {require(bps<=5000,"FLOOR");reserveFloorBps=bps;}

    function mintSellX(uint256 amount) external onlyOwner returns(uint256 out){
        uint256 beforeNav=hardNav();
        rubx.mint(address(this),amount);
        rubx.approve(address(xwpol),amount);
        out=xwpol.swapExactIn(address(rubx),amount,0,address(treasury));
        require(hardNav()==beforeNav,"FREE_HARDNAV");
    }

    function mintSellZ(uint256 amount) external onlyOwner returns(uint256 out){
        uint256 beforeNav=hardNav();
        rubz.mint(address(this),amount);
        rubz.approve(address(zwpol),amount);
        out=zwpol.swapExactIn(address(rubz),amount,0,address(treasury));
        require(hardNav()==beforeNav,"FREE_HARDNAV");
    }

    function addInternalXZ(uint256 ax,uint256 az) external onlyOwner returns(uint256 lp){
        rubx.mint(address(this),ax); rubz.mint(address(this),az);
        rubx.approve(address(xz),ax); rubz.approve(address(xz),az);
        lp=xz.addLiquidity(ax,az,address(this));
    }

    function pledgeOwnedLP(address pool,uint256 amount,uint8 tier) external onlyOwner {
        CPMMPool(pool).approve(address(vault),amount);
        vault.pledge(pool,amount,tier);
    }

    function drawAndAddHardLP(address pool,address hard,uint256 hardAmount,bool useX,uint8 tier) external onlyOwner returns(uint256 lp){
        uint256 beforeNav=hardNav();
        vault.draw(hard,hardAmount,address(this));
        require(freeTreasuryHard()*10000>=beforeNav*reserveFloorBps,"RESERVE_FLOOR");

        CPMMPool p=CPMMPool(pool);
        SoftToken soft=useX?rubx:rubz;
        uint256 softAmount;
        if(p.token0()==address(soft)) softAmount=hardAmount*p.reserve0()/p.reserve1();
        else softAmount=hardAmount*p.reserve1()/p.reserve0();

        soft.mint(address(this),softAmount);

        uint256 a0=p.token0()==hard?hardAmount:softAmount;
        uint256 a1=p.token1()==hard?hardAmount:softAmount;

        IERC20Engine(p.token0()).approve(pool,a0);
        IERC20Engine(p.token1()).approve(pool,a1);
        lp=p.addLiquidity(a0,a1,address(this));

        p.approve(address(vault),lp);
        vault.pledge(pool,lp,tier);

        require(hardNav()==beforeNav,"FREE_HARDNAV");
    }

    function freeTreasuryHard() public view returns(uint256){
        return IERC20Engine(wpol).balanceOf(address(treasury))+IERC20Engine(coll).balanceOf(address(treasury));
    }

    function hardNav() public view returns(uint256){
        uint256 total=freeTreasuryHard();
        total+=IERC20Engine(wpol).balanceOf(address(vault))+IERC20Engine(coll).balanceOf(address(vault));
        total+=IERC20Engine(wpol).balanceOf(address(this))+IERC20Engine(coll).balanceOf(address(this));
        total+=IERC20Engine(wpol).balanceOf(address(xwpol))+IERC20Engine(wpol).balanceOf(address(zwpol));
        total+=IERC20Engine(coll).balanceOf(address(xcoll))+IERC20Engine(coll).balanceOf(address(zcoll));
        return total;
    }
}
