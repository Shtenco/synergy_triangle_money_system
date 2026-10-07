// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Vault { function transferFrom(address,address,uint256) external returns(bool); }
interface IPoolVault {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function reserve0() external view returns(uint256);
    function reserve1() external view returns(uint256);
    function totalSupply() external view returns(uint256);
}
interface IOracleVault { function price(address) external view returns(uint256); }
interface ITreasuryVault { function move(address,address,uint256) external; }

contract CollateralVault {
    address public owner;
    address public operator;
    IOracleVault public oracle;
    ITreasuryVault public treasury;

    uint16 public maxReuseBps=5000;
    uint16 public recursiveTierValueBps=2500;
    uint16 public minHealthBps=12500;

    struct PoolConfig { uint16 factorBps; bool enabled; }
    mapping(address=>PoolConfig) public poolConfig;
    mapping(address=>bool) public hardToken;
    mapping(address=>mapping(uint8=>uint256)) public pledgedLP;
    address[] public pools;
    uint256 public internalDebtUsdWad;

    modifier onlyOwner(){require(msg.sender==owner,"OWNER");_;}
    modifier onlyOperator(){require(msg.sender==operator,"OP");_;}

    constructor(address oracle_,address treasury_){
        owner=msg.sender; operator=msg.sender;
        oracle=IOracleVault(oracle_); treasury=ITreasuryVault(treasury_);
    }

    function setOperator(address a) external onlyOwner {operator=a;}
    function setHardToken(address t,bool on) external onlyOwner {hardToken[t]=on;}

    function setRisk(uint16 reuseBps,uint16 recursiveValueBps,uint16 healthBps) external onlyOwner {
        require(reuseBps<=7000 && recursiveValueBps<=5000 && healthBps>=11000,"RISK");
        maxReuseBps=reuseBps; recursiveTierValueBps=recursiveValueBps; minHealthBps=healthBps;
    }

    function configurePool(address p,uint16 factorBps) external onlyOwner {
        require(factorBps<=8000,"FACTOR");
        if(!poolConfig[p].enabled)pools.push(p);
        poolConfig[p]=PoolConfig(factorBps,true);
    }

    function pledge(address p,uint256 amount,uint8 tier) external onlyOperator {
        require(poolConfig[p].enabled && tier<=1,"POOL");
        require(IERC20Vault(p).transferFrom(msg.sender,address(this),amount),"PLEDGE");
        pledgedLP[p][tier]+=amount;
    }

    function eligibleCollateralUsdWad() public view returns(uint256 total){
        for(uint256 i=0;i<pools.length;i++){
            address p=pools[i];
            PoolConfig memory cfg=poolConfig[p];
            uint256 supply=IPoolVault(p).totalSupply();
            if(supply==0)continue;
            uint256 hardUsd=_poolHardUsd(p);
            uint256 primary=hardUsd*pledgedLP[p][0]/supply;
            uint256 recursive=hardUsd*pledgedLP[p][1]/supply;
            uint256 discounted=primary+recursive*recursiveTierValueBps/10000;
            total+=discounted*cfg.factorBps/10000;
        }
    }

    function creditLimitUsdWad() public view returns(uint256){
        return eligibleCollateralUsdWad()*maxReuseBps/10000;
    }

    function healthBps() public view returns(uint256){
        if(internalDebtUsdWad==0)return type(uint256).max;
        return eligibleCollateralUsdWad()*10000/internalDebtUsdWad;
    }

    function draw(address hard,uint256 amount,address to) external onlyOperator {
        require(hardToken[hard],"NOT_HARD");
        uint256 usd=amount*oracle.price(hard)/1e18;
        require(internalDebtUsdWad+usd<=creditLimitUsdWad(),"LIMIT");
        internalDebtUsdWad+=usd;
        require(healthBps()>=minHealthBps,"HF");
        treasury.move(hard,to,amount);
    }

    function _poolHardUsd(address p) internal view returns(uint256 total){
        IPoolVault pool=IPoolVault(p);
        address a=pool.token0(); address b=pool.token1();
        if(hardToken[a]) total+=pool.reserve0()*oracle.price(a)/1e18;
        if(hardToken[b]) total+=pool.reserve1()*oracle.price(b)/1e18;
    }
}
