// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IArianeeWhitelist {
    function addWhitelistedAddress(uint256 _tokenId, address _address) external;
    function isAuthorized(uint256 _tokenId, address _sender, address _tokenOwner) external view returns(bool);
}