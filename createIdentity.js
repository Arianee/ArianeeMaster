const Web3 = require('web3');
const process = require('process');
const fs = require('fs');
const truffleConfig = require('./truffle.js');
const identityABI = JSON.parse(fs.readFileSync('./build/contracts/ArianeeIdentity.json', {encoding:'utf8'})).abi;

// https://api.myjson.com/bins/mzxqs : address arianee validate
// https://api.myjson.com/bins/w1q50 : address arianee waiting

/*
accounts list :
[ '0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1',
  '0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0',
  '0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b',
  '0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d',
  '0xd03ea8624C8C5987235048901fB614fDcA89b117',
  '0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC',
  '0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9',
  '0x28a8746e75304c0780E011BEd21C72cD78cd535E',
  '0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E',
  '0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e' ]
 */

const init = async()=>{

  const argv = process.argv;
  const network = argv[argv.indexOf('--network')+1];
  if(!network){
    throw new Error("Please specify a network with --network");
  }

  const identityContractAddress = argv[argv.indexOf('--address')+1];
  if(!identityContractAddress){
    throw new Error("Please specify a contract address with --address");
  }


  const networkConfig = truffleConfig.networks[network];

  const web3 = new Web3('http://'+networkConfig.host+':'+networkConfig.port);
  const accounts = await web3.eth.getAccounts();
  console.log(accounts);

  const identityContract =  new web3.eth.Contract(identityABI, identityContractAddress);


  web3.eth.sendTransaction({to:accounts[1], from:accounts[0], value:web3.utils.toWei("0.005", "ether")});
  web3.eth.sendTransaction({to:accounts[2], from:accounts[0], value:web3.utils.toWei("0.005", "ether")});


  await identityContract.methods.addAddressToApprovedList(accounts[1]).send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/mzxqs', '0xd9f02f9cb05bc7e2767bb956fa0372fcc7a6c88e392ae2c1ea9205b5bcb11048').send({from:accounts[1], gasPrice:1, gas:8000000});
  await identityContract.methods.validateInformation(accounts[1], 'https://api.myjson.com/bins/mzxqs', '0xd9f02f9cb05bc7e2767bb956fa0372fcc7a6c88e392ae2c1ea9205b5bcb11048').send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/w1q50', '0x31bd6f933aa9260509f4dced76f3410872f220e828c05d7f009a8796bff1ac05').send({from:accounts[1], gasPrice:1, gas:8000000});

  await identityContract.methods.addAddressToApprovedList(accounts[2]).send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/w1q50', '0x31bd6f933aa9260509f4dced76f3410872f220e828c05d7f009a8796bff1ac05').send({from:accounts[2], gasPrice:1, gas:8000000});



}

init();