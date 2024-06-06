// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./ISignatureUtils.sol";
import "./IStrategy.sol";

interface IAVSDirectory is ISignatureUtils {
    /// STRUCTS & ENUMS

    /// @notice Enum representing the status of an operator's registration with an AVS
    enum OperatorAVSRegistrationStatus {
        UNREGISTERED, // Operator not registered to AVS
        REGISTERED // Operator registered to AVS

    }

    struct OperatorSet {
        address avs;
        uint32 id;
    }

    /// EVENTS

    /// @notice Emitted when an operator's registration status for an AVS is updated
    /// specifically, when an operator enters its first operator set for an AVS, or
    /// when it was removed from the last operator set.
    event OperatorAVSRegistrationStatusUpdated(
        address indexed operator, address indexed avs, OperatorAVSRegistrationStatus status
    );

    /// @notice Emited when an operator is added to an operator set
    event OperatorAddedToOperatorSet(address operator, OperatorSet operatorSet);

    /// @notice Emitted when an operator is removed from an operator set
    event OperatorRemovedFromOperatorSet(address operator, OperatorSet operatorSet);

    /// @notice Emitted when a strategy is added to an operator set
    event OperatorSetStrategyAdded(OperatorSet operatorSet, IStrategy strategy);

    /// @notice Emitted when a strategy is removed from an operator set
    event OperatorSetStrategyRemoved(OperatorSet operatorSet, IStrategy strategy);

    /// @notice Emitted when an AVS updates their metadata URI (Uniform Resource Identifier).
    /// @dev The URI is never stored, it is simply emitted through an event for off-chain indexing.
    event AVSMetadataURIUpdated(address indexed avs, string metadataURI);

    /// EXTERNAL - STATE MODIFYING

    /**
     * @notice Called by the AVS's service manager contract to register an operator with the avs.
     *
     * @param operator The address of the operator to register.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     *
     * @dev msg.sender is the AVS
     * @dev only used by legacy M2 AVSs that haven't integrated with operator sets
     */
    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    /**
     * @notice Called by an avs to deregister an operator with the avs.
     *
     * @param operator The address of the operator to deregister.
     *
     * @dev only used by legacy M2 AVSs that haven't integrated with operator sets
     */
    function deregisterOperatorFromAVS(address operator) external;

    /**
     * @notice Called by AVSs to add an operator to an operator set
     *
     * @param operator the address of the operator to be added to the operator set
     * @param operatorSetIDs the IDs of the operator sets
     * @param signature the signature of the operator on their intent to register
     * @dev msg.sender is used as the AVS
     * @dev operator must not have a pending a deregistration from the operator set
     * @dev if this is the first operator set in the AVS that the operator is
     * registering for, a OperatorAVSRegistrationStatusUpdated event is emitted with
     * a REGISTERED status
     */
    function registerOperatorToOperatorSets(
        address operator,
        uint32[] calldata operatorSetIDs,
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature
    ) external;

    /**
     * @notice Called by AVSs or operators to remove an operator to from operator set
     *
     * @param operator the address of the operator to be removed from the
     * operator set
     * @param operatorSetIDs the IDs of the operator sets
     *
     * @dev msg.sender is used as the AVS
     * @dev operator must be registered for msg.sender AVS and the given
     * operator set
     * @dev if this removes operator from all operator sets for the msg.sender AVS
     * then an OperatorAVSRegistrationStatusUpdated event is emitted with a DEREGISTERED
     * status
     */
    function deregisterOperatorFromOperatorSets(address operator, uint32[] calldata operatorSetIDs) external;

    /**
     * @notice Called by AVSs to add a strategy to its operator set
     *
     * @param operatorSetID the ID of the operator set
     * @param strategies the list strategies of the operator set to add
     *
     * @dev msg.sender is used as the AVS
     * @dev no storage is updated as the event is used by off-chain services
     */
    function addStrategiesToOperatorSet(uint32 operatorSetID, IStrategy[] calldata strategies) external;

    /**
     * @notice Called by AVSs to remove a strategy to its operator set
     *
     * @param operatorSetID the ID of the operator set
     * @param strategies the list strategie of the operator set to remove
     *
     * @dev msg.sender is used as the AVS
     * @dev no storage is updated as the event is used by off-chain services
     */
    function removeStrategiesFromOperatorSet(uint32 operatorSetID, IStrategy[] calldata strategies) external;

    // VIEW

    /**
     * @notice Called by an AVS to emit an `AVSMetadataURIUpdated` event indicating the information has updated.
     * @param metadataURI The URI for metadata associated with an AVS
     * @dev Note that the `metadataURI` is *never stored * and is only emitted in the `AVSMetadataURIUpdated` event
     */
    function updateAVSMetadataURI(string calldata metadataURI) external;

    /**
     * @notice Returns whether or not the salt has already been used by the operator.
     * @dev Salts is used in the `registerOperatorToAVS` function.
     */
    function operatorSaltIsSpent(address operator, bytes32 salt) external view returns (bool);

    /**
     * @notice Calculates the digest hash to be signed by an operator to register with an AVS
     * @param operator The account registering as an operator
     * @param avs The AVS the operator is registering to
     * @param salt A unique and single use value associated with the approver signature.
     * @param expiry Time after which the approver's signature becomes invalid
     */
    function calculateOperatorAVSRegistrationDigestHash(
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    ) external view returns (bytes32);

    /**
     * @notice Calculates the digest hash to be signed by an operator to register with an operator set
     * @param avs The AVS that operator is registering to operator sets for.
     * @param operatorSetIDs An array of operator set IDs the operator is registering to.
     * @param salt A unique and single use value associated with the approver signature.
     * @param expiry Time after which the approver's signature becomes invalid
     */
    function calculateOperatorSetRegistrationDigestHash(
        address avs,
        uint32[] memory operatorSetIDs,
        bytes32 salt,
        uint256 expiry
    ) external view returns (bytes32);

    /// @notice The EIP-712 typehash for the Registration struct used by the contract
    function OPERATOR_AVS_REGISTRATION_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP-712 typehash for the OperatorSetRegistration struct used by the contract
    function OPERATOR_SET_REGISTRATION_TYPEHASH() external view returns (bytes32);
}
