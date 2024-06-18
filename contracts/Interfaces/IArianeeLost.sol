// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeLost {
  function setMissingStatus(uint256 _tokenId) external;
  function unsetMissingStatus(uint256 _tokenId) external;
  function setStolenStatus(uint256 _tokenId) external;
  function unsetStolenStatus(uint256 _tokenId) external;
}
