const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Arianee = artifacts.require('Aria');
const catchRevert = require("./helpers/exceptions.js").catchRevert;

const bigNumber = require('big-number');

contract("Cross Contracts", (accounts) => {

    beforeEach(async () => {
        smartAsset = await ArianeeSmartAsset.new();
        aria = await Arianee.new();
        store = await ArianeeStore.new(aria.address, smartAsset.address);
        smartAsset.assignAbilities(store.address, [1]);
        store.setCreditPrice(1, 1);
    });

    it('should balance the good amount of credit', async () => {
        await aria.approve(store.address, 10, {from: accounts[0]});
        await store.buyCredit(1, 1, {from: accounts[0]});

        const credit = await store.credits(accounts[0], 1);
        assert.equal(credit, 1);
    });

    it('it should refuse to buy credit if you have not enough arias', async () => {
        await aria.approve(store.address, 10, {from: accounts[1]});
        await catchRevert(store.buyCredit(1, 1, {from: accounts[1]}));

        const credit = await store.credits(accounts[0], 1);
        assert.equal(credit, 0);
    });

    it("should send back the good balance", async () => {
        await aria.approve(store.address, 10, {from: accounts[0]});
        await store.buyCredit(1, 1);
        await store.reserveToken(1, {from: accounts[0]});

        const count = await smartAsset.balanceOf(accounts[0]);
        assert.equal(count, 1);
    });


});