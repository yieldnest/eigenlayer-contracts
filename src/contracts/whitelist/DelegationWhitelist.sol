// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../interfaces/IDelegationWhitelist.sol";
import "./DelegationWhitelistStorage.sol";
import "../libraries/Merkle.sol";

/**
 * @title DelegationWhitelist
 * @dev Implementation of the IDelegationWhitelist interface. Upgradeable contract for managing the staker whitelisting process.
 */
contract DelegationWhitelist is Initializable, OwnableUpgradeable, DelegationWhitelistStorage, IDelegationWhitelist {
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @dev Sets the Merkle root for an operator's whitelist.
     * @param operator The address of the operator.
     * @param merkleRoot The Merkle root of the operator's whitelist.
     */
    function setWhitelistRoot(address operator, bytes32 merkleRoot) external override onlyOwner {
        _whitelistRoots[operator] = merkleRoot;
        emit WhitelistRootSet(operator, merkleRoot);
    }

    function verifyInclusion(address staker, address operator, bytes32[] calldata merkleProof) external view override returns (bool) {
        // Step 1: Calculate total bytes length
        uint256 totalLength = merkleProof.length * 32;
        
        // Step 2: Create a new bytes memory array
        bytes memory proof = new bytes(totalLength);

        // Step 3: Copy data from bytes32[] to bytes memory
        for (uint256 i = 0; i < merkleProof.length; i++) {
            bytes32 currentElement = merkleProof[i];
            for (uint256 j = 0; j < 32; j++) {
                proof[i * 32 + j] = currentElement[j];
            }
        }

        // Step 4: Call verifyInclusionKeccak
        bytes32 leaf = keccak256(abi.encodePacked(staker));
        return Merkle.verifyInclusionKeccak(proof, _whitelistRoots[operator], leaf, 0); // Assuming the index is 0
    }

    /**
     * @dev Retrieves the Merkle root for an operator's whitelist.
     * @param operator The address of the operator.
     * @return bytes32 The Merkle root of the operator's whitelist.
     */
    function getWhitelistRoot(address operator) external view override returns (bytes32) {
        return _whitelistRoots[operator];
    }
}