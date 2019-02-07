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
      smartAsset.assignAbilities(store.address, [1]);
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

	it("should send back the good balance", async()=>{
		await store.buyCredit(1,1);
		await store.reserveToken(1, {from:accounts[0]});
		const count = await smartAsset.balanceOf(accounts[0]);
		assert.equal(count, 1);
	})

	it('should send back the good URI after createFor', async()=>{
		await store.buyCredit(1,1);
		await store.reserveToken(1, {from:accounts[0]});
		await smartAsset.createFor(1,web3.utils.keccak256("imprint"), "URI", web3.utils.keccak256("initialKey"), true, {from:accounts[0]});
		const tokenUri = await smartAsset.idToUri(1);
		assert.equal(tokenUri, "URI");
	})

	it('should create a requestable nft', async()=>{
		await store.buyCredit(1,1);
		await store.reserveToken(1, {from:accounts[0]});
		await smartAsset.createFor(1,web3.utils.keccak256("imprint"), "URI", web3.utils.keccak256("initialKey"), true, {from:accounts[0]});
		const isRequestable = await smartAsset.isRequestable(1);
		assert.equal(isRequestable, true);
	})

	it('NFT should be transferable if created as requestable', async()=>{
		await store.buyCredit(1,1);
		await store.reserveToken(1, {from:accounts[0]});
		await smartAsset.createFor(1,web3.utils.keccak256("imprint"), "URI", web3.utils.keccak256("initialKey"), true, {from:accounts[0]});
		await smartAsset.requestFrom(accounts[1], 1, "initialKey");
		const count = await smartAsset.balanceOf(accounts[1]);
		const isRequestable = await smartAsset.isRequestable(1);

		assert.equal(isRequestable, false);
		assert.equal(count, 1);
	})


})