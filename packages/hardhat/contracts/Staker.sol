// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

/**
* @title Stacker Contract
* @author scaffold-eth
* @notice A contract that allow users to stake ETH
*/
contract Staker {

  // External contract that will hold stacked funds
  ExampleExternalContract public exampleExternalContract;
  
  // Balances of the user's stacked funds
  mapping(address => uint256) public balances;

  // Staking threshold
  uint256 public constant threshold = 1 ether;

  // Staking deadline
  uint256 public deadline = block.timestamp + 30 seconds;

  // Contract's Events
  event Stake(address indexed sender, uint256 amount);

  // Contract's Modifiers
  /**
  * @notice Modifier that requires the deadline to be reached or not
  * @param requireReached Check if the deadline has reached or not
  */
  modifier deadlineReached( bool requireReached ) {
    uint256 timeRemaining = timeLeft();
    if( requireReached ) {
      require(timeRemaining == 0, "Deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Deadline is already reached");
    }
    _;
  }

  /**
  * @notice Modifier that requires the external contract to not be completed
  */
  modifier stakeNotCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "Staking process already completed");
    _;
  }

  /**
  * @notice Contract Constructor
  * @param exampleExternalContractAddress Address of the external contract that will hold staked funds
  */
  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  /**
  * @notice Stake method that updates the user's balance
  */
  function stake() public payable stakeNotCompleted deadlineReached(false) {
    // update the user's balance
    balances[msg.sender] += msg.value;

    // emit the event to notify the blockchain that we have correctly Staked some fund for the user
    emit Stake(msg.sender, msg.value);
  }

  function execute() public deadlineReached(true) stakeNotCompleted {
    uint256 contractBalance = address(this).balance;

    // check the contract has enough ETH to reach the treshold
    if (contractBalance >= threshold) { 

      // Execute the external contract, transfer all the balance to the contract
      // (bool sent, bytes memory data) = exampleExternalContract.complete{value: contractBalance}();
      (bool sent,) = address(exampleExternalContract).call{value: contractBalance}(abi.encodeWithSignature("complete()"));
      require(sent, "exampleExternalContract.complete failed");
    }
  }
 
  /**
  * @notice Allow users to withdraw their balance from the contract only if deadline is reached but the stake is not completed
  */
  function withdraw() public deadlineReached(true) stakeNotCompleted {
    uint256 userBalance = balances[msg.sender];

    // check if the user has balance to withdraw
    require(userBalance > 0, "You don't have balance to withdraw");

    // reset the balance of the user
    balances[msg.sender] = 0;

    // Transfer balance back to the user
    (bool sent,) = msg.sender.call{value: userBalance}("");
    require(sent, "Failed to send user balance back to the user");
  }

  /**
  * @notice The number of seconds remaining until the deadline is reached
  */
  function timeLeft() public view returns (uint256 timeleft) {
    if( block.timestamp >= deadline ) {
      return 0;
    } else {
      return deadline - block.timestamp;
    }
  }
  /**
  * @notice the `receive()` special function that receives eth and calls stake()
  */
  receive() external payable {
        stake();
  }
  
}
