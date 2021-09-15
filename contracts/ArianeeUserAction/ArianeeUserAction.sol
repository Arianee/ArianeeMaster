// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";

abstract contract iArianeeWhitelist{
  function addWhitelistedAddress(uint256 _tokenId, address _address) virtual external ;
}

abstract contract ERC721Interface {
  function ownerOf(uint256 _tokenId) virtual public view returns(address);
}

contract ArianeeUserAction{
  iArianeeWhitelist whitelist;
  ERC721Interface smartAsset;

  constructor(address _whitelistAddress, address _smartAssetAddress) {
    whitelist = iArianeeWhitelist(address(_whitelistAddress));
    smartAsset = ERC721Interface(address(_smartAssetAddress));
  }

  function addAddressToWhitelist(uint256 _tokenId, address _address) external {
    address _owner = smartAsset.ownerOf(_tokenId);
    require(_owner == msg.sender, "You are not the owner of this certificate");

    whitelist.addWhitelistedAddress(_tokenId, _address);

  }

}