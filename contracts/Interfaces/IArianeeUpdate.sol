// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeUpdate {
  function updateSmartAsset(
    uint256 _tokenId,
    bytes32 _imprint,
    address _issuer,
    uint256 _reward
  ) external;

  function readUpdateSmartAsset(uint256 _tokenId, address _from) external returns (uint256);
}
