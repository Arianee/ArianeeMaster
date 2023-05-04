// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

import "../Interfaces/IArianeeSmartAsset.sol";
import "../Interfaces/IArianeeCreditHistory.sol";
import "../Interfaces/IArianeeEvent.sol";
import "../Interfaces/IArianeeMessage.sol";
import "../Interfaces/IArianeeUpdate.sol";

/// @title Contract managing the Arianee economy.
contract ArianeeStore is Ownable, Pausable, ERC2771Recipient {
    /**
     * Interface for all the connected contracts.
     */
    IERC20 public acceptedToken;
    IArianeeSmartAsset public nonFungibleRegistry;
    IArianeeCreditHistory public creditHistory;
    IArianeeEvent public arianeeEvent;
    IArianeeMessage public arianeeMessage;
    IArianeeUpdate public arianeeUpdate;

    function _msgSender() internal override(Context, ERC2771Recipient) view returns (address ret) {
        return ERC2771Recipient._msgSender();
    }

    function _msgData() internal override(Context, ERC2771Recipient) view returns (bytes calldata ret) {
        ret = ERC2771Recipient._msgData();
    }

    /**
     * @dev Mapping of the credit price in $cent.
     */
    mapping(uint256 => uint256) internal creditPricesUSD;

    /**
     * @dev Mapping of the credit price in Aria.
     */
    mapping(uint256 => uint256) internal creditPrices;

    /**
     * @dev Current exchange rate Aria/$
     */
    uint256 public ariaUSDExchange;

    /**
     * @dev % of rewards dispatch.
     */
    mapping (uint8=>uint8) internal dispatchPercent;

    /**
     * @dev Address needed in contract execution.
     */
    address public authorizedExchangeAddress;
    address public protocolInfraAddress;
    address public arianeeProjectAddress;

    /**
     * @dev This emits when a new address is set.
     */
    event SetAddress(string _addressType, address _newAddress);

    /**
     * @dev This emits when a credit's price is changed (in USD)
     */
    event NewCreditPrice(uint256 indexed _creditType, uint256 _price);

    /**
     * @dev This emits when the Aria/USD price is changed.
     */
    event NewAriaUSDExchange(uint256 _ariaUSDExchange);

    /**
     * @dev This emits when credits are bought.
     */
    event CreditBought(address indexed buyer, address indexed _receiver, uint256 indexed _creditType, uint256 quantity);

    /**
     * @dev This emits when a new dispatch percent is set.
     */
    event NewDispatchPercent(uint8 _percentInfra, uint8 _percentBrandsProvider, uint8 _percentOwnerProvider, uint8 _arianeeProject, uint8 _assetHolder);

    /**
     * @dev This emit when credits are spended.
     */
    event CreditSpended(uint256 indexed _type,uint256 _quantity);

    /**
     * @dev Initialize this contract. Acts as a constructor
     * @param _acceptedToken - Address of the ERC20 accepted for this store
     * @param _nonFungibleRegistry - Address of the NFT address
     */
    constructor(
        IERC20 _acceptedToken,
        IArianeeSmartAsset _nonFungibleRegistry,
        address _creditHistoryAddress,
        address _arianeeEvent,
        address _arianeeMessage,
        address _arianeeUpdate,
        uint256 _ariaUSDExchange,
        uint256 _creditPricesUSD0,
        uint256 _creditPricesUSD1,
        uint256 _creditPricesUSD2,
        uint256 _creditPricesUSD3,
        address _forwarder
    ) {
        acceptedToken = IERC20(address(_acceptedToken));
        nonFungibleRegistry = IArianeeSmartAsset(address(_nonFungibleRegistry));
        creditHistory = IArianeeCreditHistory(address(_creditHistoryAddress));
        arianeeEvent = IArianeeEvent(address(_arianeeEvent));
        arianeeMessage = IArianeeMessage(address(_arianeeMessage));
        arianeeUpdate = IArianeeUpdate(address(_arianeeUpdate));
        ariaUSDExchange = _ariaUSDExchange;
        creditPricesUSD[0] = _creditPricesUSD0;
        creditPricesUSD[1] = _creditPricesUSD1;
        creditPricesUSD[2] = _creditPricesUSD2;
        creditPricesUSD[3] = _creditPricesUSD3;
        _updateCreditPrice();
        _setTrustedForwarder(_forwarder);
    }

    function updateForwarderAddress(address _forwarder) external onlyOwner {
        _setTrustedForwarder(_forwarder);
    }

    /**
     * @notice Change address of the authorized exchange address.
     * @notice This account is the only that can change the Aria/$ exchange rate.
     * @param _authorizedExchangeAddress new address of the authorized echange address.
     */
    function setAuthorizedExchangeAddress(address _authorizedExchangeAddress) external onlyOwner() {
        authorizedExchangeAddress = _authorizedExchangeAddress;
        emit SetAddress("authorizedExchange", _authorizedExchangeAddress);
    }

    /**
     * @notice Change address of the protocol infrastructure.
     * @param _protocolInfraAddress new address of the protocol intfrastructure receiver.
     */
    function setProtocolInfraAddress(address _protocolInfraAddress) external onlyOwner() {
        protocolInfraAddress = _protocolInfraAddress;
        emit SetAddress("protocolInfra", _protocolInfraAddress);
    }

    /**
     * @notice Change address of the Arianee project address.
     * @param _arianeeProjectAddress new address of the Arianee project receiver.
     */
    function setArianeeProjectAddress(address _arianeeProjectAddress) external onlyOwner() {
        arianeeProjectAddress = _arianeeProjectAddress;
        emit SetAddress("arianeeProject", _arianeeProjectAddress);
    }

    /**
     * @notice Public function change the price of a credit type
     * @notice Can only be called by the owner of the contract
     * @param _creditType uint256 credit type to change the price
     * @param _price uint256 new price
     */
    function setCreditPrice(uint256 _creditType, uint256 _price) external onlyOwner() {
        creditPricesUSD[_creditType] = _price;
        _updateCreditPrice();

        emit NewCreditPrice(_creditType, _price);
    }

    /**
     * @notice Update Aria/USD change
     * @notice Can only be called by the authorized exchange address.
     * @param _ariaUSDExchange price of 1 $cent in aria.
    */
    function setAriaUSDExchange(uint256 _ariaUSDExchange) external {
        require(_msgSender() == authorizedExchangeAddress);
        ariaUSDExchange = _ariaUSDExchange;
        _updateCreditPrice();

        emit NewAriaUSDExchange(_ariaUSDExchange);
    }

    /**
     * @notice Buy new credit against Aria
     * @param _creditType uint256 credit type to buy
     * @param _quantity uint256 quantity to buy
     * @param _to receiver of the credits
     */
    function buyCredit(uint256 _creditType, uint256 _quantity, address _to) external whenNotPaused() {

        uint256 tokens = _quantity * creditPrices[_creditType];

        // Transfer required token quantity to buy quantity credit
        require(acceptedToken.transferFrom(
                _msgSender(),
                address(this),
                tokens
            ));

        creditHistory.addCreditHistory(_to, creditPrices[_creditType], _quantity, _creditType);

        emit CreditBought(_msgSender(), _to, _creditType, _quantity);

    }

    /**
     * @notice Hydrate token and dispatch rewards.
     * @notice Reserve token if token not reserved.
     * @param _tokenId ID of the NFT to modify.
     * @param _imprint Proof.
     * @param _uri URI of the JSON.
     * @param _encryptedInitialKey Initial encrypted key.
     * @param _tokenRecoveryTimestamp Limit date for the issuer to be able to transfer back the NFT.
     * @param _initialKeyIsRequestKey If true set initial key as request key.
     * @param _providerBrand address of the provider of the interface.
     */
    function hydrateToken(
        uint256 _tokenId,
        bytes32 _imprint,
        string calldata _uri,
        address _encryptedInitialKey,
        uint256 _tokenRecoveryTimestamp,
        bool _initialKeyIsRequestKey,
        address _providerBrand
    )
        external whenNotPaused()
    {
        if(nonFungibleRegistry.getRewards(_tokenId) == 0){
            reserveToken(_tokenId, _msgSender());
        }
        uint256 _reward = nonFungibleRegistry.hydrateToken(_tokenId, _imprint, _uri, _encryptedInitialKey, _tokenRecoveryTimestamp, _initialKeyIsRequestKey,  _msgSender());
        _dispatchRewardsAtHydrate(_providerBrand, _reward);
    }

    /**
     * @notice Request a nft and dispatch rewards.
     * @param _tokenId ID of the NFT to transfer.
     * @param _hash Hash of tokenId + newOwner address.
     * @param _keepRequestToken If false erase the access token of the NFT.
     * @param _providerOwner address of the provider of the interface.
     */
    function requestToken(
        uint256 _tokenId,
        bytes32 _hash,
        bool _keepRequestToken,
        address _providerOwner,
        bytes calldata _signature
    )
        external whenNotPaused()
    {
        uint256 _reward = nonFungibleRegistry.requestToken(_tokenId, _hash, _keepRequestToken, _msgSender(), _signature);
        _dispatchRewardsAtRequest(_providerOwner, _reward);
    }

    /**
     * @notice Request a nft and dispatch rewards, is intended to be used per a relay.
     * @param _tokenId ID of the NFT to transfer.
     * @param _hash Hash of tokenId + newOwner address.
     * @param _keepRequestToken If false erase the access token of the NFT.
     * @param _providerOwner address of the provider of the interface.
     * @param _newOwner address of the NFT new owner
     */
    function requestToken(
      uint256 _tokenId,
      bytes32 _hash,
      bool _keepRequestToken,
      address _providerOwner,
      bytes calldata _signature,
      address _newOwner
    )
    external whenNotPaused()
    {
      uint256 _reward = nonFungibleRegistry.requestToken(_tokenId, _hash, _keepRequestToken, _newOwner, _signature);
      _dispatchRewardsAtRequest(_providerOwner, _reward);
    }

    /**
     * @notice Change the percent of rewards per actor.
     * @notice Can only be called by owner.
     * @param _percentInfra Percent get by the infrastructure maintener.
     * @param _percentBrandsProvider Percent get by the brand software provider.
     * @param _percentOwnerProvider Percent get by the owner software provider.
     * @param _arianeeProject Percent get by the Arianee fondation.
     * @param _assetHolder Percent get by the asset owner.
     */
    function setDispatchPercent(
        uint8 _percentInfra,
        uint8 _percentBrandsProvider,
        uint8 _percentOwnerProvider,
        uint8 _arianeeProject,
        uint8 _assetHolder
    )
        external onlyOwner()
    {
        require(_percentInfra+_percentBrandsProvider+_percentOwnerProvider+_arianeeProject+_assetHolder == 100);
        dispatchPercent[0] = _percentInfra;
        dispatchPercent[1] = _percentBrandsProvider;
        dispatchPercent[2] = _percentOwnerProvider;
        dispatchPercent[3] = _arianeeProject;
        dispatchPercent[4] = _assetHolder;

        emit NewDispatchPercent(_percentInfra, _percentBrandsProvider, _percentOwnerProvider, _arianeeProject, _assetHolder);
    }

    /**
     * @notice Get all Arias from the previous store.
     * @notice Can only be called by the owner.
     * @param _oldStoreAddress address of the previous store.
     */
    function getAriaFromOldStore(address _oldStoreAddress) onlyOwner() external {
        ArianeeStore oldStore = ArianeeStore(address(_oldStoreAddress));
        oldStore.withdrawArias();
    }

    /**
     * @notice Withdraw all arias to the new store.
     * @notice Can only be called by the new store.
     */
    function withdrawArias() external {
        require(address(this) != creditHistory.arianeeStoreAddress());
        require(_msgSender() == creditHistory.arianeeStoreAddress());
        acceptedToken.transfer(address(creditHistory.arianeeStoreAddress()),acceptedToken.balanceOf(address(this)));
    }

    /**
     * @notice Create an event and spend an event credit.
     * @param _tokenId ID concerned by the event.
     * @param _imprint Proof.
     * @param _uri URI of the JSON.
     * @param _providerBrand address of the provider of the interface.
     */
    function createEvent(uint256 _eventId, uint256 _tokenId, bytes32 _imprint, string calldata _uri, address _providerBrand) external whenNotPaused(){
        uint256 _rewards = _spendSmartAssetsCreditFunction(2, 1);
        arianeeEvent.create(_eventId, _tokenId, _imprint, _uri, _rewards, _msgSender());
        _dispatchRewardsAtHydrate(_providerBrand, _rewards);
    }

    /**
     * @notice Owner accept an event.
     * @param _eventId event accepted.
     * @param _providerOwner address of the provider of the interface.
     */
    function acceptEvent(uint256 _eventId, address _providerOwner) external whenNotPaused() {
        uint256 _rewards = arianeeEvent.accept(_eventId, _msgSender());
        _dispatchRewardsAtRequest(_providerOwner, _rewards);
    }

    /**
     * @notice Owner refuse an event.
     * @param _eventId event accepted.
     * @param _providerOwner address of the provider of the interface.
     */
    function refuseEvent(uint256 _eventId, address _providerOwner) external{
        uint256 _rewards = arianeeEvent.refuse(_eventId, _msgSender());
        _dispatchRewardsAtRequest(_providerOwner, _rewards);
    }


    /**
   * @notice Create a message and spend an Message credit.
   * @param _messageId ID of the message to create
   * @param _tokenId ID concerned by the message.
   * @param _imprint Proof.
   * @param _providerBrand address of the provider of the interface.
   */
    function createMessage(uint256 _messageId, uint256 _tokenId, bytes32 _imprint, address _providerBrand) external whenNotPaused(){
      uint256 _reward = _spendSmartAssetsCreditFunction(1, 1);
      arianeeMessage.sendMessage(_messageId, _tokenId, _imprint, _msgSender(), _reward);

      _dispatchRewardsAtHydrate(_providerBrand, _reward);
    }

    /**
    * @notice Read a message and dispatch rewards.
    * @param _messageId ID of message.
    * @param _walletProvider address of the provider of the wallet
    */
    function readMessage(uint256 _messageId, address _walletProvider) external whenNotPaused(){
      uint256 _reward = arianeeMessage.readMessage(_messageId, _msgSender());

      _dispatchRewardsAtRequest(_walletProvider, _reward);
    }


  /**
   * @notice Create/update a smartAsset update and spend an Update Credit.
   * @param _tokenId ID concerned by the message.
   * @param _imprint Imprint of the update.
   * @param _providerBrand address of the provider of the interface.
   */
    function updateSmartAsset(uint256 _tokenId, bytes32 _imprint, address _providerBrand) external whenNotPaused(){
        uint256 _reward = _spendSmartAssetsCreditFunction(3, 1);
        arianeeUpdate.updateSmartAsset(_tokenId, _imprint, _msgSender(), _reward);
        _dispatchRewardsAtHydrate(_providerBrand, _reward);
    }

  /**
    * @notice Read an update and dispatch rewards.
    * @param _tokenId ID concerned by the update.
    * @param _walletProvider address of the provider of the wallet
    */
    function readUpdateSmartAsset(uint256 _tokenId, address _walletProvider) external whenNotPaused(){
        uint256 _reward = arianeeUpdate.readUpdateSmartAsset(_tokenId, _msgSender());

       _dispatchRewardsAtRequest(_walletProvider, _reward);
    }

    /**
     * @notice The USD credit price per type.
     * @param _creditType for which we want the USD price.
     * @return _creditPriceUSD price in USD.
     */
    function creditPriceUSD(uint256 _creditType) external view returns(uint256 _creditPriceUSD) {
        _creditPriceUSD = creditPricesUSD[_creditType];
    }

    /**
     * @notice dispatch for rewards.
     * @param _receiver for which we want the % of rewards.
     * @return _percent % of rewards.
     */
    function percentOfDispatch(uint8 _receiver) external view returns(uint8 _percent){
        _percent = dispatchPercent[_receiver];
    }

    /**
     * @notice Send the price a of a credit in aria
     * @param _creditType uint256
     * @return returne the price of the credit type.
     */
    function getCreditPrice(uint256 _creditType) external view returns (uint256) {
        return creditPrices[_creditType];
    }

    /**
     * @dev Allow or not a transfer in the SmartAsset contract.
     * @dev not used for now.
     * @param _to Receiver of the NFT.
     * @param _from Actual owner of the NFT.
     * @param _tokenId id of the token.
     * @return true.
     */
    function canTransfer(address _to, address _from, uint256 _tokenId) external pure returns(bool){
        return true;
    }

    /**
     * @dev Allow or not the destroy of a token in the SmartAsset contract.
     * @dev not used for now.
     * @param _tokenId id of the token.
     * @param _sender address asking the destroy.
     * @return false.
     */
    function canDestroy(uint256 _tokenId, address _sender) external pure returns(bool){
      return false;
    }

    /**
     * @notice Reserve ArianeeSmartAsset
     * @param _id uint256 id of the NFT
     * @param _to address receiver of the token.
     */
    function reserveToken(uint256 _id, address _to) public whenNotPaused() {
        uint256 rewards = _spendSmartAssetsCreditFunction(0, 1);
        nonFungibleRegistry.reserveToken(_id, _to, rewards);
    }

    /**
     * @dev Internal function update creditPrice.
     * @notice creditPrice need to be >100
     */
    function _updateCreditPrice() internal{
        require(creditPricesUSD[0] * ariaUSDExchange >=100);
        require(creditPricesUSD[1] * ariaUSDExchange >=100);
        require(creditPricesUSD[2] * ariaUSDExchange >=100);
        require(creditPricesUSD[3] * ariaUSDExchange >=100);
        creditPrices[0] = creditPricesUSD[0] * ariaUSDExchange;
        creditPrices[1] = creditPricesUSD[1] * ariaUSDExchange;
        creditPrices[2] = creditPricesUSD[2] * ariaUSDExchange;
        creditPrices[3] = creditPricesUSD[3] * ariaUSDExchange;
    }

    /**
     * @dev Spend credits
     * @param _type credit type used.
     * @param _quantity of credit to spend.
     */
    function _spendSmartAssetsCreditFunction(uint256 _type, uint256 _quantity) internal returns (uint256) {
        uint256 rewards = creditHistory.consumeCredits(_msgSender(), _type, _quantity);
        emit CreditSpended(_type, _quantity);
        return rewards;
    }

    /**
     * @dev Dispatch rewards at creation.
     * @param _providerBrand address of the provider of the interface.
     * @param _reward reward for this token.
     */
    function _dispatchRewardsAtHydrate(address _providerBrand, uint256 _reward) internal {
        acceptedToken.transfer(protocolInfraAddress,(_reward/100)*dispatchPercent[0]);
        acceptedToken.transfer(arianeeProjectAddress,(_reward/100)*dispatchPercent[3]);
        acceptedToken.transfer(_providerBrand,(_reward/100)*dispatchPercent[1]);
    }

    /**
     * @dev Dispatch rewards at client reception
     * @param _providerOwner address of the provider of the interface.
     * @param _reward reward for this token.
     */
    function _dispatchRewardsAtRequest(address _providerOwner, uint256 _reward) internal {
        acceptedToken.transfer(_providerOwner,(_reward/100)*dispatchPercent[2]);
        acceptedToken.transfer(_msgSender(),(_reward/100)*dispatchPercent[4]);
    }
}
