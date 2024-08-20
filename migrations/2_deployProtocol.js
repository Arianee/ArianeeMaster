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

  const ariaInstance = await deployer.deploy(Aria);
  const whiteListInstance = await deployer.deploy(ArianeeWhitelist, forwarderAddress);
  const arianeeSmartAssetInstance = await deployer.deploy(
    ArianeeSmartAsset,
    whiteListInstance.address,
    forwarderAddress,
    SMART_ASSET_IS_SOULBOUND
  );
  const messageInstance = await deployer.deploy(
    ArianeeMessage,
    whiteListInstance.address,
    arianeeSmartAssetInstance.address,
    forwarderAddress
  );
  const creditHistoryInstance = await deployer.deploy(ArianeeCreditHistory, forwarderAddress);
  const rewardsHistoryInstance = await deployer.deploy(ArianeeRewardsHistory, forwarderAddress);
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

  await rewardsHistoryInstance.setStoreAddress(arianeeStoreInstance.address);

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
