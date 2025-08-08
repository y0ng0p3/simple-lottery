// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract DeployConstants {
  uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
  uint256 public constant LOCAL_CHAIN_ID = 31337;
  uint96 constant MOCK_BASE_FEE = 21e16;
  uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
  int256 constant MOCK_WEI_PER_UNIT_LINK = 1e14;
}

contract HelperConfig is DeployConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    error HelperConfig__InvalidChainId();

    constructor() {
      networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }
    
    function getConfig() public returns (NetworkConfig memory) {
      return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
      if (networkConfigs[chainId].vrfCoordinator != address(0)) {
        return networkConfigs[chainId];
      } else if (chainId == LOCAL_CHAIN_ID) {
        getOrCreateAnvilEthConfig();
      } else {
        revert HelperConfig__InvalidChainId();
      }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
      if (activeNetworkConfig.vrfCoordinator != address(0)) {
        return activeNetworkConfig;
      }

      vm.startBroadcast();
      VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
        MOCK_BASE_FEE,
        MOCK_GAS_PRICE_LINK,
        MOCK_WEI_PER_UNIT_LINK
      );
      vm.stopBroadcast();

      activeNetworkConfig = NetworkConfig({
        entranceFee: 1e16,
        interval: 30, // 30 seconds
        vrfCoordinator: address(vrfCoordinatorMock),
        subscriptionId: 0,
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        callbackGasLimit: 500_000
      });
      return activeNetworkConfig;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
      return NetworkConfig({
        entranceFee: 1e16,
        interval: 30, // 30 seconds
        vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
        subscriptionId: 0,
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        callbackGasLimit: 500_000
      });
    }
}
