pragma solidity 0.5.6;


import "@0xcert/ethereum-erc20-contracts/src/contracts/erc20.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "./ERC900.sol";
import "./Pausable.sol";

contract iArianeeStore{
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
  iArianeeStore public store;
  
  /**
   * @dev Arianee admin addresses.
   */
  address public arianeeUnlockerAddress;
  address public arianeeWithdrawAddress;
  

  /**
   * @dev Mapping of stakes.
   */
  mapping (address => StakeContract) public stakeHolders;
 
  /**
   * @dev Stake structure.
   */
  struct Stake {
    uint256 actualAmount;
    uint256 usdAmount;
    address stakedFor;
    bool blocked;
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
  event StakeUnlock(address _staker);
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
  constructor(
      ERC20 _stakingToken,
      address _arianeeStoreAdress,
      address _newArianeeUnlockerAddress,
      address _newArianeeWithdrawAddress
  ) public {
    stakingToken = _stakingToken;
    store = iArianeeStore(address(_arianeeStoreAdress));
    arianeeUnlockerAddress = _newArianeeUnlockerAddress;
    arianeeWithdrawAddress = _newArianeeWithdrawAddress;
  }
  
  /**
   * @notice Change address of the store infrastructure.
   * @param _storeAddress new address of the store.
   */
  function setStoreAddress(address _storeAddress) external onlyOwner(){
    store = iArianeeStore(address(_storeAddress));
    emit SetAddress("storeAddress", _storeAddress);
  }

  
  /**
   * @dev Returns the stake actualAmount for active personal stakes for an address
   * @param _address address that created the stakes
   * @return uint256[] array of actualAmounts
   */
  function getPersonalStakeActualAmounts(address _address) external view returns (uint256[] memory) {
    uint256[] memory actualAmounts;
    (actualAmounts,,) = getPersonalStakes(_address);

    return actualAmounts;
  }
  
  /**
   * @dev Returns the stake actualUsdAmount for active personal stakes for an address
   * @param _address address that created the stakes
   * @return uint256[] array of actualUsdAmounts
   */
  function getPersonalStakeActualUsdAmounts(address _address) external view returns (uint256[] memory) {
    uint256[] memory ActualUsdAmounts;
    (,ActualUsdAmounts,) = getPersonalStakes(_address);

    return ActualUsdAmounts;
  }

  /**
   * @dev Returns the addresses that each personal stake was created for by an address
   * @param _address address that created the stakes
   * @return address[] array of amounts
   */
  function getPersonalStakeForAddresses(address _address) external view returns (address[] memory) {
    address[] memory stakedFor;
    (,,stakedFor) = getPersonalStakes(_address);

    return stakedFor;
  }
  
  
  /**
   * @dev unlock a stake 
   * @notice only arianeeUnlockerAddress can unlock a stake
   * @param _staker Staker to unlock.
   */
  function unlockStake(address _staker) external {
      require(msg.sender == arianeeUnlockerAddress);
      Stake storage personalStake = stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex];
      personalStake.blocked = false;
  }
  
  
  /**
   * @dev Change the arianee unlocker address
   * @param _newArianeeUnlockerAddress the new arianee unlocker address
   */
  function setArianeeUnlockerAddress(address _newArianeeUnlockerAddress) onlyOwner() external{
      arianeeUnlockerAddress = _newArianeeUnlockerAddress;
  }
  
  /**
   * @dev Change the arianee withdraw address
   * @param _newArianeeWithdrawAddress the new arianee withdraw address
   */
  function setArianeeWithdrawAddress(address _newArianeeWithdrawAddress) onlyOwner() external{
      arianeeWithdrawAddress = _newArianeeWithdrawAddress;
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
      _data,
      msg.sender);
  }
  
  /**
   * @notice Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the user, if unstaking is currently not possible the function MUST revert
   * @notice MUST trigger Unstaked event
   * @dev Unstaking tokens is an atomic operation—either all of the tokens in a stake, or none of the tokens.
   * @dev Users can only unstake a single stake at a time, it is must be their oldest active stake. Upon releasing that stake, the tokens will be
   *  transferred back to their account, and their personalStakeIndex will increment to the next active stake.
   * @dev this function allow arianee to unstake any stake
   * @param _amount uint256 the amount of tokens to unstake
   * @param _data bytes optional data to include in the Unstake event
   * @param _staker address to unstake
   */
  function unstake(uint256 _amount, bytes memory _data, address _staker) public whenNotPaused() {
    require(msg.sender == arianeeWithdrawAddress);
    withdrawStake(
      _amount,
      _data,
      _staker);
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
    returns(uint256[] memory, uint256[] memory, address[] memory)
  {
    StakeContract storage stakeContract = stakeHolders[_address];

    uint256 arraySize = stakeContract.personalStakes.length - stakeContract.personalStakeIndex;
    uint256[] memory actualAmounts = new uint256[](arraySize);
    uint256[] memory actualUsdAmounts = new uint256[](arraySize);
    address[] memory stakedFor = new address[](arraySize);

    for (uint256 i = stakeContract.personalStakeIndex; i < stakeContract.personalStakes.length; i++) {
      uint256 index = i - stakeContract.personalStakeIndex;
      actualAmounts[index] = stakeContract.personalStakes[i].actualAmount;
      actualUsdAmounts[index] = stakeContract.personalStakes[i].usdAmount;
      stakedFor[index] = stakeContract.personalStakes[i].stakedFor;
    }

    return (
      actualAmounts,
      actualUsdAmounts,
      stakedFor
    );
  }

  /**
   * @dev Helper function to create stakes for a given address
   * @param _address address The address the stake is being created for
   * @param _amount uint256 The number of tokens being staked
   * @param _data bytes optional data to include in the Stake event
   */
  function createStake(
    address _address,
    uint256 _amount,
    bytes memory _data
  )
    internal
    canStake(msg.sender, _amount)
    whenNotPaused()
  {
    
    if (!stakeHolders[msg.sender].exists) {
      stakeHolders[msg.sender].exists = true;
    }

    uint256 _usdAmount =  _amount.div(store.ariaUSDExchange());
    
    stakeHolders[_address].totalStakedFor = stakeHolders[_address].totalStakedFor.add(_amount);
    stakeHolders[_address].totalUSDStakedFor = stakeHolders[_address].totalUSDStakedFor.add(_usdAmount);
    stakeHolders[_address].personalStakes.push(
      Stake(
        _amount,
        _usdAmount,
        _address,
        true)
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
   * @param _staker address of the staker
   */
  function withdrawStake(
    uint256 _amount,
    bytes memory _data,
    address _staker
  )
    internal
  {
    Stake storage personalStake = stakeHolders[_staker].personalStakes[stakeHolders[_staker].personalStakeIndex];

    require(
        personalStake.blocked == false,
        "Your stake is blocked");
    
    require(
      personalStake.actualAmount == _amount,
      "The unstake amount does not match the current stake");
      
    require(
      stakingToken.transfer(msg.sender, _amount),
      "Unable to withdraw stake");

    stakeHolders[personalStake.stakedFor].totalStakedFor = stakeHolders[personalStake.stakedFor]
      .totalStakedFor.sub(personalStake.actualAmount);

    personalStake.actualAmount = 0;
    personalStake.usdAmount = 0;
    
    stakeHolders[_staker].personalStakeIndex++;
    

    emit Unstaked(
      personalStake.stakedFor,
      _amount,
      totalStakedFor(personalStake.stakedFor),
      _data);
  }
  
  function withdrawAllToken() external whenNotPaused() {
      require(msg.sender == arianeeWithdrawAddress);
      uint256 _amount = stakingToken.balanceOf(address(this));
      stakingToken.transfer(address(arianeeWithdrawAddress),_amount);
     
  }
  
  
}


