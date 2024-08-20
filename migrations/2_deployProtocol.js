const { GsnTestEnvironment } = require("@opengsn/dev");

const ArianeeSmartAsset = artifacts.require("ArianeeSmartAsset");
const ArianeeStore = artifacts.require("ArianeeStore");
const Aria = artifacts.require("Aria");
const ArianeeWhitelist = artifacts.require("ArianeeWhitelist");
const ArianeeCreditHistory = artifacts.require("ArianeeCreditHistory");
const ArianeeEvent = artifacts.require("ArianeeEvent");
const ArianeeIdentity = artifacts.require("ArianeeIdentity");
const ArianeeLost = artifacts.require("ArianeeLost");
const ArianeeMessage = artifacts.require("ArianeeMessage");
const ArianeeUpdate = artifacts.require("ArianeeUpdate");
const ArianeeUserAction = artifacts.require("ArianeeUserAction");
const ArianeeRewardsHistory = artifacts.require("ArianeeRewardsHistory");

const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

const SMART_ASSET_IS_SOULBOUND = false;
const FORWARDER_ADDR = "0x0000000000000000000000000000000000000001"; // If set to null, the forwarder address will be taken from the GSN test environment

async function deployProtocol(deployer, network, accounts) {
  let forwarderAddress = FORWARDER_ADDR;
  if (
    forwarderAddress === null ||
    forwarderAddress === undefined ||
    forwarderAddress === ZERO_ADDR
  ) {
    console.log("[DeployProtocol] Using GSN test environment");
    const { forwarderAddress: testForwarderAddress } = await GsnTestEnvironment.loadDeployment();
    forwarderAddress = testForwarderAddress;
  }
  console.log("[DeployProtocol] Forwarder address: ", forwarderAddress);

  const authorizedExchangeAddress = accounts[0];
  const projectAddress = accounts[0];
  const infraAddress = accounts[0];
  const bouncerAddress = accounts[0];
  const validatorAddress = accounts[0];
  const ownerAddress = accounts[0];
  const lostManager = accounts[0];

  // need to deploy as blank, otherwise it is not working with ganache cli
  // await deployer.deploy(Aria);

  // const ariaInstance = await deployer.deploy(Aria);
  const ariaInstance = await Aria.at('0x757494946FD1A932aFDD3b04D791DA2a8071b4ad');
  // const whiteListInstance = await deployer.deploy(ArianeeWhitelist, forwarderAddress);
  const whiteListInstance = await ArianeeWhitelist.at('0xD65Cf97df953cFec5BE0b4659a098260B909F55E');
  console.log("whiteListInstance", whiteListInstance.address);
  console.log("ariaInstance", ariaInstance.address);
  // const arianeeSmartAssetInstance = await deployer.deploy(
  //   ArianeeSmartAsset,
  //   whiteListInstance.address,
  //   forwarderAddress,
  //   SMART_ASSET_IS_SOULBOUND
  // );
  const arianeeSmartAssetInstance = await ArianeeSmartAsset.at('0x17e631ED032eCE7c2811B6972527767E1148CcFe');
  console.log("arianeeSmartAssetInstance", arianeeSmartAssetInstance.address);
  // const messageInstance = await deployer.deploy(
  //   ArianeeMessage,
  //   whiteListInstance.address,
  //   arianeeSmartAssetInstance.address,
  //   forwarderAddress
  // );
  const messageInstance = await ArianeeMessage.at('0x9Dbcf2De1b15DA2981E726f3D6143d9b84E6dFC9');
  console.log("messageInstance", messageInstance.address);
  // const creditHistoryInstance = await deployer.deploy(ArianeeCreditHistory, forwarderAddress);
  const creditHistoryInstance = await ArianeeCreditHistory.at('0x3F4B61a8B06f385826Fbe9890a08bcE22125AeB6');
  // const rewardsHistoryInstance = await deployer.deploy(ArianeeRewardsHistory, forwarderAddress);
  const rewardsHistoryInstance = await ArianeeRewardsHistory.at('0xa6167068F2253820Fbbb44d94403d2446F3E505C');
  const arianeeEventInstance = await deployer.deploy(
    ArianeeEvent,
    arianeeSmartAssetInstance.address,
    whiteListInstance.address,
    forwarderAddress
  );
  const arianeeLost = await deployer.deploy(
    ArianeeLost,
    arianeeSmartAssetInstance.address,
    lostManager,
    forwarderAddress
  );
  const arianeeUpdate = await deployer.deploy(
    ArianeeUpdate,
    arianeeSmartAssetInstance.address,
    forwarderAddress
  );
  const arianeeUserAction = await deployer.deploy(
    ArianeeUserAction,
    whiteListInstance.address,
    arianeeSmartAssetInstance.address,
    forwarderAddress
  );

  const arianeeStoreInstance = await deployer.deploy(
    ArianeeStore,
    ariaInstance.address,
    arianeeSmartAssetInstance.address,
    creditHistoryInstance.address,
    rewardsHistoryInstance.address,
    arianeeEventInstance.address,
    messageInstance.address,
    arianeeUpdate.address,
    authorizedExchangeAddress,
    "10",
    "10",
    "10",
    "10",
    forwarderAddress
  );

  const identityInstance = await deployer.deploy(
    ArianeeIdentity,
    bouncerAddress,
    validatorAddress,
    forwarderAddress
  );

  await arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
  await arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
  await arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
  await arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);
  await arianeeStoreInstance.setAriaUSDExchange(10);

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

  const result = {
    contractAdresses: {
      aria: ariaInstance.address,
      creditHistory: creditHistoryInstance.address,
      rewardsHistory: rewardsHistoryInstance.address,
      eventArianee: arianeeEventInstance.address,
      identity: identityInstance.address,
      smartAsset: arianeeSmartAssetInstance.address,
      staking: "",
      store: arianeeStoreInstance.address,
      whitelist: whiteListInstance.address,
      lost: arianeeLost.address,
      message: messageInstance.address,
      userAction: arianeeUserAction.address,
      updateSmartAssets: arianeeUpdate.address,
    },
    httpProvider: "http://localhost:8545",
    chainId: 5777,
  };

  console.log("###########################");
  console.log(result);
  console.log("###########################");

  return result;
}

module.exports = async function (deployer, network, accounts) {
  const protocolConfiguration = await deployProtocol(deployer, network, accounts);
};
