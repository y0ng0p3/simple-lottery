// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A simple Raffle contract
 * @author [y0ng0p3](https://github.com/y0ng0p3)
 * @notice This contract is for creating a simple Raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Type Declarations */
    enum RaffleState {
        OPEN,
        PICKING
    }
    /* Variables */
    // address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    uint32 immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    address private immutable i_owner;
    // bytes32 private i_keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    // @dev The minimum fee a player must to enter the raffle
    uint256 private s_entranceFee;
    uint256 private s_lastTimestamp;
    address payable s_lastWinner;
    address payable[] s_players;
    RaffleState s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    /* Errors */
    error Raffle__NotOwner();
    error Raffle__NotEnoughFunds();
    error Raffle__NotReady();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* Modifiers */
    // modifier onlyOwner() {
    //     if (msg.sender != i_owner) revert Raffle__NotOwner();
    //     _;
    // }

    /* Functions */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_owner = msg.sender;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_entranceFee = entranceFee;
        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    receive() external payable {}

    fallback() external payable {}

    function updateEntranceFee(uint256 newFee) external onlyOwner {
        if (newFee == 0) revert Raffle__NotEnoughFunds();
        s_entranceFee = newFee;
    }

    function enterRaffle() external payable {
        if (msg.value < s_entranceFee) revert Raffle__NotEnoughFunds();
        if (s_raffleState == RaffleState.PICKING) revert Raffle__RaffleNotOpen();
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * Getter function to retrieve entranceFee
     */
    function getEntraceFee() external view returns (uint256) {
        return s_entranceFee;
    }

    /**
     * Get funciton to retrieve the state of the raffle
     */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    /**
     * Get function to retrieve a player by its index
     */
    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    /**
     * A funciton that Chainlink nodes call to see if the lottery is ready to have a winner
     * @param //checkData - the data to check to determine if the upkeepNeeded condition is met
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return performData - data to be transfer to the perfomUpkeep() function
     */
    function checkUpkeep(bytes calldata /*checkData*/ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        upkeepNeeded = (block.timestamp >= s_lastTimestamp + i_interval) && (s_raffleState == RaffleState.OPEN)
            && (address(this).balance > 0) && (s_players.length > 0);
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /*performData*/) external {
        pickWinner();
    }

    /**
     * Get a random number
     * Use the random number to pick a player between the s_players array
     * Be automatically called
     */
    function pickWinner() internal {
        if (block.timestamp < s_lastTimestamp + i_interval) revert Raffle__NotReady();

        s_raffleState = RaffleState.PICKING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_lastWinner = winner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        (bool s,) = winner.call{value: address(this).balance}("");
        if (!s) revert Raffle__TransferFailed();
        emit WinnerPicked(winner);
    }
}
