// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeSmartAsset {
  function canOperate(uint256 _tokenId, address _operator) external returns (bool);

  function isTokenValid(
    uint256 _tokenId,
    bytes32 _hash,
    uint256 _tokenType,
    bytes memory _signature
  ) external view returns (bool);

  function issuerOf(uint256 _tokenId) external view returns (address _tokenIssuer);

  function tokenCreation(uint256 _tokenId) external view returns (uint256);

  function ownerOf(uint256 _tokenId) external returns (address _owner);

  function tokenImprint(uint256 _tokenId) external view returns (bytes32 _imprint);

  function reserveToken(uint256 id, address _to) external;

  function hydrateToken(
    uint256 _tokenId,
    bytes32 _imprint,
    string memory _uri,
    address _encryptedInitialKey,
    uint256 _tokenRecoveryTimestamp,
    bool _initialKeyIsRequestKey,
    address _owner
  ) external;

  function requestToken(
    uint256 _tokenId,
    bytes32 _hash,
    bool _keepRequestToken,
    address _newOwner,
    bytes calldata _signature
  ) external;

  function addTokenAccess(uint256 _tokenId, address _key, bool _enable, uint256 _tokenType) external;

  function recoverTokenToIssuer(uint256 _tokenId) external;

  function updateRecoveryRequest(uint256 _tokenId, bool _active) external;

  function destroy(uint256 _tokenId) external;

  function updateTokenURI(uint256 _tokenId, string calldata _uri) external;

  function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external;

  function transferFrom(address _from, address _to, uint256 _tokenId) external;

  function approve(address _approved, uint256 _tokenId) external;
}
