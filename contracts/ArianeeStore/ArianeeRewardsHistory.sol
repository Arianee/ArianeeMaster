// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';

contract ArianeeRewardsHistory is Ownable {
    /**
     * @dev Mapping from token id to rewards.
     */
    mapping(uint256 => uint256) internal tokenRewards;
    address storeAddress;

    modifier onlyStore() {
        require(msg.sender == storeAddress, 'This function can only be called by the ArianeeSmartAsset contract');
        _;
    }

    function setStoreAddress(address _newAddress) external onlyOwner {
        storeAddress = _newAddress;
    }

    function setTokenRewards(uint256 _tokenId, uint256 _reward) public onlyStore {
        tokenRewards[_tokenId] = _reward;
    }

    function getTokenReward(uint256 _tokenId) public view onlyStore returns (uint256) {
        return tokenRewards[_tokenId];
    }

    function resetTokenReward(uint256 _tokenId) public onlyStore {
        tokenRewards[_tokenId] = 0;
    }
}
