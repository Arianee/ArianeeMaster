const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeStore = artifacts.require('ArianeeStore');
const Aria = artifacts.require('Aria');
const Whitelist = artifacts.require('ArianeeWhitelist');
const CreditHistory = artifacts.require('ArianeeCreditHistory');
const ArianeeEvent = artifacts.require('ArianeeEvent');
const ArianeeIdentity = artifacts.require('ArianeeIdentity');

const authorizedExchangeAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";
const projectAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";
const infraAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";
const bouncerAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";
const validatorAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";

const faucetAddress = "0x68C817BfEf37b5cBb691a2d02517fb8b76e7cD47";
const ownerAddress = "0xd03ea8624C8C5987235048901fB614fDcA89b117";


module.exports = async function(deployer, network, accounts) {
  // deployment steps

  await deployer.deploy(Aria)
    .then(ariaInstance=>{
      return deployer.deploy(Whitelist)
        .then(whitelistInstance=>{
          return deployer.deploy(ArianeeSmartAsset, whitelistInstance.address)
            .then(arianeeSmartAssetInstance=>{
              return deployer.deploy(CreditHistory)
                .then(creditHistoryInstance=>{
                  return deployer.deploy(ArianeeEvent, arianeeSmartAssetInstance.address, whitelistInstance.address)
                    .then(arianeeEventInstance=>{
                      return deployer.deploy(
                        ArianeeStore,
                        ariaInstance.address,
                        arianeeSmartAssetInstance.address,
                        creditHistoryInstance.address,
                        arianeeEventInstance.address,
                        "10000000000000",
                        "10",
                        "10",
                        "10"
                      )
                        .then(async (arianeeStoreInstance)=>{

                          const arianeeIdentityInstance = await deployer.deploy(ArianeeIdentity, bouncerAddress, validatorAddress);

                          arianeeStoreInstance.setArianeeProjectAddress(projectAddress);
                          arianeeStoreInstance.setProtocolInfraAddress(infraAddress);
                          arianeeStoreInstance.setAuthorizedExchangeAddress(authorizedExchangeAddress);
                          arianeeStoreInstance.setDispatchPercent(10,20,20,40,10);

                          arianeeSmartAssetInstance.setStoreAddress(arianeeStoreInstance.address);
                          creditHistoryInstance.setArianeeStoreAddress(arianeeStoreInstance.address);
                          arianeeEventInstance.setStoreAddress(arianeeStoreInstance.address);

                          arianeeSmartAssetInstance.grantAbilities(arianeeStoreInstance.address, [2]);
                          whitelistInstance.grantAbilities(arianeeSmartAssetInstance.address,[2]);
                          whitelistInstance.grantAbilities(arianeeEventInstance.address,[2]);

                          arianeeEventInstance.transferOwnership(ownerAddress);
                          arianeeStoreInstance.transferOwnership(ownerAddress);
                          arianeeSmartAssetInstance.transferOwnership(ownerAddress);
                          creditHistoryInstance.transferOwnership(ownerAddress);

                          ariaInstance.transfer(faucetAddress, "100000000000000000000000");
                          web3.eth.sendTransaction({from:accounts[0], to: faucetAddress, value:"99000000000000000000"});



                          console.log("Aria contract", ariaInstance.address);
                          console.log("whitelist contract", whitelistInstance.address);
                          console.log("smart asset contract", arianeeSmartAssetInstance.address);
                          console.log("credit history contract", creditHistoryInstance.address);
                          console.log("arianee event contract", arianeeEventInstance.address);
                          console.log("store contract", arianeeStoreInstance.address);
                          console.log('identity', arianeeIdentityInstance.address);

                        })
                    })
                })
            })
        })
    })

};

