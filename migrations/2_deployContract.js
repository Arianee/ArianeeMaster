const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Arianee = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');

module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(Whitelist).then(()=>{
        deployer.deploy(CreditHistory).then(()=>{
            deployer.deploy(Arianee).then(()=>{
                deployer.deploy(ArianeeSmartAsset, Whitelist.address).then(()=>{
                    deployer.deploy(ArianeeStore, Arianee.address, ArianeeSmartAsset.address, CreditHistory.address);
                });
            });
        });
    });
};
