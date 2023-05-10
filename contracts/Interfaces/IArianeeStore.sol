// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeStore {
  function canTransfer(address _from, address _to, uint256 _tokenId, bool _isSoulbound) external returns (bool);
  function canDestroy(uint256 _tokenId, address _sender, bool _isSoulbound) external returns (bool);
  function dispatchRewardsAtFirstTransfer(uint256 _tokenId, address _newOwner) external;
}
