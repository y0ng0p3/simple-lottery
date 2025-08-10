// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

contract RaffleTest is Test {
    HelperConfig public helperConfig;
    Raffle public raffle;

    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    address public PLAYER = makeAddr("PLAYER");
    uint32 callbackGasLimit;
    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionId;
    bytes32 gasLane;
    address vrfCoordinator;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitialiazesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughFunds() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughFunds.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayers() public {
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testShouldNotPlayersShouldNotEnterWhenRaffleIsPicking() public {
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.prank(PLAYER);
        // Make sure the list of players isn't empty
        raffle.enterRaffle{value: entranceFee}();

        // Make sure enough time has passed and the block number has changed
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Simulate the Chainlink automation call
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
}
