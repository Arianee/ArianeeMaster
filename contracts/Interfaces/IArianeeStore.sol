// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeStore {
    function canTransfer(
        address _to,
        address _from,
        uint256 _tokenId
    ) external returns (bool);

    function canDestroy(
        uint256 _tokenId,
        address _sender
    ) external returns (bool);
}
