// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Storage for DelegationWhitelist
 * @dev Storage contract to hold state variables. Separated from business logic for upgradability.
 */
abstract contract DelegationWhitelistStorage {
    // Mapping from operator addresses to their corresponding Merkle root for the whitelist
    mapping(address => bytes32) internal _whitelistRoots;

    /**
     * @dev Reserved storage space to allow for layout changes in the future.
     */
    uint256[50] private __gap;
}
