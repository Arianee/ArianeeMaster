pragma solidity 0.5.6;

/// @title Base contract with an owner.
/// @dev Provides onlyOwner modifier, which prevents function from running if
/// it is called by anyone other than the owner.
contract Ownable {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /// @notice Transfer ownership from `owner` to `newOwner`
    /// @param _newOwner The new contract owner
    function transferOwnership(address _newOwner) public onlyOwner {
        if (_newOwner != address(0)) {
            newOwner = _newOwner;
        }
    }

    /// @notice accept ownership of the contract
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}
