// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPoseidon {
    function poseidon(bytes32[1] memory input) external pure returns (bytes32);
}
