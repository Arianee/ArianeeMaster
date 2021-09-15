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


async function deployProtocol(deployer, network, accounts) {

  const authorizedExchangeAddress = accounts[0];
  const projectAddress = accounts[0];
  const infraAddress = accounts[0];
  const bouncerAddress = accounts[0];
  const validatorAddress = accounts[0];
  const ownerAddress = accounts[0];
  const lostManager = accounts[0];


  // need to deploy as blank, otherwise it is not working with ganache cli
  await deployer.deploy(Aria);

  const ariaInstance = await deployer.deploy(Aria);
  const whiteListInstance = await deployer.deploy(Whitelist);
  const arianeeSmartAssetInstance = await deployer.deploy(ArianeeSmartAsset, whiteListInstance.address);
  const messageInstance = await deployer.deploy(ArianeeMessage, whiteListInstance.address, arianeeSmartAssetInstance.address);
  const creditHistoryInstance = await deployer.deploy(CreditHistory);
  const arianeeEventInstance = await deployer.deploy(ArianeeEvent, arianeeSmartAssetInstance.address, whiteListInstance.address);
  const arianeeLost = await deployer.deploy(ArianeeLost, arianeeSmartAssetInstance.address, lostManager);
  const arianeeUpdate = await deployer.deploy(ArianeeUpdate, arianeeSmartAssetInstance.address);
  const arianeeUserAction = await deployer.deploy(ArianeeUserAction, whiteListInstance.address, arianeeSmartAssetInstance.address);


  const arianeeStoreInstance = await deployer.deploy(
    ArianeeStore,
    ariaInstance.address,
    arianeeSmartAssetInstance.address,
    creditHistoryInstance.address,
    arianeeEventInstance.address,
    messageInstance.address,
    arianeeUpdate.address,
    authorizedExchangeAddress,
    '10',
    '10',
    '10',
    '10'
  );

  const identityInstance = await deployer.deploy(ArianeeIdentity,bouncerAddress, validatorAddress);

  arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
  arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
  arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
  arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);
  arianeeStoreInstance.setAriaUSDExchange(10);

  arianeeSmartAssetInstance.setStoreAddress(arianeeStoreInstance.address);
  creditHistoryInstance.setArianeeStoreAddress(arianeeStoreInstance.address);
  arianeeEventInstance.setStoreAddress(arianeeStoreInstance.address);
  arianeeUpdate.updateStoreAddress(arianeeStoreInstance.address);

  arianeeSmartAssetInstance.grantAbilities(arianeeStoreInstance.address, [2]);
  whiteListInstance.grantAbilities(arianeeSmartAssetInstance.address, [2]);
  whiteListInstance.grantAbilities(arianeeEventInstance.address, [2]);
  whiteListInstance.grantAbilities(arianeeUserAction.address, [2]);

  arianeeEventInstance.transferOwnership(ownerAddress);
  arianeeStoreInstance.transferOwnership(ownerAddress);
  arianeeSmartAssetInstance.transferOwnership(ownerAddress);
  creditHistoryInstance.transferOwnership(ownerAddress);

  messageInstance.setStoreAddress(arianeeStoreInstance.address);

  const result = {
    'contractAdresses': {
      'aria': ariaInstance.address,
      'creditHistory': creditHistoryInstance.address,
      'eventArianee': arianeeEventInstance.address,
      'identity': identityInstance.address,
      'smartAsset': arianeeSmartAssetInstance.address,
      'staking': '',
      'store': arianeeStoreInstance.address,
      'whitelist': whiteListInstance.address,
      'lost': arianeeLost.address,
      'message':messageInstance.address,
      "userAction":arianeeUserAction.address,
      "updateSmartAssets": arianeeUpdate.address
    },
    'httpProvider': 'http://localhost:8545',
    'chainId': 42
  };

  console.log('###########################');
  console.log(result);
  console.log('###########################');

  return result;

}


module.exports = async function (deployer, network, accounts) {

  const protocolConfiguration = await deployProtocol(deployer, network, accounts);

};

