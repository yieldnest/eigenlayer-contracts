// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelistApprover {
    /**
     * @dev Initializes the contract with the DelegationWhitelist address and the operator's address.
     * @param _delegationWhitelist Address of the DelegationWhitelist contract.
     * @param _operator Address of the operator (owner) of this WhitelistApprover instance.
     */
    function initialize(address _delegationWhitelist, address _operator) external;

    /**
     * @dev Updates the Merkle root for the operator's whitelist.
     * @param _merkleRoot New Merkle root to be set.
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external;

    /**
     * @dev Verifies if a given hash and signature (Merkle proof) is valid according to EIP-1271.
     * @param _hash Hash of the data signed.
     * @param _signature Merkle proof to be verified.
     * @return The EIP-1271 magic value for valid or invalid signatures.
     */
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4);
}