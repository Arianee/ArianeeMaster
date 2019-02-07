const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const catchRevert = require("./helpers/exceptions.js").catchRevert;

contract("ArianeeSmartAsset", (accounts) => {
  beforeEach(async () => {
      smartAsset = await ArianeeSmartAsset.new();
    });

  it('should returns correct balanceOf after createFor', async () => {
      //await smartAsset.createFor(accounts[0], "test");
      const count = await smartAsset.balanceOf(accounts[0]);
      console.log(count);
      assert.equal(count.toNumber(), 1);
    });

  it('should return correct BalanceOf and good encrypted', async()=>{
    await smartAsset.createForWithToken(accounts[0], "test", web3.utils.keccak256("key"))
    const count = await smartAsset.balanceOf(accounts[0]);
    const encrypted =  await smartAsset.encryptedTokenKey(count)
    const authorized = await smartAsset.isTokenRequestable(count)
      assert.equal(count.toNumber(), 1);
      assert.equal(encrypted, web3.utils.keccak256("key"));
      assert.equal(authorized, true);
  })

  it('a new token with encrypted Key should be requestable', async()=>{
    const transaction = await smartAsset.createForWithToken(accounts[0], "test", web3.utils.keccak256("key"));
    const tokenId = transaction.logs[0].args._tokenId.toString();
    const isRequestable = await smartAsset.isRequestable(tokenId);
    assert.equal(isRequestable, true);
  })

  it('a new token without encrypted Key should not be requestable', async()=>{
    const transaction = await smartAsset.createFor(accounts[0], "test");
    const tokenId = transaction.logs[0].args._tokenId.toString();
    const isRequestable = await smartAsset.isRequestable(tokenId);
    assert.equal(isRequestable, false);
  })

  it('should set a token requestable after passe encrypted key', async()=>{
    const transaction = await smartAsset.createFor(accounts[0], "test");
    const tokenId = transaction.logs[0].args._tokenId.toString();
    await smartAsset.setRequestable(tokenId, web3.utils.keccak256("key"), true);
    const isRequestable = await smartAsset.isRequestable(tokenId);
    assert.equal(isRequestable, true);
  })

  it('should remove requestable after setrequestable(,,false)', async()=>{
    const transaction = await smartAsset.createForWithToken(accounts[0], "test", web3.utils.keccak256("key"));
    const tokenId = transaction.logs[0].args._tokenId.toString();
    await smartAsset.setRequestable(tokenId, web3.utils.keccak256("key"), false);
    const isRequestable = await smartAsset.isRequestable(tokenId);
    assert.equal(isRequestable, false);
  })

  it('should not possible to make a token requestable if not owner', async()=>{
    const transaction = await smartAsset.createFor(accounts[0], "test");
    const tokenId = transaction.logs[0].args._tokenId.toString();
    await catchRevert(smartAsset.setRequestable(tokenId, web3.utils.keccak256("key"), true, {from:accounts[1]}));
    const isRequestable = await smartAsset.isRequestable(tokenId);
    assert.equal(isRequestable, false);
  })

  it('should be service after setService', async()=>{
    const transaction = await smartAsset.createFor(accounts[0], "test");
    const tokenId = transaction.logs[0].args._tokenId.toString();
    await smartAsset.setService(tokenId, web3.utils.keccak256("key"), true);
    const isService = await smartAsset.isService(tokenId);
    assert.equal(isService, true);
  })
  it('should be possible to set service if not owner', async()=>{
    const transaction = await smartAsset.createFor(accounts[0], "test");
    const tokenId = transaction.logs[0].args._tokenId.toString();
    await catchRevert(smartAsset.setService(tokenId, web3.utils.keccak256("key"), true, {from:accounts[1]}));
    const isService = await smartAsset.isService(tokenId);
    assert.equal(isService, false);
  })



})