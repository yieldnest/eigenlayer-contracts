// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for the `IClaimingManager` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IClaimingManager {

    /// STRUCTS ///

    struct DistributionRoot {
        uint32 activatedAfter; // Timestamp after which the root can be claimed against
        bytes32 root; // Merkle root of the distribution
    }

    struct PaymentMerkleClaim {
        IERC20 token; 
        uint256 amount;
        address recipient; // Explicit recipient of the claim

        uint32 rootIndex; // The index of the root in the list of roots
        uint32 leafIndex; // The index of the leaf in the Merkle tree for this root
        bytes32 userRoot; // The root associated with the user tree

        bytes proof; // Proof for the user's position in the user tree
    }

    struct TokenProof {
        IERC20 token;
        uint256 amount;
        bytes32[] proof; // Proof for tokens in the user's token tree
        uint256[] positions; // Positions for Merkle multi-proof verification
    }


    /// EVENTS /// 

    event PaymentUpdaterSet(address oldPaymentUpdater, address newPaymentUpdater);
    event ActivationDelaySet(uint32 oldActivationDelay, uint32 newActivationDelay);
    event GlobalCommissionBipsSet(uint16 oldGlobalCommissionBips, uint16 newGlobalCommissionBips);
    event RecipientSet(address account, address recipient);
    event RootSubmitted(bytes32 root, uint32 paymentsCalculatedUntilTimestamp, uint32 activatedAfter);
    event PaymentClaimed(IERC20 token, address recipient, uint256 amount);
    
    /// VIEW FUNCTIONS ///

    /// @notice The address of the entity that can update the contract with new merkle roots
    function paymentUpdater() external view returns (address);

    /// @notice Delay in timestamp before a posted root can be claimed against
    function activationDelay() external view returns (uint32);

    /// @notice Mapping: account => the address of the entity that can claim payments on behalf of the accounts
    function recipients(address account) external view returns (address);

    /// @notice Mapping: recipient => token => total amount claimed
    function cumulativeClaimed(address recipient, IERC20 token) external view returns (uint256);

    /// @notice the commission for all operators across all avss
    function globalCommissionBips() external view returns (uint16);

    /// EXTERNAL FUNCTIONS ///

    /**
     * @notice Initializes the contract
     * @param initialOwner The address of the initial owner of the contract
     * @param _paymentUpdater The address of the entity that can update the payment merkle roots
     * @param _activationDelay Delay in timestamp before a posted root can be claimed against
     * @param _globalCommissionBips The commission for all operators across all avss
     * @dev Only callable once
     */
    function initialize(address initialOwner, address _paymentUpdater, uint32 _activationDelay, uint16 _globalCommissionBips) external;

    /**
     * @notice Sets the address of the entity that can update the payment merkle roots
     * @param _paymentUpdater The address of the entity that can update the payment merkle roots
     * @dev Only callable by the contract owner
     */
    function setPaymentUpdater(address _paymentUpdater) external;

    /**
     * @notice Sets the delay in timestamp before a posted root can be claimed against
     * @param _activationDelay Delay in timestamp before a posted root can be claimed against
     * @dev Only callable by the contract owner
     */
    function setActivationDelay(uint32 _activationDelay) external;

    /**
     * @notice Sets the global commission for all operators across all avss
     * @param _globalCommissionBips The commission for all operators across all avss
     * @dev Only callable by the contract owner
     */
    function setGlobalCommission(uint16 _globalCommissionBips) external;

    /**
     * @notice Sets the address of the entity that can claim payments on behalf of the account
     * @param account The account whose recipient is being set
     * @param recipient The address of the entity that can claim payments on behalf of the account
     * @dev Only callable by the account or their paymentRecipient
     */
    function setRecipient(address account, address recipient) external;

    /**
     * @notice Creates a new distribution root
     * @param root The merkle root of the distribution
     * @param paymentsCalculatedUntilTimestamp The timestamp until which payments have been calculated
     * @dev Only callable by the paymentUpdater
     */
    function submitRoot(bytes32 root, uint32 paymentsCalculatedUntilTimestamp) external;

    /**
     * @notice Claims payments for the given claims with proofs for the user tree and token tree
     * @param claims The claims to be processed, including proof for the user tree
     * @param userProof The proof of the user's position in the user tree
     * @param tokenProofs The proofs for the tokens in the user's token tree
     */
    function processClaims(PaymentMerkleClaim[] calldata claims, bytes32[] calldata userProof, TokenProof[] calldata tokenProofs) external;
}