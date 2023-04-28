// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeMessage {
  function readMessage(uint256 _messageId, address _from) external returns (uint256);
  function sendMessage(uint256 _messageId, uint256 _tokenId, bytes32 _imprint, address _from, uint256 _reward) external;
}
