pragma solidity 0.5.6;

import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/utils/supports-interface.sol";
import "@0xcert/ethereum-erc20-contracts/src/contracts/erc20.sol";

/**
 * @title ERC20 standard token implementation.
 * @dev This interface uses the official ERC-20 specification from
 * https://eips.ethereum.org/EIPS/eip-20 and also implements every optional 
 * function.
 */
contract Aria is
  ERC20,
  SupportsInterface
{
  using SafeMath for uint256;

  /**
   * @dev Error constants.
   */
  string constant NOT_ENOUGH_BALANCE = "001001";
  string constant ALLOWANCE_ALREADY_SET = "001002";
  string constant NOT_ENOUGH_ALLOWANCE = "001003";

  /**
   * Token name.
   */
  string internal tokenName = "Arianee Token Test";

  /**
   * Token symbol.
   */
  string internal tokenSymbol = "ARIA";

  /**
   * Number of decimals.
   */
  uint8 internal tokenDecimals = 18;

  /**
   * Total supply of tokens.
   */
  uint256 internal tokenTotalSupply= 1000000000000000000000000;

  /**
   * Balance information map.
   */
  mapping (address => uint256) internal balances;

  /**
   * Token allowance mapping.
   */
  mapping (address => mapping (address => uint256)) internal allowed;

  /**
   * @dev Trigger when tokens are transferred, including zero value transfers.
   */
  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 _value
  );

  /**
   * @dev Trigger on any successful call to approve(address _spender, uint256 _value).
   */
  event Approval(
    address indexed _owner,
    address indexed _spender,
    uint256 _value
  );

  /**
   * @dev Contract constructor.
   */
  constructor()
    public
  {
    supportedInterfaces[0x36372b07] = true; // ERC20
    supportedInterfaces[0x06fdde03] = true; // ERC20 name
    supportedInterfaces[0x95d89b41] = true; // ERC20 symbol
    supportedInterfaces[0x313ce567] = true; // ERC20 decimals
    balances[msg.sender] = tokenTotalSupply;
  }

  /**
   * @notice Returns the name of the token.
   * @return Name of the token.
   */
  function name()
    external
    view
    returns (string memory _name)
  {
    _name = tokenName;
  }

  /**
   * @notice Returns the symbol of the token.
   * @return Symbol of the token.
   */
  function symbol()
    external
    view
    returns (string memory _symbol)
  {
    _symbol = tokenSymbol;
  }

  /**
   * @notice Returns the number of decimals the token uses.
   * @return Decimal of the token.
   */
  function decimals()
    external
    view
    returns (uint8 _decimals)
  {
    _decimals = tokenDecimals;
  }

  /**
   * @notice Returns the total token supply.
   * @return Total supply of the token.
   */
  function totalSupply()
    external
    view
    returns (uint256 _totalSupply)
  {
    _totalSupply = tokenTotalSupply;
  }

  /**
   * @notice Returns the account balance of another account with address _owner.
   * @param _owner The address from which the balance will be retrieved.
   * @return Balance of the given address.
   */
  function balanceOf(
    address _owner
  )
    external
    view
    returns (uint256 _balance)
  {
    _balance = balances[_owner];
  }

  /**
   * @dev Returns the amount which _spender is still allowed to withdraw from _owner.
   * @param _owner The address of the account owning tokens.
   * @param _spender The address of the account able to transfer the tokens.
   * @return the amount of token the spender is allowed to withdraw.
   */
  function allowance(
    address _owner,
    address _spender
  )
    external
    view
    returns (uint256 _remaining)
  {
    _remaining = allowed[_owner][_spender];
  }

  /**
   * @dev Transfers _value amount of tokens to address _to, and MUST fire the Transfer event. The
   * function SHOULD throw if the _from account balance does not have enough tokens to spend.
   * @param _to The address of the recipient.
   * @param _value The amount of token to be transferred.
   * @return true if the transfer succeed.
   */
  function transfer(
    address _to,
    uint256 _value
  )
    public
    returns (bool _success)
  {
    require(_value <= balances[msg.sender], NOT_ENOUGH_BALANCE);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);

    emit Transfer(msg.sender, _to, _value);
    _success = true;
  }

  /**
   * @dev Allows _spender to withdraw from your account multiple times, up to the _value amount. If
   * this function is called again it overwrites the current allowance with _value.
   * @param _spender The address of the account able to transfer the tokens.
   * @param _value The amount of tokens to be approved for transfer.
   * @return true if the approve succeed.
   */
  function approve(
    address _spender,
    uint256 _value
  )
    public
    returns (bool _success)
  {

    allowed[msg.sender][_spender] = _value;

    emit Approval(msg.sender, _spender, _value);
    _success = true;
  }

  /**
   * @dev Transfers _value amount of tokens from address _from to address _to, and MUST fire the
   * Transfer event.
   * @param _from The address of the sender.
   * @param _to The address of the recipient.
   * @param _value The amount of token to be transferred.
   * @return true if the transfer succeed.
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    returns (bool _success)
  {
    require(_value <= balances[_from], NOT_ENOUGH_BALANCE);
    require(_value <= allowed[_from][msg.sender], NOT_ENOUGH_ALLOWANCE);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

    emit Transfer(_from, _to, _value);
    _success = true;
  }

}
