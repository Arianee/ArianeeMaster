// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/IArianeeSmartAsset.sol";
import "../Interfaces/IArianeeWhitelist.sol";

contract ArianeeUserAction is Ownable, ERC2771Recipient {
  IArianeeWhitelist whitelist;
  IArianeeSmartAsset smartAsset;

  constructor(address _whitelistAddress, address _smartAssetAddress, address _forwarder) {
    whitelist = IArianeeWhitelist(address(_whitelistAddress));
    smartAsset = IArianeeSmartAsset(address(_smartAssetAddress));
    _setTrustedForwarder(_forwarder);
  }


  function addAddressToWhitelist(uint256 _tokenId, address _address) external {
    address _owner = smartAsset.ownerOf(_tokenId);
    require(_owner == _msgSender(), "You are not the owner of this certificate");

    whitelist.addWhitelistedAddress(_tokenId, _address);
  }

  function updateForwarderAddress(address _forwarder) external onlyOwner {
    _setTrustedForwarder(_forwarder);
  }

  function _msgSender() internal override(Context, ERC2771Recipient) view returns (address ret) {
    return ERC2771Recipient._msgSender();
  }

  function _msgData() internal override(Context, ERC2771Recipient) view returns (bytes calldata ret) {
    ret = ERC2771Recipient._msgData();
  }
  
}
