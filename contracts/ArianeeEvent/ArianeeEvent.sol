pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";

contract ERC721Interface {
    function canOperate(uint256 _tokenId, address _operator) public returns(bool);
    function isTokenValid(uint256 _tokenId, bytes32 _hash, uint256 _tokenType, bytes memory _signature) public view returns (bool);
    function issuerOf(uint256 _tokenId) external view returns(address _tokenIssuer);
    function tokenCreation(uint256 _tokenId) external view returns(uint256);
}

contract iArianeeWhitelist {
    function addWhitelistedAddress(uint256 _tokenId, address _address) public;
}

contract ArianeeEvent is
Ownable{
    
    using SafeMath for uint256;
    
    address arianeeStoreAddress;
    iArianeeWhitelist arianeeWhitelist;
    ERC721Interface smartAsset;
    
    uint256 eventDestroyDelay = 7776000;
    
    /// Event ID per token
    mapping(uint256 => uint256[]) public tokenEventsList;
    
    mapping(uint256 => uint256) public idToTokenEventIndex;
    
    /// Mapping from tokenid to pending events
    mapping(uint256 => uint256[]) public pendingEvents;
    
    /// Mapping form tokenid to nb pending events
    mapping(uint256 => uint256) public pendingEventsLength;
    
    /// Mapping from event ID to its index in the pending events list
    mapping(uint256 => uint256) public idToPendingEvents;
    
    mapping(uint256 => uint256) public eventIdToToken;
    
    mapping(uint256 => uint256) public rewards;
    
    mapping(uint256 => bool) destroyRequest;
    
    /// Event list    
    Event[] public events;
    
    struct Event{
        string URI;
        bytes32 imprint;
        address provider;
        uint destroyLimitTimestamp;
    }
    
    event EventCreated(uint256 _tokenId, uint256 _eventId, bytes32 _imprint, string _uri);
    event EventAccepted(uint256 _eventId, address _sender);
    event EventRefused(uint256 _eventId, address _sender);
    event EventDestroyed(uint256 _eventId);
    event DestroyRequestUpdated(uint256 _eventId, bool _active);
    event EventDestroyDelayUpdated(uint256 _newDelay);
    
    modifier onlyStore(){
        require(msg.sender == arianeeStoreAddress);
        _;
    }
    
    modifier canOperate(uint256 _eventId,address _operator){
        uint256 _tokenId = eventIdToToken[_eventId];
        require(smartAsset.canOperate(_tokenId, _operator) || smartAsset.issuerOf(_tokenId) == _operator);
        _;
    }
    
    modifier isProvider(uint256 _eventId) {
        require(msg.sender == events[_eventId].provider);
        _;
    }
    
    
    constructor(address _smartAssetAddress, address _arianeeWhitelistAddress) public{
        arianeeWhitelist = iArianeeWhitelist(address(_arianeeWhitelistAddress));
        smartAsset = ERC721Interface(address(_smartAssetAddress));
        
        events.push(Event({
            URI: "null",
            imprint: bytes32(0),
            provider: address(0),
            destroyLimitTimestamp:0
        }));
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
     * @return the id of the service.
     */
    function create(uint256 _tokenId, bytes32 _imprint, string calldata _uri, uint256 _reward, address _provider) external onlyStore() returns(uint256){
        require(smartAsset.tokenCreation(_tokenId)>0);
        
        Event memory _event = Event({
            URI : _uri,
            imprint : _imprint,
            provider : _provider,
            destroyLimitTimestamp : eventDestroyDelay.add(block.timestamp)
        });
        
        uint256 _eventId = events.push(_event);
        _eventId = _eventId - 1;
        
        uint256 length = pendingEvents[_tokenId].push(_eventId);
        idToPendingEvents[_eventId] = length;
        pendingEventsLength[_tokenId]++;
        
        eventIdToToken[_eventId] = _tokenId;
        
        rewards[_eventId]= _reward;
        
        emit EventCreated(_tokenId, _eventId, _imprint, _uri);
        return _eventId;
    }
    
    /**
     * @dev Accept an event so it can be concidered as valid.
     * @notice can only be called through the store by an operator of the NFT.
     * @param _eventId id of the service.
     */
    function accept(uint256 _eventId, address _sender) external onlyStore() canOperate(_eventId, _sender) returns(uint256){
        
        uint256 _tokenId = eventIdToToken[_eventId];
        uint256 pendingEventToRemoveIndex = idToPendingEvents[_eventId];
        uint256 lastPendingIndex = pendingEvents[_tokenId].length;
        
        if(lastPendingIndex != pendingEventToRemoveIndex){
            uint256 lastPendingEvent = pendingEvents[_tokenId][lastPendingIndex];
            pendingEvents[_tokenId][pendingEventToRemoveIndex]=lastPendingEvent;
            idToPendingEvents[lastPendingIndex] = pendingEventToRemoveIndex;
        }
        
        delete idToPendingEvents[_eventId];
        pendingEvents[_tokenId].length--;
        
        pendingEventsLength[_tokenId]--;
        
        uint256 length = tokenEventsList[_tokenId].push(_eventId);
        idToTokenEventIndex[_tokenId] = length;
        
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
    function refuse(uint256 _eventId, address _sender) external onlyStore() canOperate(_eventId, _sender) returns(uint256){
        _destroy(_eventId);
        uint256 reward = rewards[_eventId];
        delete rewards[_eventId];
        emit EventRefused(_eventId, _sender);
        return reward;
    }
    
    function destroy(uint256 _eventId) external isProvider(_eventId){
        require(block.timestamp < events[_eventId].destroyLimitTimestamp);
        _destroy(_eventId);
    }
    
    function updateDestroyRequest(uint256 _eventId, bool _active) external isProvider(_eventId){
        destroyRequest[_eventId] = _active;
        emit DestroyRequestUpdated(_eventId, _active);
    }

    function validDestroyRequest(uint256 _eventId) external onlyOwner(){
        require(destroyRequest[_eventId] == true);
        destroyRequest[_eventId] = false;
        _destroy(_eventId);
    }
    
    function updateEventDestroyDelay(uint256 _newDelay) external onlyOwner(){
        eventDestroyDelay = _newDelay;
        emit EventDestroyDelayUpdated(_newDelay);
    }
    
    
    function _destroy(uint256 _eventId) internal{
        
        uint256 _tokenId = eventIdToToken[_eventId];
        
        uint256 eventIdToRemove = idToTokenEventIndex[_eventId];
        uint256 lastEventId = tokenEventsList[_tokenId].length;
        
        if(eventIdToRemove != lastEventId){
            uint256 lastEvent = tokenEventsList[_tokenId][lastEventId];
            tokenEventsList[_tokenId][eventIdToRemove] = lastEvent;
            idToTokenEventIndex[lastEventId] = eventIdToRemove;
        }
        
        tokenEventsList[_tokenId].length--;
        pendingEventsLength[_tokenId]--;
        delete idToTokenEventIndex[_eventId];
        delete eventIdToToken[_eventId];
        events[_eventId] = Event({
            URI: "null",
            imprint: bytes32(0),
            provider: address(0),
            destroyLimitTimestamp:0
        });
        emit EventDestroyed(_eventId);

    }
    
}