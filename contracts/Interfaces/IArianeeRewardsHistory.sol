// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeRewardsHistory {
    function setStoreAddress(address _newAddress) external;

    function setTokenRewards(uint256 _tokenId, uint256 _reward) external;

    function getTokenReward(uint256 _tokenId) external view returns (uint256);

    function resetTokenReward(uint256 _tokenId) external;
}
