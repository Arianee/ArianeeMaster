// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/IArianeeSmartAsset.sol";
import "../Interfaces/IArianeeWhitelist.sol";

contract ArianeeMessage is Ownable {
  /**
   * @dev Mapping from receiver address to messagesId [].
   */
  mapping(address => uint256[]) public receiverToMessageIds;

  /**
   * @dev Mapping from messageId to amount of reward Aria.
   */
  mapping(uint256 => uint256) rewards;

  IArianeeWhitelist whitelist;
  IArianeeSmartAsset smartAsset;
  address arianeeStoreAddress;

  struct Message {
    bytes32 imprint;
    address sender;
    address to;
    uint256 tokenId;
  }

  mapping(uint256 => Message) public messages;

  /**
   * @dev This emits when a message is sent.
   */
  event MessageSent(
    address indexed _receiver,
    address indexed _sender,
    uint256 indexed _tokenId,
    uint256 _messageId
  );
  /**
   * @dev This emits when a message is read.
   */
  event MessageRead(address indexed _receiver, address indexed _sender, uint256 indexed _messageId);

  constructor(address _whitelistAddress, address _smartAssetAddress) {
    whitelist = IArianeeWhitelist(address(_whitelistAddress));
    smartAsset = IArianeeSmartAsset(address(_smartAssetAddress));
  }

  modifier onlyStore() {
    require(msg.sender == arianeeStoreAddress);
    _;
  }

  /**
   * @dev set a new store address
   * @notice can only be called by the contract owner.
   * @param _storeAddress new address of the store.
   */
  function setStoreAddress(address _storeAddress) public onlyOwner {
    arianeeStoreAddress = _storeAddress;
  }

  /**
   * @dev get length of message received by address
   * @param _receiver address.
   */
  function messageLengthByReceiver(address _receiver) public view returns (uint256) {
    return receiverToMessageIds[_receiver].length;
  }

  /**
   * @dev Send a message
   * @notice can only be called by an whitelisted address and through the store
   * @param _messageId id of the message
   * @param _tokenId token associate to the message
   * @param _imprint of the message
   */
  function sendMessage(
    uint256 _messageId,
    uint256 _tokenId,
    bytes32 _imprint,
    address _from,
    uint256 _reward
  ) public onlyStore {
    address _owner = smartAsset.ownerOf(_tokenId);
    require(whitelist.isAuthorized(_tokenId, _from, _owner));
    require(messages[_messageId].sender == address(0));

    Message memory _message = Message({
      imprint: _imprint,
      sender: _from,
      to: _owner,
      tokenId: _tokenId
    });

    messages[_messageId] = _message;
    receiverToMessageIds[_owner].push(_messageId);

    rewards[_messageId] = _reward;

    emit MessageSent(_owner, _from, _tokenId, _messageId);
  }

  /**
   * @dev Read a message
   * @notice can only be called by the store
   * @param _messageId of the message
   */
  function readMessage(uint256 _messageId, address _from) public onlyStore returns (uint256) {
    uint256 reward = rewards[_messageId];
    address _owner = messages[_messageId].to;

    require(_from == _owner);

    address _sender = messages[_messageId].sender;
    delete rewards[_messageId];

    emit MessageRead(_owner, _sender, _messageId);

    return reward;
  }
}
