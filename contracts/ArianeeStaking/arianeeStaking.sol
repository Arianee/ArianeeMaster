pragma solidity 0.5.6;


import "@0xcert/ethereum-erc20-contracts/src/contracts/erc20.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "./ERC900.sol";
import "./Pausable.sol";

contract ArianeeStore{
     function ariaUSDExchange() public view returns(uint256 _ariaUSDExchange);
}

/**
 * @title Contract managing the Arianee Staking.
 */
contract ArianeeStaking is ERC900, Ownable, Pausable {
  
  using SafeMath for uint256;

  /**
   * @notice Interface for all the connected contracts.
   */
  ERC20 public stakingToken;
  ArianeeStore public store;
  
  /**
   * @dev fees if stake unlocked by owner. 
   */
  uint8 fees = 2;
  
  /**
   * @dev address receiving fees.
   */
  address public feesReceiver;

  /**
   * @dev The default duration of stake lock-in (in seconds)
   */
  uint256 public defaultLockInDuration = 3122064000; // 99 years

  /**
   * @dev Mapping of stakes.
   */
  mapping (address => StakeContract) public stakeHolders;
 
  /**
   * @dev Stake structure.
   */
  struct Stake {
    uint256 unlockedTimestamp;
    uint256 actualAmount;
    uint256 usdAmount;
    address stakedFor;
  }

  /**
   * @dev total stake struct.
   */
  struct StakeContract {
    uint256 totalStakedFor;
    
    uint256 totalUSDStakedFor;

    uint256 personalStakeIndex;

    Stake[] personalStakes;

    bool exists;
  }

  /**
   * @dev events
   */
  event unlockStake(address _staker);
  event Staked(address _owner, uint256 _amount, uint256 _usdAmount, uint256 _totakStake, bytes _data);
  event Unstaked(address _owner, uint256 _amount, uint256 _totalStake, bytes _data);
  event SetAddress(string _addressType, address _newAddress);

  /**
   * @dev Modifier that checks that this contract can transfer tokens from the
   *  balance in the stakingToken contract for the given address.
   * @dev This modifier also transfers the tokens.
   * @param _address address to transfer tokens from
   * @param _amount uint256 the number of tokens
   */
  modifier canStake(address _address, uint256 _amount) {
    require(
      stakingToken.transferFrom(_address, address(this), _amount),
      "Stake required");

    _;
  }

  /**
   * @dev Constructor function
   * @param _stakingToken ERC20 The address of the token contract used for staking
   * @param _arianeeStoreAdress Address of the arianee store.
   */
  constructor(ERC20 _stakingToken, address _arianeeStoreAdress) public {
    stakingToken = _stakingToken;
    store = ArianeeStore(address(_arianeeStoreAdress));
  }
  
  /**
   * @notice Change address of the store infrastructure.
   * @param _storeAddress new address of the store.
   */
  function setStoreAddress(address _storeAddress) external onlyOwner(){
    store = ArianeeStore(address(_storeAddress));
    emit SetAddress("storeAddress", _storeAddress);
  }

  /**
   * @dev Returns the timestamps for when active personal stakes for an address will unlock
   * @param _address address that created the stakes
   * @return uint256[] array of timestamps
   */
  function getPersonalStakeUnlockedTimestamps(address _address) external view returns (uint256[] memory) {
    uint256[] memory timestamps;
    (timestamps,,,) = getPersonalStakes(_address);

    return timestamps;
  }

  /**
   * @dev Returns the stake actualAmount for active personal stakes for an address
   * @param _address address that created the stakes
   * @return uint256[] array of actualAmounts
   */
  function getPersonalStakeActualAmounts(address _address) external view returns (uint256[] memory) {
    uint256[] memory actualAmounts;
    (,actualAmounts,,) = getPersonalStakes(_address);

    return actualAmounts;
  }
  
  /**
   * @dev Returns the stake actualUsdAmount for active personal stakes for an address
   * @param _address address that created the stakes
   * @return uint256[] array of actualUsdAmounts
   */
  function getPersonalStakeActualUsdAmounts(address _address) external view returns (uint256[] memory) {
    uint256[] memory ActualUsdAmounts;
    (,,ActualUsdAmounts,) = getPersonalStakes(_address);

    return ActualUsdAmounts;
  }

  /**
   * @dev Returns the addresses that each personal stake was created for by an address
   * @param _address address that created the stakes
   * @return address[] array of amounts
   */
  function getPersonalStakeForAddresses(address _address) external view returns (address[] memory) {
    address[] memory stakedFor;
    (,,,stakedFor) = getPersonalStakes(_address);

    return stakedFor;
  }
  
  /**
   * @notice Change address of the fess receiver.
   * @notice Can only be called by the contract's owner.
   * @param _newFeesReceiver new address of the fees receiver.
   */
  function updateFeesReceiver(address _newFeesReceiver) external onlyOwner() {
      feesReceiver = _newFeesReceiver;
  }
  
  /**
   * @notice Change the % of fees.
   * @notice Can only be called by the contract's owner.
   * @param _fees new fees.
   */
  function udpateFees(uint8 _fees) external onlyOwner() {
      fees = _fees;
  }
  
  /**
   * @notice Unlock a stake with fees.
   * @param _staker address of the staker.
   * @param _percentUnstake keeped by the contract's owner.
   */
  function unlockStakeWithFee(address _staker, uint8 _percentUnstake) external onlyOwner() {
      require(_percentUnstake <= 100);
      uint256 firstStakeValue=  stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex].actualAmount;
      uint256 _fees = firstStakeValue.mul(fees);
      uint256 _feesrest = _fees.mod(100);
      
      uint256 _feesAmount= _fees.sub(_feesrest).div(100);
      uint256 _stakeWithoutFee = firstStakeValue.sub(_feesAmount);
    
      uint256 _stakeKeeped = _stakeWithoutFee.mul(100-_percentUnstake);
      uint256 _stakeKeepedMod = _stakeKeeped.mod(100);
      _stakeKeeped = _stakeKeeped.sub(_stakeKeepedMod).div(100);
      
      stakeHolders[_staker].totalStakedFor = stakeHolders[_staker].totalStakedFor.sub(_stakeKeeped).sub(_feesAmount);
      stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex].actualAmount = stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex].actualAmount.sub(_stakeKeeped).sub(_feesAmount);
      
      stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex].unlockedTimestamp = block.timestamp;
      stakingToken.transfer(feesReceiver, (_stakeKeeped.add(_feesAmount)));
      
      emit unlockStake(_staker);
  }
  
  /**
   * @notice Update the default lock in duration of the stake.
   * @param _defaultLockInDuration new value of the lock duration in seconds.
   */
  function updateDefaultLockInDuration(uint _defaultLockInDuration) external onlyOwner(){
      defaultLockInDuration = _defaultLockInDuration;
  }

  /**
   * @notice Stakes a certain amount of tokens, this MUST transfer the given amount from the user
   * @notice MUST trigger Staked event
   * @param _amount uint256 the amount of tokens to stake
   * @param _data bytes optional data to include in the Stake event
   */
  function stake(uint256 _amount, bytes memory _data) public whenNotPaused() {
    createStake(
      msg.sender,
      _amount,
      defaultLockInDuration,
      _data);
  }

  /**
   * @notice Stakes a certain amount of tokens, this MUST transfer the given amount from the caller
   * @notice MUST trigger Staked event
   * @param _user address the address the tokens are staked for
   * @param _amount uint256 the amount of tokens to stake
   * @param _data bytes optional data to include in the Stake event
   */
  function stakeFor(address _user, uint256 _amount, bytes memory _data) public whenNotPaused() {
    createStake(
      _user,
      _amount,
      defaultLockInDuration,
      _data);
  }

  /**
   * @notice Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the user, if unstaking is currently not possible the function MUST revert
   * @notice MUST trigger Unstaked event
   * @dev Unstaking tokens is an atomic operation—either all of the tokens in a stake, or none of the tokens.
   * @dev Users can only unstake a single stake at a time, it is must be their oldest active stake. Upon releasing that stake, the tokens will be
   *  transferred back to their account, and their personalStakeIndex will increment to the next active stake.
   * @param _amount uint256 the amount of tokens to unstake
   * @param _data bytes optional data to include in the Unstake event
   */
  function unstake(uint256 _amount, bytes memory _data) public whenNotPaused() {
    withdrawStake(
      _amount,
      _data);
  }

  /**
   * @notice Returns the current total of tokens staked for an address
   * @param _address address The address to query
   * @return uint256 The number of tokens staked for the given address
   */
  function totalStakedFor(address _address) public view returns (uint256) {
    return stakeHolders[_address].totalStakedFor;
  }
  
  /**
   * @notice Returns the current total of tokens staked for an address
   * @param _address address The address to query
   * @return uint256 The number of tokens staked for the given address
   */
  function totalUSDStakedFor(address _address) public view returns (uint256) {
    return stakeHolders[_address].totalUSDStakedFor;
  }

  /**
   * @notice Returns the current total of tokens staked
   * @return uint256 The number of tokens staked in the contract
   */
  function totalStaked() public view returns (uint256) {
    return stakingToken.balanceOf(address(this));
  }

  /**
   * @notice Address of the token being used by the staking interface
   * @return address The address of the ERC20 token used for staking
   */
  function token() public view returns (address) {
    return address(stakingToken);
  }

  /**
   * @notice MUST return true if the optional history functions are implemented, otherwise false
   * @dev Since we don't implement the optional interface, this always returns false
   * @return bool Whether or not the optional history functions are implemented
   */
  function supportsHistory() public pure returns (bool) {
    return false;
  }

  /**
   * @dev Helper function to get specific properties of all of the personal stakes created by an address
   * @param _address address The address to query
   * @return (uint256[], uint256[], uint256[], address[])
   *  timestamps array, actualAmounts array, actualUsdAmounts array, stakedFor array
   */
  function getPersonalStakes(
    address _address
  )
    view
    public
    returns(uint256[] memory, uint256[] memory, uint256[] memory, address[] memory)
  {
    StakeContract storage stakeContract = stakeHolders[_address];

    uint256 arraySize = stakeContract.personalStakes.length - stakeContract.personalStakeIndex;
    uint256[] memory unlockedTimestamps = new uint256[](arraySize);
    uint256[] memory actualAmounts = new uint256[](arraySize);
    uint256[] memory actualUsdAmounts = new uint256[](arraySize);
    address[] memory stakedFor = new address[](arraySize);

    for (uint256 i = stakeContract.personalStakeIndex; i < stakeContract.personalStakes.length; i++) {
      uint256 index = i - stakeContract.personalStakeIndex;
      unlockedTimestamps[index] = stakeContract.personalStakes[i].unlockedTimestamp;
      actualAmounts[index] = stakeContract.personalStakes[i].actualAmount;
      actualUsdAmounts[index] = stakeContract.personalStakes[i].usdAmount;
      stakedFor[index] = stakeContract.personalStakes[i].stakedFor;
    }

    return (
      unlockedTimestamps,
      actualAmounts,
      actualUsdAmounts,
      stakedFor
    );
  }

  /**
   * @dev Helper function to create stakes for a given address
   * @param _address address The address the stake is being created for
   * @param _amount uint256 The number of tokens being staked
   * @param _lockInDuration uint256 The duration to lock the tokens for
   * @param _data bytes optional data to include in the Stake event
   */
  function createStake(
    address _address,
    uint256 _amount,
    uint256 _lockInDuration,
    bytes memory _data
  )
    internal
    canStake(msg.sender, _amount)
  {
    
    if (!stakeHolders[msg.sender].exists) {
      stakeHolders[msg.sender].exists = true;
    }

    uint256 _usdAmount =  _amount.div(store.ariaUSDExchange());
    
    stakeHolders[_address].totalStakedFor = stakeHolders[_address].totalStakedFor.add(_amount);
    stakeHolders[_address].totalUSDStakedFor = stakeHolders[_address].totalUSDStakedFor.add(_usdAmount);
    stakeHolders[msg.sender].personalStakes.push(
      Stake(
        block.timestamp.add(_lockInDuration),
        _amount,
        _usdAmount,
        _address)
      );

    emit Staked(
      _address,
      _amount,
      _usdAmount,
      totalStakedFor(_address),
      _data);
  }
  
  

  /**
   * @dev Helper function to withdraw stakes for the msg.sender
   * @param _amount uint256 The amount to withdraw. MUST match the stake amount for the
   *  stake at personalStakeIndex.
   * @param _data bytes optional data to include in the Unstake event
   */
  function withdrawStake(
    uint256 _amount,
    bytes memory _data
  )
    internal
  {
    Stake storage personalStake = stakeHolders[msg.sender].personalStakes[stakeHolders[msg.sender].personalStakeIndex];

    require(
      personalStake.unlockedTimestamp <= block.timestamp,
      "The current stake hasn't unlocked yet");

    require(
      personalStake.actualAmount == _amount,
      "The unstake amount does not match the current stake");
      
    require(
      stakingToken.transfer(msg.sender, _amount),
      "Unable to withdraw stake");

    stakeHolders[personalStake.stakedFor].totalStakedFor = stakeHolders[personalStake.stakedFor]
      .totalStakedFor.sub(personalStake.actualAmount);

    personalStake.actualAmount = 0;
    stakeHolders[msg.sender].personalStakeIndex++;

    emit Unstaked(
      personalStake.stakedFor,
      _amount,
      totalStakedFor(personalStake.stakedFor),
      _data);
  }
  
}


