// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../interfaces/ISlashingManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/ISlashableProportionOracle.sol";

abstract contract SlashingManager is ISlashingManager {
    /// @notice The maximum number of basis points that can be slashed
    uint16 public constant MAX_BIPS = 10000;

    /// @notice The maximum number of basis points that can be slashed via SSRs per epoch
    uint16 public constant MAX_BIPS_SLASHED_VIA_SSRS_PER_EPOCH = 100;

    /// @notice Slashable proportion oracle
    ISlashableProportionOracle immutable public slashableProportionOracle;

    /// @notice The veto committee
    address public vetoCommittee;

    struct BipsSlashed {
        uint16 bipsPendingSlashingViaSSRs;
        uint16 bipsPendingSlashing;
        uint16 bipsSlashed;
        uint16 bipsVetoed;
    }

    /// @notice The number of basis points that have been slashed for a given operator and strategy in each epoch
    mapping (address => mapping(IStrategy => mapping(uint32 => BipsSlashed))) public slashingsForOperator;

    /// @notice The number of basis points that have been slashed for a given operator and strategy by an AVS in each epoch
    mapping (address =>  mapping (address => mapping(IStrategy => mapping(uint32 => BipsSlashed)))) public slashingsForAVSAndOperator;

    /// @notice The 
    mapping(bytes32 => SlashingRequestStatus) public slashingRequestStatuses;

    constructor(ISlashableProportionOracle _slashableProportionOracle) {
        slashableProportionOracle = _slashableProportionOracle;
    }

    /**
     * @notice Called by AVSs to make small slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeSmallSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external returns(uint16[] memory) {
        // the address of the AVS making the request
        address avs = msg.sender;
        // the number of basis points that have been slashed for in this requests processing
        uint16[] memory bipsSlashed = new uint16[](slashingRequestParams.strategies.length);

        for (uint256 i = 0; i < slashingRequestParams.strategies.length; i++) {
            // Make sure bipsToSlash is not zero
            require(slashingRequestParams.bipsToSlash[i] > 0, "SlashingManager.makeSmallSlashingRequest: bips to slash is zero");

            // Get the number of bips left to slash via SSRs for the operator and strategy in the current epoch
            uint16 bipsToSlash = 
                MAX_BIPS_SLASHED_VIA_SSRS_PER_EPOCH 
                    - slashingsForOperator[slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashingViaSSRs;
            if (bipsToSlash == 0) {
                continue;
            }

            // Truncate the bips to slash if it exceeds the remaining bips that can be slashed via SSRs
            if (bipsToSlash > slashingRequestParams.bipsToSlash[i]) {
                bipsToSlash = slashingRequestParams.bipsToSlash[i];
            }

            // Get the bipsSlashedViaSSRs for the AVS, operator, and strategy in the current epoch
            uint16 bipsSlashedViaSSRsByAVS = 
                slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashingViaSSRs;

            // Check that the AVS is not slashing more bips via SSRs than the maximum allowed
            require(
                slashableProportionOracle.getMaxSmallSlashingRequestProportion(
                    avs, 
                    slashingRequestParams.operator, 
                    slashingRequestParams.strategies[i], 
                    _getCurrentEpoch()
                ) >= bipsSlashedViaSSRsByAVS + bipsToSlash,
                "SlashingManager.makeSmallSlashingRequest: bips to slash too high"
            );

            // Slash the operator
            // TODO: call delegation manager
            _incrementSlashedBipsViaSSRs(avs, slashingRequestParams.operator, slashingRequestParams.strategies[i], bipsToSlash);

            bipsSlashed[i] = bipsToSlash;
        }

        // Store the status of the slashing request
        SlashingRequest memory slashingRequest = SlashingRequest({
            requestType: SlashingRequestType.SMALL,
            avs: avs,
            operator: slashingRequestParams.operator, 
            strategies: slashingRequestParams.strategies,
            bipsToSlash: bipsSlashed,
            extraDataHash: keccak256(slashingRequestParams.extraData),
            blockTimestamp: uint32(block.timestamp)
        });

        slashingRequestStatuses[keccak256(abi.encode(slashingRequest))] = SlashingRequestStatus.PENDING;

        return bipsSlashed;
    }

    /**
     * @notice Called by AVSs to make large slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeLargeSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external {
        // the address of the AVS making the request
        address avs = msg.sender;

        for (uint256 i = 0; i < slashingRequestParams.strategies.length; i++) {
            // Make sure bipsToSlash is not zero
            require(slashingRequestParams.bipsToSlash[i] > 0, "SlashingManager.makeLargeSlashingRequest: bips to slash is zero");

            // Get the bipsSlashedViaSSRs for the AVS, operator, and strategy in the current epoch
            uint16 bipsSlashedByAVS = slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashing;

            // Get the bips left to slash for the operator and strategy in the current epoch
            uint16 bipsToSlash = MAX_BIPS - slashingsForOperator[slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashing;

            // Truncate the bips to slash if it exceeds the remaining bips that can be slashed
            if (bipsToSlash > slashingRequestParams.bipsToSlash[i]) {
                bipsToSlash = slashingRequestParams.bipsToSlash[i];
            }

            // Check that the AVS is not slashing more bips via SSRs than the maximum allowed
            require(
                slashableProportionOracle.getMaxLargeSlashingRequestProportion(
                    avs, 
                    slashingRequestParams.operator, 
                    slashingRequestParams.strategies[i], 
                    _getCurrentEpoch()
                ) >= bipsSlashedByAVS + bipsToSlash,
                "SlashingManager.makeLargeSlashingRequest: bips to slash too high"
            );

            slashingsForOperator[slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashing += bipsToSlash;
            slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingSlashing += bipsToSlash;
        }

        // Store the status of the slashing request
        SlashingRequest memory slashingRequest = SlashingRequest({
            requestType: SlashingRequestType.LARGE,
            avs: avs,
            operator: slashingRequestParams.operator, 
            strategies: slashingRequestParams.strategies,
            bipsToSlash: slashingRequestParams.bipsToSlash,
            extraDataHash: keccak256(slashingRequestParams.extraData),
            blockTimestamp: uint32(block.timestamp)
        });

        slashingRequestStatuses[keccak256(abi.encode(slashingRequest))] = SlashingRequestStatus.PENDING;
    }

    /**
     * @notice Called by the veto committee to veto a slashing request
     * @param largeSlashingRequest the LSR to veto
     * @dev only callable by the veto committee
     */
    function vetoLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external {
        require(msg.sender == vetoCommittee, "SlashingManager.vetoLargeSlashingRequest: only veto committee can veto");
        // TODO
    }

    /**
     * @notice Permissionlessly called to execute an LSR
     * @param largeSlashingRequest the LSR to execute
     * @dev permissionlessly callable
     */
    function executeLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external virtual;

    function _incrementSlashedBipsViaSSRs(address avs, address operator, IStrategy strategy, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][_getCurrentEpoch()].bipsSlashed += bipsToSlash;
        slashingsForOperator[operator][strategy][_getCurrentEpoch()].bipsPendingSlashingViaSSRs += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][_getCurrentEpoch()].bipsSlashed += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][_getCurrentEpoch()].bipsPendingSlashingViaSSRs += bipsToSlash;
    }

    // TODO: get epoch from timestamp
    function _getEpochFromTimestamp(uint32 timestamp) internal view returns(uint32) {
        return uint32(block.timestamp / 14 days);
    }

    // TODO: implement this function
    function _getCurrentEpoch() internal view returns(uint32) {
        return uint32(block.timestamp / 14 days);
    }
}
