// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {MultisigCall, MultisigCallUtils, MultisigBuilder} from "zeus-templates/templates/MultisigBuilder.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Deploy} from "./1-eoa.s.sol";
import {RewardsCoordinator} from "src/contracts/core/RewardsCoordinator.sol";
import {EigenLabsUpgrade} from "../EigenLabsUpgrade.s.sol";
import {IPauserRegistry} from "src/contracts/interfaces/IPauserRegistry.sol";
import {ITimelock} from "zeus-templates/interfaces/ITimelock.sol";
import {console} from "forge-std/console.sol";
import {EncGnosisSafe} from "zeus-templates/utils/EncGnosisSafe.sol";
import {MultisigCallUtils, MultisigCall} from "zeus-templates/utils/MultisigCallUtils.sol";
import {IMultiSend} from "zeus-templates/interfaces/IMultiSend.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import { BlankContract } from "./BlankContract.sol";
/**
 * Purpose: enqueue a multisig transaction which tells the ProxyAdmin to upgrade RewardsCoordinator.
 */
contract Queue is MultisigBuilder, Deploy {
    using MultisigCallUtils for MultisigCall[];
    using EigenLabsUpgrade for *;
    using EncGnosisSafe for *;
    using MultisigCallUtils for *;

    MultisigCall[] private _executorCalls;
    MultisigCall[] private _opsCalls;

    function options() internal virtual override view returns (MultisigOptions memory) {
        return MultisigOptions(
            address(0x872Ac6896A7DCd3907704Fab60cc87ab7Cac6A9B), // zeus holesky SAFE
            Operation.Call
        );
    }

    function runAsMultisig() internal virtual override {
        BlankContract ctr = BlankContract(zDeployedImpl(type(BlankContract).name));
        ctr.updateInteger(20);
    }
}
