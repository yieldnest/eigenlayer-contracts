// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../src/contracts/core/AVSDirectory.sol";
import "../../src/contracts/interfaces/IAVSDirectory.sol";
import "../../src/contracts/core/AllocationManager.sol";
import "../../src/contracts/interfaces/IAllocationManager.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

// use forge:
// RUST_LOG=forge,foundry=trace forge script script/tasks/register_operator_to_operatorSet.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile)" -- <DEPLOYMENT_OUTPUT_JSON>
// RUST_LOG=forge,foundry=trace forge script script/tasks/register_operator_to_operatorSet.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile)" -- local/slashing_output.json
contract RegisterStrategiesToOperatorSet is Script, Test {

    function run(string memory configFile, address strategy, uint32 operatorSetId) public {
        // Load config
        string memory deployConfigPath = string(bytes(string.concat("script/output/", configFile)));
        string memory configData = vm.readFile(deployConfigPath);

        // Pull avs directory address
        address allocManager = stdJson.readAddress(configData, ".addresses.allocationManager");

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        // Attach to the deployed contracts
        AllocationManager allocationManager = AllocationManager(allocManager);

        // Add strategies to array
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy);

        // Add strategy to OperatorSet
        allocationManager.addStrategiesToOperatorSet(operatorSetId, strategies);

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();
    }
}
