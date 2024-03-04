// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../permissions/Pausable.sol";
import "../libraries/Merkle.sol";

import "../interfaces/IClaimingManager.sol";

contract ClaimingManager is IClaimingManager, Initializable, OwnableUpgradeable, Pausable {
    /// @notice The address of the entity that can update the payment merkle roots
    address public paymentUpdater;
    /// @notice Delay in timestamp before a posted root can be claimed against
    uint32 public activationDelay;
    /// @notice List of merkle roots and their activation timestamps
    DistributionRoot[] public paymentMerkleRoots;

    /// @notice the commission for all operators across all avss
    uint16 public globalCommissionBips;

    /// @notice Mapping: account => paymentRecipient
    mapping(address => address) public recipients;
    /// @notice Mapping: recipient => token => total amount claimed
    mapping(address => mapping(IERC20 => uint256)) public cumulativeClaimed;

    /// EXTERNAL FUNCTIONS ///

    /**
     * @notice Initializes the contract
     * @param initialOwner The address of the initial owner of the contract
     * @param _paymentUpdater The address of the entity that can update the payment merkle roots
     * @param _activationDelay Delay in timestamp before a posted root can be claimed against
     * @param _globalCommissionBips The commission for all operators across all avss
     * @dev Only callable once
     */
    function initialize(address initialOwner, address _paymentUpdater, uint32 _activationDelay, uint16 _globalCommissionBips) external initializer {
        __Ownable_init();
        transferOwnership(initialOwner);
        _setPaymentUpdater(_paymentUpdater);
        _setActivationDelay(_activationDelay);
        _setGlobalCommission(_globalCommissionBips);
    }

    /**
     * @notice Sets the address of the entity that can update the payment merkle roots
     * @param _paymentUpdater The address of the entity that can update the payment merkle roots
     * @dev Only callable by the contract owner
     */
    function setPaymentUpdater(address _paymentUpdater) external onlyOwner {
        _setPaymentUpdater(_paymentUpdater);
    }

    /**
     * @notice Sets the delay in timestamp before a posted root can be claimed against
     * @param _activationDelay Delay in timestamp before a posted root can be claimed against
     * @dev Only callable by the contract owner
     */
    function setActivationDelay(uint32 _activationDelay) external onlyOwner {
        _setActivationDelay(_activationDelay);
    }

    /**
     * @notice Sets the global commission for all operators across all avss
     * @param _globalCommissionBips The commission for all operators across all avss
     * @dev Only callable by the contract owner
     */
    function setGlobalCommission(uint16 _globalCommissionBips) external onlyOwner {
        _setGlobalCommission(_globalCommissionBips);
    }

    /**
     * @notice Sets the address of the entity that can claim payments on behalf of the account
     * @param account The account whose recipient is being set
     * @param recipient The address of the entity that can claim payments on behalf of the account
     * @dev Only callable by the entity or their paymentRecipients
     */
    function setRecipient(address account, address recipient) external {
        require(msg.sender == account || msg.sender == recipients[account], "ClaimingManager.setRecipient: caller is not account or recipient");
        _setRecipient(account, recipient);
    }

    /**
     * @notice Creates a new distribution root
     * @param root The merkle root of the distribution
     * @param paymentsCalculatedUntilTimestamp The timestamp until which payments have been calculated
     * @dev Only callable by the paymentUpdater
     */
    function submitRoot(bytes32 root, uint32 paymentsCalculatedUntilTimestamp) external {
        require(msg.sender == paymentUpdater, "ClaimingManager.submitRoot: caller is not paymentUpdater");
        require(root != bytes32(0), "ClaimingManager.submitRoot: root is empty");

        // the root will be activated after the activation delay
        uint32 activatedAfter = uint32(block.timestamp + activationDelay);

        // Add the new root to the list of payment Merkle roots. Note that these roots are not token-specific.
        // Each root represents a state of cumulative payments across all tokens, and they are used for verifying claims.
        paymentMerkleRoots.push(DistributionRoot({activatedAfter: uint32(block.timestamp + activationDelay), root: root}));
        emit RootSubmitted(root, paymentsCalculatedUntilTimestamp, activatedAfter);
    }

    /**
     * @notice Claims payments for the given claims with proofs for the user tree and token tree
     * @param claims The claims to be processed, including proof for the user tree
     * @param userProof The proof of the user's position in the user tree
     * @param tokenProofs The proofs for the tokens in the user's token tree
     */
    function processClaims(PaymentMerkleClaim[] calldata claims, bytes32[] calldata userProof, TokenProof[] calldata tokenProofs) external {
        for (uint256 i = 0; i < claims.length; i++) {
            _processClaim(claims[i], userProof, tokenProofs);
        }
    }

    /// INTERNAL FUNCTIONS /// 

    function _setPaymentUpdater(address _paymentUpdater) internal {
        address oldPaymentUpdater = paymentUpdater;
        paymentUpdater = _paymentUpdater;
        emit PaymentUpdaterSet(oldPaymentUpdater, _paymentUpdater);
    }

    function _setActivationDelay(uint32 _activationDelay) internal {
        uint32 oldActivationDelay = activationDelay;
        activationDelay = _activationDelay;
        emit ActivationDelaySet(oldActivationDelay, _activationDelay);
    }

    function _setGlobalCommission(uint16 _globalCommissionBips) internal {
        uint16 oldGlobalCommissionBips = globalCommissionBips;
        globalCommissionBips = _globalCommissionBips;
        emit GlobalCommissionBipsSet(oldGlobalCommissionBips, _globalCommissionBips);
    }
    
    function _setRecipient(address account, address recipient) internal {
        recipients[account] = recipient;
        emit RecipientSet(account, recipient);
    }
 
    function _processClaim(
        PaymentMerkleClaim calldata claim,
        bytes32[] calldata userProof,
        TokenProof[] calldata tokenProofs
    ) internal {
        // Verify the user's position in the user tree using the userRoot from the claim
        bytes32 userLeaf = _computeUserLeaf(msg.sender, claim.userRoot);
        require(
            Merkle.verifyInclusionKeccak(
                abi.encodePacked(userProof), 
                claim.userRoot, // This should be the root you're verifying against
                userLeaf, 
                claim.leafIndex
            ),
            "Invalid user proof"
        );

        // Verify each token in the user's token tree
        for (uint i = 0; i < tokenProofs.length; i++) {
            bytes32 tokenLeaf = _computeTokenLeaf(tokenProofs[i].token, tokenProofs[i].amount);
            // Assume paymentMerkleRoots[claim.rootIndex].root is the root of the user's token tree
            require(
                Merkle.verifyInclusionKeccak(
                    abi.encodePacked(tokenProofs[i].proof),
                    paymentMerkleRoots[claim.rootIndex].root, // The root of the user's token tree
                    tokenLeaf, 
                    tokenProofs[i].positions[i]
                ),
                "Invalid token proof"
            );
        }

        // Process the claims after successful verification
        for (uint i = 0; i < tokenProofs.length; i++) {
            _updateClaimedAmounts(msg.sender, tokenProofs[i].token, tokenProofs[i].amount);
        }
    }

    function _computeUserLeaf(address user, bytes32 userRoot) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, userRoot));
    }

    function _computeTokenLeaf(IERC20 token, uint256 amount) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, amount));
    }

    function _updateClaimedAmounts(address user, IERC20 token, uint256 amount) internal {
        uint256 pastClaimedAmount = cumulativeClaimed[user][token];
        require(pastClaimedAmount <= amount, "ClaimingManager: Claim amount is less than previously claimed");
        cumulativeClaimed[user][token] = amount;
        uint256 transferAmount = amount - pastClaimedAmount;
        token.transfer(user, transferAmount);
    }
}