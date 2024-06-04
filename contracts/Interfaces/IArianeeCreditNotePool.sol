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
    uint[5] _pubSignals; // 160 bytes
} // Total: 416 bytes

interface ICreditNotePool {
    function purchase(bytes32 _commitmentHash, uint256 _creditType, address _issuerProxy) external;

    function spend(CreditNoteProof calldata _creditNoteProof, uint256 _creditType, address _issuerProxy) external;
}
