// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../src/contracts/core/AllocationManager.sol";
import "../../src/contracts/core/DelegationManager.sol";
import "../../src/contracts/libraries/SlashingLib.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

// use forge:
// RUST_LOG=forge,foundry=trace forge script script/tasks/complete_withdrawal_from_strategy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile,address delegatedTo,address strategy,address token,uint256 amount)" -- <DEPLOYMENT_OUTPUT_JSON> <OPERATOR_ADDRESS> <STRATEGY_ADDRESS> <TOKEN_ADDRESS> <AMOUNT> <NONCE> <START_BLOCK_NUMBER>
// RUST_LOG=forge,foundry=trace forge script script/tasks/complete_withdrawal_from_strategy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(string memory configFile,address delegatedTo,address strategy,address token,uint256 amount,uint256 nonce,uint32 startBlock)" -- local/slashing_output.json 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x8aCd85898458400f7Db866d53FCFF6f0D49741FF 0x67d269191c92Caf3cD7723F116c85e6E9bf55933 750 0 630 
contract CompleteWithdrawFromStrategy is Script, Test {
    string public deployConfigPath;
    string public configData;

    function run(string memory configFile, address delegatedTo, address strategy, address token, uint256 amount, uint256 nonce, uint32 startBlock) public {
        // Load config
        deployConfigPath = string(bytes(string.concat("script/output/", configFile)));
        configData = vm.readFile(deployConfigPath);

        // Pull addresses from config
        address allocationManager = stdJson.readAddress(configData, ".addresses.allocationManager");
        address delegationManager = stdJson.readAddress(configData, ".addresses.delegationManager");

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        // Attach to Managers
        AllocationManager am = AllocationManager(allocationManager);
        DelegationManager dm = DelegationManager(delegationManager);

        // Add token to array
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(token);

        // Place addresses in array to reduce stack depth
        address[] memory addresses = new address[](2);
        addresses[0] = strategy;
        addresses[1] = delegatedTo;

        // Get the withdrawal struct
        IDelegationManagerTypes.Withdrawal memory withdrawal = _getWithdrawalStruct(am, dm, addresses, amount, nonce, startBlock);
        
        // complete
        dm.completeQueuedWithdrawal(withdrawal, tokens, true);

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();
    }

    function _getWithdrawalStruct(AllocationManager am, DelegationManager dm, address[] memory addresses, uint256 amount, uint256 nonce, uint32 startBlock) internal returns (IDelegationManagerTypes.Withdrawal memory)  {
        // Add strategy to array
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(addresses[0]);
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
        emit log_uint(depositScalingFactor);
        emit log_uint(maxMagnitudes[0]);
        emit log_uint(scaledShares[0]);

        // Create the withdrawal struct
        IDelegationManagerTypes.Withdrawal memory withdrawal = IDelegationManagerTypes.Withdrawal({
            staker: msg.sender,
            delegatedTo: addresses[1],
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
