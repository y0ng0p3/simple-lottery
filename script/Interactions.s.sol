// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, DeployConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    uint256 public s_latestSubId;
    mapping(uint256 chainId => uint256[] subIds) public s_chainIdToSubIds;
    HelperConfig public helperConfig;

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        (config.subscriptionId, config.vrfCoordinator) = createSubscription(vrfCoordinator);

        s_latestSubId = config.subscriptionId;
        s_chainIdToSubIds[block.chainid].push(config.subscriptionId);
        HelperConfig.NetworkConfig memory currentNetworkConfig = HelperConfig.NetworkConfig({
            entranceFee: config.entranceFee,
            interval: config.interval,
            vrfCoordinator: config.vrfCoordinator,
            subscriptionId: config.subscriptionId,
            gasLane: config.gasLane,
            callbackGasLimit: config.callbackGasLimit,
            link: config.link
        });
        helperConfig.updateActiveNetworkConfig(currentNetworkConfig);
        helperConfig.updateChainNetworkConfig(block.chainid, currentNetworkConfig);
        return (config.subscriptionId, config.vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console2.log("Creating a subscription on chainId: %d...", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console2.log("Subscription Id: %d created", subId);
        console2.log("Update the subscription Id in HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public {
        (uint256 subId,) = createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, DeployConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;
    HelperConfig helperConfig;

    function fundSubscriptionUsingConfig() public {
        // if (address(helperConfig) == address(0)) {
        // helperConfig = new HelperConfig();
        // }
        helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console2.log("Funding subscription with Id: ", subscriptionId);
        console2.log("using vrfCoordinator: ", vrfCoordinator);
        console2.log("on chainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    HelperConfig public helperConfig;

    function addConsumerUsingConfig(address consumer) public {
        helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(consumer, vrfCoordinator, subId);
    }

    function addConsumer(address consumer, address vrfCoordinator, uint256 subId) public {
        console2.log("Adding consumer contract: ", consumer);
        console2.log("to the vrfCoordinator: ", vrfCoordinator);
        console2.log("on the chain with the id: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function run() external {
        address lastDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(lastDeployedContract);
    }
}
