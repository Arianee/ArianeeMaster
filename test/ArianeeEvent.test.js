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


const { GsnTestEnvironment } = require('@opengsn/dev');
const truffleAssert = require('truffle-assertions');
const { describe } = require('yargs');

contract.only('ArianeeEvent', (accounts) => {
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
      '100',
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

  it('should create the contract', async () => {
    const arianeeEventAddress = arianeeEventInstance.address;
    expect(arianeeEventAddress).to.be.a('string');
  });
      
  it('should create an event successfully', async () => {
          
    // approve aria
    await ariaInstance.approve(arianeeStoreInstance.address, '100000000000000000');
          
    // buy smartasset credit
    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);
          
    // create a smartAsset
    await arianeeStoreInstance.hydrateToken(12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0xa148b056ED8917789F2D6baB8A27A966e86b18e2', 1885113294, true, '0x305051e9a023fe881ee21ca43fd90c460b427caa');
          
          
    // buy event credits
    await arianeeStoreInstance.buyCredit(2, 1, accounts[0]);
          
    // create an event
    await arianeeStoreInstance.createEvent(4234234, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');
          
    const token = await arianeeEventInstance.eventIdToToken(4234234);
          
    assert.equal(token.toString(), '12345');
          
  });
        
  /**
         * Related to this bug : 
         * https://linear.app/arianee/issue/ARI-1462/bug-on-protocol-accept-event
         * Bug description : 
         * Create 1 pending event1
         * Create 1 other pending event2
         * Accept pending event2 twice
         * Then event1 cannot be accepted
        */
  it('should not be able to accept same event twice', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, '100000000000000000');
           
    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);
           
    await arianeeStoreInstance.hydrateToken(12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0xa148b056ED8917789F2D6baB8A27A966e86b18e2', 1885113294, true, '0x305051e9a023fe881ee21ca43fd90c460b427caa');
           
    await arianeeStoreInstance.buyCredit(2, 4, accounts[0]);
           
    await arianeeStoreInstance.createEvent(1, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');
    await arianeeStoreInstance.createEvent(2, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');
           
    // event should be in pending
    const event1Pending = await arianeeEventInstance.idToPendingEvents(1);
    assert.equal(event1Pending.toString(), '0');
           
    const token = await arianeeEventInstance.eventIdToToken(1);
    const pendingEvent = await arianeeEventInstance.pendingEvents(token, event1Pending);
    assert.equal(pendingEvent.toString(), '1');
           
    await arianeeStoreInstance.acceptEvent(2, '0x305051e9a023fe881ee21ca43fd90c460b427caa');
           
    // should not be able to accept event 2 twice
    await truffleAssert.fails(
      arianeeStoreInstance.acceptEvent(2, '0x305051e9a023fe881ee21ca43fd90c460b427caa'),
      truffleAssert.ErrorType.REVERT,
      'Event is not pending'
    );
            
    // should be able to still accept event 1
    await arianeeStoreInstance.acceptEvent(1, '0x305051e9a023fe881ee21ca43fd90c460b427caa');
  });  

  it('should refuse an event successfully', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, '100000000000000000');

    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);

    await arianeeStoreInstance.hydrateToken(12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0xa148b056ED8917789F2D6baB8A27A966e86b18e2', 1885113294, true, '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    await arianeeStoreInstance.buyCredit(2, 1, accounts[0]);

    await arianeeStoreInstance.createEvent(4234234, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    await arianeeStoreInstance.refuseEvent(4234234, '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    const eventIdToToken = await arianeeEventInstance.eventIdToToken(4234234);
    assert.equal(eventIdToToken.toString(), '0');
  });

  it('should not be able to refuse a already accepted event', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, '100000000000000000');

    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);

    await arianeeStoreInstance.hydrateToken(12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0xa148b056ED8917789F2D6baB8A27A966e86b18e2', 1885113294, true, '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    await arianeeStoreInstance.buyCredit(2, 1, accounts[0]);

    await arianeeStoreInstance.createEvent(4234234, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    await arianeeStoreInstance.acceptEvent(4234234, '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    truffleAssert.fails(
      arianeeStoreInstance.refuseEvent(4234234, '0x305051e9a023fe881ee21ca43fd90c460b427caa'),
      truffleAssert.ErrorType.REVERT
    );
  });
  it('should not be able to refuse twice an event ', async () => {
    await ariaInstance.approve(arianeeStoreInstance.address, '100000000000000000');

    await arianeeStoreInstance.buyCredit(0, 1, accounts[0]);

    await arianeeStoreInstance.hydrateToken(12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0xa148b056ED8917789F2D6baB8A27A966e86b18e2', 1885113294, true, '0x305051e9a023fe881ee21ca43fd90c460b427caa');

    await arianeeStoreInstance.buyCredit(2, 1, accounts[0]);

    await arianeeStoreInstance.createEvent(4234234, 12345, '0xbab03af901afd67bf4428ef62efe52738be09cbb7ec2b6d45d1118ac9fbaa6d2', '', '0x305051e9a023fe881ee21ca43fd90c460b427caa');


    await arianeeStoreInstance.refuseEvent(4234234, '0x305051e9a023fe881ee21ca43fd90c460b427caa');
    
    truffleAssert.fails(
      arianeeStoreInstance.refuseEvent(4234234, '0x305051e9a023fe881ee21ca43fd90c460b427caa'),
      truffleAssert.ErrorType.REVERT
    );
  });
});