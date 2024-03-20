pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "../../src/contracts/core/StrategyManager.sol";
import "../../src/contracts/strategies/StrategyBaseTVLLimits.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract Upgade_SM is Script, Test {
    Vm cheats = Vm(HEVM_ADDRESS);

    ProxyAdmin public eigenLayerProxyAdmin = ProxyAdmin(0x31F4A6Ba1d9c6F74e8c267a2918C5A172b082261);
    StrategyBase public baseStrategyImplementation;
    StrategyBase public strategyBaseProxy = StrategyBase(address(0xF83a81117AE073B13ce70f37302392BA90F28725));
    StrategyManager public strategyManager = StrategyManager(address(0x4F35BcB70dC1C7A817FFB21D1e1F322f6041D3d3));

    function run() public {
        // Deploy the strategy
        cheats.startBroadcast();

        baseStrategyImplementation = new StrategyBaseTVLLimits(strategyManager);
        eigenLayerProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(strategyBaseProxy))),
            address(baseStrategyImplementation)
        );

        cheats.stopBroadcast();
    }
}