const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');

contract("ArianeeSmartAsset", (accounts) => {
  beforeEach(async () => {
      smartAsset = await ArianeeSmartAsset.new();
    });

it('returns correct balanceOf after createFor', async () => {
    await smartAsset.createFor(accounts[0], "test");
    const count = await smartAsset.balanceOf(accounts[0]);
    assert.equal(count.toNumber(), 1);
  });

it('should return correctBalance Of and good encrypted', async()=>{
  await smartAsset.createForWithToken(accounts[0], "test", web3.utils.keccak256("test"))
  const count = await smartAsset.balanceOf(accounts[0]);
  const encrypted =  await smartAsset.encryptedTokenKey(count)
  const authorized = await smartAsset.isTokenRequestable(count)
    assert.equal(count.toNumber(), 1);
    assert.equal(encrypted, web3.utils.keccak256("test"));
    assert.equal(authorized, true);
})


})