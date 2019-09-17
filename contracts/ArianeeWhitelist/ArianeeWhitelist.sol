pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";

contract ArianeeWhitelist is
Abilitable{
  
  /**
   * @dev Mapping from  token id to whitelisted address
   */
  mapping(uint256=> mapping(address=>bool)) internal whitelistedAddress;
  
  /**
   * @dev Mapping from address to token to blacklisted address.
   */
  mapping(address=> mapping(uint256=> mapping(address=>bool))) internal optOutAddressPerOwner;

  /**
   * @dev This emits when a new address is whitelisted for a token
   */
  event WhitelistedAddressAdded(uint256 _tokenId, address _address);

  /**
   * @dev This emits when an address is blacklisted by a NFT owner on a given token.
   */
  event BlacklistedAddresAdded(address _sender, uint256 _tokenId, bool _activate);
  
  uint8 constant ABILITY_ADD_WHITELIST = 2;

  /**
   * @dev add an address to the whitelist for a nft.
   * @notice can only be called by contract authorized.
   * @param _tokenId id of the nft
   * @param _address address to whitelist.
   */
  function addWhitelistedAddress(uint256 _tokenId, address _address) external hasAbilities(ABILITY_ADD_WHITELIST) {
      whitelistedAddress[_tokenId][_address] = true;
      emit WhitelistedAddressAdded(_tokenId, _address);
  }

  /**
   * @dev blacklist an address by a receiver.
   * @param _sender address to blacklist.
   * @param _activate blacklist or unblacklist the sender
   */
  function addBlacklistedAddress(address _sender, uint256 _tokenId, bool _activate) external {
      optOutAddressPerOwner[msg.sender][_tokenId][_sender] = _activate;
      emit BlacklistedAddresAdded(_sender, _tokenId, _activate);
  }
  
  /**
   * @dev Return if a sender is authorized to send  message to this owner.
   * @param _tokenId NFT to check.
   * @param _sender address to check.
   * @param _tokenOwner owner of the token id.
   * @return true if address it authorized.
   */
  function isAuthorized(uint256 _tokenId, address _sender, address _tokenOwner) external view returns(bool) {
      return (whitelistedAddress[_tokenId][_sender] && !isBlacklisted(_tokenOwner, _sender, _tokenId));
  }

  /**
   * @dev Return if an address whitelisted for a given NFT.
   * @param _tokenId NFT to check.
   * @param _address address to check.
   * @return true if address it whitelisted.
   */
  function isWhitelisted(uint256 _tokenId, address _address) public view returns (bool _isWhitelisted) {
      _isWhitelisted = whitelistedAddress[_tokenId][_address];
  }

  /**
   * @dev Return if an address backlisted by a user for a given NFT.
   * @param _owner owner of the token id.
   * @param _sender address to check.
   * @param _tokenId NFT to check.
   * @return true if address it blacklisted.
   */
  function isBlacklisted(address _owner, address _sender, uint256 _tokenId) public view returns(bool _isBlacklisted) {
      _isBlacklisted = optOutAddressPerOwner[_owner][_tokenId][_sender];
  }

}