const IWETH = artifacts.require("IWETh");
const ACFuns = artifacts.require("ACFuns");
const IUniswapV2Factory = artifacts.require("IUniswapV2Factory");
const IUniswapV2Router = artifacts.require("IUniswapV2Router")
const IUniswapV2Pair = artifacts.require("IUniswapV2Pair");
const TestToken = artifacts.require("TestToken")
const Pool = artifacts.require("Pool")
const Borrower = artifacts.require("Borrower")

const AirdropStrategy = artifacts.require("AirdropStrategy");
const Cellar = artifacts.require("Cellar");
const StakingRewards = artifacts.require("StakingRewards");

const utils = require('../migrations/utils');
const { time } = require('@openzeppelin/test-helpers');

async function getArtifacts() {
    const config = utils.getContractAddresses();

    const [acf, dai, weth, acf_dai, factory, router, airdropStrategy,
        pool_dai, borrower_weth, borrower_factory, borrower_pair, borrower_stakingRewards,
        cellar_dai, cellar_staking] = await Promise.all([
        ACFuns.at(config.contracts.tokens.ACF.address),
        TestToken.at(config.contracts.tokens.DAI.address),
        TestToken.at(config.contracts.tokens.WETH.address),
        IUniswapV2Pair.at(config.contracts.pairs.ACF_DAI),
        IUniswapV2Factory.at(config.contracts.factory),
        IUniswapV2Router.at(config.contracts.router),
        AirdropStrategy.at(config.contracts.airdropStrategy),
        Pool.at(config.contracts.pools.DAI.address),
        Borrower.at(config.contracts.pools.DAI.WETH.borrower),
        IUniswapV2Factory.at(config.contracts.pools.DAI.WETH.factory),
        IUniswapV2Pair.at(config.contracts.pools.DAI.WETH.pair),
        StakingRewards.at(config.contracts.pools.DAI.WETH.stakingRewards),

        Cellar.at(config.contracts.cellars.DAI.address),
        StakingRewards.at(config.contracts.cellars.DAI.stakingRewards)
    ]);
    res = {
        acf,
        dai,
        weth,
        acf_dai,
        factory,
        router,
        airdropStrategy,
        pools: {
            dai: {
                pool: pool_dai,
                borrower: borrower_weth,
                factory: borrower_factory,
                pair: borrower_pair,
                stakingRewards: borrower_stakingRewards
            }
        },
        cellars: {
            dai: {
                cellar: cellar_dai,
                stakingToken: acf_dai,
                rewardsToken: acf,
                stakingRewards: cellar_staking
            }
        }
    }

    return res;

}

async function swapEthTo(to, amount, account) {
    const config = utils.getContractAddresses();
    let weth = await IWETH.at(config.contracts.tokens.WETH.address);
    await weth.deposit({from: account, value: amount})
    let factory = await IUniswapV2Factory(config.contracts.factory);
    // let pairAddr = await factory.getPair(weth.address, to);
    // let pair = await IUniswapV2Pair.at(pairAddr);
    await weth.approve(config.contracts.router, amount, {from: account});
    let router = await IUniswapV2Router.at(config.contracts.router);
    let amountOut = await router.getAmountsOut(amount, [weth.address, to]);
    let deadline = (await time.latest()).add(time.duration.days(1));
    await router.swapTokensForExactTokens(amountOut[1], amount, [weth.address, to], account, deadline, {from: account});
    let tt = await TestToken.at(to);
    console.log("to token name", await tt.name());
    console.log("to acct  bala:", (await tt.balanceOf(account)).toString())
}

module.exports = {
    getArtifacts,
    swapEthTo
}