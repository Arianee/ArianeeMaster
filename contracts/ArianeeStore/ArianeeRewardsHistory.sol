// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';

contract ArianeeRewardsHistory is Ownable {
    /**
     * @dev Mapping from token id to rewards.
     */
    mapping(uint256 => uint256) internal tokenRewards;
    /**
     * @dev Mapping from token id to the address of the NMP provider.
     */
    mapping(uint256 => address) internal tokenToNmpProvider;
    /**
     * @dev Mapping from token id to the address of the wallet provider.
     */
    mapping(uint256 => address) internal tokenToWalletProvider;

    address public storeAddress;

    modifier onlyStore() {
        require(msg.sender == storeAddress, 'This function can only be called by the ArianeeSmartAsset contract');
        _;
    }

    function setStoreAddress(address _newAddress) external onlyOwner {
        storeAddress = _newAddress;
    }

    // Token Rewards

    function setTokenRewards(uint256 _tokenId, uint256 _reward) public onlyStore {
        tokenRewards[_tokenId] = _reward;
    }

    function getTokenReward(uint256 _tokenId) public view onlyStore returns (uint256) {
        return tokenRewards[_tokenId];
    }

    function resetTokenReward(uint256 _tokenId) public onlyStore {
        tokenRewards[_tokenId] = 0;
    }

    // Token NMP Provider

    function setTokenNmpProvider(uint256 _tokenId, address _nmpProvider) public onlyStore {
        tokenToNmpProvider[_tokenId] = _nmpProvider;
    }

    function getTokenNmpProvider(uint256 _tokenId) public view onlyStore returns (address) {
        return tokenToNmpProvider[_tokenId];
    }

    // Token Wallet Provider

    function setTokenWalletProvider(uint256 _tokenId, address _walletProvider) public onlyStore {
        tokenToWalletProvider[_tokenId] = _walletProvider;
    }

    function getTokenWalletProvider(uint256 _tokenId) public view onlyStore returns (address) {
        return tokenToWalletProvider[_tokenId];
    }
}
