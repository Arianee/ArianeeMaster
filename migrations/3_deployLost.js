const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const ArianeeLost = artifacts.require("ArianeeLost");

async function deployLost(deployer, network, accounts) {
  const lostManager = accounts[0];

  // need to deploy as blank, otherwise it is not working with ganache cli
  // await deployer.deploy(Aria);

  const arianeeSmartAssetInstance = await ArianeeSmartAsset.at("0xC35C6Ec800a4d9918fD1a1BF3060CFE3926f318e");

  const arianeeLost = await deployer.deploy(
    ArianeeLost,
    arianeeSmartAssetInstance.address,
    lostManager
  );

  const result = {
    contractAdresses: {
      lost: arianeeLost.address,
    },
    httpProvider: "http://localhost:8545",
    chainId: deployer.network_id,
  };

  console.log("###########################");
  console.log(result);
  console.log("###########################");

  return result;
}

module.exports = async function (deployer, network, accounts) {
  await deployLost(deployer, network, accounts);
};
