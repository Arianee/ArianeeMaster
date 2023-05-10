const ArianeeSmartAsset = artifacts.require("ArianeeSmartAsset");
const ArianeeStore = artifacts.require("ArianeeStore");
const Aria = artifacts.require("Aria");
const Whitelist = artifacts.require("ArianeeWhitelist");
const CreditHistory = artifacts.require("ArianeeCreditHistory");
const ArianeeEvent = artifacts.require("ArianeeEvent");
const ArianeeIdentity = artifacts.require("ArianeeIdentity");
const ArianeeLost = artifacts.require("ArianeeLost");
const ArianeeMessage = artifacts.require("ArianeeMessage");
const ArianeeUpdate = artifacts.require("ArianeeUpdate");
const ArianeeUserAction = artifacts.require("ArianeeUserAction");

const { GsnTestEnvironment } = require('@opengsn/dev');
const truffleAssert = require('truffle-assertions');

contract("Soulbound", (accounts) => {
  let arianeeSmartAssetInstance,
    ariaInstance,
    arianeeStoreInstance,
    whiteListInstance,
    creditHistoryInstance,
    messageInstance,
    arianeeEventInstance,
    arianeeLost,
    arianeeUpdate,
    arianeeUserAction;

  before(async () => {
    forwarderAddress = (await GsnTestEnvironment.loadDeployment()).forwarderAddress;
    console.log('[Soulbound] Forwarder address: ', forwarderAddress);
  });

  beforeEach(async () => {
    const authorizedExchangeAddress = accounts[0];
    const projectAddress = accounts[2];
    const infraAddress = accounts[3];
    const bouncerAddress = accounts[0];
    const validatorAddress = accounts[0];
    const ownerAddress = accounts[0];
    const lostManager = accounts[0];

    ariaInstance = await Aria.new();
    whiteListInstance = await Whitelist.new(forwarderAddress);
    // This ArianeeSmartAsset contract is deployed WITH the "Soublound" feature
    arianeeSmartAssetInstance = await ArianeeSmartAsset.new(whiteListInstance.address, forwarderAddress, true);
    messageInstance = await ArianeeMessage.new(
      whiteListInstance.address,
      arianeeSmartAssetInstance.address,
      forwarderAddress
    );
    creditHistoryInstance = await CreditHistory.new(forwarderAddress);
    arianeeEventInstance = await ArianeeEvent.new(
      arianeeSmartAssetInstance.address,
      whiteListInstance.address,
      forwarderAddress
    );
    arianeeLost = await ArianeeLost.new(arianeeSmartAssetInstance.address, lostManager, forwarderAddress);
    arianeeUpdate = await ArianeeUpdate.new(arianeeSmartAssetInstance.address, forwarderAddress);
    arianeeUserAction = await ArianeeUserAction.new(
      whiteListInstance.address,
      arianeeSmartAssetInstance.address,
      forwarderAddress
    );

    arianeeStoreInstance = await ArianeeStore.new(
      ariaInstance.address,
      arianeeSmartAssetInstance.address,
      creditHistoryInstance.address,
      arianeeEventInstance.address,
      messageInstance.address,
      arianeeUpdate.address,
      "100000000000000000",
      "10",
      "10",
      "10",
      "10",
      forwarderAddress
    );

    const identityInstance = await ArianeeIdentity.new(bouncerAddress, validatorAddress, forwarderAddress);

    await arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
    await arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
    await arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
    await arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);

    await arianeeSmartAssetInstance.setStoreAddress(arianeeStoreInstance.address);
    await creditHistoryInstance.setArianeeStoreAddress(arianeeStoreInstance.address);
    await arianeeEventInstance.setStoreAddress(arianeeStoreInstance.address);
    await arianeeUpdate.updateStoreAddress(arianeeStoreInstance.address);

    await arianeeSmartAssetInstance.grantAbilities(arianeeStoreInstance.address, [2]);
    await whiteListInstance.grantAbilities(arianeeSmartAssetInstance.address, [2]);
    await whiteListInstance.grantAbilities(arianeeEventInstance.address, [2]);
    await whiteListInstance.grantAbilities(arianeeUserAction.address, [2]);

    await arianeeEventInstance.transferOwnership(ownerAddress);
    await arianeeStoreInstance.transferOwnership(ownerAddress);
    await arianeeSmartAssetInstance.transferOwnership(ownerAddress);
    await creditHistoryInstance.transferOwnership(ownerAddress);

    await messageInstance.setStoreAddress(arianeeStoreInstance.address);
  });

  it("should dispatch rewards correctly", async () => {
    await ariaInstance.transfer(accounts[1], "1000000000000000000", { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, "1000000000000000000", {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[1], { from: accounts[1] });

    await arianeeStoreInstance.reserveToken(1, accounts[1], { from: accounts[1] });
    let account = web3.eth.accounts.create();
    let tokenId = 1;
    let address = accounts[6];
    let encoded = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["uint", "address"], [tokenId, address])
    );
    let signedMessage = account.sign(encoded, account.address);

    await arianeeStoreInstance.hydrateToken(
      tokenId,
      web3.utils.keccak256("imprint"),
      "http://arianee.org",
      account.address,
      Math.floor(Date.now() / 1000) + 2678400,
      true,
      accounts[4],
      { from: accounts[1] }
    );

    await arianeeStoreInstance.methods["requestToken(uint256,bytes32,bool,address,bytes)"](
      tokenId,
      signedMessage.messageHash,
      false,
      accounts[5],
      signedMessage.signature,
      { from: accounts[6] }
    );

    const nftBalance = await arianeeSmartAssetInstance.balanceOf(accounts[6]);
    assert.equal(nftBalance, 1);

    let count = [];
    count[0] = await ariaInstance.balanceOf(accounts[0]);
    count[1] = (await ariaInstance.balanceOf(accounts[1])).toString();
    count[2] = await ariaInstance.balanceOf(accounts[2]);
    count[3] = await ariaInstance.balanceOf(accounts[3]);
    count[4] = (await ariaInstance.balanceOf(accounts[4])).toString();
    count[5] = await ariaInstance.balanceOf(accounts[5]);
    count[6] = await ariaInstance.balanceOf(accounts[6]);

    const storeBalance = await ariaInstance.balanceOf(arianeeStoreInstance.address);

    assert.equal(storeBalance, 0);
    assert.equal(count[1], 0);
    assert.equal(count[2], 400000000000000000);
    assert.equal(count[3], 100000000000000000);
    assert.equal(count[4], 200000000000000000);
    assert.equal(count[5], 200000000000000000);
    assert.equal(count[6], 100000000000000000);
  });

  it("should allow transfer if the token is owned by the issuer", async () => {
    await ariaInstance.transfer(accounts[1], "1000000000000000000", { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, "1000000000000000000", {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[1], { from: accounts[1] });

    let tokenId = 2;
    await arianeeStoreInstance.reserveToken(tokenId, accounts[1], { from: accounts[1] });

    let account = web3.eth.accounts.create();
    let address = accounts[6];
    let encoded = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["uint", "address"], [tokenId, address])
    );
    let signedMessage = account.sign(encoded, account.address);

    await arianeeStoreInstance.hydrateToken(
      tokenId,
      web3.utils.keccak256("imprint"),
      "http://arianee.org",
      account.address,
      Math.floor(Date.now() / 1000) + 2678400,
      true,
      accounts[4],
      { from: accounts[1] }
    );

    await arianeeStoreInstance.methods["requestToken(uint256,bytes32,bool,address,bytes)"](
      tokenId,
      signedMessage.messageHash,
      false,
      accounts[5],
      signedMessage.signature,
      { from: accounts[6] }
    );

    const issuerNftBalance = await arianeeSmartAssetInstance.balanceOf(accounts[1]);
    assert.equal(issuerNftBalance, 0);

    const tokenOwner = await arianeeSmartAssetInstance.ownerOf(tokenId);
    assert.equal(tokenOwner, accounts[6]);
  });

  it("should NOT allow transfer if the token is NOT owned by the issuer", async () => {
    await ariaInstance.transfer(accounts[1], "1000000000000000000", { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, "1000000000000000000", {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[1], { from: accounts[1] });

    let tokenId = 3;
    await arianeeStoreInstance.reserveToken(tokenId, accounts[1], { from: accounts[1] });

    let account = web3.eth.accounts.create();
    let address = accounts[6];
    let encoded = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["uint", "address"], [tokenId, address])
    );
    let signedMessage = account.sign(encoded, account.address);

    await arianeeStoreInstance.hydrateToken(
      tokenId,
      web3.utils.keccak256("imprint"),
      "http://arianee.org",
      account.address,
      Math.floor(Date.now() / 1000) + 2678400,
      true,
      accounts[4],
      { from: accounts[1] }
    );

    await arianeeStoreInstance.methods["requestToken(uint256,bytes32,bool,address,bytes)"](
      tokenId,
      signedMessage.messageHash,
      false,
      accounts[5],
      signedMessage.signature,
      { from: accounts[6] }
    );

    const issuerNftBalance = await arianeeSmartAssetInstance.balanceOf(accounts[1]);
    assert.equal(issuerNftBalance, 0);

    const tokenOwner1 = await arianeeSmartAssetInstance.ownerOf(tokenId);
    assert.equal(tokenOwner1, accounts[6]);

    let address2 = accounts[7];
    let encoded2 = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["uint", "address"], [tokenId, address2])
    );
    let signedMessage2 = account.sign(encoded2, account.address);

    await truffleAssert.fails(
      arianeeSmartAssetInstance.addTokenAccess(tokenId, account.address, true, 1, { from: accounts[6] }),
      truffleAssert.ErrorType.REVERT,
      "ArianeeSmartAsset: Only the issuer can add a transfer token access to a soulbound smart asset"
    );

    await truffleAssert.fails(
      arianeeStoreInstance.methods["requestToken(uint256,bytes32,bool,address,bytes)"](
        tokenId,
        signedMessage2.messageHash,
        false,
        accounts[5],
        signedMessage2.signature,
        { from: accounts[7] }
      ),
      truffleAssert.ErrorType.REVERT,
      "ArianeeSmartAsset: Invalid request token"
    );

    const tokenOwner = await arianeeSmartAssetInstance.ownerOf(tokenId);
    assert.equal(tokenOwner, accounts[6]);
  });
});
