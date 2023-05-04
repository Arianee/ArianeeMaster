// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Aria is ERC20 {
  constructor() ERC20("ARIA20", "ARIA") {
    _mint(msg.sender, 200000000 * 10 ** decimals());
  }
}