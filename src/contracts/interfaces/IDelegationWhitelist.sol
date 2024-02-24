// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../libraries/Merkle.sol";

/**
 * @title IDelegationWhitelist
 * @notice Interface for the DelegationWhitelist contract in EL.
 * @notice This contract manages a whitelist of stakers for each operator, using Merkle proofs for efficient verification.
 * @notice The main functionalities of this contract are:
 * - Allowing operators to set a Merkle root representing their whitelist of stakers.
 * - Enabling verification of stakers' ability to delegate to operators based on Merkle proofs.
 */
interface IDelegationWhitelist {
    /**
     * @notice Sets the Merkle root for a given operator's whitelist.
     * @param operator The address of the operator setting the Merkle root.
     * @param merkleRoot The Merkle root representing the whitelist of stakers.
     *
     * @dev This function is callable only by the operator or an authorized delegate.
     */
    function setWhitelistRoot(address operator, bytes32 merkleRoot) external;

    /**
     * @notice Verifies if a staker is whitelisted to delegate to a specific operator using a Merkle proof.
     * @param staker The address of the staker attempting to delegate.
     * @param operator The address of the operator to whom the staker wants to delegate.
     * @param merkleProof The Merkle proof demonstrating the staker's presence in the operator's whitelist.
     * @return bool True if the staker is whitelisted, false otherwise.
     *
     * @dev This function does not modify state and should be marked as view.
     * @dev This function should determine the correct hashing algorithm (keccak256 or sha256) based on the contract's implementation.
     */
    function verifyInclusion(address staker, address operator, bytes32[] calldata merkleProof) external view returns (bool);

    /**
     * @notice Retrieves the Merkle root for a given operator's whitelist.
     * @param operator The address of the operator.
     * @return bytes32 The Merkle root of the operator's whitelist, or zero if no whitelist is set.
     *
     * @dev This function does not modify state and should be marked as view.
     */
    function getWhitelistRoot(address operator) external view returns (bytes32);

    /**
     * @notice Emitted when an operator sets a new Merkle root for their whitelist.
     * @param operator The address of the operator.
     * @param newMerkleRoot The new Merkle root set by the operator.
     */
    event WhitelistRootSet(address indexed operator, bytes32 indexed newMerkleRoot);
}
