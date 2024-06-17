// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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

interface ICreditNotePool {
    function purchase(bytes32 _commitmentHash, uint256 _zkCreditType) external;

    function spend(CreditNoteProof calldata _creditNoteProof, uint256 _zkCreditType) external;
}
