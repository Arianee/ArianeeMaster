// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract Aria is ERC20 {
  constructor() ERC20("Aria", "Aria") {}
}