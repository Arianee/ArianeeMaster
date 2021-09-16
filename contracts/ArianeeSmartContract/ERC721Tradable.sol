// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";

import "./common/meta-transactions/ContentMixin.sol";
import "./common/meta-transactions/NativeMetaTransaction.sol";

import "./Pausable.sol";


contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title ERC721Tradable
 * ERC721Tradable - ERC721 contract that whitelists a trading address, and has minting functionality.
 */
abstract contract ERC721Tradable is ContextMixin, ERC721Enumerable, NativeMetaTransaction, Ownable, Pausable {

    using Strings for uint256;
    
    mapping(address => bool) approvedOperator;
    
    /**
   * @dev Base URI
   */
  string internal URIBase;

  /**
   * @dev Mapping from token id to URI.
   */
  mapping(uint256 => string) internal idToUri;
  
  /**
   * @dev This emits when the uri base is udpated.
   */
  event SetNewUriBase(string _newUriBase);
  
  string constant NOT_VALID_CERT = "007003";

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _initializeEIP712(_name);
        setUriBase("https://cert.arianee.org/");
    }


    function addApprovedOperator(address _newOperator) public onlyOwner(){
        approvedOperator[_newOperator] = true;
    }
    
    function removeApprovedOperator(address _newOperator) public onlyOwner(){
        approvedOperator[_newOperator] = false;
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {
        if (approvedOperator[operator]) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }


    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }
    
 
  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overriden in child contracts.
   */
  function baseTokenURI() public view returns (string memory) {
      return URIBase;
  }
  
  /**
   * @notice return the URI of a NFT.
   * @param _tokenId uint256 ID of the NFT.
   * @return URI of the NFT.
   */
  function tokenURI(uint256 _tokenId) override public view returns (string memory){
      require(_exists(_tokenId), NOT_VALID_CERT);
      if(bytes(idToUri[_tokenId]).length > 0){
        return idToUri[_tokenId];
      }
      else{
          return bytes(URIBase).length > 0 ? string(abi.encodePacked(URIBase, _tokenId.toString())) : "";
      }
  }
  
  
  /**
   * @notice Change the base URI address.
   * @param _newURIBase the new URI base address.
   */
  function setUriBase(string memory _newURIBase) public onlyOwner(){
      URIBase = _newURIBase;

      emit SetNewUriBase(URIBase);
  }
}
