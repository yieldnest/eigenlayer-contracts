// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Vm.sol";
import "zeus-templates/utils/ZEnvHelpers.sol";  

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// core/
import "src/contracts/core/AllocationManager.sol";
import "src/contracts/core/AVSDirectory.sol";
import "src/contracts/core/DelegationManager.sol";
import "src/contracts/core/RewardsCoordinator.sol";
import "src/contracts/core/StrategyManager.sol";

/// permissions/
import "src/contracts/permissions/PauserRegistry.sol";
import "src/contracts/permissions/PermissionController.sol";

/// pods/
import "src/contracts/pods/EigenPod.sol";
import "src/contracts/pods/EigenPodManager.sol";

/// strategies/
import "src/contracts/strategies/EigenStrategy.sol";
import "src/contracts/strategies/StrategyBase.sol";
import "src/contracts/strategies/StrategyBaseTVLLimits.sol";
import "src/contracts/strategies/StrategyFactory.sol";

library Env {

    using ZEnvHelpers for *;

    /// Dummy types and variables to facilitate syntax, e.g: `Env.proxy.delegationManager()`
    enum DeployedProxy { A }
    enum DeployedImpl { A }
    enum DeployedInstance { A }

    DeployedProxy internal constant proxy = DeployedProxy.A;
    DeployedImpl internal constant impl = DeployedImpl.A;
    DeployedInstance internal constant instance = DeployedInstance.A;

    /**
     * env
     */

    function executorMultisig() internal view returns (address) {
        return _envAddress("executorMultisig");
    }

    function opsMultisig() internal view returns (address) {
        return _envAddress("operationsMultisig");
    }

    function protocolCouncilMultisig() internal view returns (address) {
        return _envAddress("protocolCouncilMultisig");
    }

    function pauserMultisig() internal view returns (address) {
        return _envAddress("pauserMultisig");
    }

    function proxyAdmin() internal view returns (address) {
        return _envAddress("proxyAdmin");
    }

    function ethPOS() internal view returns (IETHPOSDeposit) {
        return IETHPOSDeposit(_envAddress("ethPOS"));
    }

    function timelockController() internal view returns (TimelockController) {
        return TimelockController(payable(_envAddress("timelockController")));
    }

    function multiSendCallOnly() internal view returns (address) {
        return _envAddress("MultiSendCallOnly");   
    }

    function EIGENPOD_GENESIS_TIME() internal view returns (uint64) {
        return _envU64("EIGENPOD_GENESIS_TIME");
    }

    function MIN_WITHDRAWAL_DELAY() internal view returns (uint32) {
        return _envU32("MIN_WITHDRAWAL_DELAY");
    }

    function ALLOCATION_CONFIGURATION_DELAY() internal view returns (uint32) {
        return _envU32("ALLOCATION_CONFIGURATION_DELAY");
    }

    function CALCULATION_INTERVAL_SECONDS() internal view returns (uint32) {
        return _envU32("CALCULATION_INTERVAL_SECONDS");
    }

    function MAX_REWARDS_DURATION() internal view returns (uint32) {
        return _envU32("MAX_REWARDS_DURATION");
    }

    function MAX_RETROACTIVE_LENGTH() internal view returns (uint32) {
        return _envU32("MAX_RETROACTIVE_LENGTH");
    }

    function MAX_FUTURE_LENGTH() internal view returns (uint32) {
        return _envU32("MAX_FUTURE_LENGTH");
    }

    function GENESIS_REWARDS_TIMESTAMP() internal view returns (uint32) {
        return _envU32("GENESIS_REWARDS_TIMESTAMP");
    }

    /**
     * core/
     */

    function allocationManager(DeployedProxy) internal view returns (AllocationManager) {
        return AllocationManager(_deployedProxy(type(AllocationManager).name));
    }

    function allocationManager(DeployedImpl) internal view returns (AllocationManager) {
        return AllocationManager(_deployedImpl(type(AllocationManager).name));
    }

    function avsDirectory(DeployedProxy) internal view returns (AVSDirectory) {
        return AVSDirectory(_deployedProxy(type(AVSDirectory).name));
    }

    function avsDirectory(DeployedImpl) internal view returns (AVSDirectory) {
        return AVSDirectory(_deployedImpl(type(AVSDirectory).name));
    }

    function delegationManager(DeployedProxy) internal view returns (DelegationManager) {
        return DelegationManager(_deployedProxy(type(DelegationManager).name));
    }

    function delegationManager(DeployedImpl) internal view returns (DelegationManager) {
        return DelegationManager(_deployedImpl(type(DelegationManager).name)); 
    }

    function rewardsCoordinator(DeployedProxy) internal view returns (RewardsCoordinator) {
        return RewardsCoordinator(_deployedProxy(type(RewardsCoordinator).name));
    }

    function rewardsCoordinator(DeployedImpl) internal view returns (RewardsCoordinator) {
        return RewardsCoordinator(_deployedImpl(type(RewardsCoordinator).name)); 
    }

    function strategyManager(DeployedProxy) internal view returns (StrategyManager) {
        return StrategyManager(_deployedProxy(type(StrategyManager).name));
    }

    function strategyManager(DeployedImpl) internal view returns (StrategyManager) {
        return StrategyManager(_deployedImpl(type(StrategyManager).name)); 
    }

    /**
     * permissions/
     */

    function pauserRegistry(DeployedImpl) internal view returns (PauserRegistry) {
        return PauserRegistry(_deployedImpl(type(PauserRegistry).name));
    }

    function permissionController(DeployedProxy) internal view returns (PermissionController) {
        return PermissionController(_deployedProxy(type(PermissionController).name));
    }

    function permissionController(DeployedImpl) internal view returns (PermissionController) {
        return PermissionController(_deployedImpl(type(PermissionController).name)); 
    }

    /**
     * pods/
     */

    function eigenPod(DeployedProxy) internal view returns (EigenPod) {
        return EigenPod(payable(_deployedProxy(type(EigenPod).name)));
    }

    function eigenPod(DeployedImpl) internal view returns (EigenPod) {
        return EigenPod(payable(_deployedImpl(type(EigenPod).name))); 
    }

    function eigenPodManager(DeployedProxy) internal view returns (EigenPodManager) {
        return EigenPodManager(_deployedProxy(type(EigenPodManager).name));
    }

    function eigenPodManager(DeployedImpl) internal view returns (EigenPodManager) {
        return EigenPodManager(_deployedImpl(type(EigenPodManager).name)); 
    }

    /**
     * strategies/
     */

    function eigenStrategy(DeployedProxy) internal view returns (EigenStrategy) {
        return EigenStrategy(_deployedProxy(type(EigenStrategy).name));
    }

    function eigenStrategy(DeployedImpl) internal view returns (EigenStrategy) {
        return EigenStrategy(_deployedImpl(type(EigenStrategy).name)); 
    }

    // Beacon proxy
    function strategyBase(DeployedProxy) internal view returns (StrategyBase) {
        return StrategyBase(_deployedProxy(type(StrategyBase).name));
    }

    // Beaconed impl
    function strategyBase(DeployedImpl) internal view returns (StrategyBase) {
        return StrategyBase(_deployedImpl(type(StrategyBase).name)); 
    }

    // Returns the number of proxy instances
    function strategyBaseTVLLimits_Count(DeployedInstance) internal view returns (uint) {
        return _deployedInstanceCount(type(StrategyBaseTVLLimits).name);
    }

    // Returns the proxy instance at index `i`
    function strategyBaseTVLLimits(DeployedInstance, uint i) internal view returns (StrategyBaseTVLLimits) {
        return StrategyBaseTVLLimits(_deployedInstance(type(StrategyBaseTVLLimits).name, i));
    }

    function strategyBaseTVLLimits(DeployedImpl) internal view returns (StrategyBaseTVLLimits) {
        return StrategyBaseTVLLimits(_deployedImpl(type(StrategyBaseTVLLimits).name)); 
    }

    function strategyFactory(DeployedProxy) internal view returns (StrategyFactory) {
        return StrategyFactory(_deployedProxy(type(StrategyFactory).name));
    }

    function strategyFactory(DeployedImpl) internal view returns (StrategyFactory) {
        return StrategyFactory(_deployedImpl(type(StrategyFactory).name)); 
    }

    /**
     * Helpers
     */

    function _deployedInstance(string memory name, uint idx) private view returns (address) {
        return ZEnvHelpers.state().deployedInstance(name, idx);
    }

    function _deployedInstanceCount(string memory name) private view returns (uint) {
        return ZEnvHelpers.state().deployedInstanceCount(name);
    }

    function _deployedProxy(string memory name) private view returns (address) {
        return ZEnvHelpers.state().deployedProxy(name);
    }

    function _deployedImpl(string memory name) private view returns (address) {
        return ZEnvHelpers.state().deployedImpl(name);
    }

    function _envAddress(string memory key) private view returns (address) {
        return ZEnvHelpers.state().envAddress(key);
    }

    function _envU64(string memory key) private view returns (uint64) {
        return ZEnvHelpers.state().envU64(key);
    }

    function _envU32(string memory key) private view returns (uint32) {
        return ZEnvHelpers.state().envU32(key);
    }
}