// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @dev Utility library of inline functions on bytes.
 */
library ByteUtils {
  function slice(bytes memory data, uint start, uint end) internal pure returns (bytes memory) {
    bytes memory result = new bytes(end - start);
    for (uint i = 0; i < end - start; i++) {
      result[i] = data[i + start];
    }
    return result;
  }
}
