const ArianeeIdentity = artifacts.require('ArianeeIdentity');
const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Aria = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const ArianeeEvent = artifacts.require('ArianeeEvent');
const ArianeeLost = artifacts.require('ArianeeLost');
const ArianeeMessage = artifacts.require('ArianeeMessage');
const ArianeeUpdate = artifacts.require('ArianeeUpdate');
const ArianeeUserAction = artifacts.require('ArianeeUserAction');

const ArianeeIssuerProxy = artifacts.require('ArianeeIssuerProxy');

const { ProtocolClientV1 } = require('@arianee/arianee-protocol-client');
const { default: Core } = require('@arianee/core');
const { Prover, DEFAULT_CREDIT_PROOF } = require('@arianee/privacy-circuits');
const { JsonRpcProvider, ZeroAddress } = require('ethers');

const truffleAssert = require('truffle-assertions');

// WARNING: The contracts states are not reset between tests
// Because of this you can't run it along other tests files, they will fail
// You can run it alone with `npm run test -- ./test/IssuerProxy.test.js`

const CREDIT_TYPE_CERTIFICATE = 0;
const CREDIT_TYPE_MESSAGE = 1;
const CREDIT_TYPE_EVENT = 2;
const CREDIT_TYPE_UPDATE = 3;

contract('IssuerProxy', (accounts) => {
  let deployer;
  let relayer;
  let nonCreditFreeRelayer;

  let interfaceProvider;

  let arianeeIdentityInstance,
    arianeeSmartAssetInstance,
    ariaInstance,
    arianeeStoreInstance,
    whiteListInstance,
    creditHistoryInstance,
    messageInstance,
    arianeeEventInstance,
    arianeeLostInstance,
    arianeeUpdateInstance,
    arianeeUserActionInstance,
    arianeeIssuerProxyInstance;

  let prover;
  let protocolV1;

  before(async () => {
    // forwarderAddress = (await GsnTestEnvironment.loadDeployment()).forwarderAddress;
    // console.log('[IssuerProxy] Forwarder address: ', forwarderAddress);

    deployer = accounts[0];
    relayer = accounts[8];
    nonCreditFreeRelayer = accounts[9];

    // We use a random account for the interface provider
    // The ìnterfaceProvider` can't be ZeroAddress otherwise we'll get a revert when the store try to transfer the rewards
    interfaceProvider = Core.fromRandom().getAddress();

    arianeeIdentityInstance = await ArianeeIdentity.deployed();
    arianeeSmartAssetInstance = await ArianeeSmartAsset.deployed();
    ariaInstance = await Aria.deployed();
    arianeeStoreInstance = await ArianeeStore.deployed();
    whiteListInstance = await Whitelist.deployed();
    creditHistoryInstance = await CreditHistory.deployed();
    messageInstance = await ArianeeMessage.deployed();
    arianeeEventInstance = await ArianeeEvent.deployed();
    arianeeLostInstance = await ArianeeLost.deployed();
    arianeeUpdateInstance = await ArianeeUpdate.deployed();
    arianeeUserActionInstance = await ArianeeUserAction.deployed();

    arianeeIssuerProxyInstance = await ArianeeIssuerProxy.deployed();

    // Add the relayer to the "credit free sender" whitelist to bypass the credit note proof check as it's out of the scope of this test
    await arianeeIssuerProxyInstance.addCreditFreeSender(relayer, { from: deployer });

    // Add some credit for the ArianeeIssuerProxy
    // We don't check anything that is credit related in this test file, we just need to have some credit to be able to perform some actions
    const creditTypeQuantityEach = 100;

    const creditTypeCertPrice = await arianeeStoreInstance.getCreditPrice(CREDIT_TYPE_CERTIFICATE);
    const creditTypeCertAriaAmount = creditTypeCertPrice * creditTypeQuantityEach;
    const creditTypeEventPrice = await arianeeStoreInstance.getCreditPrice(CREDIT_TYPE_EVENT);
    const creditTypeEventAriaAmount = creditTypeEventPrice * creditTypeQuantityEach;

    const totalAriaAmount = creditTypeCertAriaAmount + creditTypeEventAriaAmount;

    await ariaInstance.approve(arianeeStoreInstance.address, totalAriaAmount, { from: deployer });
    await arianeeStoreInstance.buyCredit(CREDIT_TYPE_CERTIFICATE, creditTypeQuantityEach, arianeeIssuerProxyInstance.address, { from: deployer });
    await arianeeStoreInstance.buyCredit(CREDIT_TYPE_EVENT, creditTypeQuantityEach, arianeeIssuerProxyInstance.address, { from: deployer });

    // Protocol configuration
    const authorizedExchangeAddress = accounts[0];
    const projectAddress = accounts[2];
    const infraAddress = accounts[3];

    await arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
    await arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
    await arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
    await arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);

    const protocolDetails = {
      protocolVersion: '1.0',
      chainId: 1337,
      contractAdresses: {
        aria: ariaInstance.address,
        creditHistory: creditHistoryInstance.address,
        eventArianee: arianeeEventInstance.address,
        identity: arianeeIdentityInstance.address,
        smartAsset: arianeeSmartAssetInstance.address,
        store: arianeeStoreInstance.address,
        lost: arianeeLostInstance.address,
        whitelist: whiteListInstance.address,
        message: messageInstance.address,
        userAction: arianeeUserActionInstance.address,
        updateSmartAssets: arianeeUpdateInstance.address,
        issuerProxy: arianeeIssuerProxyInstance.address,
        creditNotePool: ZeroAddress,
      },
    };

    const proverCore = Core.fromRandom();
    prover = new Prover({ core: proverCore, circuitsBuildPath: 'node_modules/@arianee/privacy-circuits/build', useCreditNotePool: false });
    await prover.init();

    const provider = new JsonRpcProvider('http://localhost:8545');
    const signer = await provider.getSigner(deployer);

    protocolV1 = new ProtocolClientV1(signer, protocolDetails, {});
  });

  // Commitment and proof tests

  it(`should be able to reserve a token with a non-used commitment hash`, async () => {
    const tokenId = 123;
    const { commitmentHashAsStr } = await prover.issuerProxy.computeCommitmentHash({ protocolV1, tokenId });

    await arianeeIssuerProxyInstance.reserveToken(commitmentHashAsStr, tokenId, { from: relayer });

    const registeredCommitmentHash = await arianeeIssuerProxyInstance.commitmentHashes(tokenId, { from: relayer });
    assert.equal(registeredCommitmentHash?.toString(), commitmentHashAsStr);

    const ownerOf = await arianeeSmartAssetInstance.ownerOf(tokenId, { from: relayer });
    assert.equal(ownerOf, arianeeIssuerProxyInstance.address);
  });

  it(`shouldn't be able to reserve a token that was already reserved`, async () => {
    const tokenId = 123;
    const { commitmentHashAsStr } = await prover.issuerProxy.computeCommitmentHash({ protocolV1, tokenId });

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.reserveToken(commitmentHashAsStr, tokenId, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeIssuerProxy: A commitment has already been registered for this token'
    );
  });

  it(`should be able to hydrate a previously reserved token`, async () => {
    const tokenId = 123;

    const fragment = 'hydrateToken';
    const creditNotePool = ZeroAddress;
        // We don't need to provide the commitment hash as `tokenId=123` is already registered
    const commitmentHash = 0;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';
    const encryptedInitialKey = ZeroAddress;
    const tokenRecoveryTimestamp = 0;
    const initialKeyIsRequestKey = false;

    const values = [creditNotePool, commitmentHash, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await arianeeIssuerProxyInstance.hydrateToken(callData, DEFAULT_CREDIT_PROOF, creditNotePool, commitmentHash, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider, { from: relayer });

    const tokenImprint = await arianeeSmartAssetInstance.tokenImprint(tokenId, { from: relayer });
    assert.equal(tokenImprint, imprint);
  });

  it(`should be able to hydrate and reserve on-the-fly a token`, async () => {
    const tokenId = 456;
    const { commitmentHashAsStr } = await prover.issuerProxy.computeCommitmentHash({ protocolV1, tokenId });

    const fragment = 'hydrateToken';
    const creditNotePool = ZeroAddress;
    // We need to provide the commitment hash as `tokenId=456` is not registered and will be reserved on-the-fly
    const commitmentHash = commitmentHashAsStr;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';
    const encryptedInitialKey = ZeroAddress;
    const tokenRecoveryTimestamp = 0;
    const initialKeyIsRequestKey = false;

    const values = [creditNotePool, commitmentHash, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await arianeeIssuerProxyInstance.hydrateToken(callData, DEFAULT_CREDIT_PROOF, creditNotePool, commitmentHash, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider, { from: relayer });

    const ownerOf = await arianeeSmartAssetInstance.ownerOf(tokenId, { from: relayer });
    assert.equal(ownerOf, arianeeIssuerProxyInstance.address);

    const tokenImprint = await arianeeSmartAssetInstance.tokenImprint(tokenId, { from: relayer });
    assert.equal(tokenImprint, imprint);
  });

  it(`should be able to add a token access with a valid proof`, async () => {
    const tokenId = 123;

    const fragment = 'addTokenAccess';
    const key = ZeroAddress;
    const enable = true;
    const type = 1;

    const values = [tokenId, key, enable, type];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await arianeeIssuerProxyInstance.addTokenAccess(callData, tokenId, key, enable, type, { from: relayer });
  });

  it(`should be able to create an event with a valid proof`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = ZeroAddress;
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // INFO: The relayer is in the "credit free sender" whitelist so we can bypass the credit note proof check (i.e using DEFAULT_CREDIT_PROOF) for this test
    await arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer });
  });

  it(`shouldn't be able to create an event with an invalid proof (invalid fragment)`, async () => {
    const tokenId = 123;

    const fragment = 'acceptEvent'; // We use the wrong fragment here
    const eventId = 1;

    const values = [eventId, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: false });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    const creditNotePool = ZeroAddress;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeePrivacyProxy: Proof intent does not match the function call'
    );
  });

  it(`shouldn't be able to create an event with an invalid proof (invalid values)`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = ZeroAddress;
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, `0x${'12'.repeat(32)}`, uri, interfaceProvider]; // We use the wrong values here (imprint tempered)

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeePrivacyProxy: Proof intent does not match the function call'
    );
  });

  it(`shouldn't be able to create an event with an invalid proof (invalid nonce)`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = ZeroAddress;
    const eventId = 2;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });

    let nonce = Math.floor(Math.random() * 1_000_000_000);
    // Mock the `_getNonce` method to set a fixed nonce
    const _getNonce = prover.issuerProxy._getNonce;
    prover.issuerProxy._getNonce = () => { return nonce };

    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
    // We try to create the same event again with the same nonce
    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeePrivacyProxy: Proof nonce has already been used'
    );
    
    // Restore the original `_getNonce` method
    prover.issuerProxy._getNonce = _getNonce;
  });

  it(`shouldn't be able to create an event with an invalid proof (invalid commitmentHash)`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = ZeroAddress;
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });

    // Mock the `_computeCommitmentHash` method to return an invalid commitment hash
    const _computeCommitmentHash = prover.issuerProxy._computeCommitmentHash;
    prover.issuerProxy._computeCommitmentHash = () => { return { commitmentHashAsStr: '123' }};

    let generateProofErr = null;
    try {
      await prover.issuerProxy.generateProof({
        protocolV1,
        tokenId,
        intentHashAsStr,
      });
    } catch (err) {
      generateProofErr = err;
    } finally {
      // Restore the original `_computeCommitmentHash` method
      prover.issuerProxy._computeCommitmentHash = _computeCommitmentHash;
    }

    assert.equal(generateProofErr.message.match(/Error in template OwnershipVerifier/)?.length, 1);
  });

  it(`shouldn't be able to create an event with an invalid proof (invalid callData)`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = ZeroAddress;
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // We temper the callData
    callData[0][0] = callData[0][0].slice(0, -3) + '123';

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeePrivacyProxy: OwnershipProof verification failed'
    );
  });

  // IArianeeCreditNotePool management tests

  it(`shouldn't be able to create an event with a non whitelisted IArianeeCreditNotePool`, async () => {
    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = '0x0000000000000000000000000000000000000123';
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // INFO: The `nonCreditFreeRelayer` is not in the "credit free sender" whitelist, we use it intentionally to test the IArianeeCreditNotePool whitelist

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: nonCreditFreeRelayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeIssuerProxy: Target IArianeeCreditNotePool is not whitelisted'
    );
  });

  it(`should be able to create an event with a whitelisted IArianeeCreditNotePool`, async () => {
    // Add the IArianeeCreditNotePool to the whitelist
    const creditNotePool = '0x0000000000000000000000000000000000000123';
    await arianeeIssuerProxyInstance.addCreditNotePool(creditNotePool);

    const tokenId = 123;

    const fragment = 'createEvent';
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // We don't really wait for a successful event creation here, the transaction will revert because `0x0000000000000000000000000000000000000123` is not a real IArianeeCreditNotePool contract
    // It's ok for us if the transaction revert with a classic "VM Exception while processing transaction: revert" error and not with the "ArianeeIssuerProxy: Target IArianeeCreditNotePool is not whitelisted" error
    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: nonCreditFreeRelayer }),
      truffleAssert.ErrorType.REVERT,
      'VM Exception while processing transaction: revert'
    );
  });

  // Credit free sender management tests

  it(`shouldn't be able to create an event with a non whitelisted credit free sender`, async () => {
    // At the beginning of the test file we added the relayer to the "credit free sender" whitelist
    // So we already know that adding a credit free sender works if the previous tests passed
    // We will now remove it from the credit free sender whitelist and try to create an event with it
    await arianeeIssuerProxyInstance.removeCreditFreeSender(relayer, { from: deployer });

    const tokenId = 123;

    const fragment = 'createEvent';
    const creditNotePool = '0x0000000000000000000000000000000000000456'; // Be sure to use a non whitelisted IArianeeCreditNotePool
    const eventId = 1;
    const imprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';

    const values = [creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.createEvent(callData, DEFAULT_CREDIT_PROOF, creditNotePool, tokenId, eventId, imprint, uri, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeIssuerProxy: Target IArianeeCreditNotePool is not whitelisted'
    );
  });
});
