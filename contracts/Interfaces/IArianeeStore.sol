// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeStore {
  function canTransfer(
    address _from,
    address _to,
    uint256 _tokenId,
    bool _isSoulbound
  ) external returns (bool);

  function canDestroy(uint256 _tokenId, address _sender, bool _isSoulbound) external returns (bool);

  function dispatchRewardsAtFirstTransfer(uint256 _tokenId, address _newOwner) external;

  function reserveToken(uint256 _id, address _to) external;

  function hydrateToken(
    uint256 _tokenId,
    bytes32 _imprint,
    string calldata _uri,
    address _encryptedInitialKey,
    uint256 _tokenRecoveryTimestamp,
    bool _initialKeyIsRequestKey,
    address _providerBrand
  ) external;

  function createEvent(
    uint256 _eventId,
    uint256 _tokenId,
    bytes32 _imprint,
    string calldata _uri,
    address _providerBrand
  ) external;

  function acceptEvent(uint256 _eventId, address _providerOwner) external;

  function createMessage(uint256 _messageId, uint256 _tokenId, bytes32 _imprint, address _providerBrand) external;

  function updateSmartAsset(uint256 _tokenId, bytes32 _imprint, address _providerBrand) external;

  function getCreditPrice(uint256 _creditType) external view returns (uint256);

  function buyCredit(uint256 _creditType, uint256 _quantity, address _to) external;
}
