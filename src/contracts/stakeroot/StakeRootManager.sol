// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IStakeRootManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "../libraries/OperatorSetLib.sol";

/**
 * @title StakeRootManager
 * @notice This contract manages subscriptions for AVSs to get access to their operator stakes and information
 * through proven operatorSetRoots.
 */
contract StakeRootManager is IStakeRootManager, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using OperatorSetLib for OperatorSet;

    // IMMUTABLES
    uint32 public constant MIN_CALCULATION_INTERVAL = 12 hours;

    struct SubscriptionState {
        SubscriptionParams params;
        SubscriptionParams pendingParams;
        uint32 pendingParamsTimestamp;

        uint256 depositBalance;
        uint32 latestRequestTimestamp;

        bytes32 latestProvenRoot;
        uint32 latestProvenCalculationTimestamp;
    }

    /// @notice Mapping from operatorSet hash to their subscription state
    mapping(bytes32 => SubscriptionState) public subscriptions;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice Initialize a new subscription for an operatorSet
     * @param operatorSet The operatorSet to initialize the subscription for
     * @param params The parameters for the subscription
     * @param initDepositAmount The initial deposit amount for the subscription
     * @dev msg.sender must be permissioned to the AVS. TODO: UAM
     */
    function initSubscription(
        OperatorSet calldata operatorSet,
        SubscriptionParams calldata params,
        uint256 initDepositAmount
    ) external {
        bytes32 key = operatorSet.key();
        require(msg.sender == operatorSet.avs, "Only the AVS can initialize a subscription");
        require(subscriptions[key].params.calculationInterval == 0, "Subscription already exists");
        require(initDepositAmount > 0, "Initial deposit must be greater than 0");
        _validateSubscriptionParams(params);

        // Transfer tokens from sender
        require(
            params.token.transferFrom(msg.sender, address(this), initDepositAmount),
            "Token transfer failed"
        );

        // Store subscription state
        SubscriptionParams memory pendingParams;
        subscriptions[key] = SubscriptionState({
            params: params,
            pendingParams: pendingParams,
            pendingParamsTimestamp: 0,
            depositBalance: initDepositAmount,
            latestRequestTimestamp: 0,
            latestProvenRoot: bytes32(0),
            latestProvenCalculationTimestamp: 0
        });
    }

    /**
     * @notice Update an existing subscription for an operatorSet
     * @param operatorSet The operatorSet to update the subscription for
     * @param newParams The new parameters for the subscription
     * @dev msg.sender must be permissioned to the AVS. TODO: UAM
     */
    function updateSubscription(
        OperatorSet calldata operatorSet,
        SubscriptionParams calldata newParams
    ) external {
        bytes32 key = operatorSet.key();
        SubscriptionState storage state = subscriptions[key];
        _updateSubscription(state);
        require(msg.sender == operatorSet.avs, "Only the AVS can update a subscription");
        require(state.params.calculationInterval > 0, "Subscription does not exist");
        _validateSubscriptionParams(newParams);
        
        // set update latest request timestamp
        state.latestRequestTimestamp = getLatestRequestTimestamp(operatorSet);
        // the new params take effect for requests after next request
        state.pendingParams = newParams;
        state.pendingParamsTimestamp = state.latestRequestTimestamp + state.params.calculationInterval;
    }

    /**
     * @notice Refill the deposit balance for an operatorSet's subscription
     * @param operatorSet The operatorSet to refill the subscription for
     * @param refillAmount The amount to refill
     * @dev anyone can refill a subscription
     */
    function refillSubscription(
        OperatorSet calldata operatorSet,
        uint256 refillAmount
    ) external {
        bytes32 key = operatorSet.key();
        SubscriptionState storage state = subscriptions[key];
        _updateSubscription(state);
        require(state.params.calculationInterval > 0, "Subscription does not exist");
        require(refillAmount > 0, "Refill amount must be greater than 0");

        // transfer tokens from sender
        require(
            state.params.token.transferFrom(msg.sender, address(this), refillAmount),
            "Token transfer failed"
        );

        // update deposit balance
        state.depositBalance += refillAmount;
    }

    /**
     * @notice Submit a proof for an operatorSet's latest request
     * @param operatorSet The operatorSet to submit the proof for
     * @param operatorSetRoot The proven operatorSetRoot
     * @param proof The proof of the operatorSetRoot
     */
    function submitProof(
        OperatorSet calldata operatorSet,
        bytes32 operatorSetRoot,
        Proof calldata proof
    ) external {
        bytes32 key = operatorSet.key();
        SubscriptionState storage state = subscriptions[key];
        _updateSubscription(state);
        require(state.params.calculationInterval > 0, "Subscription does not exist");
        require(
            state.latestRequestTimestamp > state.latestProvenCalculationTimestamp
            || operatorSetRoot != state.latestProvenRoot,
            "Root already proven"
        );

        uint32 latestRequestTimestamp = state.latestRequestTimestamp;

        // TODO: Verify the proof
        // This would involve checking the proof against the operatorSetRoot
        // and verifying it was calculated at the correct timestamp

        // store the proven root
        state.latestProvenRoot = operatorSetRoot;
        state.latestProvenCalculationTimestamp = latestRequestTimestamp;

        // send proof reward to the recipient
        uint256 proofReward = _getProofReward(state);
        require(state.params.token.transfer(proof.recipient, proofReward), "Token transfer failed");
    }

    function getLatestRequestTimestamp(OperatorSet calldata operatorSet) public view returns (uint32) {
        return _getLatestRequestTimestamp(subscriptions[operatorSet.key()]);
    }

    function getSubscriptionParams(OperatorSet calldata operatorSet) public view returns (SubscriptionParams memory) {
        return _getSubscriptionParams(subscriptions[operatorSet.key()]);
    }

    /// INTERNAL FUNCTIONS

    function _updateSubscription(SubscriptionState storage state) internal {
        state.latestRequestTimestamp = _getLatestRequestTimestamp(state);
        if (state.pendingParamsTimestamp <= block.timestamp && state.pendingParamsTimestamp != 0) {
            state.params = state.pendingParams;
            delete state.pendingParams;
            delete state.pendingParamsTimestamp;
        }
    }

    function _getSubscriptionParams(SubscriptionState storage state) internal view returns (SubscriptionParams memory) {
        if (state.pendingParamsTimestamp <= block.timestamp) {
            return state.pendingParams;
        }
        return state.params;
    }

    function _getLatestRequestTimestamp(SubscriptionState storage state) internal view returns (uint32) {
        SubscriptionParams memory params = _getSubscriptionParams(state);
        if (state.latestRequestTimestamp + params.calculationInterval > block.timestamp) {
            return state.latestRequestTimestamp + params.calculationInterval;
        }
        return state.latestRequestTimestamp;
    }

    function _getProofReward(SubscriptionState storage state) internal view returns (uint256) {
        // TODO: Implement proof reward calculation
        return 0;
    }

    function _validateSubscriptionParams(SubscriptionParams calldata params) internal pure {
        require(params.calculationInterval > MIN_CALCULATION_INTERVAL, "Invalid calculation interval");
        require(address(params.operatorSetCalculator) != address(0), "Invalid calculator");
        require(address(params.token) != address(0), "Invalid token");
    }
}
