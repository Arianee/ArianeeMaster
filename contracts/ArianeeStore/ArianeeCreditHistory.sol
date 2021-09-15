// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract ArianeeCreditHistory is
Ownable
{
  using SafeMath for uint256;

  /**
   * @dev Mapping from address to array of creditHistory by type of credit.
   */
  mapping(address => mapping(uint256=>CreditBuy[])) internal creditHistory;

  /**
   * @dev Mapping from address to creditHistory index by type of the credit.
   */
  mapping(address => mapping(uint256=>uint256)) internal historyIndex;

  /**
   * @dev Mapping from address to totalCredit by type of the credit.
   */
  mapping(address => mapping(uint256=>uint256)) internal totalCredits;

  /**
   * @dev Address of the actual store address.
   */
  address public arianeeStoreAddress;

  struct CreditBuy{
      uint256 price;
      uint256 quantity;
  }

  /**
   * @dev This emits when a new address is set.
   */
  event SetAddress(string _addressType, address _newAddress);

  modifier onlyStore(){
      require(msg.sender == arianeeStoreAddress, 'not called by store');
      _;
  }

  /**
   * @dev public function that change the store contract address.
   * @notice Can only be called by the contract owner.
   */
  function setArianeeStoreAddress(address _newArianeeStoreAdress) onlyOwner() external {
      arianeeStoreAddress = _newArianeeStoreAdress;
      emit SetAddress("arianeeStore", _newArianeeStoreAdress);
  }

  /**
   * @dev public funciton that add a credit history when credit are bought.
   * @notice can only be called by the store.
   * @param _spender address of the buyer
   * @param _price current price of the credit.
   * @param _quantity of credit buyed.
   * @param _type of credit buyed.
   */
  function addCreditHistory(address _spender, uint256 _price, uint256 _quantity, uint256 _type) external onlyStore() {

      CreditBuy memory _creditBuy = CreditBuy({
          price: _price,
          quantity: _quantity
          });

      creditHistory[_spender][_type].push(_creditBuy);
      totalCredits[_spender][_type] = SafeMath.add(totalCredits[_spender][_type], _quantity);
  }

  /**
   * @dev Public function that consume a given quantity of credit and return the price of the oldest non spent credit.
   * @notice Can only be called by the store.
   * @param _spender address of the buyer.
   * @param _type type of credit.
   * @return price of the credit.
   */
  function consumeCredits(address _spender, uint256 _type, uint256 _quantity) external onlyStore() returns (uint256) {
      require(totalCredits[_spender][_type]>0, "No credit of that type");
      uint256 _index = historyIndex[_spender][_type];
      require(creditHistory[_spender][_type][_index].quantity >= _quantity);

      uint256 price = creditHistory[_spender][_type][_index].price;
      creditHistory[_spender][_type][_index].quantity = SafeMath.sub(creditHistory[_spender][_type][_index].quantity, _quantity);
      totalCredits[_spender][_type] = SafeMath.sub(totalCredits[_spender][_type], 1);

      if(creditHistory[_spender][_type][_index].quantity == 0){
          historyIndex[_spender][_type] = SafeMath.add(historyIndex[_spender][_type], 1);
      }

      return price;
  }

  /**
   * @notice Give a specific credit history for a given spender, and type.
   * @param _spender for which we want the credit history.
   * @param _type of the credit for which we want the history.
   * @param _index of the credit for which we want the history.
   * @return _price credit price for this purchase.
   * * @return _quantity credit quantity for this purchase.
   */
  function userCreditHistory(address _spender, uint256 _type, uint256 _index) external view returns (uint256 _price, uint256 _quantity) {
      _price = creditHistory[_spender][_type][_index].price;
      _quantity = creditHistory[_spender][_type][_index].quantity;
  }

  /**
   * @notice Get the actual index for a spender and a credit type.
   * @param _spender for which we want the credit history.
   * @param _type of the credit for which we want the history.
   * @return _historyIndex Current index.
   */
  function userIndex(address _spender, uint256 _type) external view returns(uint256 _historyIndex){
      _historyIndex = historyIndex[_spender][_type];
  }

  /**
   * @notice Give the total balance of credit for a spender.
   * @param _spender for which we want the credit history.
   * @param _type of the credit for which we want the history.
   * @return _totalCredits Balance of the spender.
   */
  function balanceOf(address _spender, uint256 _type) external view returns(uint256 _totalCredits){
      _totalCredits = totalCredits[_spender][_type];
  }

}