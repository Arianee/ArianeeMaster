// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../Interfaces/IArianeeSmartAsset.sol";
import "../Interfaces/IArianeeWhitelist.sol";

contract ArianeeEvent is Ownable, Pausable, ERC2771Recipient {
    address arianeeStoreAddress;
    IArianeeWhitelist arianeeWhitelist;
    IArianeeSmartAsset smartAsset;

    uint256 eventDestroyDelay = 31536000;

    /// Event ID per token
    mapping(uint256 => uint256[]) public tokenEventsList;

    mapping(uint256 => uint256) public idToTokenEventIndex;

    /// Mapping from tokenid to pending events
    mapping(uint256 => uint256[]) public pendingEvents;

    /// Mapping from event ID to its index in the pending events list
    mapping(uint256 => uint256) public idToPendingEvents;

    mapping(uint256 => uint256) public eventIdToToken;

    mapping(uint256 => uint256) public rewards;

    mapping(uint256 => bool) destroyRequest;

    /// Event list
    mapping(uint256 => Event) internal events;
    //Event[] public events;

    struct Event{
        string URI;
        bytes32 imprint;
        address provider;
        uint destroyLimitTimestamp;
    }

    event EventCreated(uint256 indexed _tokenId, uint256 indexed _eventId, bytes32 indexed _imprint, string _uri, address _provider);
    event EventAccepted(uint256 indexed _eventId, address indexed _sender);
    event EventRefused(uint256 indexed _eventId, address indexed _sender);
    event EventDestroyed(uint256 indexed _eventId);
    event DestroyRequestUpdated(uint256 indexed _eventId, bool _active);
    event EventDestroyDelayUpdated(uint256 _newDelay);

    modifier onlyStore(){
        require(_msgSender() == arianeeStoreAddress);
        _;
    }

    modifier canOperate(uint256 _eventId,address _operator){
        uint256 _tokenId = eventIdToToken[_eventId];
        require(smartAsset.canOperate(_tokenId, _operator) || smartAsset.issuerOf(_tokenId) == _operator);
        _;
    }

    modifier isProvider(uint256 _eventId) {
        require(_msgSender() == events[_eventId].provider);
        _;
    }


    constructor(address _smartAssetAddress, address _arianeeWhitelistAddress, address _forwarder) {
        arianeeWhitelist = IArianeeWhitelist(address(_arianeeWhitelistAddress));
        smartAsset = IArianeeSmartAsset(address(_smartAssetAddress));
        _setTrustedForwarder(_forwarder);
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

    /**
     * @dev set a new store address
     * @notice can only be called by the contract owner.
     * @param _storeAddress new address of the store.
     */
    function setStoreAddress(address _storeAddress) public onlyOwner(){
        arianeeStoreAddress = _storeAddress;
    }

    /**
     * @dev create a new event linked to a nft
     * @notice can only be called through the store.
     * @param _tokenId id of the NFT
     * @param _imprint of the JSON.
     * @param _uri uri of the JSON of the service.
     * @param _reward total rewards of this event.
     * @param _provider address of the event provider.
     */
    function create(uint256 _eventId, uint256 _tokenId, bytes32 _imprint, string calldata _uri, uint256 _reward, address _provider) external onlyStore() whenNotPaused() {
        require(smartAsset.tokenCreation(_tokenId)>0);
        require(events[_eventId].provider == address(0));

        Event memory _event = Event({
            URI : _uri,
            imprint : _imprint,
            provider : _provider,
            destroyLimitTimestamp : eventDestroyDelay + block.timestamp
        });

        events[_eventId] = _event;

        pendingEvents[_tokenId].push(_eventId);
        uint256 length = pendingEvents[_tokenId].length;
        idToPendingEvents[_eventId] = length - 1;

        eventIdToToken[_eventId] = _tokenId;

        rewards[_eventId]= _reward;

        emit EventCreated(_tokenId, _eventId, _imprint, _uri, _provider);
    }

    /**
     * @dev Accept an event so it can be concidered as valid.
     * @notice can only be called through the store by an operator of the NFT.
     * @param _eventId id of the service.
     */
    function accept(uint256 _eventId, address _sender) external onlyStore() canOperate(_eventId, _sender) whenNotPaused() returns(uint256){

        uint256 _tokenId = eventIdToToken[_eventId];
        uint256 pendingEventToRemoveIndex = idToPendingEvents[_eventId];
        uint256 lastPendingIndex = pendingEvents[_tokenId].length - 1;

        if(lastPendingIndex != pendingEventToRemoveIndex){
            uint256 lastPendingEvent = pendingEvents[_tokenId][lastPendingIndex];
            pendingEvents[_tokenId][pendingEventToRemoveIndex]=lastPendingEvent;
            idToPendingEvents[lastPendingEvent] = pendingEventToRemoveIndex;
        }

        pendingEvents[_tokenId].pop();
        delete idToPendingEvents[_eventId];

        tokenEventsList[_tokenId].push(_eventId);
        uint256 length = tokenEventsList[_tokenId].length;
        idToTokenEventIndex[_eventId] = length - 1;

        arianeeWhitelist.addWhitelistedAddress(_tokenId, events[_eventId].provider);
        uint256 reward = rewards[_eventId];
        delete rewards[_eventId];

        emit EventAccepted(_eventId, _sender);
        return reward;
    }

    /**
     * @dev refuse an event so it can be concidered as valid.
     * @notice can only be called through the store by an operator of the NFT.
     * @param _eventId id of the service.
     */
    function refuse(uint256 _eventId, address _sender) external onlyStore() canOperate(_eventId, _sender) whenNotPaused() returns(uint256){
        _destroyPending(_eventId);
        uint256 reward = rewards[_eventId];
        delete rewards[_eventId];
        emit EventRefused(_eventId, _sender);

        return reward;
    }

    function destroy(uint256 _eventId) external isProvider(_eventId) whenNotPaused(){
        require(block.timestamp < events[_eventId].destroyLimitTimestamp);
        require(idToPendingEvents[_eventId] == 0);
        _destroy(_eventId);
    }

    function updateDestroyRequest(uint256 _eventId, bool _active) external isProvider(_eventId) whenNotPaused() {
        require(idToPendingEvents[_eventId] == 0);
        destroyRequest[_eventId] = _active;
        emit DestroyRequestUpdated(_eventId, _active);
    }

    function validDestroyRequest(uint256 _eventId) external onlyOwner() whenNotPaused() {
        require(destroyRequest[_eventId] == true);
        destroyRequest[_eventId] = false;
        _destroy(_eventId);
    }

    function updateEventDestroyDelay(uint256 _newDelay) external onlyOwner() whenNotPaused() {
        eventDestroyDelay = _newDelay;
        emit EventDestroyDelayUpdated(_newDelay);
    }

    function getEvent(uint256 _eventId) public view returns(string memory uri, bytes32 imprint, address provider, uint timestamp){
        require(events[_eventId].provider != address(0));
        return (events[_eventId].URI, events[_eventId].imprint, events[_eventId].provider, events[_eventId].destroyLimitTimestamp);
    }

    function _destroy(uint256 _eventId) internal{

        uint256 _tokenId = eventIdToToken[_eventId];

        uint256 eventIdToRemove = idToTokenEventIndex[_eventId];
        uint256 lastEventId = tokenEventsList[_tokenId].length - 1;

        if(eventIdToRemove != lastEventId){
            uint256 lastEvent = tokenEventsList[_tokenId][lastEventId];
            tokenEventsList[_tokenId][eventIdToRemove] = lastEvent;
            idToTokenEventIndex[lastEvent] = eventIdToRemove;
        }

        tokenEventsList[_tokenId].pop();
        delete idToTokenEventIndex[_eventId];
        delete eventIdToToken[_eventId];
        delete events[_eventId];

        emit EventDestroyed(_eventId);

    }

    function _destroyPending(uint256 _eventId) internal{

        uint256 _tokenId = eventIdToToken[_eventId];
        uint256 pendingEventToRemoveIndex = idToPendingEvents[_eventId];
        uint256 lastPendingIndex = pendingEvents[_tokenId].length - 1;

        if(lastPendingIndex != pendingEventToRemoveIndex){
            uint256 lastPendingEvent = pendingEvents[_tokenId][lastPendingIndex];
            pendingEvents[_tokenId][pendingEventToRemoveIndex]=lastPendingEvent;
            idToPendingEvents[lastPendingEvent] = pendingEventToRemoveIndex;
        }

        pendingEvents[_tokenId].pop();

        delete idToPendingEvents[_eventId];
        delete eventIdToToken[_eventId];
        delete events[_eventId];

        emit EventDestroyed(_eventId);

    }

    function pendingEventsLength(uint256 _tokenId) public view returns(uint256){
        return pendingEvents[_tokenId].length;
    }

    function eventsLength(uint256 _tokenId) public view returns(uint256){
        return tokenEventsList[_tokenId].length;
    }

}