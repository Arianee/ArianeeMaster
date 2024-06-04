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

interface ICreditVerifier {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[5] calldata _pubSignals
    ) external view returns (bool);
}

interface IPoseidon {
    function poseidon(bytes32[1] memory input) external pure returns (bytes32);
}

contract ArianeeCreditNotePool is Ownable, ReentrancyGuard, MerkleTreeWithHistory, ERC2771Recipient {
    using ByteUtils for bytes;
    using SafeERC20 for IERC20;

    /**
     * @notice The CreditNoteProof must be the second argument if used in a function
     * This is allowing us to remove the CreditNoteProof from `_msgData()` easily
     */
    struct CreditNoteProof {
        uint[2] _pA; // 64 bytes
        uint[2][2] _pB; // 128 bytes
        uint[2] _pC; // 64 bytes
        uint[5] _pubSignals; // 160 bytes
    } // Total: 416 bytes

    uint256 public constant SELECTOR_SIZE = 4;
    uint256 public constant OWNERSHIP_PROOF_SIZE = 352;
    uint256 public constant CREDIT_NOTE_PROOF_SIZE = 416;

    uint256 public constant MAX_NULLIFIER_PER_COMMITMENT = 1000;

    /**
     * @notice The ERC20 token used to purchase credits
     */
    IERC20 public token;

    /**
     * @notice The ArianeeStore contract used to purchase credits
     */
    IArianeeStore public store;

    /**
     * @notice The contract used to verify the credit note proofs
     */
    ICreditVerifier public verifier;

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
     */
    event Purchased(
        uint256 creditType,
        bytes32 commitmentHash,
        uint32 leafIndex,
        address indexed issuerProxy,
        uint256 timestamp
    );
    /**
     * @notice Emitted when a credit note is spent
     */
    event Spent(uint256 creditType, bytes32 nullifierHash, uint256 timestamp);

    constructor(
        address _token,
        address _store,
        address _verifier,
        uint32 _merkleTreeHeight,
        address _hasher,
        address _poseidon,
        address _trustedForwarder
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        _setTrustedForwarder(_trustedForwarder);

        token = IERC20(_token);
        store = IArianeeStore(_store);
        verifier = ICreditVerifier(_verifier);
        poseidon = IPoseidon(_poseidon);
    }

    function purchase(bytes32 _commitmentHash, uint256 _creditType, address _issuerProxy) external nonReentrant {
        require(_creditType >= 1 && _creditType <= 4, 'CreditNotePool: The credit type should be either 1, 2, 3 or 4');
        require(!commitmentHashes[_commitmentHash], 'CreditNotePool: This commitment has already been registered');

        uint32 insertedIndex = _insert(_commitmentHash);
        commitmentHashes[_commitmentHash] = true;

        // The credit type is 0-indexed in the store, but 1-indexed in the commitment
        uint256 creditPrice = store.getCreditPrice(_creditType - 1);

        // One credit note is worth `MAX_NULLIFIER_PER_COMMITMENT` credits
        uint256 amount = MAX_NULLIFIER_PER_COMMITMENT * creditPrice;

        // The caller should have approved the contract to transfer the amount of tokens
        token.safeTransferFrom(_msgSender(), address(this), amount);
        store.buyCredit(_creditType, MAX_NULLIFIER_PER_COMMITMENT, _issuerProxy);

        emit Purchased(_creditType, _commitmentHash, insertedIndex, _issuerProxy, block.timestamp);
    }

    function spend(
        CreditNoteProof calldata _creditNoteProof,
        uint256 _creditType,
        address _issuerProxy
    ) external nonReentrant {
        _verifyProof(_creditNoteProof, _creditType, _issuerProxy);

        bytes32 pNullifierHash = bytes32(_creditNoteProof._pubSignals[3]);
        nullifierHashes[bytes32(_creditNoteProof._pubSignals[3])] = true;
        emit Spent(_creditType, pNullifierHash, block.timestamp);
    }

    function _verifyProof(
        CreditNoteProof calldata _creditNoteProof,
        uint256 _creditType,
        address _issuerProxy
    ) internal view {
        bytes32 pRoot = bytes32(_creditNoteProof._pubSignals[0]);
        require(isKnownRoot(pRoot), 'CreditNotePool: Cannot find your merkle root'); // Make sure to use a recent one

        uint256 pCreditType = _creditNoteProof._pubSignals[1];
        require(
            pCreditType == _creditType,
            'CreditNotePool: Proof credit type does not match the function argument `_creditType`'
        );

        uint256 pIssuerProxy = _creditNoteProof._pubSignals[2];
        require(
            pIssuerProxy == uint256(uint160(_issuerProxy)),
            'CreditNotePool: Proof issuer proxy address does not match the function argument `_issuerProxy`'
        );

        bytes32 pNullifierHash = bytes32(_creditNoteProof._pubSignals[3]);
        require(!nullifierHashes[pNullifierHash], 'CreditNotePool: This note has already been spent');

        uint256 pIntentHash = _creditNoteProof._pubSignals[4];
        bytes memory msgData = _msgData();
        // Removing the `OwnershipProof` (352 bytes) and the `CreditNoteProof` (416 bytes) from the msg.data before computing the hash to compare
        uint256 msgDataHash = uint256(
            poseidon.poseidon(
                [
                    keccak256(
                        abi.encodePacked(
                            bytes.concat(
                                msgData.slice(0, SELECTOR_SIZE),
                                msgData.slice(
                                    SELECTOR_SIZE + OWNERSHIP_PROOF_SIZE + CREDIT_NOTE_PROOF_SIZE,
                                    msgData.length
                                )
                            )
                        )
                    )
                ]
            )
        );
        require(pIntentHash == msgDataHash, 'CreditNotePool: Proof intent does not match the function call');

        require(
            verifier.verifyProof(
                _creditNoteProof._pA,
                _creditNoteProof._pB,
                _creditNoteProof._pC,
                _creditNoteProof._pubSignals
            ),
            'CreditNotePool: Proof verification failed'
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
