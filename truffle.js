module.exports = {
    networks: {
        test: {
            host: '127.0.0.1',
            port: 8546,
            gas: 8000000,
            network_id: "*",
            from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
        }
    },
    compilers: {
    solc: {
      version: "0.5.1"
	  }
	}
};
