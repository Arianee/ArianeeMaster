const Web3 = require('web3');
const process = require('process');
const fs = require('fs');
const truffleConfig = require('./truffle.js');
const identityABI = JSON.parse(fs.readFileSync('./build/contracts/ArianeeIdentity.json', {encoding:'utf8'})).abi;
const storeABI = JSON.parse(fs.readFileSync('./build/contracts/ArianeeStore.json', {encoding:'utf8'})).abi;
const ariaABI = JSON.parse(fs.readFileSync('./build/contracts/Aria.json', {encoding:'utf8'})).abi;
const ArianeeLib= require('@arianee/arianeejs');
const axios = require('axios');

// https://api.myjson.com/bins/mzxqs : address arianee validate
// https://api.myjson.com/bins/w1q50 : address arianee waiting
//"https://cert.arianee.org/cert/sampleCert.json"
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

let identityContract;
let storeContract;
let ariaContract;

const init = async()=>{

  const argv = process.argv;
  const network = argv[argv.indexOf('--network')+1];
  if(!network){
    throw new Error("Please specify a network with --network");
  }

  const identityContractAddress = argv[argv.indexOf('--identityAddress')+1];

  if(!identityContractAddress){
    throw new Error("Please specify an identity contract address with --identityAddress");
  }

  const storeContractAddress = argv[argv.indexOf('--storeAddress')+1];
  if(!storeContractAddress){
    throw new Error("Please specify a store contract address with --storeAddress");
  }

  const ariaContractAddress = argv[argv.indexOf('--ariaAddress')+1];

  if(!ariaContractAddress){
    throw new Error("Please specify a store contract address with --ariaAddress");
  }


  const networkConfig = truffleConfig.networks[network];

  const web3 = new Web3('http://'+networkConfig.host+':'+networkConfig.port);
  const accounts = await web3.eth.getAccounts();


  identityContract =  new web3.eth.Contract(identityABI, identityContractAddress);
  storeContract =  new web3.eth.Contract(storeABI, storeContractAddress);
  ariaContract =  new web3.eth.Contract(ariaABI, ariaContractAddress);


  web3.eth.sendTransaction({to:accounts[1], from:accounts[0], value:web3.utils.toWei("0.005", "ether")});
  web3.eth.sendTransaction({to:accounts[2], from:accounts[0], value:web3.utils.toWei("0.005", "ether")});


  await identityContract.methods.addAddressToApprovedList(accounts[1]).send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/mzxqs', '0xd9f02f9cb05bc7e2767bb956fa0372fcc7a6c88e392ae2c1ea9205b5bcb11048').send({from:accounts[1], gasPrice:1, gas:8000000});
  await identityContract.methods.validateInformation(accounts[1], 'https://api.myjson.com/bins/mzxqs', '0xd9f02f9cb05bc7e2767bb956fa0372fcc7a6c88e392ae2c1ea9205b5bcb11048').send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/w1q50', '0x31bd6f933aa9260509f4dced76f3410872f220e828c05d7f009a8796bff1ac05').send({from:accounts[1], gasPrice:1, gas:8000000});

  await identityContract.methods.addAddressToApprovedList(accounts[2]).send({from:accounts[0], gasPrice:1, gas:8000000});
  await identityContract.methods.updateInformations('https://api.myjson.com/bins/w1q50', '0x31bd6f933aa9260509f4dced76f3410872f220e828c05d7f009a8796bff1ac05').send({from:accounts[2], gasPrice:1, gas:8000000});

  const cert1URI = "https://api.myjson.com/bins/wbsvc";
  const cert1Passphrase = "cert1passphrase";
  const cert2URI = "https://api.myjson.com/bins/1f2yfc";
  const cert2Passphrase = "cert2passphrase;,";

  await ariaContract.methods.approve(storeContractAddress, "900000000000000000000000").send({from:accounts[0]});
  await storeContract.methods.buyCredit("0","1",accounts[1]).send({from:accounts[0],gasPrice:1, gas:8000000});
  await storeContract.methods.buyCredit("0","1",accounts[2]).send({from:accounts[0],gasPrice:1, gas:8000000});

  await createCertificate(1, cert1URI, cert1Passphrase, accounts[1], accounts[3]);
  await createCertificate(2, cert2URI, cert2Passphrase, accounts[2], accounts[3]);

}

init();

 createCertificate = async(tokenid, uri, passphrase, account, rewardAccount)=>{


  let cert1 = await axios.get(uri);


  let cert1schema = await axios.get(cert1.data.$schema);


  let arianee = await new ArianeeLib.Arianee().init('arianeetestnet');

  const wallet = arianee.fromPassPhrase(passphrase);

  const hash = await wallet.utils.cert(cert1schema.data, cert1.data);


  await storeContract.methods
    .hydrateToken(
      tokenid,
      hash,
      uri,
      wallet.publicKey,
      Math.round((new Date().valueOf()+31536000000)/1000),
      false,
      rewardAccount
    )
    .send({from:account,gasPrice:1, gas:8000000})
}