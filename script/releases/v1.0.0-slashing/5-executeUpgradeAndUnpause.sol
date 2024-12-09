// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../Env.sol";
import {QueueAndUnpause} from "./2-queueUpgradeAndUnpause.s.sol";

import {MultisigCall, MultisigCallUtils} from "zeus-templates/templates/MultisigBuilder.sol";
import {SafeTx, SafeTxUtils} from "zeus-templates/utils/SafeTxUtils.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract Execute is QueueAndUnpause {
    using MultisigCallUtils for MultisigCall[];
    using SafeTxUtils for SafeTx;
    using Env for *;

    function options() internal override view returns (MultisigOptions memory) {
        return MultisigOptions(
            Env.protocolCouncilMultisig(),
            Operation.Call
        );
    }

    /**
     * @dev Overrides the previous _execute function to execute the queued transactions.
     */
    function runAsMultisig() internal override {
        bytes memory call = _getMultisigTransactionCalldata();
        TimelockController timelock = Env.timelockController();
        timelock.execute(
            Env.executorMultisig(),
            0,
            call,
            0,
            bytes32(0)
        );
    }

    function testDeploy() override public {}

    function testExecute() public { 
        // 1- run queueing logic
        vm.startPrank(Env.opsMultisig());
        super.runAsMultisig();
        vm.stopPrank();

        TimelockController timelock = Env.timelockController();
        bytes memory call = _getMultisigTransactionCalldata();
        bytes32 txHash = timelock.hashOperation(Env.executorMultisig(), 0, call, 0, 0);
        assertEq(timelock.isOperationPending(txHash), true, "Transaction should be queued and pending.");


        // 2- warp past delay?
        vm.warp(block.timestamp + timelock.getMinDelay()); // 1 tick after ETA
        assertEq(timelock.isOperationReady(txHash), true, "Transaction should be executable.");
        
        // 3- execute
        execute();

        // 3. TODO: assert that the execute did something
    }
}
