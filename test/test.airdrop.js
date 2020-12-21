const { expectRevert, time } = require('@openzeppelin/test-helpers');

const AirdropStrategy = artifacts.require('AirdropStrategy');
const TestToken = artifacts.require('TestToken');

contract('AirdropStrategy', ([deployer, admin, gov, alice]) => {
    beforeEach(async () => {
        this.as = await AirdropStrategy.new(admin, { from: deployer });
        this.tt = await TestToken.new("Token1", "T1", 18, admin, {from: deployer});
    });

    it('should setAirdropRatio successfully', async () => {
        
        await this.as.setGovernance(gov, {from: admin});
        
        assert.equal(await this.as.governance(), gov);
        

        await this.as.setAirdropRatio(
            this.tt.address, 
            web3.utils.toWei('100', 'ether'), 
            (await time.latest()).add(time.duration.days(14)),
            {from: gov}
        );

        let amt;
        amt = await this.as.getAirdropAmount(this.tt.address, web3.utils.toWei('1', 'ether'));
        assert.equal(amt.valueOf(), web3.utils.toWei('100', 'ether'))

        await time.increase(time.duration.days(15));

        amt = await this.as.getAirdropAmount(this.tt.address, web3.utils.toWei('1', 'ether'));
        assert.equal(amt.valueOf(), '0')
        
    });
});