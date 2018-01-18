pragma solidity ^0.4.17;

contract SinglePrisonersDilemma {

  uint COLLAB = 1;
  uint DEFECT = 2;

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

  struct Prisoner {
    bytes32 commitment;
    uint action;
  }

  mapping(address => bool) paid;

  mapping (address => Prisoner) prisoners;

  modifier onlyCommit() {
    require(now < endCommit);
    _;
  }

  modifier onlyReveal() {
    require(now > endCommit && now < endReveal);
    _;
  }

  modifier onlyWithdraw() {
    require(now > endReveal);
    _;
  }

  modifier onlyWarden() {
    require(msg.sender == warden);
    _;
  }

  modifier onlyPrisoners() {
    require(msg.sender == prisonerOne || msg.sender == prisonerTwo);
    _;
  }

  function SinglePrisonersDilemma(
      address _prisonerOne,
      address _prisonerTwo,
      uint _timeUntilEndCommit,
      uint _timeUntilEndReveal,
      uint _collabPayout,
      uint _defectPayout,
      uint _splitPayoutHigh,
      uint _splitPayoutLow
  ) payable public {
    // sanity check
    require (_timeUntilEndCommit < _timeUntilEndReveal);

    // save addresses
    warden = msg.sender;
    prisonerOne = _prisonerOne;
    prisonerTwo = _prisonerTwo;

    // setup timeouts
    creationTime = now;
    endCommit = now + _timeUntilEndCommit;
    endReveal = now + _timeUntilEndReveal;

    // payments
    collabPayout =  _collabPayout;
    defectPayout = _defectPayout;
    splitPayoutHigh = _splitPayoutHigh;
    splitPayoutLow = _splitPayoutLow;

    require (2 * collabPayout <= msg.value);
  }

  function commit(bytes32 commitment) public onlyCommit onlyPrisoners {
    require(prisoners[msg.sender].commitment == bytes32(0));
    prisoners[msg.sender].commitment = commitment;
  }

  function reveal(uint salt, uint action) public onlyReveal onlyPrisoners {
    require(keccak256(salt, action) == prisoners[msg.sender].commitment);
    require(validAction(action));
    prisoners[msg.sender].action = action;
  }

  function withdraw() public onlyWithdraw {
    require(!paid[msg.sender]);
    uint payout = getPayout();
    msg.sender.transfer(payout);
    paid[msg.sender] = true;
  }

  function getPayout() public constant returns (uint) {
    if (msg.sender == warden) {
      return getWardenPayout();
    } else if (msg.sender == prisonerOne || msg.sender == prisonerTwo) {
      return getPrisonerPayout(msg.sender);
    } else {
      return 0;
    }
  }

  function getWardenPayout() public constant returns (uint) {
    uint toPay = 0;

    if (!paid[prisonerOne]) {
      toPay += getPrisonerPayout(prisonerOne);
    }

    if (!paid[prisonerTwo]) {
      toPay += getPrisonerPayout(prisonerTwo);
    }

    return this.balance - toPay;
  }

  function getPrisonerPayout(address prisoner) public constant returns (uint) {
    require (prisoner == prisonerOne || prisoner == prisonerTwo);

    uint myAction = prisoners[prisoner].action;

    if (!validAction(myAction)) {
      return 0;
    }

    uint otherAction = 0;

    if (prisoner == prisonerOne) {
      otherAction = prisoners[prisonerTwo].action;
    } else if (prisoner == prisonerTwo) {
      otherAction = prisoners[prisonerTwo].action;
    }

    if (!validAction(otherAction)) {
      return splitPayoutHigh; // or maybe something else!
    }

    if (myAction == COLLAB && otherAction == COLLAB) {
      return collabPayout;
    } else if (myAction == DEFECT && otherAction == DEFECT) {
      return defectPayout;
    } else if (myAction == DEFECT) {
      return splitPayoutHigh;
    } else {
      return splitPayoutLow;
    }
  }

  function validAction(uint action) public constant returns (bool) {
    require (action == COLLAB || action == DEFECT);
  }

}
