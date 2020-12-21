const { expectRevert } = require('@openzeppelin/test-helpers');

const Access = artifacts.require('Access.sol');

contract('Access', ([deployer, admin, gov, admin1, gov1, gov2]) => {
    beforeEach(async () => {
        this.access = await Access.new(admin, { from: deployer });
    });

    it('should setGovernance successfully', async () => {
        await this.access.setGovernance(gov, {from: admin});

        await expectRevert(
            this.access.setGovernance(gov1, { from: gov1 }),
            '!gov !admin'
        );
        await this.access.setGovernance(gov1, {from: gov});
        await expectRevert(
            this.access.setGovernance(gov2, {from: gov}),
            '!gov !admin'
        );
        await this.access.setGovernance(gov, {from: gov1});
        
    });
});