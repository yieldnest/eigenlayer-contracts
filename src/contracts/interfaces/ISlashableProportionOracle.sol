// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../interfaces/IStrategy.sol";

// the payments protocol and opt in/out protocol will define this in the future.
interface ISlashableProportionOracle {

    /**
     * @notice Returns the maximum proportion of the operator's strategy shares that can be slashed by a certain AVS via large slashing requests at the given epoch
     * @param avs the address of the AVS
     * @param operator the address of the operator
     * @param strategy the address of the strategy
     * @param epoch the epoch at which to check the slashable proportion
     */
    function getMaxLargeSlashingRequestProportion(address avs, address operator, IStrategy strategy, uint32 epoch) external view returns (uint16);

    /**
     * @notice Returns the maximum proportion of the operator's strategy shares that can be slashed by a certain AVS via small slashing requests at the given epoch
     * @param avs the address of the AVS
     * @param operator the address of the operator
     * @param strategy the address of the strategy
     * @param epoch the epoch at which to check the slashable proportion
     */
    function getMaxSmallSlashingRequestProportion(address avs, address operator, IStrategy strategy, uint32 epoch) external view returns (uint16);

}