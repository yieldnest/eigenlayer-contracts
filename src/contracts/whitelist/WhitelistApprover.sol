// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "./DelegationWhitelist.sol";
import "../interfaces/IWhitelistApprover.sol";
import "../libraries/Merkle.sol";

/**
 * @title WhitelistApprover
 * @author Layr Labs, Inc.
 * @dev This contract is an implementation of EIP-1271 for EigenLayer operators. It allows operators to maintain and verify a whitelist of stakers using Merkle proofs.
 * The contract is upgradeable and only the operator can update the Merkle root.
 */
contract WhitelistApprover is OwnableUpgradeable, IWhitelistApprover {
    // Reference to the DelegationWhitelist contract
    DelegationWhitelist public delegationWhitelist;

    // Merkle root representing the whitelist of stakers for this operator
    bytes32 public operatorMerkleRoot;

    /**
     * @dev Initializes the contract by setting the operator as the owner and linking the DelegationWhitelist contract.
     * @param _delegationWhitelist Address of the DelegationWhitelist contract.
     * @param _operator Address of the operator who owns this contract.
     */
    function initialize(address _delegationWhitelist, address _operator) public initializer {
        __Ownable_init();
        transferOwnership(_operator);
        delegationWhitelist = DelegationWhitelist(_delegationWhitelist);
    }

    /**
     * @dev Allows the operator to update their whitelist's Merkle root.
     * @param _merkleRoot New Merkle root to represent the updated whitelist.
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        operatorMerkleRoot = _merkleRoot;
    }

    /**
     * @dev Verifies if a staker is included in the operator's whitelist using a Merkle proof. Conforms to EIP-1271.
     * @param _hash Hash of the data associated with the staker (usually their address).
     * @param _signature Merkle proof to verify if the staker is in the whitelist.
     * @return Returns the EIP-1271 magic value indicating if the signature (Merkle proof) is valid or not.
     */
    function isValidSignature(bytes32 _hash, bytes memory _signature) public view returns (bytes4) {
        // Verify if the staker is included in the whitelist using Merkle proof
        if (Merkle.verifyInclusionKeccak(_signature, operatorMerkleRoot, _hash, 0)) {
            return 0x1626ba7e; // EIP-1271 magic value for valid signature
        } else {
            return 0xffffffff; // EIP-1271 magic value for invalid signature
        }
    }
}
