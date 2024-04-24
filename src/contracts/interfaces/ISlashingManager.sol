// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategy.sol";

interface ISlashingManager {
    enum SlashingRequestStatus {
        NULL,
        PENDING,
        VETOED,
        EXECUTED
    }

    enum SlashingRequestType {
        NULL,
        NONVETOABLE,
        VETOABLE
    }

    struct SlashingRequestParams {
        address operator; // provided by the avs, operator to slash
        IStrategy[] strategies; // provided by the avs, strategies to slash
        uint16[] bipsToSlash; // provided by the avs, the basis points to slash
        bytes extraData; // provided the avs, for communication purposes out of protocol
    }

    struct SlashingRequest {
        SlashingRequestType requestType; // NULL, SMALL, LARGE
        address avs; // params.avs
        address operator; // params.operator
        IStrategy[] strategies; // params.strategies
        uint16[] bipsToSlash; // params.bipsToSlash
        bytes32 extraDataHash; // hash of params.extraData. hash used for cheaper witnessing later on
        uint32 blockTimestamp; // blockTimestamp when request was initiated
    }

    /**
     * @notice Called by AVSs to make nonvetoable slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeNonvetoableSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external;

    /**
     * @notice Called by AVSs to make vetoable slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeVetoableSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external;

    /**
     * @notice Called by the veto committee to veto a slashing request
     * @param slashingRequest the slashing request to veto
     * @dev only callable by the veto committee
     */
    function vetoSlashingRequest(SlashingRequest calldata slashingRequest) external;

    /**
     * @notice Permissionlessly called to execute a slashing request
     * @param slashingRequest the slashing request to execute
     * @dev permissionlessly callable
     */
    function executeSlashingRequest(SlashingRequest calldata slashingRequest) external returns(uint16[] memory);
}
