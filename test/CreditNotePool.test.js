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
const ArianeenCreditNotePool = artifacts.require('ArianeeCreditNotePool');

const { ProtocolClientV1 } = require('@arianee/arianee-protocol-client');
const { default: Core } = require('@arianee/core');
const { Prover, DEFAULT_OWNERSHIP_PROOF } = require('@arianee/privacy-circuits');
const { MaxUint256 } = require('ethers');
const { JsonRpcProvider, ZeroAddress } = require('ethers');

const truffleAssert = require('truffle-assertions');

// WARNING: The contracts states are not reset between tests
// Because of this you can't run it along other tests files, they will fail
// You can run it alone with `npm run test -- ./test/CreditNotePool.test.js`

const CREDIT_TYPE_CERTIFICATE = 0;
const CREDIT_TYPE_MESSAGE = 1;
const CREDIT_TYPE_EVENT = 2;
const CREDIT_TYPE_UPDATE = 3;

const CREDIT_TYPE_INVALID = 66;

contract('CreditNotePool', (accounts) => {
  let deployer;
  let relayer;

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
    arianeeIssuerProxyInstance,
    arianeeCreditNotePoolInstance;

  let MaxNullifierPerCommitment;

  let prover;
  let protocolV1;

  before(async () => {
    // forwarderAddress = (await GsnTestEnvironment.loadDeployment()).forwarderAddress;
    // console.log('[IssuerProxy] Forwarder address: ', forwarderAddress);

    deployer = accounts[0];
    relayer = accounts[9];

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
    arianeeCreditNotePoolInstance = await ArianeenCreditNotePool.deployed();

    // Give some Aria to the relayer
    await ariaInstance.transfer(relayer, 100_000_000, { from: deployer });
    // Give max allowance to the ArianeeCreditNotePool contract
    await ariaInstance.approve(arianeeCreditNotePoolInstance.address, MaxUint256, { from: relayer });

    // Retrieve `MAX_NULLIFIER_PER_COMMITMENT`
    MaxNullifierPerCommitment = await arianeeCreditNotePoolInstance.MAX_NULLIFIER_PER_COMMITMENT();

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
        creditNotePool: arianeeCreditNotePoolInstance.address,
      },
    };

    const proverCore = Core.fromRandom();
    prover = new Prover({ core: proverCore, circuitsBuildPath: 'node_modules/@arianee/privacy-circuits/build', useCreditNotePool: true });
    await prover.init();

    const provider = new JsonRpcProvider('http://localhost:8545');
    const signer = await provider.getSigner(deployer);

    protocolV1 = new ProtocolClientV1(signer, protocolDetails, {});
  });

  it(`should be able to buy some certificate credits`, async () => {
    const creditType = CREDIT_TYPE_CERTIFICATE;
    const { commitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, commitmentHashAsHex, creditType, { from: relayer });

    const isRegistered = await arianeeCreditNotePoolInstance.commitmentHashes(commitmentHashAsHex, { from: relayer });
    assert.equal(isRegistered, true);

    const issuerProxy = arianeeIssuerProxyInstance.address;
    const balanceOfCredit = await creditHistoryInstance.balanceOf(issuerProxy, creditType);
    assert.equal(balanceOfCredit.toString(), MaxNullifierPerCommitment.toString());
  });

  it(`shouldn't be able to buy credit with an already registered commitment`, async () => {
    const creditType = CREDIT_TYPE_EVENT;
    const { commitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, commitmentHashAsHex, creditType, { from: relayer });

    await truffleAssert.fails(
      arianeeCreditNotePoolInstance.purchase(registrationProofCallData, commitmentHashAsHex, creditType, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: This commitment has already been registered'
    );
  });

  it(`should be able to spend a credit proof`, async () => {
    // Buy some certificate credits
    const creditType = CREDIT_TYPE_CERTIFICATE;
    const { nullifier, secret, commitmentHashAsHex: creditNotePoolCommitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHashAsHex, creditType, { from: relayer });

    // Prepare the commitment hash for the token
    const tokenId = 123;
    const { commitmentHashAsStr: ownershipCommitmentHashAsStr } = await prover.issuerProxy.computeCommitmentHash({ protocolV1, tokenId });

    // Prepare the intent hash
    const fragment = 'hydrateToken';
    const creditNotePool = arianeeCreditNotePoolInstance.address;
    const imprint = `0x${'11'.repeat(32)}`;
    const uri = 'https://example.com';
    const encryptedInitialKey = ZeroAddress;
    const tokenRecoveryTimestamp = 0;
    const initialKeyIsRequestKey = false;

    const values = [creditNotePool, ownershipCommitmentHashAsStr, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });

    // Get a credit proof
    const { callData: creditProofCallData } = await prover.creditNotePool.generateProof({
      protocolV1,
      nullifier,
      nullifierDerivationIndex: BigInt(1),
      secret,
      creditType,
      intentHashAsStr,
      performValidation: false,
    });

    // Reserve and hydrate the token
    await arianeeIssuerProxyInstance.hydrateToken(DEFAULT_OWNERSHIP_PROOF, creditProofCallData, creditNotePool, ownershipCommitmentHashAsStr, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider, { from: relayer });

    const tokenImprint = await arianeeSmartAssetInstance.tokenImprint(tokenId);
    assert.equal(tokenImprint, imprint);
  });

  it(`shouldn't be able to spend a credit proof with an invalid intent hash`, async () => {
    // Buy some certificate credits
    const creditType = CREDIT_TYPE_CERTIFICATE;
    const { nullifier, secret, commitmentHashAsHex: creditNotePoolCommitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHashAsHex, creditType, { from: relayer });

    // Prepare the commitment hash for the token
    const tokenId = 999;
    const { commitmentHashAsStr: ownershipCommitmentHashAsStr } = await prover.issuerProxy.computeCommitmentHash({ protocolV1, tokenId });

    // Prepare the intent hash
    const fragment = 'hydrateToken';
    const creditNotePool = arianeeCreditNotePoolInstance.address;
    const nonMatchingImprint = `0x${'00'.repeat(32)}`;
    const uri = 'https://example.com';
    const encryptedInitialKey = ZeroAddress;
    const tokenRecoveryTimestamp = 0;
    const initialKeyIsRequestKey = false;

    const values = [creditNotePool, ownershipCommitmentHashAsStr, tokenId, nonMatchingImprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });

    // Get a credit proof
    const { callData: creditProofCallData } = await prover.creditNotePool.generateProof({
      protocolV1,
      nullifier,
      nullifierDerivationIndex: BigInt(1),
      secret,
      creditType,
      intentHashAsStr,
      performValidation: false,
    });

    // Try to reserve and hydrate the token
    const imprint = `0x${'11'.repeat(32)}`;

    await truffleAssert.fails(
      arianeeIssuerProxyInstance.hydrateToken(DEFAULT_OWNERSHIP_PROOF, creditProofCallData, creditNotePool, ownershipCommitmentHashAsStr, tokenId, imprint, uri, encryptedInitialKey, tokenRecoveryTimestamp, initialKeyIsRequestKey, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: Proof intent does not match the function call'
    );
  });

  it(`shouldn't be able to spend a credit proof with the same nullifierDerivationIndex twice`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_UPDATE;
    const { nullifier, secret, commitmentHashAsHex: creditNotePoolCommitmentHash, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHash, creditType, { from: relayer });

    // Get an ownership proof
    const tokenId = 123;

    const fragment = 'updateSmartAsset';
    const creditNotePool = arianeeCreditNotePoolInstance.address;
    const imprint = `0x${'00'.repeat(32)}`;

    const values = [creditNotePool, tokenId, imprint, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData: ownershipProofCallData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // Get a credit proof
    const { callData: creditProofCallData } = await prover.creditNotePool.generateProof({
      protocolV1,
      nullifier,
      nullifierDerivationIndex: BigInt(1),
      secret,
      creditType,
      intentHashAsStr,
      performValidation: false,
    });

    // Update the token
    await arianeeIssuerProxyInstance.updateSmartAsset(ownershipProofCallData, creditProofCallData, creditNotePool, tokenId, imprint, interfaceProvider, { from: relayer });

    // Prepare a new ownership proof (because the previous one has been used so the nonce is not valid anymore)
    const { callData: ownershipProofCallData2 } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // Try to update the token with the same credit proof
    await truffleAssert.fails(
      arianeeIssuerProxyInstance.updateSmartAsset(ownershipProofCallData2, creditProofCallData, creditNotePool, tokenId, imprint, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: This note has already been spent'
    );
  });

  it(`shouldn't be able to spend a credit proof with a non-matching expected credit type`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_MESSAGE;
    const { nullifier, secret, commitmentHashAsHex: creditNotePoolCommitmentHash, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHash, creditType, { from: relayer });

    // Get an ownership proof
    const tokenId = 123;

    const fragment = 'updateSmartAsset';
    const creditNotePool = arianeeCreditNotePoolInstance.address;
    const imprint = `0x${'00'.repeat(32)}`;

    const values = [creditNotePool, tokenId, imprint, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData: ownershipProofCallData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // Get a credit proof
    const { callData: creditProofCallData } = await prover.creditNotePool.generateProof({
      protocolV1,
      nullifier,
      nullifierDerivationIndex: BigInt(1),
      secret,
      creditType,
      intentHashAsStr,
      performValidation: false,
    });

    // Update the token
    await truffleAssert.fails(
      arianeeIssuerProxyInstance.updateSmartAsset(ownershipProofCallData, creditProofCallData, creditNotePool, tokenId, imprint, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: Proof credit type does not match the function argument `_creditType`'
    );
  });

  it(`shouldn't be able to purchase a credit proof with a non-matching credit type`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_UPDATE;
    const { commitmentHashAsHex: creditNotePoolCommitmentHash, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await truffleAssert.fails(
      arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHash, CREDIT_TYPE_CERTIFICATE, { from: relayer }), // Pass the wrong credit type here
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: Proof credit type does not match the function argument `_creditType`'
    );
  });

  it(`shouldn't be able to spend an invalid credit proof (invalid callData)`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_UPDATE;
    const { nullifier, secret, commitmentHashAsHex: creditNotePoolCommitmentHash, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, creditNotePoolCommitmentHash, creditType, { from: relayer });

    // Get an ownership proof
    const tokenId = 123;

    const fragment = 'updateSmartAsset';
    const creditNotePool = arianeeCreditNotePoolInstance.address;
    const imprint = `0x${'00'.repeat(32)}`;

    const values = [creditNotePool, tokenId, imprint, interfaceProvider];

    const { intentHashAsStr } = await prover.issuerProxy.computeIntentHash({ protocolV1, fragment, values, needsCreditNoteProof: true });
    const { callData: ownershipProofCallData } = await prover.issuerProxy.generateProof({
      protocolV1,
      tokenId,
      intentHashAsStr,
    });

    // Get a credit proof
    const { callData: creditProofCallData } = await prover.creditNotePool.generateProof({
      protocolV1,
      nullifier,
      nullifierDerivationIndex: BigInt(1),
      secret,
      creditType,
      intentHashAsStr,
      performValidation: false,
    });

    // We temper the callData
    creditProofCallData[0][0] = creditProofCallData[0][0].slice(0, -3) + '123';

    // Update the token
    await truffleAssert.fails(
      arianeeIssuerProxyInstance.updateSmartAsset(ownershipProofCallData, creditProofCallData, creditNotePool, tokenId, imprint, interfaceProvider, { from: relayer }),
      truffleAssert.ErrorType.REVERT,
      'ArianeeCreditNotePool: CreditNoteProof verification failed'
    );
  });

  it(`shouldn't be able to generate a credit registration proof with an invalid credit type`, async () => {
    const creditType = CREDIT_TYPE_INVALID;

    let computeCommitmentHashErr = null;
    try {
      await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType, withRegistrationProof: true });
    } catch (err) {
      computeCommitmentHashErr = err;
    }

    assert.equal(computeCommitmentHashErr.message.match(/Error in template CreditRegister/)?.length, 1);
  });

  it(`shouldn't be able to generate a credit proof with nullifierDerivationIndex < 1`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_UPDATE;
    const { nullifier, secret, commitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, commitmentHashAsHex, creditType, { from: relayer });

    let generateProofErr = null;
    try {
      await prover.creditNotePool.generateProof({
        protocolV1,
        nullifier,
        nullifierDerivationIndex: BigInt(0),
        secret,
        creditType,
        intentHashAsStr: '',
        performValidation: false,
      });
    } catch (err) {
      generateProofErr = err;
    }

    assert.equal(generateProofErr.message.match(/Error in template CreditVerifier/)?.length, 1);
  });

  it(`shouldn't be able to generate a credit proof with nullifierDerivationIndex > 1000`, async () => {
    // Buy some update credits
    const creditType = CREDIT_TYPE_UPDATE;
    const { nullifier, secret, commitmentHashAsHex, registrationProofResult } = await prover.creditNotePool.computeCommitmentHash({ protocolV1, creditType });
    const { callData: registrationProofCallData } = registrationProofResult;

    await arianeeCreditNotePoolInstance.purchase(registrationProofCallData, commitmentHashAsHex, creditType, { from: relayer });

    let generateProofErr = null;
    try {
      await prover.creditNotePool.generateProof({
        protocolV1,
        nullifier,
        nullifierDerivationIndex: BigInt(1001),
        secret,
        creditType,
        intentHashAsStr: '',
        performValidation: false,
      });
    } catch (err) {
      generateProofErr = err;
    }

    assert.equal(generateProofErr.message.match(/Error in template CreditVerifier/)?.length, 1);
  });
});
