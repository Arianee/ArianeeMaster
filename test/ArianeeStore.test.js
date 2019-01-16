const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Arianee = artifacts.require('Arianee');
const catchRevert = require("./helpers/exceptions.js").catchRevert;

const bigNumber = require('big-number');

contract("Cross Contracts", (accounts) => {
	beforeEach(async () => {
      smartAsset = await ArianeeSmartAsset.new();
      aria = await Arianee.new();
      store = await ArianeeStore.new(aria.address, smartAsset.address);
    });

	it('should balance the good amount of credit', async()=>{
		await aria.allocate(accounts[1], 100, 0);
		await aria.approve(store.address, 10, {from: accounts[1]});
		
		await store.setCreditPrice(1,1);
		await store.buyCredit(1,1, {from:accounts[1]});
		const credit = await store.credits(accounts[1],1);
		assert.equal(credit, 1);
	})

	it('it should refuse to buy credit', async()=>{
		await store.setCreditPrice(1,1);
		await catchRevert(store.buyCredit(1,1), 'impossible to buy');
		const credit = await store.credits(accounts[0],1);
		assert.equal(credit,0);
		
	})

	it('should give me the good amount of aria', async()=>{
		await aria.allocate(accounts[1], 200, 0);
		const count = await aria.balances(accounts[1]);
		assert.equal(count, 200);
	})

	it("should send back the token", async()=>{
		await store.buyCredit(1,1);
		await store.createFor(accounts[0], "test");
		const count = await smartAsset.balanceOf(accounts[0]);
		const tokenUri = await smartAsset.tokenURI(1);

		assert.equal(count, 1);
		assert.equal(tokenUri, "test");
	})


})