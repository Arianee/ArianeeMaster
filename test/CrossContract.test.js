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

        store = await ArianeeStore.new(aria.address, smartAsset.address, creditHistory.address, "100000000000000000",10 ,10 ,10);

        smartAsset.assignAbilities(store.address, [2]);
        smartAsset.setStoreAddress(ArianeeStore.address);

        store.setArianeeProjectAddress(accounts[2]);
        store.setProtocolInfraAddress(accounts[3]);
        store.setAuthorizedExchangeAddress(accounts[0]);
        store.setDispatchPercent(10,20,20,40,10);

        creditHistory.setArianeeStoreAddress(store.address);

        whitelist.assignAbilities(smartAsset.address,[2]);

    });

    it('it should refuse to buy credit if you have not enough arias', async () => {

        await aria.approve(store.address, 0, {from: accounts[0]});
        await catchRevert(store.buyCredit(0, 1, accounts[0], {from: accounts[0]}));

        const credit = await creditHistory.balanceOf(accounts[0], 0);
        assert.equal(credit, 0);
    });

    it("should send back the good balance", async () => {
        await aria.approve(store.address, "1000000000000000000", {from: accounts[0]});
        await store.buyCredit(0, 1, accounts[0]);
        await store.reserveToken(1, accounts[0], {from: accounts[0]});

        const count = await smartAsset.balanceOf(accounts[0]);
        assert.equal(count, 1);
    });

    it("should dispatch rewards correctly when buy a certificate", async()=>{
        await aria.transfer(accounts[1],"1000000000000000000", {from:accounts[0]});
        await aria.approve(store.address, "1000000000000000000", {from: accounts[1]});
        await store.buyCredit(0,1, accounts[1],{from:accounts[1]});

        await store.reserveToken(1, accounts[1],{from: accounts[1]});
        await store.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), true, accounts[4], {from:accounts[1]});

        await store.requestToken(1, 'encryptedInitialKey', true, accounts[5], {from:accounts[6]});

        let count = [];
        count[0] = await aria.balanceOf(accounts[0]);
        count[1] = await aria.balanceOf(accounts[1]);
        count[2] = await aria.balanceOf(accounts[2]);
        count[3] = await aria.balanceOf(accounts[3]);
        count[4] = await aria.balanceOf(accounts[4]);
        count[5] = await aria.balanceOf(accounts[5]);
        count[6] = await aria.balanceOf(accounts[6]);

        const storeBalance = await aria.balanceOf(store.address);

        assert.equal(storeBalance, 0);
        assert.equal(count[1], 0);
        assert.equal(count[2], 400000000000000000);
        assert.equal(count[3], 100000000000000000);
        assert.equal(count[4], 200000000000000000);
        assert.equal(count[5], 200000000000000000);
        assert.equal(count[6], 100000000000000000);

    });


});