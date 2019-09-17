pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";

contract ArianeeWhitelist{
    function isAuthorized(uint256 _tokenId, address _sender, address _tokenOwner) public view returns(bool);
}

contract ERC721Interface {
    function ownerOf(uint256 _tokenId) public view returns(address);
}


contract ArianeeMessage is Ownable{
    
    mapping(uint256 => Message[]) public messageList;
    mapping(uint256 => uint256[]) rewards;
    
    ArianeeWhitelist whitelist;
    ERC721Interface smartAsset;
    address arianeeStoreAddress;
    
    struct Message{
        string URI;
        bytes32 imprint;
        address sender;
        address to;
    }
    
    constructor(address _whitelistAddress, address _smartAssetAddress, address _arianeeStoreAddress) public{
        whitelist = ArianeeWhitelist(address(_whitelistAddress));
        smartAsset = ERC721Interface(address(_smartAssetAddress));
        arianeeStoreAddress = _arianeeStoreAddress;
    }
    
    modifier canSendMessage(uint256 _tokenId, address _sender){
        address _owner = smartAsset.ownerOf(_tokenId);
        require(whitelist.isAuthorized(_tokenId, _sender, _owner));
        _;
    }
    
    modifier onlyStore(){
        require(msg.sender == arianeeStoreAddress);
        _;
    }
    /**
     * @dev set a new store address
     * @notice can only be called by the contract owner.
     * @param _storeAddress new address of the store.
     */
    function setStoreAddress(address _storeAddress) public onlyOwner(){
        arianeeStoreAddress = _storeAddress;
    }
    
    /**
     * @dev Send a message
     * @notice can only be called by an whitelisted address and through the store
     * @param _tokenId token associate to the message
     * @param _uri URI of the message
     * @param _imprint of the message
     * @param _to receiver of the message
     */
    function sendMessage(uint256 _tokenId, string memory _uri, bytes32 _imprint, address _to, uint256 _reward) public canSendMessage(_tokenId, tx.origin) onlyStore() returns(uint256){
        Message memory _message = Message({
            URI : _uri,
            imprint : _imprint,
            sender : tx.origin,
            to : _to
        });
        
        uint256 _messageId = messageList[_tokenId].push(_message);
        rewards[_tokenId].push(_reward);
        return _messageId;
    }
    
    function readMessage(uint256 _tokenId, uint256 _messageId) public onlyStore() returns(uint256){
        uint256 reward = rewards[_tokenId][_messageId];
        delete rewards[_tokenId][_messageId];
        return reward;   
    }
    
    
}