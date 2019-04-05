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
                    deployer.deploy(ArianeeStore, Arianee.address, ArianeeSmartAsset.address, CreditHistory.address, 10,10,10,10);

                    ArianeeSmartAsset.assignAbilities(arianeeStore.address, [1]);
                    ArianeeStore.setDispatchPercent(10,20,20,40,10);
                    CreditHistory.setArianeeStoreAddress(arianeeStore.address);
                    Whitelist.assignAbilities(ArianeeSmartAsset.address,[1]);

                    console.log("WhiteList : "+Whitelist.address);
                    console.log("CreditHistory : "+CreditHistory.address);
                    console.log("Aria : "+Arianee);
                    console.log("ArianeeSmartAsset : "+ArianeeSmartAsset);
                    console.log("ArianeeStore : "+ArianeeStore);

                });
            });
        });
    });
};
