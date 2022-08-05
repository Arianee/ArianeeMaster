// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Contract relaying Arianee meta-transactions.
contract ArianeeForwarder is MinimalForwarder, Ownable, Pausable {
  address public signer;

  uint256 public avgGasUsedToRefundSender = 25000;
  uint8 public failedTxCompensationFactor = 120;

  event SenderRefunded(address indexed _sender, uint _amount);
  event ForwardSuccess(address indexed _sender, address indexed _from, address indexed _to);

  constructor(address _signer) {
    signer = _signer;
  }

  /**
   * @dev Executes a meta-transaction via a low-level call.
   * @param _req the meta-transaction to execute
   * @param _signature the meta-transaction corresponding signature
   * @return _success boolean indicating if the meta-transaction execution has succeed
   * @return _returndata optional bytes returned from the meta-transaction execution
   */
  function execute(ForwardRequest calldata _req, bytes calldata _signature) public payable override whenNotPaused returns (bool _success, bytes memory _returndata) {
    uint256 startGas = gasleft();

    bytes32 argsHash = keccak256(abi.encode(_req, _signature));
    bytes32 messageHash = ECDSA.toEthSignedMessageHash(argsHash);
    require(
      ECDSA.recover(messageHash, _signature) == signer,
      "ArianeeForwarder: Invalid signature"
    );

    (bool success, bytes memory returndata) = super.execute(_req, _signature);

    refundSender(startGas - gasleft());
    emit ForwardSuccess(msg.sender, _req.from, _req.to);

    return (success, returndata);
  }

  function refundSender(uint256 _gasUsed) internal {
    uint256 refundAmount = ((_gasUsed + avgGasUsedToRefundSender) * tx.gasprice) + block.basefee;
    uint256 finalRefundAmount = (refundAmount / 100) * failedTxCompensationFactor; // INFO: refundAmount * failedTxCompensationFactor (default: 120 aka 1.2) in order to compensate funds loss from potential failed tx
    require(
      address(this).balance >= finalRefundAmount,
      "ArianeeForwarder: Contract has insufficient balance to refund sender"
    );

    payable(msg.sender).transfer(refundAmount);
    emit SenderRefunded(msg.sender, refundAmount);
  }

  receive () external payable { }

  function setSigner(address _signer) public onlyOwner {
    signer = _signer;
  }

  function setAvgGasUsedToRefundSender(uint256 _avgGasUsedToRefundSender) public onlyOwner {
    avgGasUsedToRefundSender = _avgGasUsedToRefundSender;
  }

  function setFailedTxCompensationFactor(uint8 _failedTxCompensationFactor) public onlyOwner {
    failedTxCompensationFactor = _failedTxCompensationFactor;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function withdraw() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  function withdrawTokens(address _contract, uint256 _amount) public onlyOwner {
    IERC20 tokenContract = IERC20(_contract);
    tokenContract.transfer(msg.sender, _amount);
  }
}
