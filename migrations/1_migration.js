var Migrations = artifacts.require('Migrations');

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(Migrations);
};