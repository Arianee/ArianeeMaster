// SPDX-License-Identifier: MIT
pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";



abstract contract ERC721Interface {
  function canOperate(uint256 _tokenId, address _operator) public virtual returns (bool);
  function isTokenValid(uint256 _tokenId, bytes32 _hash, uint256 _tokenType, bytes memory _signature) public virtual view returns (bool);
  function issuerOf(uint256 _tokenId) external virtual view returns (address _tokenIssuer);
  function tokenCreation(uint256 _tokenId) external virtual view returns (uint256);
}
contract ArianeeLost is Ownable {

  /**
   * @dev Mapping from token id to missing status.
    */
  mapping(uint256 => bool) tokenMissingStatus;

  /**
   * @dev Mapping from token id to stolen status.
     */
  mapping(uint256 => bool) tokenStolenStatus;

  /**
   * @dev Mapping of authorizedIdentities
     */
  mapping(address => bool) authorizedIdentities;

  /**
    * @dev Mapping from token id to address that set stolen status.
    */
  mapping(uint256 => address) tokenStolenIssuer;

  /**
   * @dev address of the manager.
     */
  address managerIdentity;

  /**
   * @dev Interface to connected contract.
     */
  ERC721Interface public smartAsset;

  /**
   * @dev This emits when a new manager is set by the contract owner.
     */
  event NewManagerIdentity(address indexed _newManagerIdentity);

  /**
   * @dev This emits when a passport is declared missing by its owner.
     */
  event Missing(uint256 indexed _tokenId);

  /**
   * @dev This emits when a passport is declared no missing anymore by its owner.
     */
  event UnMissing(uint256 indexed _tokenId);

  /**
   * @dev This emits when the manager declare a new authorized identity.
     */
  event AuthorizedIdentityAdded(address indexed _newIdentityAuthorized);

  /**
   * @dev This emits when the manager declare an identity not authorized anymore.
     */
  event AuthorizedIdentityRemoved(address indexed _newIdentityUnauthorized);

  /**
   * @dev This emits when an authorized identity declare a passport as stolen.
     */
  event Stolen(uint256 indexed _tokenId);

  /**
   * @dev This emits when an authorized identity declare a passport not stolen anymore.
     */
  event UnStolen(uint256 indexed _tokenId);

  /**
   * @param _smartAssetAddress address of SmartAssetContract
      */
  constructor(address _smartAssetAddress, address _managerIdentity) {
    smartAsset = ERC721Interface(_smartAssetAddress);
    setManagerIdentity(_managerIdentity);
  }

  modifier onlyTokenOwnerOrIssuerOrAuthorizedIdentity(uint256 _tokenId){
    require(smartAsset.canOperate(_tokenId, msg.sender)
    || smartAsset.issuerOf(_tokenId) == msg.sender
    || authorizedIdentities[msg.sender],
      "ArianeeLost: only token owner, issuer or authorized identity can operate"
    );
    _;
  }

  /**
   * @dev tokenId's underlying has to be missing
      * @param _tokenId tokenId of certificate.
      */
  modifier onlyHasBeenMissing(uint256 _tokenId){
    require(
      tokenMissingStatus[_tokenId] == true,
      "ArianeeLost: token status must be missing "
    );
    _;
  }

  /**
   * @dev tokenId's underlying has not to be missing
     * @param _tokenId tokenId of certificate.
     */
  modifier onlyHasNotBeenMissing(uint256 _tokenId){
    require(
      tokenMissingStatus[_tokenId] == false,
      "ArianeeLost: token status must be not missing "
    );
    _;
  }

  /**
 * @dev tokenId's underlying has not to be missing
     * @param _tokenId tokenId of certificate.
     */
  modifier onlyIsNotStolen(uint256 _tokenId){
    require(
      tokenStolenStatus[_tokenId] != true,
      "ArianeeLost: token status must be not stolen"
    );
    _;
  }

  /**
 * @dev tokenId's underlying has not to be missing
     * @param _tokenId tokenId of certificate.
     */
  modifier onlyIsStolen(uint256 _tokenId){
    require(
      tokenStolenStatus[_tokenId] == true,
      "ArianeeLost: token status must be stolen"
    );
    _;
  }

  modifier onlyManager(){
    require(
      msg.sender == managerIdentity,
      "ArianeeLost: only manager can operate"
    );
    _;
  }

  modifier onlyAuthorizedIdentityOrIssuer(uint256 _tokenId){
    require(
      smartAsset.issuerOf(_tokenId) == msg.sender || authorizedIdentities[ msg.sender],
      "ArianeeLost: only authorized identity or issuer can operate"
    );
    _;
  }

  modifier onlyAuthorizedIdentityToUnsetStolenStatusOrIssuer(uint256 _tokenId){
    require(smartAsset.issuerOf(_tokenId) == msg.sender
    || authorizedIdentities[msg.sender],

      "ArianeeLost: only token owner, issuer or authorized identity can operate"
    );
    _;
  }

  /**
 * @dev Public function to set tokenId's underlying status as missing
     * @dev Can only be called by the owner of the token or issuer or authorized address
     * @param _tokenId tokenId of certificate.
     */
  function _setMissingStatus(uint256 _tokenId) internal onlyHasNotBeenMissing(_tokenId) {
    tokenMissingStatus[_tokenId] = true;
    emit Missing(_tokenId);
  }

  /**
   * @dev Public function to set tokenId's underlying status as missing
     * @dev Can only be called by the owner of the token or issuer or authorized address
     * @param _tokenId tokenId of certificate.
     */
  function setMissingStatus(uint256 _tokenId) external onlyTokenOwnerOrIssuerOrAuthorizedIdentity(_tokenId) {
    _setMissingStatus(_tokenId);
  }

  /**
     * @dev Public function to unset tokenId's underlying status as missing. underlying has been retrieved.
     * can only be unset if the token is not stolen and has been missing
     * @param _tokenId tokenId of certificate.
     */
  function _unsetMissingStatus(uint256 _tokenId) internal onlyIsNotStolen(_tokenId) onlyHasBeenMissing(_tokenId) {
    tokenMissingStatus[_tokenId] = false;
    emit UnMissing(_tokenId);
  }

  /**
* @dev Public function to unset tokenId's underlying status as missing. underlying has been retrieved.
             * @dev Can only be called by the owner of the token or issuer or authorized address
             * @param _tokenId tokenId of certificate.
             */
  function unsetMissingStatus(uint256 _tokenId) external onlyTokenOwnerOrIssuerOrAuthorizedIdentity(_tokenId) {
    _unsetMissingStatus(_tokenId);
  }

  /**
   * @dev Public function to get missing status of token.
     * @param _tokenId tokenId of certificate.
     * @return _isMissing bool
     */
  function isMissing(uint256 _tokenId) public view returns (bool _isMissing) {
    _isMissing = tokenMissingStatus[_tokenId];
  }

  /**
   * @dev Set the manager identity.
     * @dev Can only be called by the contract owner.
     * @param _managerIdentity the address of the new manager.
     */
  function setManagerIdentity(address _managerIdentity) public onlyOwner() {
    managerIdentity = _managerIdentity;
    emit NewManagerIdentity(_managerIdentity);
  }

  /**
   * @dev Set a new identity authorized to set and unset stolen status.
     * @dev Can only be called by the manager.
     * @param _newIdentityAuthorized address of the new authorized identity.
     */
  function addAuthorizedIdentity(address _newIdentityAuthorized) external onlyManager() {
    authorizedIdentities[_newIdentityAuthorized] = true;
    emit AuthorizedIdentityAdded(_newIdentityAuthorized);
  }

  /**
   * @dev Remove a new identity authorized to set and unset stolen status.
     * @dev Can only be called by the manager.
     * @param _newIdentityUnauthorized address authorized identity to remove.
     */
  function removeAuthorizedIdentity(address _newIdentityUnauthorized) external onlyManager() {
    authorizedIdentities[_newIdentityUnauthorized] = false;
    emit AuthorizedIdentityRemoved(_newIdentityUnauthorized);
  }

  /**
   * @dev Set a token has stolen.
     * @dev Can only be called by an authorized identity.
     * @dev The item need to be missing.
     * @param _tokenId token id to be set as stolen.
     */
  function setStolenStatus(uint256 _tokenId) external onlyIsNotStolen(_tokenId) onlyAuthorizedIdentityOrIssuer(_tokenId) {
    if (tokenMissingStatus[_tokenId] == false) {
      _setMissingStatus(_tokenId);
    }

    tokenStolenStatus[_tokenId] = true;
    tokenStolenIssuer[_tokenId] = msg.sender;
    emit Stolen(_tokenId);
  }

  /**
   * @dev Remove the stolen status
     * @dev Can only be called by the authorized identity that assigned the stolen status or the manager.
     * @param _tokenId token id for which removed the stolen status.
     */
  function unsetStolenStatus(uint256 _tokenId) external onlyIsStolen(_tokenId) onlyAuthorizedIdentityToUnsetStolenStatusOrIssuer(_tokenId) {
    tokenStolenStatus[_tokenId] = false;
    tokenStolenIssuer[_tokenId] = address(0);
    emit UnStolen(_tokenId);
  }

  /**
   * @dev Public function to get the stolen status of token.
     * @param _tokenId tokenId of passport.
     * @return _isStolen bool
     */
  function isStolen(uint256 _tokenId) view external returns (bool _isStolen){
    return tokenStolenStatus[_tokenId];
  }

  /**
   * @dev Public function to know if an address is authorized.
     * @param _address address to check
     * @return _isAuthorized bool
     */
  function isAddressAuthorized(address _address) view external returns (bool _isAuthorized){
    return authorizedIdentities[_address];
  }

/**
 * @dev Public function to get the manager address.
     * @return _managerIdentity bool
     */
  function getManagerIdentity() view external returns (address _managerIdentity){
    return managerIdentity;
  }

}