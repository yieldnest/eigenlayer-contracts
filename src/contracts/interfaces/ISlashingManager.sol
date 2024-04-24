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
        SMALL,
        LARGE
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
     * @notice Called by AVSs to make small slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeSmallSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external returns (uint16[] memory);

    /**
     * @notice Called by AVSs to make large slashing requests
     * @param slashingRequestParams the parameters of the slashing request
     * @dev operator and strategies must be slashable at the current time according to the opt in/out subprotocol
     */
    function makeLargeSlashingRequest(SlashingRequestParams calldata slashingRequestParams) external;

    /**
     * @notice Called by the veto committee to veto a slashing request
     * @param largeSlashingRequest the LSR to veto
     * @dev only callable by the veto committee
     */
    function vetoLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external;

    /**
     * @notice Permissionlessly called to execute an LSR
     * @param largeSlashingRequest the LSR to execute
     * @dev permissionlessly callable
     */
    function executeLargeSlashingRequest(SlashingRequest calldata largeSlashingRequest) external returns(uint16[] memory);
}
