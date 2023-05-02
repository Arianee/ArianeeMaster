// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeSmartAsset {
    function canOperate(uint256 _tokenId, address _operator) external returns(bool);
    function isTokenValid(uint256 _tokenId, bytes32 _hash, uint256 _tokenType, bytes memory _signature) external view returns (bool);
    function issuerOf(uint256 _tokenId) external view returns(address _tokenIssuer);
    function tokenCreation(uint256 _tokenId) external view returns(uint256);
    function ownerOf(uint256 _tokenId) external returns (address _owner);
    function tokenImprint(uint256 _tokenId) external view returns(bytes32 _imprint);
    function reserveToken(uint256 id, address _to, uint256 _rewards) external;
    function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, address _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey, address _owner) external returns(uint256);
    function requestToken(uint256 _tokenId, bytes32 _hash, bool _keepRequestToken, address _newOwner, bytes calldata _signature) external returns(uint256);
    function getRewards(uint256 _tokenId) external view returns(uint256);
}