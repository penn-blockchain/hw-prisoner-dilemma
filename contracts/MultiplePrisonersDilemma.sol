pragma solidity ^0.4.17;

contract MultiplePrisonersDilemma {

  uint COLLAB = 1;
  uint DEFECT = 2;

  uint delimmaNum;

  struct Prisoner {
    bytes32 commitment;
    uint action;
  }

  struct Dilemma {
    uint creationTime;
    uint endCommit;
    uint endReveal;

    uint collabPayout;
    uint defectPayout;
    uint splitPayoutHigh;
    uint splitPayoutLow;

    address warden;
    bool wardenPayed;

    address prisonerOne;
    address prisonerTwo;

    mapping(address => Prisoner) prisoners;

    mapping (address => bool) paid;

    uint totalValue;
  }

  mapping (uint => Dilemma) delimmas;


  modifier onlyCommit(uint delimma) {
    require(now < delimmas[delimma].endCommit);
    _;
  }

  modifier onlyReveal(uint delimma) {
    require(now > delimmas[delimma].endCommit && now < delimmas[delimma].endReveal);
    _;
  }

  modifier onlyWithdraw(uint delimma) {
    require(now > delimmas[delimma].endReveal);
    _;
  }

  modifier onlyWarden(uint delimma) {
    require(msg.sender == delimmas[delimma].warden);
    _;
  }

  modifier onlyPrisoners(uint delimma) {
    require(msg.sender == delimmas[delimma].prisonerOne || msg.sender == delimmas[delimma].prisonerTwo);
    _;
  }

  function MultiplePrisonersDilemma() public {}

  function createDilemma(
      address _prisonerOne,
      address _prisonerTwo,
      uint _timeUntilEndCommit,
      uint _timeUntilEndReveal,
      uint _collabPayout,
      uint _defectPayout,
      uint _splitPayoutHigh,
      uint _splitPayoutLow
  ) payable public returns (uint) {
    //sanity check
    require(_timeUntilEndCommit < _timeUntilEndReveal);

    // save addresses
    delimmas[delimmaNum].warden = msg.sender;
    delimmas[delimmaNum].prisonerOne = _prisonerOne;
    delimmas[delimmaNum].prisonerTwo = _prisonerTwo;

    // setup timeouts
    delimmas[delimmaNum].creationTime = now;
    delimmas[delimmaNum].endCommit = now + _timeUntilEndCommit;
    delimmas[delimmaNum].endReveal = now + _timeUntilEndReveal;

    // payouts
    delimmas[delimmaNum].collabPayout = _collabPayout;
    delimmas[delimmaNum].defectPayout = _defectPayout;
    delimmas[delimmaNum].splitPayoutHigh = _splitPayoutHigh;
    delimmas[delimmaNum].splitPayoutLow = _splitPayoutLow;

    // save amount sent
    delimmas[delimmaNum].totalValue = msg.value;

    require (2 * _collabPayout <= msg.value);
    delimmaNum++;
    return delimmaNum - 1;
  }

  function commit(uint delimmaID, bytes32 commitment) public onlyCommit(delimmaID) onlyPrisoners(delimmaID) {
    require(delimmas[delimmaID].prisoners[msg.sender].commitment == bytes32(0));
    delimmas[delimmaID].prisoners[msg.sender].commitment = commitment;
  }

  function reveal(uint delimmaID, uint salt, uint action) public onlyReveal(delimmaID) onlyPrisoners(delimmaID) {
    require(keccak256(salt, action) == delimmas[delimmaID].prisoners[msg.sender].commitment);
    require(validAction(action));
    delimmas[delimmaID].prisoners[msg.sender].action = action;
  }

  function withdraw(uint delimmaID) public onlyWithdraw(delimmaID) {
    require(!delimmas[delimmaID].paid[msg.sender]);
    uint payout = getPayout(delimmaID);
    msg.sender.transfer(payout);
    delimmas[delimmaID].paid[msg.sender] = true;
  }

  function getPayout(uint delimmaID) public constant returns (uint) {
    if (msg.sender == delimmas[delimmaID].warden) {
      return getWardenPayout(delimmaID);
    } else if (msg.sender == delimmas[delimmaID].prisonerOne || msg.sender == delimmas[delimmaID].prisonerTwo) {
      return getPrisonerPayout(delimmaID, msg.sender);
    } else {
      return 0;
    }
  }

  function getWardenPayout(uint delimmaID) public constant returns (uint) {
    uint toPay = 0;

    if (!delimmas[delimmaID].paid[delimmas[delimmaID].prisonerOne]) {
      toPay += getPrisonerPayout(delimmaID, delimmas[delimmaID].prisonerOne);
    }

    if (!delimmas[delimmaID].paid[delimmas[delimmaID].prisonerTwo]) {
      toPay += getPrisonerPayout(delimmaID, delimmas[delimmaID].prisonerTwo);
    }

    return delimmas[delimmaID].totalValue - toPay;
  }

  function getPrisonerPayout(uint delimmaID, address prisoner) public constant returns (uint) {
    require (prisoner == delimmas[delimmaID].prisonerOne || prisoner == delimmas[delimmaID].prisonerTwo);

    uint myAction = delimmas[delimmaID].prisoners[prisoner].action;

    if (!validAction(myAction)) {
      return 0;
    }

    uint otherAction = 0;

    if (prisoner == delimmas[delimmaID].prisonerOne) {
      otherAction = delimmas[delimmaID].prisoners[delimmas[delimmaID].prisonerTwo].action;
    } else if (prisoner == delimmas[delimmaID].prisonerTwo) {
      otherAction = delimmas[delimmaID].prisoners[delimmas[delimmaID].prisonerTwo].action;
    }

    if (!validAction(otherAction)) {
      return delimmas[delimmaID].splitPayoutHigh; // or maybe something else!
    }

    if (myAction == COLLAB && otherAction == COLLAB) {
      return delimmas[delimmaID].collabPayout;
    } else if (myAction == DEFECT && otherAction == DEFECT) {
      return delimmas[delimmaID].defectPayout;
    } else if (myAction == DEFECT) {
      return delimmas[delimmaID].splitPayoutHigh;
    } else {
      return delimmas[delimmaID].splitPayoutLow;
    }
  }

  function validAction(uint action) public constant returns (bool) {
    require (action == COLLAB || action == DEFECT);
  }
}
