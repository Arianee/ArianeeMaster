// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

struct CreditNoteProof {
  uint[2] _pA;
  uint[2][2] _pB;
  uint[2] _pC;
  uint[3] _pubSignals;
}

interface ICreditNotePool {
  function purchase(bytes32 _commitmentHash, address _issuerProxy) external;

  function spend(uint256 _creditType, CreditNoteProof calldata _creditNoteProof) external;
}
