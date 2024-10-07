// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import '@opengsn/contracts/src/ERC2771Recipient.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

import './UnorderedNonce.sol';
import '../Utilities/ByteUtils.sol';

import '../Interfaces/IArianeeStore.sol';
import '../Interfaces/IArianeeSmartAsset.sol';
import '../Interfaces/IArianeeEvent.sol';
import '../Interfaces/IArianeeLost.sol';
import '../Interfaces/IArianeeCreditNotePool.sol';
import '../Interfaces/IPoseidon.sol';

interface IOwnershipVerifier {
  function verifyProof(
    uint[2] calldata _pA,
    uint[2][2] calldata _pB,
    uint[2] calldata _pC,
    uint[3] calldata _pubSignals
  ) external view returns (bool);
}

contract ArianeeIssuerProxy is Ownable2Step, UnorderedNonce, ERC2771Recipient {
  using ByteUtils for bytes;

  uint256 public constant CREDIT_TYPE_CERTIFICATE = 0;
  uint256 public constant CREDIT_TYPE_MESSAGE = 1;
  uint256 public constant CREDIT_TYPE_EVENT = 2;
  uint256 public constant CREDIT_TYPE_UPDATE = 3;

  /**
   * @notice The OwnershipProof must be the first argument if used in a function
   * This is allowing us to remove the OwnershipProof from `_msgData()` easily
   */
  struct OwnershipProof {
    uint[2] _pA; // 64 bytes
    uint[2][2] _pB; // 128 bytes
    uint[2] _pC; // 64 bytes
    uint[3] _pubSignals; // 96 bytes
  } // Total: 352 bytes

  uint256 public constant SELECTOR_SIZE = 4;
  uint256 public constant OWNERSHIP_PROOF_SIZE = 352;
  uint256 public constant CREDIT_NOTE_PROOF_SIZE = 384;

  /**
   * @notice The ArianeeStore contract used to pass issuer intents (can be updated)
   */
  IArianeeStore public store;
  /**
   * @notice The ArianeeSmartAsset contract used to pass issuer intents
   */
  IArianeeSmartAsset public immutable smartAsset;
  /**
   * @notice The ArianeeEvent contract used to pass issuer intents
   */
  IArianeeEvent public immutable arianeeEvent;
  /**
   * @notice The ArianeeLost contract used to pass issuer intents
   */
  IArianeeLost public immutable arianeeLost;

  /**
   * @notice The contract used to verify the ownership proofs
   */
  IOwnershipVerifier public immutable verifier;

  /**
   * @notice The contract used to compute Poseidon hashes
   */
  IPoseidon public immutable poseidon;

  /**
   * @notice The contracts used for credit notes management
   */
  mapping(address => bool) public creditNotePools;
  /**
   * @notice The addresses allowed to send intents without a CreditNoteProof
   */
  mapping(address => bool) public creditFreeSenders;

  /**
   * @notice Mapping<TokenId, CommitmentHash>
   */
  mapping(uint256 tokenId => uint256) public commitmentHashes;

  /**
   * @notice Emitted when a "credit free sender" is sending an intent
   */
  event CreditFreeSenderLog(address indexed _sender, uint256 _creditType);
  /**
   * @notice Emitted when a "credit free sender" is added
   */
  event CreditFreeSenderAdded(address indexed _sender);
  /**
   * @notice Emitted when a "credit free sender" is removed
   */
  event CreditFreeSenderRemoved(address indexed _sender);

  /**
   * @notice Emitted when a CreditNotePool is added
   */
  event CreditNotePoolAdded(address indexed _creditNotePool);

  /**
   * @notice Emitted when a token commitment is registered
   */
  event TokenCommitmentRegistered(uint256 indexed _commitmentHash, uint256 indexed _tokenId);
  /**
   * @notice Emitted when a token commitment is updated
   */
  event TokenCommitmentUpdated(uint256 indexed _previousCommitmentHash, uint256 indexed _newCommitmentHash, uint256 indexed _tokenId);
  /**
   * @notice Emitted when a token commitment is unregistered
   */
  event TokenCommitmentUnregistered(uint256 indexed _commitmentHash, uint256 indexed _tokenId);

  /**
   * @notice Emitted when the store address is updated
   */
  event StoreUpdated(address _oldStore, address _newStore);

  constructor(
    address _store,
    address _smartAsset,
    address _arianeeEvent,
    address _arianeeLost,
    address _verifier,
    address _poseidon,
    address _trustedForwarder
  ) {
    _setTrustedForwarder(_trustedForwarder);
    _setStoreAddress(_store);

    smartAsset = IArianeeSmartAsset(_smartAsset);
    arianeeEvent = IArianeeEvent(_arianeeEvent);
    arianeeLost = IArianeeLost(_arianeeLost);
    verifier = IOwnershipVerifier(_verifier);
    poseidon = IPoseidon(_poseidon);
  }

  // OwnershipProof

  modifier onlyWithProof(OwnershipProof calldata _ownershipProof, bool needsCreditNoteProof, uint256 _tokenId) {
    _verifyProof(_ownershipProof, needsCreditNoteProof, _tokenId);
    _;
  }

  function _verifyProof(OwnershipProof calldata _ownershipProof, bool needsCreditNoteProof, uint256 _tokenId) internal {
    require(commitmentHashes[_tokenId] != 0, 'ArianeeIssuerProxy: No commitment registered for this token');

    uint256 pCommitmentHash = _ownershipProof._pubSignals[0];
    require(
      pCommitmentHash == commitmentHashes[_tokenId],
      'ArianeePrivacyProxy: Proof commitment does not match the registered commitment for this token'
    );

    uint256 pIntentHash = _ownershipProof._pubSignals[1];
    bytes memory msgData = _msgData();

    // Removing the `OwnershipProof` (352 bytes) and if needed the `CreditNoteProof` (384 bytes) from the msg.data before computing the hash to compare
    uint256 msgDataHash = uint256(poseidon.poseidon([keccak256(abi.encodePacked(bytes.concat(msgData.slice(0, SELECTOR_SIZE), msgData.slice(SELECTOR_SIZE + OWNERSHIP_PROOF_SIZE + (needsCreditNoteProof ? CREDIT_NOTE_PROOF_SIZE : 0), msgData.length))))]));
    require(
      pIntentHash == msgDataHash,
      'ArianeePrivacyProxy: Proof intent does not match the function call'
    );

    uint256 pNonce = _ownershipProof._pubSignals[2];
    require(_useUnorderedNonce(pCommitmentHash, pNonce), 'ArianeePrivacyProxy: Proof nonce has already been used');

    require(
      verifier.verifyProof(_ownershipProof._pA, _ownershipProof._pB, _ownershipProof._pC, _ownershipProof._pubSignals),
      'ArianeePrivacyProxy: OwnershipProof verification failed'
    );
  }

  function tryRegisterCommitment(uint256 _tokenId, uint256 _commitmentHash) internal {
    require(
      commitmentHashes[_tokenId] == 0,
      'ArianeeIssuerProxy: A commitment has already been registered for this token'
    );
    commitmentHashes[_tokenId] = _commitmentHash;
    emit TokenCommitmentRegistered(_commitmentHash, _tokenId);
  }

  function tryUnregisterCommitment(uint256 _tokenId) internal {
    require(
      commitmentHashes[_tokenId] != 0,
      'ArianeeIssuerProxy: No commitment registered for this token'
    );
    uint256 commitmentHash = commitmentHashes[_tokenId];
    delete commitmentHashes[_tokenId];
    emit TokenCommitmentUnregistered(commitmentHash, _tokenId);
  }

  // CreditNoteProof

  function trySpendCredit(address _creditNotePool, uint256 _creditType, CreditNoteProof calldata _creditNoteProof) internal {
    if (creditFreeSenders[_msgSender()] == true) {
      emit CreditFreeSenderLog(_msgSender(), _creditType);
    } else {
      require(creditNotePools[_creditNotePool] == true, 'ArianeeIssuerProxy: Target IArianeeCreditNotePool is not whitelisted');
      IArianeeCreditNotePool(_creditNotePool).spend(_creditNoteProof, _msgData(), _creditType);
    }
  }

  function addCreditNotePool(address _creditNotePool) external onlyOwner {
    creditNotePools[_creditNotePool] = true;
    emit CreditNotePoolAdded(_creditNotePool);
  }

  function addCreditFreeSender(address _sender) public onlyOwner {
    creditFreeSenders[_sender] = true;
    emit CreditFreeSenderAdded(_sender);
  }

  function addCreditFreeSenderBatch(address[] calldata _senders) external onlyOwner {
    for (uint256 i = 0; i < _senders.length; i++) {
      addCreditFreeSender(_senders[i]);
    }
  }

  function removeCreditFreeSender(address _sender) public onlyOwner {
    delete creditFreeSenders[_sender];
    emit CreditFreeSenderRemoved(_sender);
  }

  function removeCreditFreeSenderBatch(address[] calldata _senders) external onlyOwner {
    for (uint256 i = 0; i < _senders.length; i++) {
      removeCreditFreeSender(_senders[i]);
    }
  }

  // IArianeeStore (IArianeeSmartAsset related functions)

  function reserveToken(uint256 _commitmentHash, uint256 _tokenId) external {
    tryRegisterCommitment(_tokenId, _commitmentHash);
    store.reserveToken(_tokenId, address(this));
  }

  function hydrateToken(
    OwnershipProof calldata _ownershipProof,
    CreditNoteProof calldata _creditNoteProof,
    address _creditNotePool,
    uint256 _commitmentHash, // If no proof is provided, this commitment hash is required
    uint256 _tokenId,
    bytes32 _imprint,
    string memory _uri,
    address _encryptedInitialKey,
    uint256 _tokenRecoveryTimestamp,
    bool _initialKeyIsRequestKey,
    address _interfaceProvider
  ) external {
    if (_commitmentHash != 0) {
      // If a commitment hash is provided, we try to register it before hydrating the token
      // This can happen if the token was not reserved before being hydrated
      tryRegisterCommitment(_tokenId, _commitmentHash);
    }

    // Proof verification is made inline here because we need to do it after the eventual commitment hash registration
    _verifyProof(_ownershipProof, true, _tokenId);

    trySpendCredit(_creditNotePool, CREDIT_TYPE_CERTIFICATE, _creditNoteProof);

    store.hydrateToken(
      _tokenId,
      _imprint,
      _uri,
      _encryptedInitialKey,
      _tokenRecoveryTimestamp,
      _initialKeyIsRequestKey,
      _interfaceProvider
    );
  }

  // UnorderedNonce

  function invalidateUnorderedNonces(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId,
    uint256 _commitmentHash,
    uint256 _wordPos,
    uint256 _mask
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    invalidateUnorderedNonces(_commitmentHash, _wordPos, _mask);
  }

  // IArianeeSmartAsset

  function addTokenAccess(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId,
    address _key,
    bool _enable,
    uint256 _tokenType
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.addTokenAccess(_tokenId, _key, _enable, _tokenType);
  }

  function recoverTokenToIssuer(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.recoverTokenToIssuer(_tokenId);
  }

  function updateRecoveryRequest(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId,
    bool _active
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.updateRecoveryRequest(_tokenId, _active);
  }

  function destroy(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.destroy(_tokenId);
    // Free the commitment hash when destroying the token to allow it to be reused
    tryUnregisterCommitment(_tokenId);
  }

  function updateTokenURI(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId,
    string calldata _uri
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.updateTokenURI(_tokenId, _uri);
  }

  function safeTransferFrom(
    OwnershipProof calldata _ownershipProof,
    address _from,
    address _to,
    uint256 _tokenId,
    bytes calldata _data
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.safeTransferFrom(_from, _to, _tokenId, _data);
  }

  function transferFrom(
    OwnershipProof calldata _ownershipProof,
    address _from,
    address _to,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.transferFrom(_from, _to, _tokenId);
  }

  function approve(
    OwnershipProof calldata _ownershipProof,
    address _approved,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    smartAsset.approve(_approved, _tokenId);
  }

  // IArianeeStore (IArianeeUpdate related functions)

  function updateSmartAsset(
    OwnershipProof calldata _ownershipProof,
    CreditNoteProof calldata _creditNoteProof,
    address _creditNotePool,
    uint256 _tokenId,
    bytes32 _imprint,
    address _interfaceProvider
  ) external onlyWithProof(_ownershipProof, true, _tokenId) {
    trySpendCredit(_creditNotePool, CREDIT_TYPE_UPDATE, _creditNoteProof);
    store.updateSmartAsset(_tokenId, _imprint, _interfaceProvider);
  }

  // IArianeeStore (IArianeeEvent related functions)

  function createEvent(
    OwnershipProof calldata _ownershipProof,
    CreditNoteProof calldata _creditNoteProof,
    address _creditNotePool,
    uint256 _tokenId,
    uint256 _eventId,
    bytes32 _imprint,
    string calldata _uri,
    address _interfaceProvider
  ) external onlyWithProof(_ownershipProof, true, _tokenId) {
    trySpendCredit(_creditNotePool, CREDIT_TYPE_EVENT, _creditNoteProof);
    store.createEvent(_eventId, _tokenId, _imprint, _uri, _interfaceProvider);
  }

  function acceptEvent(OwnershipProof calldata _ownershipProof, uint256 _eventId, address _interfaceProvider) external {
    uint256 tokenId = arianeeEvent.eventIdToToken(_eventId);
    require(tokenId != 0, 'ArianeePrivacyProxy: Event not found');

    // Proof verification is made inline here because we need to get the tokenId from the eventId first
    _verifyProof(_ownershipProof, false, tokenId);

    store.acceptEvent(_eventId, _interfaceProvider);
  }

  // IArianeeEvent

  function destroyEvent(OwnershipProof calldata _ownershipProof, uint256 _eventId) external {
    uint256 tokenId = arianeeEvent.eventIdToToken(_eventId);
    require(tokenId != 0, 'ArianeePrivacyProxy: Event not found');

    // Proof verification is made inline here because we need to get the tokenId from the eventId first
    _verifyProof(_ownershipProof, false, tokenId);

    arianeeEvent.destroy(_eventId);
  }

  function updateDestroyEventRequest(OwnershipProof calldata _ownershipProof, uint256 _eventId, bool _active) external {
    uint256 tokenId = arianeeEvent.eventIdToToken(_eventId);
    require(tokenId != 0, 'ArianeePrivacyProxy: Event not found');

    // Proof verification is made inline here because we need to get the tokenId from the eventId first
    _verifyProof(_ownershipProof, false, tokenId);

    arianeeEvent.updateDestroyRequest(_eventId, _active);
  }

  // IArianeeStore (IArianeeMessage related functions)

  function createMessage(
    OwnershipProof calldata _ownershipProof,
    CreditNoteProof calldata _creditNoteProof,
    address _creditNotePool,
    uint256 _messageId,
    uint256 _tokenId,
    bytes32 _imprint,
    address _interfaceProvider
  ) external onlyWithProof(_ownershipProof, true, _tokenId) {
    trySpendCredit(_creditNotePool, CREDIT_TYPE_MESSAGE, _creditNoteProof);
    store.createMessage(_messageId, _tokenId, _imprint, _interfaceProvider);
  }

  // IArianeeLost

  function setStolenStatus(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    arianeeLost.setStolenStatus(_tokenId);
  }

  function unsetStolenStatus(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    arianeeLost.unsetStolenStatus(_tokenId);
  }

  function setMissingStatus(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    arianeeLost.setMissingStatus(_tokenId);
  }

  function unsetMissingStatus(
    OwnershipProof calldata _ownershipProof,
    uint256 _tokenId
  ) external onlyWithProof(_ownershipProof, false, _tokenId) {
    arianeeLost.unsetMissingStatus(_tokenId);
  }

  // Emergency

  function updateCommitment(OwnershipProof calldata _ownershipProof, uint256 _tokenId, uint256 _newCommitmentHash) public onlyWithProof(_ownershipProof, false, _tokenId) onlyOwner {
    require(
      commitmentHashes[_tokenId] != 0,
      'ArianeeIssuerProxy: No commitment registered for this token'
    );
    uint256 previousCommitmentHash = commitmentHashes[_tokenId];
    commitmentHashes[_tokenId] = _newCommitmentHash;
    emit TokenCommitmentUpdated(previousCommitmentHash, _newCommitmentHash, _tokenId);
  }

  function updateCommitmentBatch(OwnershipProof[] calldata _ownershipProofs, uint256[] calldata _tokenIds, uint256[] calldata _newCommitmentHashes) external onlyOwner {
    require(
      _ownershipProofs.length == _tokenIds.length && _tokenIds.length == _newCommitmentHashes.length,
      'ArianeeIssuerProxy: Arrays length mismatch'
    );

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      updateCommitment(_ownershipProofs[i], _tokenIds[i], _newCommitmentHashes[i]);
    }
  }

  // Store management

  function _setStoreAddress(address _store) internal {
    store = IArianeeStore(_store);
  }

  function setStoreAddress(address _store) external onlyOwner {
    address oldStore = address(store);
    _setStoreAddress(_store);
    emit StoreUpdated(oldStore, _store);
  }

  function getStoreAddress() external view returns (address) {
    return address(store);
  }

  // ERC2771Recipient

  function _msgSender() internal view override(Context, ERC2771Recipient) returns (address ret) {
    return ERC2771Recipient._msgSender();
  }

  function _msgData() internal view override(Context, ERC2771Recipient) returns (bytes calldata ret) {
    ret = ERC2771Recipient._msgData();
  }
}
