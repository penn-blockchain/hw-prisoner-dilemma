pragma solidity ^0.4.17;

contract MultiplePrisonersDilemma {

  uint COLLAB = 1;
  uint DEFECT = 2;


  /*
  Lets say that _prices are 0, 5, 8
  Both players must deposit 8 ether
  The prices correspond to years in jail
  Instead of serving time in jail, you give ether to the jail
  */

  enum Stage {
    Commit,
    Reveal,
    CheckBoard,
    Withdraw
  }

  struct Player {
    bytes32 commitment;
    uint reveal;
    bool isComitted;
    bool isRevealed;

  }
  struct Dilemma {
    Stage currentStage;
    uint [] prices;
    mapping (address => Player) players;
    address player1;
    address player2;
    address jail;
    bool firstCommit;
    bool firstReveal;
    uint timeOfFirstCommit;
    uint timeOfFirstReveal;
    mapping (address => uint) balances;
    mapping (address => mapping (uint => mapping (uint => uint))) penalty;
  }

  uint maxTime = 3 * 1 days;

  mapping (uint => Dilemma) allGames;
  uint DilemmaID = 0;

  modifier playersOnly (address player, uint _DilemmaID) {
    require (allGames[_DilemmaID].player1 == player || allGames[_DilemmaID].player2 == player);
    _;
  }

  modifier checkState (uint _DilemmaID, Stage stage) {
    require (allGames[_DilemmaID].currentStage == stage);
    _;
  }

  function createDilemma (address _player1, address _player2, address _jail, uint [] _prices) {
    uint length = _prices.length;
    require (length == 4);
    // make sure prices are formatted correctly
    for (uint i = 1; i < length; i ++) {
      require (_prices[i-1] < _prices[i]);
    }
    DilemmaID ++;
    allGames[DilemmaID].player1 = _player1;
    allGames[DilemmaID].player2 = _player2;
    allGames[DilemmaID].jail = _jail;
    allGames[DilemmaID].prices = _prices;
    allGames[DilemmaID].currentStage = Stage.Commit;
    createBoard(_prices, DilemmaID, _player1, _player2);

  }

// their committment must be in the order: user address, random Number, response
  function commit (bytes32 _commitment, uint _DilemmaID) playersOnly (msg.sender, _DilemmaID) checkState (_DilemmaID, Stage.Commit) payable {
    require (allGames[DilemmaID].prices[3] <= msg.value);
    allGames[_DilemmaID].balances[msg.sender] += msg.value;
    allGames[_DilemmaID].players[msg.sender].commitment = _commitment;
    allGames[_DilemmaID].players[msg.sender].isComitted = true;
    allGames[_DilemmaID].firstCommit = true;
    // if you recommit, you resart the timer for the other player's committment
    allGames[_DilemmaID].timeOfFirstCommit = now;


    // check to change state
    address player1 = allGames[_DilemmaID].player1;
    address player2 = allGames[_DilemmaID].player2;
    if (allGames[_DilemmaID].players[player1].isComitted && allGames[_DilemmaID].players[player2].isComitted) {
      allGames[_DilemmaID].currentStage = Stage.Reveal;
    }
  }

  // response 0 represents "say nothing"
  // response 1 represents "turn parter in"
  function reveal (uint _randomNumber, uint _response, uint _DilemmaID) playersOnly (msg.sender, _DilemmaID) checkState (_DilemmaID, Stage.Reveal) {
    bytes32 check = sha256(msg.sender, _randomNumber, _response);
    // if you swtich your answer, you lose your entire deposit
    if (allGames[_DilemmaID].players[msg.sender].commitment == check) {
      allGames[_DilemmaID].players[msg.sender].reveal = _response;
    } else {
      // figure out if msg.sender is player1 or player 2
      // give the player that did not cheat, msg.sender's balance
      if (msg.sender == allGames[_DilemmaID].player1){
        allGames[_DilemmaID].balances[allGames[DilemmaID].player2] += allGames[_DilemmaID].balances[msg.sender];
      } else {
        allGames[_DilemmaID].balances[allGames[DilemmaID].player1] += allGames[_DilemmaID].balances[msg.sender];
      }
      allGames[_DilemmaID].balances[msg.sender] = 0;

    }
    allGames[_DilemmaID].firstReveal = true;
    allGames[_DilemmaID].timeOfFirstReveal = now;

    // check to change state
    address player1 = allGames[_DilemmaID].player1;
    address player2 = allGames[_DilemmaID].player2;
    if (allGames[_DilemmaID].players[player1].isRevealed && allGames[_DilemmaID].players[player2].isRevealed) {
      allGames[_DilemmaID].currentStage = Stage.CheckBoard;
    }
  }


  // find penalties after both parties reveal
  function checkBoard (uint _DilemmaID) checkState (_DilemmaID, Stage.CheckBoard) {
    address player1 = allGames[_DilemmaID].player1;
    address player2 = allGames[_DilemmaID].player2;
    address jail = allGames[_DilemmaID].jail;
    uint answer1 = allGames[_DilemmaID].players[player1].reveal;
    uint answer2 = allGames[_DilemmaID].players[player2].reveal;
    uint penalty1 = allGames[_DilemmaID].penalty[player1][answer1][answer2];
    uint penalty2 = allGames[_DilemmaID].penalty[player2][answer1][answer2];
    allGames[_DilemmaID].balances[player1] -= penalty1;
    allGames[_DilemmaID].balances[player2] -= penalty2;
    allGames[_DilemmaID].balances[jail] += penalty1 + penalty2;
  }

  // if only one party commits, then after three days allow party to withdraw his funds
  function commitTimeIsUp (uint _DilemmaID) playersOnly (msg.sender, _DilemmaID) checkState (_DilemmaID, Stage.Commit) {
    if (now > allGames[_DilemmaID].timeOfFirstCommit + maxTime) {
      allGames[_DilemmaID].currentStage = Stage.Withdraw;
    }
  }

// WLOG if only player1 reveals, then he automatically wins player2's balance.
// this prevents player2 from observing the reveal of player1 to see if he will win
// and if he does not win then not revealing and later withdrawing his balance
  function revealTimeIsUp (uint _DilemmaID) playersOnly (msg.sender, DilemmaID) checkState (_DilemmaID, Stage.Reveal){
    if (now > allGames[_DilemmaID].timeOfFirstReveal + maxTime) {
      address player1 = allGames[_DilemmaID].player1;
      address player2 = allGames[_DilemmaID].player2;
      if (allGames[_DilemmaID].players[player1].isRevealed == true) {
        // if player1 isComitted and not player 2
        allGames[_DilemmaID].balances[allGames[DilemmaID].player1] += allGames[_DilemmaID].balances[player2];
        allGames[_DilemmaID].balances[allGames[DilemmaID].player2] = 0;
      } else {
        // if player2 comitted and not player1
        allGames[_DilemmaID].balances[allGames[DilemmaID].player2] += allGames[_DilemmaID].balances[player1];
        allGames[_DilemmaID].balances[allGames[DilemmaID].player2] = 0;
      }
    }
  }


  function withdraw (uint _DilemmaID) checkState (_DilemmaID, Stage.Withdraw) {
    uint amount = allGames[_DilemmaID].balances[msg.sender];
    allGames[_DilemmaID].balances[msg.sender] = 0;
    msg.sender.transfer(amount);
  }


  // find the penalties to each player for each arrangement
  function createBoard (uint [] prices, uint _DilemmaID, address _player1, address _player2) internal {
    // (1,1)
    allGames[_DilemmaID].penalty[_player1][1][1] = prices[1];
    allGames[_DilemmaID].penalty[_player2][1][1] = prices[1];
    // (1,0)
    allGames[_DilemmaID].penalty[_player1][1][0] = prices[0];
    allGames[_DilemmaID].penalty[_player2][1][0] = prices[3];
    // (0,1)
    allGames[_DilemmaID].penalty[_player1][0][1] = prices[3];
    allGames[_DilemmaID].penalty[_player2][0][1] = prices[0];
    // (0,0)
    allGames[_DilemmaID].penalty[_player1][0][0] = prices[2];
    allGames[_DilemmaID].penalty[_player2][0][0] = prices[2];
  }

  function MultiplePrisonersDilemma() public {}

}
