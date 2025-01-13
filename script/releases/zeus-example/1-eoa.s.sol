// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {EOADeployer} from "zeus-templates/templates/EOADeployer.sol";
import {RewardsCoordinator} from "src/contracts/core/RewardsCoordinator.sol";
import {IDelegationManager} from "src/contracts/interfaces/IDelegationManager.sol";
import {DelegationManager} from "src/contracts/core/DelegationManager.sol";
import {StrategyManager} from "src/contracts/core/StrategyManager.sol";
import {EigenLabsUpgrade} from "../EigenLabsUpgrade.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {IPauserRegistry} from "src/contracts/interfaces/IPauserRegistry.sol";
import { BlankContract } from "./BlankContract.sol";

contract Deploy is EOADeployer {
    using EigenLabsUpgrade for *;

    function _runAsEOA() internal override {
        zUpdateUint16("ZEUS_EXAMPLE_UINT16", uint16(16));
        zUpdateUint32("ZEUS_EXAMPLE_UINT32", uint32(1 days));

        // Deploying new RewardsCoordinator implementation with operator split activation delay lock.
        vm.startBroadcast();
        
        deploySingleton(
            address(
                new BlankContract()
            ),
            this.impl(type(BlankContract).name)
        );

        vm.stopBroadcast();
    }

    function testDeploy() public virtual {
        // Deploy RewardsCoordinator Implementation
    }
}
