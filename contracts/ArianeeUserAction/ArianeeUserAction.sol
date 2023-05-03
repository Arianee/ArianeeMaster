// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "../Interfaces/IArianeeSmartAsset.sol";
import "../Interfaces/IArianeeWhitelist.sol";

contract ArianeeUserAction is ERC2771Recipient {
  IArianeeWhitelist whitelist;
  IArianeeSmartAsset smartAsset;

  constructor(address _whitelistAddress, address _smartAssetAddress) {
    whitelist = IArianeeWhitelist(address(_whitelistAddress));
    smartAsset = IArianeeSmartAsset(address(_smartAssetAddress));
  }


  function addAddressToWhitelist(uint256 _tokenId, address _address) external {
    address _owner = smartAsset.ownerOf(_tokenId);
    require(_owner == _msgSender(), "You are not the owner of this certificate");

    whitelist.addWhitelistedAddress(_tokenId, _address);
  }
}
