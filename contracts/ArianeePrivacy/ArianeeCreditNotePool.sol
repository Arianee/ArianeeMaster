// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@opengsn/contracts/src/ERC2771Recipient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './MerkleTreeWithHistory.sol';
import '../Utilities/ByteUtils.sol';

import '../Interfaces/IArianeeStore.sol';
import '../Interfaces/IArianeeSmartAsset.sol';
import '../Interfaces/IArianeeEvent.sol';
import '../Interfaces/IPoseidon.sol';

interface ICreditRegister {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[2] calldata _pubSignals
    ) external view returns (bool);
}

interface ICreditVerifier {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[3] calldata _pubSignals
    ) external view returns (bool);
}

contract ArianeeCreditNotePool is Ownable, ReentrancyGuard, MerkleTreeWithHistory, ERC2771Recipient {
    using ByteUtils for bytes;
    using SafeERC20 for IERC20;

    struct CreditRegistrationProof {
        uint[2] _pA;
        uint[2][2] _pB;
        uint[2] _pC;
        uint[2] _pubSignals;
    }

    /**
     * @notice The CreditNoteProof must be the second argument if used in a function
     * This is allowing us to remove the CreditNoteProof from `_msgData()` easily
     */
    struct CreditNoteProof {
        uint[2] _pA; // 64 bytes
        uint[2][2] _pB; // 128 bytes
        uint[2] _pC; // 64 bytes
        uint[3] _pubSignals; // 96 bytes
    } // Total: 352 bytes

    uint256 public constant SELECTOR_SIZE = 4;
    uint256 public constant OWNERSHIP_PROOF_SIZE = 352;
    uint256 public constant CREDIT_NOTE_PROOF_SIZE = 352;

    uint256 public constant MAX_NULLIFIER_PER_COMMITMENT = 1000;

    /**
     * @notice The address of the ArianeeIssuerProxy contract (the only one allowed to interact with this contract)
     */
    address public issuerProxy;

    /**
     * @notice The ERC20 token used to purchase credits
     */
    IERC20 public token;

    /**
     * @notice The ArianeeStore contract used to purchase credits
     */
    IArianeeStore public store;

    /**
     * @notice The contract used to verify the `creditRegister` proofs
     */
    ICreditRegister public creditRegister;

    /**
     * @notice The contract used to verify the `creditVerifier` proofs
     */
    ICreditVerifier public creditVerifier;

    /**
     * @notice The contract used to compute Poseidon hashes
     */
    IPoseidon public immutable poseidon;

    /**
     * @notice Mapping<NullifierHash, IsUsed>
     */
    mapping(bytes32 => bool) public nullifierHashes;
    /**
     * @notice Mapping<CommitmentHash, IsRegistered>
     */
    mapping(bytes32 => bool) public commitmentHashes;

    /**
     * @notice Emitted when a credit note is purchased
     * @dev The `creditType` is 0-indexed
     */
    event Purchased(uint256 creditType, bytes32 commitmentHash, uint32 indexed leafIndex, uint256 timestamp);
    /**
     * @notice Emitted when a credit note is spent
     * @dev The `creditType` is 0-indexed
     */
    event Spent(uint256 creditType, bytes32 nullifierHash, uint256 timestamp);

    constructor(
        address _issuerProxy,
        address _token,
        address _store,
        address _creditRegister,
        address _creditVerifier,
        uint32 _merkleTreeHeight,
        address _hasher,
        address _poseidon,
        address _trustedForwarder
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        _setTrustedForwarder(_trustedForwarder);

        issuerProxy = _issuerProxy;
        token = IERC20(_token);
        store = IArianeeStore(_store);
        creditRegister = ICreditRegister(_creditRegister);
        creditVerifier = ICreditVerifier(_creditVerifier);
        poseidon = IPoseidon(_poseidon);
    }

    modifier onlyIssuerProxy() {
        require(
            _msgSender() == issuerProxy,
            'ArianeeCreditNotePool: This function can only be called by the ArianeIssuerProxy contract'
        );
        _;
    }

    /**
     * @dev WARNING: The parameter `_zkCreditType` is the credit type that the user wants to purchase BUT it is 1-indexed.
     * This is done on purpose for easier circuit implementation.
     * Example: If the user wants to purchase a "certificate" credit (type 0), the `_zkCreditType` should be 1.
     * @notice Emits a `Purchased` event when a credit note is successfully purchased (`creditType` is 0-indexed)
     */
    function purchase(CreditRegistrationProof calldata _creditRegistrationProof, bytes32 _commitmentHash, uint256 _zkCreditType) external nonReentrant {
        require(
            _zkCreditType >= 1 && _zkCreditType <= 4,
            'ArianeeCreditNotePool: The credit type should be either 1, 2, 3 or 4'
        );
        require(
            !commitmentHashes[_commitmentHash],
            'ArianeeCreditNotePool: This commitment has already been registered'
        );

        _verifyRegistrationProof(_creditRegistrationProof, _commitmentHash, _zkCreditType);

        uint32 insertedIndex = _insert(_commitmentHash);
        commitmentHashes[_commitmentHash] = true;

        // The credit type is 0-indexed in the store, but 1-indexed in the commitment
        uint256 creditType = _zkCreditType - 1;
        uint256 creditPrice = store.getCreditPrice(creditType);

        // One credit note is worth `MAX_NULLIFIER_PER_COMMITMENT` credits
        uint256 amount = MAX_NULLIFIER_PER_COMMITMENT * creditPrice;

        // The caller should have approved the contract to transfer the amount of tokens
        token.safeTransferFrom(_msgSender(), address(this), amount);

        // Approve the store to transfer the required amount of tokens
        require(token.approve(address(store), amount), 'ArianeeCreditNotePool: ERC20 approval failed');
        // Buy the credits from the store
        store.buyCredit(creditType, MAX_NULLIFIER_PER_COMMITMENT, issuerProxy);

        emit Purchased(creditType, _commitmentHash, insertedIndex, block.timestamp);
    }

    function _verifyRegistrationProof(
        CreditRegistrationProof calldata _creditRegistrationProof,
        bytes32 _commitmentHash,
        uint256 _zkCreditType
    ) internal view {
        bytes32 pCommitmentHash = bytes32(_creditRegistrationProof._pubSignals[0]);
        require(
            pCommitmentHash == _commitmentHash,
            'ArianeeCreditNotePool: Proof commitment does not match the function argument `_commitmentHash`'
        );

        uint256 pCreditType = _creditRegistrationProof._pubSignals[1];
        require(
            pCreditType == _zkCreditType,
            'ArianeeCreditNotePool: Proof credit type does not match the function argument `_zkCreditType`'
        );

        require(
            creditRegister.verifyProof(
                _creditRegistrationProof._pA,
                _creditRegistrationProof._pB,
                _creditRegistrationProof._pC,
                _creditRegistrationProof._pubSignals
            ),
            'ArianeeCreditNotePool: CreditRegistrationProof verification failed'
        );
    }

    function spend(
        CreditNoteProof calldata _creditNoteProof,
        uint256 _zkCreditType
    ) public onlyIssuerProxy nonReentrant {
        _verifyProof(_creditNoteProof, _zkCreditType);

        bytes32 pNullifierHash = bytes32(_creditNoteProof._pubSignals[2]);
        nullifierHashes[bytes32(_creditNoteProof._pubSignals[2])] = true;

        uint256 creditType = _zkCreditType - 1;
        emit Spent(creditType, pNullifierHash, block.timestamp);
    }

    function _verifyProof(CreditNoteProof calldata _creditNoteProof, uint256 _zkCreditType) internal view {
        bytes32 pRoot = bytes32(_creditNoteProof._pubSignals[0]);
        require(isKnownRoot(pRoot), 'ArianeeCreditNotePool: Cannot find your merkle root'); // Make sure to use a recent one

        uint256 pCreditType = _creditNoteProof._pubSignals[1];
        require(
            pCreditType == _zkCreditType,
            'ArianeeCreditNotePool: Proof credit type does not match the function argument `_zkCreditType`'
        );

        bytes32 pNullifierHash = bytes32(_creditNoteProof._pubSignals[2]);
        require(!nullifierHashes[pNullifierHash], 'ArianeeCreditNotePool: This note has already been spent');

        // We don't check the intent hash in the `ArianeeCreditNotePool` contract because it is already checked in the `ArianeeIssuerProxy` contract
        // and the `ArianeeIssuerProxy` contract is the only one allowed to call the `spend` function.

        require(
            creditVerifier.verifyProof(
                _creditNoteProof._pA,
                _creditNoteProof._pB,
                _creditNoteProof._pC,
                _creditNoteProof._pubSignals
            ),
            'ArianeeCreditNotePool: CreditNoteProof verification failed'
        );
    }

    function isSpentBatch(bytes32[] calldata _nullifierHashes) external view returns (bool[] memory) {
        bool[] memory spent = new bool[](_nullifierHashes.length);
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            spent[i] = nullifierHashes[_nullifierHashes[i]];
        }
        return spent;
    }

    function isSpent(bytes32 _nullifierHash) external view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    // ERC2771Recipient

    function _msgSender() internal view override(Context, ERC2771Recipient) returns (address ret) {
        return ERC2771Recipient._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Recipient) returns (bytes calldata ret) {
        ret = ERC2771Recipient._msgData();
    }
}
