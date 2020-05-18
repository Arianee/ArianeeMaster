const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Aria = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const ArianeeEvent = artifacts.require('ArianeeEvent');
const ArianeeIdentity = artifacts.require('ArianeeIdentity');
const ArianeeLost = artifacts.require('ArianeeLost');
const ArianeeMessage = artifacts.require('ArianeeMessage');

const authorizedExchangeAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';
const projectAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';
const infraAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';
const bouncerAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';
const validatorAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';

const faucetAddress = '0x68C817BfEf37b5cBb691a2d02517fb8b76e7cD47';
const ownerAddress = '0xd03ea8624C8C5987235048901fB614fDcA89b117';

const {Arianee, NETWORK} = require('@arianee/arianeejs');

async function deployProtocol(deployer, network, accounts) {
  // need to deploy as blank, otherwise it is not working with ganache cli
  await deployer.deploy(Aria);

  const ariaInstance = await deployer.deploy(Aria);
  const whiteListInstance = await deployer.deploy(Whitelist);
  const arianeeSmartAssetInstance = await deployer.deploy(ArianeeSmartAsset, whiteListInstance.address);
  const messageInstance = await deployer.deploy(ArianeeMessage, whiteListInstance.address, arianeeSmartAssetInstance.address);
  const creditHistoryInstance = await deployer.deploy(CreditHistory);
  const arianeeEventInstance = await deployer.deploy(ArianeeEvent, arianeeSmartAssetInstance.address, whiteListInstance.address);

  const arianeeLost = await deployer.deploy(ArianeeLost, arianeeSmartAssetInstance.address);

  const arianeeStoreInstance = await deployer.deploy(
    ArianeeStore,
    ariaInstance.address,
    arianeeSmartAssetInstance.address,
    creditHistoryInstance.address,
    arianeeEventInstance.address,
    messageInstance.address,
    '10',
    '10',
    '10',
    '10'
  );

  const identityInstance = await deployer.deploy(ArianeeIdentity, accounts[0], accounts[0]);

  arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
  arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
  arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
  arianeeStoreInstance.setDispatchPercent(10, 20, 20, 40, 10);

  arianeeSmartAssetInstance.setStoreAddress(arianeeStoreInstance.address);
  creditHistoryInstance.setArianeeStoreAddress(arianeeStoreInstance.address);
  arianeeEventInstance.setStoreAddress(arianeeStoreInstance.address);

  arianeeSmartAssetInstance.grantAbilities(arianeeStoreInstance.address, [2]);
  whiteListInstance.grantAbilities(arianeeSmartAssetInstance.address, [2]);
  whiteListInstance.grantAbilities(arianeeEventInstance.address, [2]);

  arianeeEventInstance.transferOwnership(ownerAddress);
  arianeeStoreInstance.transferOwnership(ownerAddress);
  arianeeSmartAssetInstance.transferOwnership(ownerAddress);
  creditHistoryInstance.transferOwnership(ownerAddress);

  messageInstance.setStoreAddress(arianeeStoreInstance.address);
  ariaInstance.transfer(faucetAddress, '100000000000000000000000');
  web3.eth.sendTransaction({
    from: accounts[0],
    to: faucetAddress,
    value: '99000000000000000000'
  });

  const result = {
    'contractAdresses': {
      'aria': ariaInstance.address,
      'creditHistory': creditHistoryInstance.address,
      'eventArianee': arianeeEventInstance.address,
      'identity': identityInstance.address,
      'smartAsset': arianeeEventInstance.address,
      'staking': '',
      'store': arianeeStoreInstance.address,
      'whitelist': whiteListInstance.address,
      'lost': arianeeLost.address,
      'message':messageInstance.address
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

