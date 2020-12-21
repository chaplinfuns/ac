const { expectRevert } = require('@openzeppelin/test-helpers');

const ACFuns = artifacts.require('ACFuns.sol');

contract('ACFuns', ([deployer, owner, alice]) => {
    beforeEach(async () => {
        this.acf = await ACFuns.new(owner, { from: deployer });
    });

    it('should mint successfully', async () => {
        let o = await this.acf.owner();
        assert.equal(o, owner)

        await this.acf.mint(alice, web3.utils.toWei('10000', 'ether'), {from: owner})
        
        await expectRevert(
            this.acf.mint(alice, web3.utils.toWei('10000', 'ether'), { from: alice }),
            'Ownable: caller is not the owner'
        );
        await expectRevert(
            this.acf.mint(alice, web3.utils.toWei('99990001', 'ether'), {from: owner}),
            'exceeds max supply'
        );
        
    });
});