// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../interfaces/ISlashingManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/ISlashableProportionOracle.sol";

abstract contract SlashingManager is ISlashingManager {
    /// @notice The maximum number of basis points that can be slashed via SSRs per epoch
    uint16 public constant MAX_BIPS_SLASHED_VIA_SSRS_PER_EPOCH = 100;

    /// @notice Slashable proportion oracle
    ISlashableProportionOracle immutable public slashableProportionOracle;

    struct BipsSlashed {
        uint16 bipsSlashed;
        uint16 bipsSlashedViaSSRs;
    }

    /// @notice The number of basis points that have been slashed for a given operator and strategy in each epoch
    mapping (address => mapping(IStrategy => mapping(uint32 => BipsSlashed))) public slashingsForOperator;

    /// @notice The number of basis points that have been slashed by a given avs and strategy in each epoch
    mapping (address => mapping(IStrategy => mapping(uint32 => BipsSlashed))) public slashingsForAVS;

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
            uint16 bipsToSlash = MAX_BIPS_SLASHED_VIA_SSRS_PER_EPOCH - slashingsForOperator[slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsSlashedViaSSRs;
            if (bipsToSlash == 0) {
                continue;
            }

            // Truncate the bips to slash if it exceeds the remaining bips that can be slashed via SSRs
            if (bipsToSlash > slashingRequestParams.bipsToSlash[i]) {
                bipsToSlash = slashingRequestParams.bipsToSlash[i];
            }

            // Get the bipsSlashedViaSSRs for the AVS, operator, and strategy in the current epoch
            uint16 bipsSlashedViaSSRsByAVS = slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsSlashedViaSSRs;

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

        slashingRequestStatuses[keccak256(abi.encode(slashingRequest))] = SlashingRequestStatus.EXECUTED;

        return bipsSlashed;
    }

    /**
     * @notice Called by AVSs to make large slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeLargeSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external virtual;

    /**
     * @notice Called by the veto committee to veto a slashing request
     * @param largeSlashingRequest the LSR to veto
     * @dev only callable by the veto committee
     */
    function vetoLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external virtual;

    /**
     * @notice Permissionlessly called to execute an LSR
     * @param largeSlashingRequest the LSR to execute
     * @dev permissionlessly callable
     */
    function executeLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external virtual;

    function _incrementSlashedBipsViaSSRs(address avs, address operator, IStrategy strategy, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][_getCurrentEpoch()].bipsSlashed += bipsToSlash;
        slashingsForOperator[operator][strategy][_getCurrentEpoch()].bipsSlashedViaSSRs += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][_getCurrentEpoch()].bipsSlashed += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][_getCurrentEpoch()].bipsSlashedViaSSRs += bipsToSlash;
    }

    // TODO: implement this function
    function _getCurrentEpoch() internal view returns(uint32) {
        return uint32(block.timestamp / 14 days);
    }
}
