pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";

contract iArianeeWhitelist{
  function addWhitelistedAddress(uint256 _tokenId, address _address) external ;
}

contract ERC721Interface {
  function ownerOf(uint256 _tokenId) public view returns(address);
}

contract ArianeeUserAction{
  iArianeeWhitelist whitelist;
  ERC721Interface smartAsset;

  constructor(address _whitelistAddress, address _smartAssetAddress) public{
    whitelist = iArianeeWhitelist(address(_whitelistAddress));
    smartAsset = ERC721Interface(address(_smartAssetAddress));
  }

  function addAddressToWhitelist(uint256 _tokenId, address _address) external {
    address _owner = smartAsset.ownerOf(_tokenId);
    require(_owner == msg.sender, "You are not the owner of this certificate");

    whitelist.addWhitelistedAddress(_tokenId, _address);

  }

}