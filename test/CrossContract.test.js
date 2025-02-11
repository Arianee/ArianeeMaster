const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Aria = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const ArianeeEvent = artifacts.require('ArianeeEvent');
const ArianeeIdentity = artifacts.require('ArianeeIdentity');
const ArianeeLost = artifacts.require('ArianeeLost');
const ArianeeMessage = artifacts.require('ArianeeMessage');
const ArianeeUpdate = artifacts.require('ArianeeUpdate');
const ArianeeUserAction = artifacts.require('ArianeeUserAction');
const ArianeeRewardsHistory = artifacts.require('ArianeeRewardsHistory');

const { expectRevert } = require('@openzeppelin/test-helpers');
// const { GsnTestEnvironment } = require("@opengsn/dev");

contract('CrossContracts', (accounts) => {
  let arianeeSmartAssetInstance,
    ariaInstance,
    arianeeRewardsHistory,
    arianeeStoreInstance,
    whiteListInstance,
    creditHistoryInstance,
    messageInstance,
    arianeeEventInstance,
    arianeeLost,
    arianeeUpdate,
    arianeeUserAction;

  let forwarderAddress = '0x0000000000000000000000000000000000000001';

  const authorizedExchangeAddress = accounts[0];
  const projectAddress = accounts[2];
  const infraAddress = accounts[3];

  const bouncerAddress = accounts[0];
  const validatorAddress = accounts[0];
  const ownerAddress = accounts[0];
  const lostManager = accounts[0];

  async function deployAndConfigureArianeeStore() {
    arianeeStoreInstance = await ArianeeStore.new(
      ariaInstance.address,
      arianeeSmartAssetInstance.address,
      creditHistoryInstance.address,
      arianeeRewardsHistory.address,
      arianeeEventInstance.address,
      messageInstance.address,
      arianeeUpdate.address,
      '100000000000000000',
      '10',
      '10',
      '10',
      '10',
      forwarderAddress
    );

      // Configure ArianeeStore
      await arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
      await arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
      await arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
      await arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);

    // Update ArianeeStore address in all contracts
    await arianeeSmartAssetInstance.setStoreAddress(arianeeStoreInstance.address);
    await creditHistoryInstance.setArianeeStoreAddress(arianeeStoreInstance.address);
    await arianeeEventInstance.setStoreAddress(arianeeStoreInstance.address);
    await arianeeUpdate.updateStoreAddress(arianeeStoreInstance.address);
    await messageInstance.setStoreAddress(arianeeStoreInstance.address);
    await arianeeRewardsHistory.setStoreAddress(arianeeStoreInstance.address);

    // Granting abilities
    await arianeeSmartAssetInstance.grantAbilities(arianeeStoreInstance.address, [2]);

    // Transfer ArianeeStore ownership after deployment and configuration
    await arianeeStoreInstance.transferOwnership(ownerAddress);
  }

  before(async () => {
    // forwarderAddress = (await GsnTestEnvironment.loadDeployment()).forwarderAddress;
    console.log('[CrossContracts] Forwarder address: ', forwarderAddress);
  });

  beforeEach(async () => {
    ariaInstance = await Aria.new();
    whiteListInstance = await Whitelist.new(forwarderAddress);
    // This ArianeeSmartAsset contract is deployed WITHOUT the "Soublound" feature
    arianeeSmartAssetInstance = await ArianeeSmartAsset.new(whiteListInstance.address, forwarderAddress, false);
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

    arianeeRewardsHistory = await ArianeeRewardsHistory.new();

    await ArianeeIdentity.new(bouncerAddress, validatorAddress, forwarderAddress);

    await deployAndConfigureArianeeStore();

    await whiteListInstance.grantAbilities(arianeeSmartAssetInstance.address, [2]);
    await whiteListInstance.grantAbilities(arianeeEventInstance.address, [2]);
    await whiteListInstance.grantAbilities(arianeeUserAction.address, [2]);

    await arianeeEventInstance.transferOwnership(ownerAddress);
    await arianeeSmartAssetInstance.transferOwnership(ownerAddress);
    await creditHistoryInstance.transferOwnership(ownerAddress);
  });

  it('it should refuse to buy credit if you have not enough arias', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, 0, { from: accounts[0] });
    try {
      await arianeeStoreInstance.buyCredit(0, 1, accounts[0], { from: accounts[0] });
      assert.equal(true, false);
    } catch (e) {
      const credit = await creditHistoryInstance.balanceOf(accounts[0], 0);
      assert.equal(credit, 0);
    }
  });

  it('should send back the good balance', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, '1000000000000000000', {
      from: accounts[0],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);
    await arianeeStoreInstance.reserveToken(1, accounts[0], { from: accounts[0] });
    const count = await arianeeSmartAssetInstance.balanceOf(accounts[0]);
    assert.equal(count, 1);
  });

  it('should dispatch rewards correctly when hydrating a certificate', async () => {
    await ariaInstance.transfer(accounts[1], '1000000000000000000', { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, '1000000000000000000', {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[1], { from: accounts[1] });

    await arianeeStoreInstance.reserveToken(1, accounts[1], { from: accounts[1] });
    let account = web3.eth.accounts.create();
    let tokenId = 1;
    let address = accounts[6];
    let encoded = web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint', 'address'], [tokenId, address]));
    let signedMessage = account.sign(encoded, account.address);

    await arianeeStoreInstance.hydrateToken(
      1,
      web3.utils.keccak256('imprint'),
      'http://arianee.org',
      account.address,
      Math.floor(Date.now() / 1000) + 2678400,
      true,
      accounts[4],
      { from: accounts[1] }
    );

    let count = [];

    count[2] = await ariaInstance.balanceOf(accounts[2]);
    count[3] = await ariaInstance.balanceOf(accounts[3]);
    count[4] = (await ariaInstance.balanceOf(accounts[4])).toString();

    await arianeeStoreInstance.methods['requestToken(uint256,bytes32,bool,address,bytes)'](
      1,
      signedMessage.messageHash,
      true,
      accounts[5],
      signedMessage.signature,
      { from: accounts[6] }
    );

    const nftBalance = await arianeeSmartAssetInstance.balanceOf(accounts[6]);

    count[0] = await ariaInstance.balanceOf(accounts[0]);
    count[1] = (await ariaInstance.balanceOf(accounts[1])).toString();
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

    assert.equal(nftBalance, 1);
  });

  it('should dispatch rewards correctly when hydrating a certificate that was bought before an ArianeeStore migration', async () => {
    await ariaInstance.transfer(accounts[1], '1000000000000000000', { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, '1000000000000000000', {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1, accounts[1], { from: accounts[1] });
    let account = web3.eth.accounts.create();
    let tokenId = 1;

    await arianeeStoreInstance.hydrateToken(
      tokenId,
      web3.utils.keccak256('imprint'),
      'http://arianee.org',
      account.address,
      Math.floor(Date.now() / 1000) + 2678400,
      true,
      accounts[4],
      { from: accounts[1] }
    );

    let address = accounts[6];
    let encoded = web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint', 'address'], [tokenId, address]));
    let signedMessage = account.sign(encoded, account.address);

    // Update the ArianeeStore contract
    const oldArianeeStoreInstanceAddress = arianeeStoreInstance.address;
    await deployAndConfigureArianeeStore();

    // Migrate the Arias from the old ArianeeStore to the new one
    await arianeeStoreInstance.getAriaFromOldStore(oldArianeeStoreInstanceAddress, { from: accounts[0] });

    let count = [];

    count[2] = await ariaInstance.balanceOf(accounts[2]);
    count[3] = await ariaInstance.balanceOf(accounts[3]);
    count[4] = (await ariaInstance.balanceOf(accounts[4])).toString();

    await arianeeStoreInstance.methods['requestToken(uint256,bytes32,bool,address,bytes)'](
      1,
      signedMessage.messageHash,
      true,
      accounts[5],
      signedMessage.signature,
      { from: accounts[6] }
    );

    const nftBalance = await arianeeSmartAssetInstance.balanceOf(accounts[6]);

    count[0] = await ariaInstance.balanceOf(accounts[0]);
    count[1] = (await ariaInstance.balanceOf(accounts[1])).toString();
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

    assert.equal(nftBalance, 1);
  });


  it('should let owner withdraw aria properly', async () => {
    await ariaInstance.transfer(accounts[1], '1000000000000000000000', { from: accounts[0] });
    await ariaInstance.approve(arianeeStoreInstance.address, '1000000000000000000000', {
      from: accounts[1],
    });
    await arianeeStoreInstance.buyCredit(0, 1000, accounts[1], { from: accounts[1] });
    const balanceBeforeWithdraw = await ariaInstance.balanceOf(accounts[0]);
    await arianeeStoreInstance.withdrawArias('1000000000000000000000', {from:accounts[0]});
    const balanceAfterWithdraw = await ariaInstance.balanceOf(accounts[0]);
    const withdrawAmount = web3.utils.toBN('1000000000000000000000');
    expect(balanceAfterWithdraw.toString()).to.equal(balanceBeforeWithdraw.add(withdrawAmount).toString());
  });

  it.only('should let only owner to withdraw aria', async () => {
    await expectRevert(
      arianeeStoreInstance.withdrawArias('1', { from: accounts[1] }),
      'Ownable: caller is not the owner'
    );
  });

});
