const { expectRevert, time } = require('@openzeppelin/test-helpers');

const utils = require('./utils.js')

const toWei = web3.utils.toWei

contract('Cellar', ([admin, gov, alice]) => {
    beforeEach(async () => {
        const artifacts = await utils.getArtifacts();
        Object.assign(this, artifacts);
        console.log("cellars.dai.cellar.address = ", this.cellars.dai.cellar.address)
        await this.cellars.dai.cellar.setGovernance(gov, {from: admin})
        await this.cellars.dai.cellar.setStakingRewards(this.cellars.dai.stakingRewards.address, {from: gov})
        // for cellar airdrop usage
        await this.acf.mint(this.cellars.dai.cellar.address, toWei('2000000', 'ether'), {from: admin})
        
        await this.airdropStrategy.setGovernance(gov, {from: admin})
        await this.airdropStrategy.setAirdropRatio(this.dai.address, toWei('1', 'ether'), (await time.latest()).add(time.duration.days(14)), {from: gov});

        await this.cellars.dai.stakingRewards.setGovernance(gov, {from: admin});
        await this.cellars.dai.stakingRewards.setApprovedStaker(this.cellars.dai.cellar.address, {from: gov});
    });

    it('should addLiquidity and removeLiquidity successfully', async () => {
        let govAddr = await this.cellars.dai.cellar.governance();
        assert.equal(govAddr, gov)

        // for staking rewards distribution of acf-dai uni pair
        await this.acf.mint(this.cellars.dai.stakingRewards.address, toWei('1000000', 'ether'), {from: admin})
        await this.cellars.dai.stakingRewards.notifyRewardAmount(toWei('1000000', 'ether'), {from: gov});

        // swap ether for dai in uniswap 
        await utils.swapEthTo(this.dai.address, toWei('1', 'ether'), alice)
        let daiAmountToAdd = toWei('1', 'ether');
        await this.dai.approve(this.cellars.dai.cellar.address, daiAmountToAdd, {from: alice});
        await this.cellars.dai.cellar.addLiquidity(daiAmountToAdd, {from: alice});

        await time.increase(time.duration.days(1));
        // 1 / 7* 1000000 ether => 125,000 ether
        await this.cellars.dai.stakingRewards.getReward(alice, {from: alice});
        let aliceAcfBal = await this.acf.balanceOf(alice);
        console.log("aliceAcfBal = ", aliceAcfBal.toString())
        assert.equal(aliceAcfBal.valueOf(), toWei('125000', 'ether'))
        // await this.cellars.dai.cellar.exit({from: alice})
         
    });
});