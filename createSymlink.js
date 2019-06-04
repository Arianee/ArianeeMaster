const fs = require('fs');
const async = require('async');

const contracts =[
  '../ArianeeToken/contracts/Aria.sol',
  '../ArianeeToken/contracts/erc20.sol',
  '../ArianeeStore/contracts/arianeeStore.sol',
  '../ArianeeStore/contracts/ArianeeCreditHistory.sol',

  '../ArianeeSmartContract/contracts/Migrations.sol',
  '../ArianeeIdentity/contracts/ArianeeIdentity.sol',
  '../ArianeeSmartContract/contracts/tokens/ArianeeSmartAsset.sol',
  '../ArianeeSmartContract/contracts/tokens/Pausable.sol',

  '../ArianeeMessage/contracts/ArianeeWhitelist.sol',
  '../ArianeeMessage/contracts/ArianeeMessage.sol',

  '../ArianeeService/contracts/ArianeeService.sol'

];


if(!fs.existsSync('./contracts')){
  fs.mkdir('./contracts', err=>{
    if(err){
      console.log('Can\'t create contracts folder');
    }
  });
}

async.each(contracts, (contract, cb)=>{
  let contractFileName = contract.split('/');
  contractFileName = contractFileName[contractFileName.length-1];
  const dest = './contracts/'+contractFileName;
  fs.symlink(contract, dest, cb);
}, function(){
  console.log('Symlinks created');
});
