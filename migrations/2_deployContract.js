const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Arianee = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const ArianeeIdentity = artifacts.require('ArianeeIdentity');

let smartasset, creditHistory;

const arianeeProjectAddress ='0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  protocolInfraAddress='0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  authorizedEchangeAddress='0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  bouncerAddress='0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  validatorAddress='0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1';

module.exports = function(deployer) {
  let whitelistDeploy = deployer.deploy(Whitelist,{gasPrice:1});
  deployer.deploy(Arianee,{gasPrice:1});
  deployer.deploy(CreditHistory,{gasPrice:1})
    .then((instance)=>{
      creditHistory= instance;
      return deployer.deploy(ArianeeSmartAsset, Whitelist.address);
    })
    .then((instance)=>{
      smartasset = instance;
      return deployer.deploy(ArianeeStore, Arianee.address, ArianeeSmartAsset.address, CreditHistory.address, '100000000000000000',10,10,10);
    })
    .then((instance)=>{

      smartasset.grantAbilities(ArianeeStore.address, [2]);
      smartasset.setStoreAddress(ArianeeStore.address);

      instance.setArianeeProjectAddress(arianeeProjectAddress);
      instance.setProtocolInfraAddress(protocolInfraAddress);
      instance.setAuthorizedExchangeAddress(authorizedEchangeAddress);
      instance.setDispatchPercent(10,20,20,40,10);

      creditHistory.setArianeeStoreAddress(ArianeeStore.address);
      whitelistDeploy.then((instance)=>{ instance.grantAbilities(ArianeeSmartAsset.address,[2]); });

    });

  deployer.deploy(ArianeeIdentity, bouncerAddress, validatorAddress);

};

