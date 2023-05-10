// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../Utilities/0x/NFTokenMetadataEnumerable.sol";
import "../Utilities/0x/Abilitable.sol";
import "../Interfaces/IArianeeWhitelist.sol";
import "../Interfaces/IArianeeStore.sol";

/// @title Contract handling Arianee Certificates.
contract ArianeeSmartAsset is NFTokenMetadataEnumerable, Abilitable, Ownable, Pausable {
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
   * @dev Mapping from token id to Cert.
   */
  mapping(uint256 => Cert) internal certificate;

  /**
   * @dev Mapping from token id to a boolean that indicates whether the first transfer has been done or not.
   */
  mapping (uint256 => bool) internal idToFirstTransfer;

  /**
   * @dev Flag indicating if the NFT is a soulbound token (non-transferable) or not.
   */
  bool public isSoulbound;

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
  IArianeeWhitelist public arianeeWhitelist;
  IArianeeStore public store;

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
   * @dev Check if the _msgSender() can operate the NFT.
   * @param _tokenId ID of the NFT to test.
   * @param _operator Address to test.
   */
  modifier isOperator(uint256 _tokenId, address _operator) {
    require(canOperate(_tokenId, _operator), NOT_OPERATOR);
    _;
  }

  /**
   * @dev Check if _msgSender() is the issuer of a NFT.
   * @param _tokenId ID of the NFT to test.
   */
   modifier isIssuer(uint256 _tokenId) {
    require(_msgSender() == certificate[_tokenId].tokenIssuer);
    _;
   }

  /**
    * @dev Initialize this contract. Acts as a constructor
    * @param _arianeeWhitelistAddress Address of the whitelist contract.
    */
  constructor(
    address _arianeeWhitelistAddress,
    address _forwarder,
    bool _isSoulbound
  )
  {
    nftName = "Arianee";
    nftSymbol = "Arianee";
    isSoulbound = _isSoulbound;

    setWhitelistAddress(_arianeeWhitelistAddress);

    // 28.04.2023: Keeping the same behaviour with the new _setUri function, passing an empty string as postfix parameter
    // _setUriBase("https://cert.arianee.org/");
    _setUri("https://cert.arianee.org/", "");

    _setTrustedForwarder(_forwarder);
  }

  function updateForwarderAddress(address _forwarder) external onlyOwner {
    _setTrustedForwarder(_forwarder);
  }

  function _msgSender() internal override(Context, ERC2771Recipient) view returns (address ret) {
    return ERC2771Recipient._msgSender();
  }

  function _msgData() internal override(Context, ERC2771Recipient) view returns (bytes calldata ret) {
    ret = ERC2771Recipient._msgData();
  }

  /**
   * @notice Change address of the store infrastructure.
   * @param _storeAddress new address of the store.
   */
  function setStoreAddress(address _storeAddress) external onlyOwner(){
    store = IArianeeStore(address(_storeAddress));
    emit SetAddress("storeAddress", _storeAddress);
  }

  /**
   * @notice Reserve a NFT at the given ID.
   * @dev Has to be called through an authorized contract.
   * @dev Can only be called by an authorized address.
   * @param _tokenId ID to reserve.
   * @param _to receiver of the token.
   */
  function reserveToken(uint256 _tokenId, address _to) external hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() {
    super._create(_to, _tokenId);
    idToFirstTransfer[_tokenId] = true;
  }

  /**
   * @notice Recover the NFT to the issuer.
   * @dev only if called by the issuer and if called before the token Recovery Timestamp of the NFT.
   * @param _tokenId ID of the NFT to recover.
   */
  function recoverTokenToIssuer(uint256 _tokenId) external whenNotPaused() isIssuer(_tokenId) {
    require(block.timestamp < certificate[_tokenId].tokenRecoveryTimestamp);
    idToApproval[_tokenId] = certificate[_tokenId].tokenIssuer;
    _transferFrom(idToOwner[_tokenId], certificate[_tokenId].tokenIssuer, _tokenId);

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
  function validRecoveryRequest(uint256 _tokenId) external onlyOwner() {
    require(recoveryRequest[_tokenId]);
    recoveryRequest[_tokenId] = false;

    idToApproval[_tokenId] = owner();
    _transferFrom(idToOwner[_tokenId], certificate[_tokenId].tokenIssuer, _tokenId);

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
    require(idToOwner[_tokenId] != address(0), NOT_VALID_CERT);
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
  function addTokenAccess(uint256 _tokenId, address _key, bool _enable, uint256 _tokenType) external isOperator(_tokenId, _msgSender()) whenNotPaused() {
    require(_tokenType > 0, "ArianeeSmartAsset: The tokenType parameter must be > 0");

    bool isTransferTokenAccess = (_tokenType == 1);
    if (isTransferTokenAccess && isSoulbound) {
      address tokenOwner = idToOwner[_tokenId];
      address tokenIssuer = certificate[_tokenId].tokenIssuer;
      require(tokenOwner == tokenIssuer, "ArianeeSmartAsset: Only the issuer can add a transfer token access to a soulbound smart asset");
    }

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
  function requestToken(uint256 _tokenId, bytes32 _hash, bool _keepRequestToken, address _newOwner, bytes calldata _signature) external hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() {
    require(isTokenValid(_tokenId, _hash, 1, _signature), "ArianeeSmartAsset: Invalid request token");
    bytes32 message = keccak256(abi.encode(_tokenId, _newOwner));
    require(ECDSA.toEthSignedMessageHash(message) == _hash);

    idToApproval[_tokenId] = _msgSender();

    if (_keepRequestToken) {
      require(isSoulbound == false, "ArianeeSmartAsset: Forbidden to keep the request token for a soulbound smart asset");
    } else {
      tokenAccess[_tokenId][1] = address(0);
    }

    _transferFrom(idToOwner[_tokenId], _newOwner, _tokenId);
  }

  /**
   * @notice Destroy a token.
   * @notice Can only be called by the issuer.
   * @param _tokenId to destroy.
   */
  function destroy(uint256 _tokenId) external whenNotPaused() {
    require(store.canDestroy(_tokenId, _msgSender(), isSoulbound));

    _destroy(_tokenId);

    delete idToFirstTransfer[_tokenId];
    delete idToImprint[_tokenId];
    delete idToUri[_tokenId];

    delete tokenAccess[_tokenId][0];
    delete tokenAccess[_tokenId][1];

    delete certificate[_tokenId];

    emit TokenDestroyed(_tokenId);
  }

  /**
   * @notice return the URI of a NFT.
   * @param _tokenId uint256 ID of the NFT.
   * @return URI of the NFT.
   */
  function tokenURI(uint256 _tokenId) external override view returns (string memory){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_CERT);
      if(bytes(idToUri[_tokenId]).length > 0){
        return idToUri[_tokenId];
      }
      else{
          return string(abi.encodePacked(uriPrefix, _uint2str(_tokenId)));
      }
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
   * @return _tokenIssuer Issuer address of _tokenId.
   */
  function issuerOf(uint256 _tokenId) external view returns(address _tokenIssuer){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenIssuer = certificate[_tokenId].tokenIssuer;
  }

   /**
   * @notice The imprint for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the imprint.
   * @return _imprint Imprint address of _tokenId.
   */
  function tokenImprint(uint256 _tokenId) external view returns(bytes32 _imprint){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _imprint = idToImprint[_tokenId];
  }


  /**
   * @notice The creation date for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the creation date.
   * @return _tokenCreation Creation date of _tokenId.
   */
  function tokenCreation(uint256 _tokenId) external view returns(uint256 _tokenCreation){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
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
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenAccess = tokenAccess[_tokenId][_tokenType];
  }

  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return _tokenRecoveryTimestamp Recovery timestamp of _tokenId.
   */
  function tokenRecoveryDate(uint256 _tokenId) external view returns(uint256 _tokenRecoveryTimestamp){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenRecoveryTimestamp = certificate[_tokenId].tokenRecoveryTimestamp;
  }

  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return _recoveryRequest Recovery timestamp of _tokenId.
   */
  function recoveryRequestOpen(uint256 _tokenId) external view returns(bool _recoveryRequest){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _recoveryRequest = recoveryRequest[_tokenId];
  }

  /**
   * @notice Check if an operator is valid for a given NFT.
   * @param _tokenId nft to check.
   * @param _operator operator to check.
   * @return true if operator is valid.
   */
  function canOperate(uint256 _tokenId, address _operator) public view returns (bool){
    address tokenOwner = idToOwner[_tokenId];
    return tokenOwner == _operator || ownerToOperators[tokenOwner][_operator];
  }

  /**
   * @notice Change the base URI address.
   * @param _newURIBase the new URI base address.
   */
  function setUriBase(string memory _newURIBase) public onlyOwner() {
      // 28.04.2023: Keeping the same behaviour with the new _setUri function, passing an empty string as postfix parameter
      // _setUriBase(_newURIBase);
      _setUri(_newURIBase, "");
      emit SetNewUriBase(_newURIBase);
  }

  /**
   * @notice Change address of the whitelist.
   * @param _whitelistAddres new address of the whitelist.
   */
  function setWhitelistAddress(address _whitelistAddres) public onlyOwner(){
    arianeeWhitelist = IArianeeWhitelist(address(_whitelistAddres));
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
  function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, address _initialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey, address _owner) public hasAbilities(ABILITY_CREATE_ASSET) whenNotPaused() isOperator(_tokenId, _owner) {
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
   * @notice Override of the _transferFrom function that perform multiple checks depending on the token type.
   * @dev Require the store to approve the transfer.
   * @dev Dispatch the rewards at the first transfer of a token.
   */
  function _transferFrom(address _from, address _to, uint256 _tokenId) internal override {
    require(store.canTransfer(_from, _to, _tokenId, isSoulbound), "ArianeeSmartAsset: Transfer rejected by the store");

    if (isSoulbound) {
      address tokenOwner = idToOwner[_tokenId];
      require(tokenOwner == _from, NOT_VALID_NFT);

      address tokenIssuer = certificate[_tokenId].tokenIssuer;

      // If the owner is NOT the issuer, the token is soulbound and the transfer can be made only by the issuer to change the owner if needed
      if (tokenOwner != tokenIssuer) {
        require(tokenIssuer == _msgSender(), "ArianeeSmartAsset: Only the issuer can transfer a soulbound smart asset");
      }

      /*
      * If the previous condition has not been hit, the owner IS the issuer and the token is not soulbound yet or not anymore for a limited time.
      * This is either the first transfer of the token to its first "real" owner or a recovery request made by the issuer on the behalf of the owner (i.e the owner lost his wallet and wants to recover his token)
      */
    }

    super._transferFrom(_from, _to, _tokenId);
    arianeeWhitelist.addWhitelistedAddress(_tokenId, _to);

    if (_isFirstTransfer(_tokenId)) {
      idToFirstTransfer[_tokenId] = false;
      store.dispatchRewardsAtFirstTransfer(_tokenId, _to);
    }
  }

  function _isFirstTransfer(uint256 _tokenId) internal view returns (bool) {
    return idToFirstTransfer[_tokenId] == true;
  }

}

