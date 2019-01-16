const fs = require('fs');
const async = require('async');

const contracts =[
				'./ArianeeToken/contracts/Arianee.sol',
				'./ArianeeToken/contracts/ArianeeBase.sol',
				'./ArianeeToken/contracts/EIP20.sol',
				'./ArianeeToken/contracts/EIP20Interface.sol',
				'./ArianeeStore/contracts/ERC900.sol',
				'./ArianeeStore/contracts/ERC900BasicStakeContract.sol',
				'./ArianeeStore/contracts/Migrations.sol',
				'./ArianeeStore/contracts/Ownable.sol',
				'./ArianeeStore/contracts/arianeeStore.sol',
				'./ArianeeSmartContract/contracts/tokens'
				]


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
})


