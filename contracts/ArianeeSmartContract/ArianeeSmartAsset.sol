// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";
import "./ECDSA.sol";

import "./ERC721Tradable.sol";

abstract contract iArianeeWhitelist {
  function addWhitelistedAddress(uint256 _tokenId, address _address) virtual external;
}


abstract contract iArianeeStore{
    function canTransfer(address _to,address _from,uint256 _tokenId) virtual external returns(bool);
    function canDestroy(uint256 _tokenId, address _sender) virtual external returns(bool);
}



/// @title Contract handling Arianee Certificates.

contract ArianeeSmartAsset is ERC721Tradable, Abilitable
{
    
  /**
   * @dev Contract Base URI
   */
  string internal contractURIBase;     
    
  /**
   * @dev Base URI
   */
  string internal URIBase; 

  /**
   * @dev Mapping from token id to URI.
   */
  mapping(uint256 => string) internal idToUri;

  /**
   * @dev Mapping from token id to Token Access (0=view, 1=transfer).
   */
  mapping(uint256 => mapping(uint256 => address)) internal tokenAccess;

  /**
   * @dev Mapping from token id to TokenImprintUpdate.
   */
  mapping(uint256 => bytes32) internal idToImprint;

  /**
   * @dev Mapping from token id to recovery request bool.
   */
  mapping(uint256=>bool) internal recoveryRequest;

  /**
   * @dev Mapping from token id to total rewards for this NFT.
   */
  mapping(uint256=>uint256) internal rewards;

  /**
   * @dev Mapping from token id to Cert.
   */
  mapping(uint256 => Cert) internal certificate;

  /**
   * @dev This emits when a new address is set.
   */
  event SetAddress(string _addressType, address _newAddress);

  struct Cert {
      address tokenIssuer;
      uint256 tokenCreationDate;
      uint256 tokenRecoveryTimestamp;
  }

  /**
   * @dev Ability to create and hydrate NFT.
   */
  uint8 constant ABILITY_CREATE_ASSET = 2;

  /**
   * @dev Error constants.
   */
  string constant CAPABILITY_NOT_SUPPORTED = "007001";
  string constant TRANSFERS_DISABLED = "007002";
  string constant NOT_VALID_CERT = "007003";
  string constant NFT_ALREADY_SET = "007006";
  string constant NOT_OPERATOR = "007004";

  /**
   * Interface for all the connected contracts.
   */
  iArianeeWhitelist public arianeeWhitelist;
  iArianeeStore public store;

  /**
   * @dev This emits when a token is hydrated.
   */
  event Hydrated(uint256 indexed _tokenId, bytes32 indexed _imprint, string _uri, address _initialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey, uint256 _tokenCreation);

  /**
   * @dev This emits when a issuer request a NFT recovery.
   */
  event RecoveryRequestUpdated(uint256 indexed _tokenId, bool _active);

  /**
   * @dev This emits when a NFT is recovered to the issuer.
   */
  event TokenRecovered(uint256 indexed _token);

  /**
   * @dev This emits when a NFT's URI is udpated.
   */
  event TokenURIUpdated(uint256 indexed _tokenId, string URI);

  /**
   * @dev This emits when a token access is added.
   */
  event TokenAccessAdded(uint256 indexed _tokenId, address _encryptedTokenKey, bool _enable, uint256 _tokenType);

  /**
   * @dev This emits when a token access is destroyed.
   */
  event TokenDestroyed(uint256 indexed _tokenId);

  /**
   * @dev This emits when the uri base is udpated.
   */
  event SetNewUriBase(string _newUriBase);


  /**
   * @dev Check if the msg.sender can operate the NFT.
   * @param _tokenId ID of the NFT to test.
   * @param _operator Address to test.
   */
  modifier isOperator(uint256 _tokenId, address _operator) {
    require(canOperate(_tokenId, _operator), NOT_OPERATOR);
    _;
  }

  /**
   * @dev Check if msg.sender is the issuer of a NFT.
   * @param _tokenId ID of the NFT to test.
   */
   modifier isIssuer(uint256 _tokenId) {
    require(msg.sender == certificate[_tokenId].tokenIssuer);
    _;
   }

  /**
    * @dev Initialize this contract. Acts as a constructor
    * @param _arianeeWhitelistAddress Address of the whitelist contract.
    */
  constructor(
    address _arianeeWhitelistAddress,
    string memory _contractURIBase
  )         ERC721Tradable("Arianee", "Arianee", 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)
  {

    contractURIBase = _contractURIBase;

    setWhitelistAddress(_arianeeWhitelistAddress);
    setUriBase("https://cert.arianee.org/");

  }
  
  /**
   * @notice Change address of the store infrastructure.
   * @return contractUri.
   */ 
  function contractURI() public view returns (string memory) {
    return contractURIBase;
  }  

  /**
   * @notice Change address of the store infrastructure.
   * @param _storeAddress new address of the store.
   */
  function setStoreAddress(address _storeAddress) external onlyOwner(){
    store = iArianeeStore(address(_storeAddress));
    emit SetAddress("storeAddress", _storeAddress);
  }

  /**
   * @notice Reserve a NFT at the given ID.
   * @dev Has to be called through an authorized contract.
   * @dev Can only be called by an authorized address.
   * @param _tokenId ID to reserve.
   * @param _to receiver of the token.
   * @param _rewards total rewards of this NFT.
   */
  function reserveToken(uint256 _tokenId, address _to, uint256 _rewards) external hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() {
    super._mint(_to, _tokenId);
    rewards[_tokenId] = _rewards;
  }

  /**
   * @notice Recover the NFT to the issuer.
   * @dev only if called by the issuer and if called before the token Recovery Timestamp of the NFT.
   * @param _tokenId ID of the NFT to recover.
   */
  function recoverTokenToIssuer(uint256 _tokenId) external whenNotPaused() isIssuer(_tokenId) {
    require(block.timestamp < certificate[_tokenId].tokenRecoveryTimestamp);
    _approve(certificate[_tokenId].tokenIssuer,  _tokenId);
    _transferFrom(ownerOf(_tokenId), certificate[_tokenId].tokenIssuer, _tokenId);

    emit TokenRecovered(_tokenId);
  }

  /**
   * @notice Update a recovery request (doesn't transfer the NFT).
   * @dev Works only if called by the issuer.
   * @param _tokenId ID of the NFT to recover.
   * @param _active boolean to active or unactive the request.
   */
  function updateRecoveryRequest(uint256 _tokenId, bool _active) external whenNotPaused() isIssuer(_tokenId){
    recoveryRequest[_tokenId] = _active;

    emit RecoveryRequestUpdated(_tokenId, _active);
  }

  /**
   * @notice Valid a recovery request and transfer the NFT to the issuer.
   * @dev only if the request is active and if called by the owner of the contract.
   * @param _tokenId Id of the NFT to recover.
   */
  function validRecoveryRequest(uint256 _tokenId) external onlyOwner(){
    require(recoveryRequest[_tokenId]);
    recoveryRequest[_tokenId] = false;

    _approve(owner(),  _tokenId);
    
    _transferFrom(ownerOf(_tokenId), certificate[_tokenId].tokenIssuer, _tokenId);

    emit RecoveryRequestUpdated(_tokenId, false);
    emit TokenRecovered(_tokenId);
  }

  /**
   * @notice External function to update the tokenURI.
   * @notice Can only be called by the NFT's issuer.
   * @param _tokenId ID of the NFT to edit.
   * @param _uri New URI for the certificate.
   */
  function updateTokenURI(uint256 _tokenId, string calldata _uri) external isIssuer(_tokenId) whenNotPaused() {
    require(ownerOf(_tokenId) != address(0), NOT_VALID_CERT);
    idToUri[_tokenId] = _uri;

    emit TokenURIUpdated(_tokenId, _uri);
  }

  /**
   * @notice Add a token access to a NFT.
   * @notice can only be called by an NFT's operator.
   * @param _tokenId ID of the NFT.
   * @param _key Public address of the token to encode the hash with.
   * @param _enable Enable or disable the token access.
   * @param _tokenType Type of token access (0=view, 1=tranfer).
   */
  function addTokenAccess(uint256 _tokenId, address _key, bool _enable, uint256 _tokenType) external isOperator(_tokenId, msg.sender) whenNotPaused() {
      require(_tokenType>0);
    if (_enable) {
      tokenAccess[_tokenId][_tokenType] = _key;
    }
    else {
      tokenAccess[_tokenId][_tokenType] = address(0);
    }

    emit TokenAccessAdded(_tokenId, _key, _enable, _tokenType);
  }

  /**
   * @notice Transfers the ownership of a NFT to another address
   * @notice Requires to send the correct tokenKey and the NFT has to be requestable
   * @dev Has to be called through an authorized contract.
   * @dev approve the requester if _tokenKey is valid to allow transferFrom without removing ERC721 compliance.
   * @param _tokenId ID of the NFT to transfer.
   * @param _hash Hash of tokenId + newOwner address.
   * @param _keepRequestToken If false erase the access token of the NFT.
   * @param _newOwner Address of the new owner of the NFT.
   */
  function requestToken(uint256 _tokenId, bytes32 _hash, bool _keepRequestToken, address _newOwner, bytes calldata _signature) external hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() returns(uint256 reward){

    require(isTokenValid(_tokenId, _hash, 1, _signature));
    bytes32 message = keccak256(abi.encode(_tokenId, _newOwner));
    require(ECDSA.toEthSignedMessageHash(message) == _hash);

    _approve(msg.sender,  _tokenId);

    if(!_keepRequestToken){
      tokenAccess[_tokenId][1] = address(0);
    }
    _transferFrom(ownerOf(_tokenId), _newOwner, _tokenId);
    reward = rewards[_tokenId];
    delete rewards[_tokenId];
  }

  /**
   * @notice Destroy a token.
   * @notice Can only be called by the issuer.
   * @param _tokenId to destroy.
   */
  function destroy(uint256 _tokenId) external whenNotPaused() {
    require(store.canDestroy(_tokenId, msg.sender));

    _burn(_tokenId);
    idToImprint[_tokenId] = "";
    idToUri[_tokenId] = "";
    tokenAccess[_tokenId][0] = address(0);
    tokenAccess[_tokenId][1] = address(0);
    rewards[_tokenId] = 0;
    Cert memory _emptyCert = Cert({
             tokenIssuer : address(0),
             tokenCreationDate: 0,
             tokenRecoveryTimestamp: 0
            });

    certificate[_tokenId] = _emptyCert;

    emit TokenDestroyed(_tokenId);
  }

  /**
   * @notice Check if a token is requestable.
   * @param _tokenId uint256 ID of the token to check.
   * @return True if the NFT is requestable.
   */
  function isRequestable(uint256 _tokenId) external view returns (bool) {
    return tokenAccess[_tokenId][1] != address(0);
  }

  /**
   * @notice The issuer address for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the issuer.
   * @return _tokenIssuer Issuer address of _tokenIssuer.
   */
  function issuerOf(uint256 _tokenId) external view returns(address _tokenIssuer){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _tokenIssuer = certificate[_tokenId].tokenIssuer;
  }

   /**
   * @notice The imprint for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the imprint.
   * @return _imprint Imprint address of _tokenId.
   */
  function tokenImprint(uint256 _tokenId) external view returns(bytes32 _imprint){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _imprint = idToImprint[_tokenId];
  }


  /**
   * @notice The creation date for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the creation date.
   * @return _tokenCreation Creation date of _tokenId.
   */
  function tokenCreation(uint256 _tokenId) external view returns(uint256 _tokenCreation){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _tokenCreation = certificate[_tokenId].tokenCreationDate;
  }

  /**
   * @notice The Token Access for a given Token ID and token type.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the token access.
   * @param _tokenType for which we want the token access.
   * @return _tokenAccess Token access of _tokenId.
   */
  function tokenHashedAccess(uint256 _tokenId, uint256 _tokenType) external view returns(address _tokenAccess){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _tokenAccess = tokenAccess[_tokenId][_tokenType];
  }

  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return _tokenRecoveryTimestamp Recovery timestamp of _tokenId.
   */
  function tokenRecoveryDate(uint256 _tokenId) external view returns(uint256 _tokenRecoveryTimestamp){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _tokenRecoveryTimestamp = certificate[_tokenId].tokenRecoveryTimestamp;
  }

  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return _recoveryRequest Recovery timestamp of _tokenId.
   */
  function recoveryRequestOpen(uint256 _tokenId) external view returns(bool _recoveryRequest){
      require(ownerOf(_tokenId) != address(0), 'NOT_VALID_NFT');
      _recoveryRequest = recoveryRequest[_tokenId];
  }

  /**
   * @notice The rewards for a given Token ID.
   * @param _tokenId Id for which we want the rewards.
   * @return Rewards of _tokenId.
   */
  function getRewards(uint256 _tokenId) external view returns(uint256){
      return rewards[_tokenId];
  }

  /**
   * @notice Check if an operator is valid for a given NFT.
   * @param _tokenId nft to check.
   * @param _operator operator to check.
   * @return true if operator is valid.
   */
  function canOperate(uint256 _tokenId, address _operator) public view returns (bool){
    address tokenOwner = ownerOf(_tokenId);
    return tokenOwner == _operator || isApprovedForAll(tokenOwner,_operator);
  }

  /**
   * @notice Change the base URI address.
   * @param _newURIBase the new URI base address.
   */
  function setUriBase(string memory _newURIBase) public onlyOwner(){
      URIBase = _newURIBase;
      
      emit SetNewUriBase(URIBase);
  }

  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overriden in child contracts.
   */
  function baseTokenURI() override public view returns (string memory) {
      return URIBase;
  }
  


  /**
   * @notice Change address of the whitelist.
   * @param _whitelistAddres new address of the whitelist.
   */
  function setWhitelistAddress(address _whitelistAddres) public onlyOwner(){
    arianeeWhitelist = iArianeeWhitelist(address(_whitelistAddres));
    emit SetAddress("whitelistAddress", _whitelistAddres);
  }

  /**
   * @notice Specify information on a reserved NFT.
   * @dev to be called through an authorized contract.
   * @dev Can only be called once and by an NFT's operator.
   * @param _tokenId ID of the NFT to modify.
   * @param _imprint Proof of the certification.
   * @param _uri URI of the JSON certification.
   * @param _initialKey Initial key.
   * @param _tokenRecoveryTimestamp Limit date for the issuer to be able to transfer back the NFT.
   * @param _initialKeyIsRequestKey If true set initial key as request key.
   */
  function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, address _initialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey, address _owner) public hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() isOperator(_tokenId, _owner) returns(uint256){
    require(!(certificate[_tokenId].tokenCreationDate > 0), NFT_ALREADY_SET);
    uint256 _tokenCreation = block.timestamp;
    tokenAccess[_tokenId][0] = _initialKey;
    idToImprint[_tokenId] = _imprint;
    idToUri[_tokenId] = _uri;

    arianeeWhitelist.addWhitelistedAddress(_tokenId, _owner);

    if (_initialKeyIsRequestKey) {
      tokenAccess[_tokenId][1] = _initialKey;
    }

    Cert memory _cert = Cert({
             tokenIssuer : _owner,
             tokenCreationDate: _tokenCreation,
             tokenRecoveryTimestamp :_tokenRecoveryTimestamp
            });

    certificate[_tokenId] = _cert;

    emit Hydrated(_tokenId, _imprint, _uri, _initialKey, _tokenRecoveryTimestamp, _initialKeyIsRequestKey, _tokenCreation);

    return rewards[_tokenId];
  }

  /**
   * @notice Check if a token access is valid.
   * @param _tokenId ID of the NFT to validate.
   * @param _hash Hash of tokenId + newOwner address.
   * @param _tokenType Type of token access (0=view, 1=transfer).
   */
  function isTokenValid(uint256 _tokenId, bytes32 _hash, uint256 _tokenType, bytes memory _signature) public view returns (bool){
    return ECDSA.recover(_hash, _signature) ==  tokenAccess[_tokenId][_tokenType];
  }

  /**
   * @notice Legacy function of TransferFrom, add the new owner as whitelisted for the message.
   * @dev Require the store to approve the transfer.
   */
  function _transferFrom(address _to, address _from, uint256 _tokenId) internal {
    require(store.canTransfer(_to, _from, _tokenId));
    super.transferFrom(_to, _from, _tokenId);
    arianeeWhitelist.addWhitelistedAddress(_tokenId, _to);
  }


  /**
   * @notice Change address of the proxyRegistryAddress.
   * @param _proxyRegistryAddress new address of the whitelist.
   */
  function setProxyRegistryAddress(address _proxyRegistryAddress) public onlyOwner(){
    proxyRegistryAddress = _proxyRegistryAddress;
    emit SetAddress("proxyRegistryAddress", proxyRegistryAddress);
  }    

}

