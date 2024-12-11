// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IOperatorSetRootCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct PriceParams {
    uint256 TODO; // TODO: parameters defining the price curve
}

struct Proof {
    bytes proofData; // The ZK proof data
    uint256 timestamp; // The timestamp at which the proof was generated
    address recipient; // The address to receive the proof reward
}

struct SubscriptionParams {
    IOperatorSetRootCalculator operatorSetCalculator; // Defined below: the contract to call to calculate operatorSetRoots
    uint32 calculationInterval; // the interval, in seconds, at which a new operatorSet root must be calculated
    IERC20 token; // the payment token for proofs
    PriceParams priceParams; // TODO: parameters defining the price curve for each aution
}

interface IStakeRootManager {
    /**
     * @notice used by AVSs to initialize their subscription to the StakeRoot service
     * @param operatorSet the operatorSet the subscription is for
     * @param params the parameters of the subscription defining various payment parameters
     * @param initDepositAmount the initial deposit of `params.token` to start the subscription with
     * @dev msg.sender must be permissioned to this call via UAM
     * @dev `initDepositAmount` of `params.token` will be transferred from the sender to this contract
     */
    function initSubscription(
        OperatorSet calldata operatorSet,
        SubscriptionParams calldata params,
        uint256 initDepositAmount
    ) external;

    /**
     * @notice used by AVSs to update their subscription to the StakeRoot service
     * @param operatorSet the operatorSet the subscription is for
     * @param params the parameters of the subscription defining various payment variables
     * @dev msg.sender must be permissioned to this call via UAM
     * @dev updates can only occur when there are no outstanding requests
     */
    function updateSubscription(
        OperatorSet calldata operatorSet,
        SubscriptionParams calldata params
    ) external;

    /**
     * @notice used by AVSs to update their subscription to the StakeRoot service
     * @param operatorSet the operatorSet the subscription is for
     * @param refillAmount the amount of payment tokens to refill the deposit
     */
    function refillSubscription(
        OperatorSet calldata operatorSet,
        uint256 refillAmount
    ) external;

    /**
     * @notice submits the proof for the latest request for the given operatorSet
     * @param operatorSet the operatorSet to submit the proof for
     * @param operatorSetRoot the proven operatorSetRoot
     * @param proof the proof of the operatorSetRoot at the latest auction timestamp
     */
    function submitProof(
        OperatorSet calldata operatorSet,
        bytes32 operatorSetRoot,
        Proof calldata proof
    ) external;
}