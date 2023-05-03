// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/IArianeeSmartAsset.sol";

contract ArianeeUpdate is Ownable, ERC2771Recipient {

  /**
   * Interface for connected contract.
   */
  IArianeeSmartAsset smartAsset;

  /**
   * @dev Mapping of the updates.
   */
  mapping(uint256 => Update) internal smartAssetUpdate;

  /**
   * @dev Current ArianeeStore address.
   */
  address public storeAddress;

  /**
   * @dev Mapping for the rewards
   */
  mapping(uint256 => uint256) rewards;


  /**
   * @dev Update structure.
   */
  struct Update{
        bytes32 imprint;
        uint256 updateTimestamp;
    }

  constructor(address _smartAssetAddress) {
      smartAsset = IArianeeSmartAsset(address(_smartAssetAddress));
  }

  function _msgSender() internal override(Context, ERC2771Recipient) view returns (address ret) {
    return ERC2771Recipient._msgSender();
  }

  function _msgData() internal override(Context, ERC2771Recipient) view returns (bytes calldata ret) {
    ret = ERC2771Recipient._msgData();
  }

  /**
   * @dev This emits when a certificate is updated.
   */
  event SmartAssetUpdated(uint256 indexed _tokenId, bytes32 indexed _imprint);

  /**
   * @dev This emits when the store address is updated.
   */
  event StoreAddressUpdated(address indexed _newStoreAddress);

  /**
   * @dev This emits when a certificate update is read.
   */
  event SmartAssetUpdateReaded(uint256 indexed _tokenId);


  /**
   * @dev create/update a smartAsset update.
   * @notice can only be called through the store.
   * @param _tokenId id of the NFT
   * @param _imprint of the JSON.
   * @param _issuer address of the initial caller (throw if is not issuer).
   * @param _reward total rewards of this event.
   */
  function updateSmartAsset(uint256 _tokenId, bytes32 _imprint, address _issuer, uint256 _reward) external {
        require(_msgSender() == storeAddress);
        require(_issuer == smartAsset.issuerOf(_tokenId));

        smartAssetUpdate[_tokenId] = Update({
            imprint: _imprint,
            updateTimestamp: block.timestamp
        });
        rewards[_tokenId] = _reward;

        emit SmartAssetUpdated(_tokenId, _imprint);
  }

  /**
   * @dev set as read a smartAsset update
   * @notice can only be called through the store.
   * @param _tokenId id of the NFT
   * @param _from address of the initial caller (must be able to operate the NFT).
   */
  function readUpdateSmartAsset(uint256 _tokenId, address _from) external returns(uint256){
      require(_msgSender() == storeAddress);
      require(smartAsset.canOperate(_tokenId, _from));

      uint256 _reward = rewards[_tokenId];
      delete rewards[_tokenId];

      emit SmartAssetUpdateReaded(_tokenId);

      return _reward;
  }

  /**
   * @dev send the smartAsset imprint (the updated one if the smartAsset was updated, the original otherwise)
   * @notice throw if the smartAsset doesn't exist
   * @param _tokenId id of the NFT
   * @return bytes32 imprint
   */
  function getImprint(uint256 _tokenId) public view returns(bytes32) {
      bytes32 _updatedImprint = getUpdatedImprint(_tokenId);
      if(_updatedImprint == 0){
          require(smartAsset.tokenImprint(_tokenId) != 0, 'This smart asset doesn\'t exist');
          return smartAsset.tokenImprint(_tokenId);
      }
      else{
          return _updatedImprint;
      }
  }

  /**
   * @dev send the smartAsset updated imprint
   * @notice return 0x00... if the smartAsset was not updated.
   * @param _tokenId id of the NFT
   * @return bytes32 imprint
   */
  function getUpdatedImprint(uint256 _tokenId) public view returns(bytes32){
      return smartAssetUpdate[_tokenId].imprint;
  }

  /**
   * @dev send all the update information
   * @notice throw if the smartAsset doesn't exist.
   * @param _tokenId id of the NFT
   * @return bool true if updated
   * @return bytes32 send the updated imprint or 0x00... if not updated
   * @return bytes32 send the original imprint
   * @return uint256 timestamp of the last update (0 if no update)
   */
  function getUpdate(uint256 _tokenId) public view returns (bool, bytes32, bytes32, uint256){
      bytes32 _originalImprint = smartAsset.tokenImprint(_tokenId);
      require(_originalImprint != 0, 'This smart asset doesn\'t exist');
      bool _isUpdated = smartAssetUpdate[_tokenId].imprint != 0;

      return(_isUpdated, smartAssetUpdate[_tokenId].imprint, _originalImprint, smartAssetUpdate[_tokenId].updateTimestamp);
  }

  /**
   * @dev set a new store address
   * @notice can only be called by owner
   * @param _newStoreAddress new store address
   */
  function updateStoreAddress(address _newStoreAddress) external onlyOwner(){
      storeAddress = _newStoreAddress;
      emit StoreAddressUpdated(_newStoreAddress);
  }
}