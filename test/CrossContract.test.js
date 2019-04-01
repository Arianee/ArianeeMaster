const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Arianee = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const catchRevert = require("./helpers/exceptions.js").catchRevert;

const bigNumber = require('big-number');

contract("Cross Contracts", (accounts) => {
    let smartAsset, aria, store, whitelist, creditHistory;
    beforeEach(async () => {
        whitelist = await Whitelist.new();
        creditHistory = await CreditHistory.new();
        aria = await Arianee.new();

        smartAsset = await ArianeeSmartAsset.new(whitelist.address);
        store = await ArianeeStore.new(aria.address, smartAsset.address, creditHistory.address);

        smartAsset.assignAbilities(store.address, [1]);

        store.setArianeeProjectAddress(accounts[2]);
        store.setProtocolInfraAddress(accounts[3]);
        store.setAuthorizedExchangeAddress(accounts[0]);
        store.setAriaUSDExchange(10); // 10 Aria = 0.01$
        store.setCreditPrice(0, 10);
        store.setCreditPrice(1, 10);
        store.setCreditPrice(2, 10);

        creditHistory.changeArianeeStoreAddress(store.address);

        whitelist.assignAbilities(smartAsset.address,[1]);
    });

    it('it should refuse to buy credit if you have not enough arias', async () => {
        await aria.approve(store.address, 10, {from: accounts[0]});
        await catchRevert(store.buyCredit(1, 1, {from: accounts[0]}));

        const credit = await store.credits(accounts[0], 1);
        assert.equal(credit, 0);
    });

    it("should send back the good balance", async () => {
        await aria.approve(store.address, 1000, {from: accounts[0]});
        await store.buyCredit(1, 1);
        await store.reserveToken(1, {from: accounts[0]});

        const count = await smartAsset.balanceOf(accounts[0]);
        assert.equal(count, 1);
    });


});