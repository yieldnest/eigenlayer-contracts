// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../src/contracts/core/AllocationManager.sol";
import "../../src/contracts/core/DelegationManager.sol";
import "../../src/contracts/libraries/SlashingLib.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

// use forge:
// RUST_LOG=forge,foundry=trace forge script script/tasks/complete_withdrawal_from_strategy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile,,address strategy,address token,uint256 amount)" -- <DEPLOYMENT_OUTPUT_JSON> <STRATEGY_ADDRESS> <TOKEN_ADDRESS> <AMOUNT> <NONCE> <START_BLOCK_NUMBER>
// RUST_LOG=forge,foundry=trace forge script script/tasks/complete_withdrawal_from_strategy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile,,address strategy,address token,uint256 amount,uint256 nonce,uint32 startBlock)" -- local/slashing_output.json 0x8aCd85898458400f7Db866d53FCFF6f0D49741FF 0x67d269191c92Caf3cD7723F116c85e6E9bf55933 750 0 630 
contract completeWithdrawFromStrategy is Script, Test {
    Vm cheats = Vm(VM_ADDRESS);

    string public deployConfigPath;
    string public config_data;

    function run(string memory configFile, address strategy, address token, uint256 amount, uint256 nonce, uint32 startBlock) public {
        // Load config
        deployConfigPath = string(bytes(string.concat("script/output/", configFile)));
        config_data = vm.readFile(deployConfigPath);

        // Pull addresses from config
        address allocationManager = stdJson.readAddress(config_data, ".addresses.allocationManager");
        address delegationManager = stdJson.readAddress(config_data, ".addresses.delegationManager");

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        // Attach to Managers
        AllocationManager am = AllocationManager(allocationManager);
        DelegationManager dm = DelegationManager(delegationManager);

        // Add token to array
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(token);

        // Get the withdrawal struct
        IDelegationManagerTypes.Withdrawal memory withdrawal = getWithdrawalStruct(am, dm, strategy, amount, nonce, startBlock);
        
        // complete
        dm.completeQueuedWithdrawal(withdrawal, tokens, true);

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();
    }

    function getWithdrawalStruct(AllocationManager am, DelegationManager dm, address strategy, uint256 amount, uint256 nonce, uint32 startBlock) internal view returns (IDelegationManagerTypes.Withdrawal memory)  {
        // Add strategy to array
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy);
        // Add shares to array
        uint256[] memory shares = new uint256[](1);
        shares[0] = amount;

        // Get SSF for Staker in strategy
        (uint184 depositScalingFactor, uint64 beaconChainScalingFactor, bool isBeaconChainScalingFactorSet) = dm.stakerScalingFactor(msg.sender, strategies[0]);
        // Populate the StakerScalingFactors struct with the returned values
        StakerScalingFactors memory ssf = StakerScalingFactors({
            depositScalingFactor: depositScalingFactor,
            beaconChainScalingFactor: beaconChainScalingFactor,
            isBeaconChainScalingFactorSet: isBeaconChainScalingFactorSet
        });
        
        // Get TM for Operator in strategies
        uint64[] memory maxMagnitudes = am.getMaxMagnitudesAtBlock(msg.sender, strategies, startBlock);
        // Get scaled shares for the given amount
        uint256[] memory scaledShares = new uint256[](1);
        scaledShares[0] = SlashingLib.scaleSharesForQueuedWithdrawal(amount, ssf, maxMagnitudes[0]);

        // Log the current state before completing
        console.logUint(depositScalingFactor);
        console.logUint(maxMagnitudes[0]);
        console.logUint(scaledShares[0]);

        // Create the withdrawal struct
        IDelegationManagerTypes.Withdrawal memory withdrawal = IDelegationManagerTypes.Withdrawal({
            staker: msg.sender,
            delegatedTo: msg.sender,
            withdrawer: msg.sender,
            nonce: nonce,
            startBlock: startBlock,
            strategies: strategies,
            scaledShares: scaledShares 
        });

        // Return the withdrawal struct
        return withdrawal;
    }
}
