module.exports = {
  networks: {
    test: {
      host: '127.0.0.1',
      port: 8546,
      gas: 8000000,
      network_id: 1337
    }
  },
  compilers: {
    solc: {
      version: '0.5.6',
      settings: {
        optimizer: {
          enabled: true,
          runs:1
        }
      },
    }
  }
};