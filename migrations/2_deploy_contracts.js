const ACFuns = artifacts.require("ACFuns");
const IUniswapV2Factory = artifacts.require("IUniswapV2Factory");
const IUniswapV2Pair = artifacts.require("IUniswapV2Pair");

const Pool = artifacts.require("Pool")
const Borrower = artifacts.require("Borrower")

const AirdropStrategy = artifacts.require("AirdropStrategy");
const Cellar = artifacts.require("Cellar");
const StakingRewards = artifacts.require("StakingRewards");

const utils = require('./utils')
const { time } = require('@openzeppelin/test-helpers');




const toWei = web3.utils.toWei

const tickerSymbols = ['DAI', 'WETH']

module.exports = async function (deployer, network, accounts) {
    console.log("2_deploy_contracts.js, network: ", network)
    
    if (network == "development") {
        return;
    }
    const admin = accounts[0];

    const acfuns = await deployer.deploy(ACFuns, admin);
    // console.log("ACFuns addr : ", acfuns.address)

    let config =  {
        admin: admin,
        contracts: {
            tokens: {
                ACF: {address: ACFuns.address, decimals: 18}
            },
            pairs:{
                ACF_DAI: ""
            }
        }
    }
    utils.writeContractAddresses(config);
    
    config = loadUnderDifferentDevelopment(network, config);
    
    // create dai_acf swap pair through factory.createPair(), add it to config
    {
        const factory = await IUniswapV2Factory.at(config.contracts.factory);
        let txC = await factory.createPair(config.contracts.tokens.ACF.address, config.contracts.tokens.DAI.address);
        let lp1 = await IUniswapV2Pair.at(txC.logs[0].args.pair)
        config.contracts.pairs.ACF_DAI = lp1.address;
    }


    
    // deploy dai pool of asset for borrow, deploy borrower
    {
        console.log("config.contracts.tokens['DAI'].address = ", config.contracts.tokens['DAI'].address);
        console.log("config.contracts.tokens.ACF.address = ", config.contracts.tokens.ACF.address);

        const daiPool = await deployer.deploy(Pool, 
            admin,
            config.contracts.tokens['DAI'].address,
            config.contracts.tokens.ACF.address,
            {from: admin}
        );
        config.contracts.pools = {}
        config.contracts.pools['DAI'] = {}
        config.contracts.pools['DAI'].address = daiPool.address;

        const daiBorrowerForWeth = await deployer.deploy(Borrower,
            admin,
            config.contracts.tokens['WETH'].address,
            config.contracts.factory,
            config.contracts.pools['DAI'].address,
            {from: admin}
        );
        // config.contracts.pools['DAI'].borrower = daiBorrowerForWeth.address;
        // config.contracts.pools['DAI'].factory = config.contracts.factory;
        // config.contracts.pools['DAI'].pair = await daiBorrowerForWeth.pair();
        config.contracts.pools['DAI']['WETH'] = {
            borrower: daiBorrowerForWeth.address,
            factory: config.contracts.factory,
            pair: await daiBorrowerForWeth.pair()
        }
        // set stakingRewards contract
        const stakingRewards = await deployer.deploy(StakingRewards, 
            admin, 
            config.contracts.tokens.ACF.address,
            config.contracts.pools['DAI']['WETH'].pair,
            {from: admin}
        );
        config.contracts.pools['DAI']['WETH'].stakingRewards = stakingRewards.address;
        console.log("config.contracts.pools['DAI']['WETH'].stakingRewards = ", config.contracts.pools['DAI']['WETH'].stakingRewards)
        await daiBorrowerForWeth.setStakingRewards(
            config.contracts.pools['DAI']['WETH'].stakingRewards,
            {from: admin}
        );
    }
    
    
    
    // create airdrop strategy, cellar and stakingRewards to provide airdrop contract
    {
        const strategy = await deployer.deploy(AirdropStrategy, admin);
        console.log("strategy addr : ", strategy.address)
        // await strategy.setAirdropRatio(
        //     config.contracts.tokens['DAI'].address,
        //     toWei('100', 'ether'), // for add_liquidity, 1 dai will get 100 acf
        //     (await time.latest()).add(time.duration.days(14)), // acf will distributed for 2 weeks
        //     {from: admin}
        // );
        config.contracts.airdropStrategy = strategy.address;
        
        const cellar = await deployer.deploy(Cellar, 
            admin,
            config.contracts.factory,
            config.contracts.tokens.DAI.address,
            config.contracts.tokens.ACF.address,
            config.contracts.airdropStrategy,
            admin,
            '0',
            {from: admin}
        );
        config.contracts.cellars = {};
        config.contracts.cellars.DAI = {
            "address": cellar.address,
            "stakingToken": config.contracts.pairs.ACF_DAI,
            "rewardsToken": config.contracts.tokens.ACF.address,
            "stakingRewards": ""
        };

        const stakingRewards = await deployer.deploy(StakingRewards, 
            admin, 
            config.contracts.tokens.ACF.address,
            config.contracts.pairs.ACF_DAI,
            {from: admin}
        );
        config.contracts.cellars.DAI.stakingRewards = stakingRewards.address;
    }

    utils.writeContractAddresses(config);

};

function loadUnderDifferentDevelopment(network) {
    const config = utils.getContractAddresses();

    if (network == 'development') {
        // deploy Dai, Uniswap, create swap pair, add_liquidity to pair
    } else if(network == "mainnet_fork") {

        // load the above mentioned from deployed.json file
        const deployedConfig = utils.getConfigContractAddresses();
        config.contracts.factory = deployedConfig.mainnet.contracts.factory;
        for (let i = 0; i < tickerSymbols.length; i++) {
            config.contracts.tokens[tickerSymbols[i]] = {
                address: deployedConfig.mainnet.contracts.tokens[tickerSymbols[i]].address,
                decimals: deployedConfig.mainnet.contracts.tokens[tickerSymbols[i]].decimals,
            }
        }
        config.contracts.router = deployedConfig.mainnet.contracts.router;
        
    }
    return config;
    
}