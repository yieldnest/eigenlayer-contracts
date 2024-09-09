// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "./TransactionSubmitter.sol";
import "script/utils/ExistingDeploymentParser.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * Operator Indices: Derived from `MNEMONIC`. Indices 0-1000
 * AVS Indices: Contract 0-10 in `transaction_submitter` 
 * Strategy Indices: Contract 0-15 in `transaction_submitter`
 * Staker Indices: Derived from `MNEMONIC`. Indices 750-100_000 (500 operators have also deposited)
 * AVS Indices: Contract 0-5 in `transaction_submitter`
 */
contract MiniBuilder is ExistingDeploymentParser {
    Vm cheats = Vm(VM_ADDRESS);
    using Strings for uint256;

    // Addresses set by _parseState function
    ProxyAdmin proxyAdmin;
    TransactionSubmitter transactionSubmitter;
    uint256 operatorsRegistered;
    string MNEMONIC;

    // Path to EigenLayer contracts
    string contractsPath = "script/configs/holesky/eigenlayer_addresses_preprod.config.json";
    // Path to state so we do not duplicate transactions deployed directly from this contract
    string statePath = "script/utils/rewards_testing/preprod_state.json";

    // Operator Indices
    uint256 minOperatorIndex = 0;
    uint256 maxOperatorIndex = 1000;
    uint256 numOperatorsRegisteredToAVSs = 800;

    // Staker Indices
    uint256 minStakerIndex = 750;
    uint256 stakerNonOperatorStartIndex = 1001;
    uint256 maxStakerIndex = 51_000; // 50000 pure stakers. 250 opStakers
    uint256 firstHalfStakerIndex = 26_000;

    // AVS Indices
    uint16 minAVSIndex = 0;
    uint16 maxAVSIndex = 5;

    function delegateFirstHalfOfStakers() external parseState {
        uint256 firstStaker = 13001; //13001 to 26000 should be next
        uint256 lastStaker = firstHalfStakerIndex;

        uint256 batchSize = 40;

        for (uint256 i = firstStaker; i < lastStaker; i += batchSize) {
            TransactionSubmitter.StakerDelegation[] memory delegations = new TransactionSubmitter.StakerDelegation[](batchSize);

            for (uint256 j = 0; j < batchSize; j++) {
                uint256 stakerPrivateKey = vm.deriveKey(MNEMONIC, uint32(i + j));
                address staker = vm.addr(stakerPrivateKey);

                address operator = vm.addr(vm.deriveKey(MNEMONIC, uint32(_getOperatorIndexFirstHalf(i + j))));

                ISignatureUtils.SignatureWithExpiry memory stakerSignature = _getStakerDelegationSignature(stakerPrivateKey, staker, operator);

                delegations[j] = TransactionSubmitter.StakerDelegation({
                    staker: staker,
                    operator: operator,
                    stakerSignatureAndExpiry: stakerSignature,
                    approverSignatureAndExpiry: ISignatureUtils.SignatureWithExpiry({
                        signature: "",
                        expiry: 0
                    }),
                    approverSalt: bytes32(0)
                });
            }

            vm.startBroadcast();
            transactionSubmitter.delegateStakers(delegations);
            vm.stopBroadcast();
        }
    }

    /**
     *
     *                         HELPER FUNCTIONS
     *
     */

    modifier parseState() {
        _parseDeployedContracts(contractsPath);
        _parseState(statePath);
        _;
    }

    function _parseState(string memory statePathToParse) internal {
        // READ JSON CONFIG DATA
        string memory stateData = vm.readFile(statePathToParse);
        emit log_named_string("Using state file", statePathToParse);

        transactionSubmitter = TransactionSubmitter(payable(stdJson.readAddress(stateData, ".submitterProxy")));
        proxyAdmin = ProxyAdmin(stdJson.readAddress(stateData, ".submitterProxyAdmin"));
        operatorsRegistered = stdJson.readUint(stateData, ".operatorsRegistered");
        MNEMONIC = vm.envString("MNEMONIC");
    }

    /// @notice helper to get operator Signature
    function _getOperatorSignature(
        uint256 _operatorPrivateKey,
        address operator,
        address avs
    ) internal returns (ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        operatorSignature.expiry = type(uint32).max;
        operatorSignature.salt = bytes32(vm.randomUint());
        {
            bytes32 digestHash = avsDirectory.calculateOperatorAVSRegistrationDigestHash(operator, avs, operatorSignature.salt, operatorSignature.expiry);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_operatorPrivateKey, digestHash);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        return operatorSignature;
    }

    function _getStakerDelegationSignature(
        uint256 _stakerPrivateKey,
        address staker,
        address operator
    ) internal returns (ISignatureUtils.SignatureWithExpiry memory stakerSignature) {
        stakerSignature.expiry = type(uint32).max;
        {
            bytes32 digestHash = delegationManager.calculateCurrentStakerDelegationDigestHash(staker, operator, stakerSignature.expiry);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_stakerPrivateKey, digestHash);
            stakerSignature.signature = abi.encodePacked(r, s, v);
        }
        return stakerSignature;
    }

    function _getRandomAVSs(address[] memory avss) internal returns (address[] memory) {
        uint256 min = 1;
        uint256 max = 5;
        uint256 randomNumber = vm.randomUint(min, max);

        address[] memory randomAVSs = new address[](randomNumber);

        for (uint256 i = 0; i < randomNumber; i++) {
            randomAVSs[i] = avss[i];
        }

        return randomAVSs;
    }

    function _getOperatorSignatures(
        uint256 _operatorPrivateKey,
        address operator,
        address[] memory avss
    ) internal returns (ISignatureUtils.SignatureWithSaltAndExpiry[] memory operatorSignatures) {
        ISignatureUtils.SignatureWithSaltAndExpiry[] memory signatures = new ISignatureUtils.SignatureWithSaltAndExpiry[](avss.length);
        for (uint256 i = 0; i < avss.length; i++) {
            signatures[i] = _getOperatorSignature(_operatorPrivateKey, operator, avss[i]);
        }
        return signatures;
    }

    function _getOperatorIndexFirstHalf(uint256 stakerIndex) internal returns (uint256) {
        uint256 lastIndex = firstHalfStakerIndex;
        if (stakerIndex < 11_000) {
            return 0;
        } else if (stakerIndex < 16_000) {
            return 1;
        } else if (stakerIndex < 21_000) {
            return 2;
        } else if (stakerIndex < 23_500) {
            return 3;
        } else if (stakerIndex <= 26_000) {
            return 4;
        } else {
            return 5;
        }
    }
} 