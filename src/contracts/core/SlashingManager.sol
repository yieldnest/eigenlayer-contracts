// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../interfaces/ISlashingManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/ISlashableProportionOracle.sol";

contract SlashingManager is ISlashingManager {
    /// @notice The maximum number of basis points that can be slashed
    uint16 public constant MAX_BIPS = 10000;

    /// @notice Slashable proportion oracle
    ISlashableProportionOracle immutable public slashableProportionOracle;

    /// @notice The veto committee
    address public vetoCommittee;

    struct SlashingSummary {
        uint32 bipsPendingNonvetoableSlashing; // these may overflow 10000, but will be resolved during execution
        uint32 bipsPendingVetoableSlashing;
        uint16 bipsSlashed;
        uint32 bipsVetoed;
    }

    /// @notice avs => whether the AVS's slashing requests can be vetoed
    mapping (address => bool) public vetoableAVSs;

    /// @notice The number of basis points that have been slashed for a given operator and strategy in each epoch
    mapping (address => mapping(IStrategy => mapping(uint32 => SlashingSummary))) public slashingsForOperator;

    /// @notice The number of basis points that have been slashed for a given operator and strategy by an AVS in each epoch
    mapping (address =>  mapping (address => mapping(IStrategy => mapping(uint32 => SlashingSummary)))) public slashingsForAVSAndOperator;

    /// @notice The 
    mapping(bytes32 => SlashingRequestStatus) public slashingRequestStatuses;

    modifier onlyVetoCommittee() {
        require(msg.sender == vetoCommittee, "SlashingManager.onlyVetoCommittee: only veto committee can call this function");
        _;
    }

    constructor(ISlashableProportionOracle _slashableProportionOracle) {
        slashableProportionOracle = _slashableProportionOracle;
    }

    /**
     * @notice Called by AVSs to make nonvetoable slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeNonvetoableSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external {
        // the address of the AVS making the request
        address avs = msg.sender;

        for (uint256 i = 0; i < slashingRequestParams.strategies.length; i++) {
            // Make sure bipsToSlash is not zero
            require(slashingRequestParams.bipsToSlash[i] > 0, "SlashingManager.makeNonvetoableSlashingRequest: bips to slash is zero");

            // Get the bipsPendingNonVetoableSlashingByAVS for the AVS, operator, and strategy in the current epoch
            uint32 bipsPendingNonVetoableSlashingByAVS = 
                slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingNonvetoableSlashing;
            
            // Check that the AVS is not slashing more nonvetoable bips than the maximum allowed
            require(
                slashableProportionOracle.getMaxNonvetoableSlashingRequestProportion(
                    avs, 
                    slashingRequestParams.operator, 
                    slashingRequestParams.strategies[i], 
                    _getCurrentEpoch()
                ) >= bipsPendingNonVetoableSlashingByAVS + slashingRequestParams.bipsToSlash[i],
                "SlashingManager.makeNonvetoableSlashingRequest: bips to slash too high"
            );

            // increment the number of nonvetoable bips slashed 
            _incrementBipsPendingNonvetoableSlashing(avs, slashingRequestParams.operator, slashingRequestParams.strategies[i], _getCurrentEpoch(), slashingRequestParams.bipsToSlash[i]);
        }

        // Store the status of the slashing request
        SlashingRequest memory slashingRequest = SlashingRequest({
            requestType: SlashingRequestType.NONVETOABLE,
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
     * @notice Called by AVSs to make vetoable slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeVetoableSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external {
        // the address of the AVS making the request
        address avs = msg.sender;

        // make sure the AVS is vetoable
        require(vetoableAVSs[msg.sender], "SlashingManager.makeVetoableSlashingRequest: AVS not vetoable");

        for (uint256 i = 0; i < slashingRequestParams.strategies.length; i++) {
            // Make sure bipsToSlash is not zero
            require(slashingRequestParams.bipsToSlash[i] > 0, "SlashingManager.makeVetoableSlashingRequest: bips to slash is zero");

            // Get the bipsPendingSlashingVetoableByAVS for the AVS, operator, and strategy in the current epoch
            uint32 bipsPendingSlashingVetoableByAVS = slashingsForAVSAndOperator[avs][slashingRequestParams.operator][slashingRequestParams.strategies[i]][_getCurrentEpoch()].bipsPendingVetoableSlashing;

            // Check that the AVS is not slashing more nonvetoable bips than the maximum allowed
            require(
                slashableProportionOracle.getMaxVetoableSlashingRequestProportion(
                    avs, 
                    slashingRequestParams.operator, 
                    slashingRequestParams.strategies[i], 
                    _getCurrentEpoch()
                ) >= bipsPendingSlashingVetoableByAVS + slashingRequestParams.bipsToSlash[i],
                "SlashingManager.makeVetoableSlashingRequest: bips to slash too high"
            );

            // increment the number of bips slashed
            _incrementBipsPendingVetoableSlashing(avs, slashingRequestParams.operator, slashingRequestParams.strategies[i], _getCurrentEpoch(), slashingRequestParams.bipsToSlash[i]);
        }

        // Store the status of the slashing request
        SlashingRequest memory slashingRequest = SlashingRequest({
            requestType: SlashingRequestType.VETOABLE,
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
     * @param slashingRequest the slashing request to veto
     * @dev only callable by the veto committee
     */
    function vetoSlashingRequest(SlashingRequest calldata slashingRequest) external {
        require(msg.sender == vetoCommittee, "SlashingManager.vetoSlashingRequest: only veto committee can veto");
        require(vetoableAVSs[slashingRequest.avs], "SlashingManager.vetoSlashingRequest: AVS not vetoable");
        require(slashingRequest.requestType == SlashingRequestType.VETOABLE, "SlashingManager.vetoSlashingRequest: only vetoable slashing requests can be vetoed");
        require(_inVetoPeriodForTime(slashingRequest.blockTimestamp), "SlashingManager.vetoSlashingRequest: not in veto period");

        uint32 requestEpoch = _getEpochFromTimestamp(slashingRequest.blockTimestamp);
        // Get the status of the slashing request
        bytes32 requestHash = keccak256(abi.encode(slashingRequest));
        require(slashingRequestStatuses[requestHash] == SlashingRequestStatus.PENDING, "SlashingManager.vetoSlashingRequest: slashing request not pending");
        
        // subtract bipsPendingSlashing
        for (uint256 i = 0; i < slashingRequest.strategies.length; i++) {
            _decrementBipsPendingVetoableSlashing(slashingRequest.avs, slashingRequest.operator, slashingRequest.strategies[i], requestEpoch, slashingRequest.bipsToSlash[i]);
        }

        slashingRequestStatuses[requestHash] = SlashingRequestStatus.VETOED;
    }

    /**
     * @notice Permissionlessly called to execute a slashing request
     * @param slashingRequest the slashing request to execute
     * @dev permissionlessly callable
     */
    function executeSlashingRequest(SlashingRequest calldata slashingRequest) external returns(uint16[] memory) {
        require(_inExecutionPeriodForTime(slashingRequest.blockTimestamp), "SlashingManager.executeSlashingRequest: not in execution period");

        uint16[] memory bipsSlashed = new uint16[](slashingRequest.strategies.length);

        uint32 requestEpoch = _getEpochFromTimestamp(slashingRequest.blockTimestamp);
        // Get the status of the slashing request
        bytes32 requestHash = keccak256(abi.encode(slashingRequest));
        require(slashingRequestStatuses[requestHash] == SlashingRequestStatus.PENDING, "SlashingManager.executeSlashingRequest: slashing request not pending");

        // Get bips left to slash
        for (uint256 i = 0; i < slashingRequest.strategies.length; i++) {
            uint16 bipsToSlash = MAX_BIPS - slashingsForOperator[slashingRequest.operator][slashingRequest.strategies[i]][requestEpoch].bipsSlashed;
            if (bipsToSlash == 0) {
                continue;
            }

            // Truncate the bips to slash if it exceeds the remaining bips that can be slashed
            if (bipsToSlash > slashingRequest.bipsToSlash[i]) {
                bipsToSlash = slashingRequest.bipsToSlash[i];
            }
            bipsSlashed[i] = bipsToSlash;

            // increment the number of bips slashed
            _decrementBipsPendingVetoableSlashing(slashingRequest.avs, slashingRequest.operator, slashingRequest.strategies[i], requestEpoch, bipsToSlash);
            _incrementBipsSlashed(slashingRequest.avs, slashingRequest.operator, slashingRequest.strategies[i], requestEpoch, bipsToSlash);
        }

        // TODO: Execute the slashing request

        slashingRequestStatuses[requestHash] = SlashingRequestStatus.EXECUTED;

        return bipsSlashed;
    }

    function _incrementBipsPendingNonvetoableSlashing(address avs, address operator, IStrategy strategy, uint32 epoch, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][epoch].bipsPendingNonvetoableSlashing += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][epoch].bipsPendingNonvetoableSlashing += bipsToSlash;
    }

    function _incrementBipsPendingVetoableSlashing(address avs, address operator, IStrategy strategy, uint32 epoch, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][epoch].bipsPendingVetoableSlashing += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][epoch].bipsPendingVetoableSlashing += bipsToSlash;
    }

    function _decrementBipsPendingVetoableSlashing(address avs, address operator, IStrategy strategy, uint32 epoch, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][epoch].bipsPendingVetoableSlashing -= bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][epoch].bipsPendingVetoableSlashing -= bipsToSlash;
    }

    function _incrementBipsSlashed(address avs, address operator, IStrategy strategy, uint32 epoch, uint16 bipsToSlash) internal {
        slashingsForOperator[operator][strategy][epoch].bipsSlashed += bipsToSlash;
        slashingsForAVSAndOperator[avs][operator][strategy][epoch].bipsSlashed += bipsToSlash;
    }

    // TODO: get if we're in the veto period for timestamp
    function _inVetoPeriodForTime(uint32 timestamp) internal pure returns(bool) {
        return timestamp == 69;
    }

    // TODO: get if we're in the execution period for timestamp
    function _inExecutionPeriodForTime(uint32 timestamp) internal pure returns(bool) {
        return timestamp == 69;
    }

    // TODO: get epoch from timestamp
    function _getEpochFromTimestamp(uint32 timestamp) internal pure returns(uint32) {
        return uint32(timestamp / 14 days);
    }

    // TODO: implement this function
    function _getCurrentEpoch() internal view returns(uint32) {
        return uint32(block.timestamp / 14 days);
    }
}
