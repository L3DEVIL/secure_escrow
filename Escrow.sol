// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract SecureEscrow {
    address public escrowAgent;
    uint public collectedFees;
    uint private tradeCounter;
    uint public feePercentage = 2;
    bool public paused = false;

    enum State { AWAITING_COLLATERAL, AWAITING_DELIVERY, COMPLETE, REFUNDED }

    struct Trade {
        address buyer;
        address payable seller;
        uint amount;
        uint collateral;
        bool buyerApproved;
        bool sellerApproved;
        bool collateralProvided;
        State currentState;
    }

    mapping(uint => Trade) public trades;

    event TradeCreated(uint tradeID, address buyer, address seller, uint amount, uint collateral);
    event FundsReleased(uint tradeID, address recipient, uint amount);

    constructor() {
        escrowAgent = msg.sender;
        tradeCounter = 0;
    }

    modifier onlyEscrowAgent() {
        require(msg.sender == escrowAgent, "Only escrow agent can call this.");
        _;
    }

    modifier onlyBuyer(uint tradeID) {
        require(msg.sender == trades[tradeID].buyer, "Only buyer can call this.");
        _;
    }

    modifier onlySeller(uint tradeID) {
        require(msg.sender == trades[tradeID].seller, "Only seller can call this.");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused.");
        _;
    }

    modifier validTradeID(uint tradeID) {
        require(trades[tradeID].buyer != address(0), "Invalid trade ID.");
        _;
    }

    modifier nonReentrant() {
        require(!reentrancyLock, "Reentrant call detected");
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    bool private reentrancyLock = false;

    function createTrade(address payable _seller) external payable whenNotPaused returns (uint) {
        uint _amount = msg.value;
        require(_amount > 0, "Amount must be greater than zero.");

        tradeCounter++;
        uint fee = (_amount * feePercentage) / 100;
        uint amountAfterFee = _amount - fee;
        uint _collateral = (amountAfterFee * 5) / 100;

        trades[tradeCounter] = Trade({
            buyer: msg.sender,
            seller: _seller,
            amount: amountAfterFee,
            collateral: _collateral,
            buyerApproved: false,
            sellerApproved: false,
            collateralProvided: false,
            currentState: State.AWAITING_COLLATERAL
        });

        collectedFees += fee;

        emit TradeCreated(tradeCounter, msg.sender, _seller, amountAfterFee, _collateral);
        return tradeCounter;
    }

    function depositCollateral(uint tradeID, bool _preApprove) external payable onlySeller(tradeID) validTradeID(tradeID) whenNotPaused nonReentrant {
        Trade storage trade = trades[tradeID];
        require(trade.currentState == State.AWAITING_COLLATERAL, "Collateral not needed at this stage.");
        require(msg.value == trade.collateral, "Incorrect collateral amount sent.");
        require(!trade.collateralProvided, "Collateral already provided.");

        trade.collateralProvided = true;
        trade.sellerApproved = _preApprove;
        trade.currentState = State.AWAITING_DELIVERY;
    }

    function approve(uint tradeID) external validTradeID(tradeID) whenNotPaused nonReentrant {
        Trade storage trade = trades[tradeID];
        require(trade.currentState == State.AWAITING_DELIVERY, "Not in a state to approve.");

        if (msg.sender == trade.buyer) {
            trade.buyerApproved = true;
        } else if (msg.sender == trade.seller) {
            trade.sellerApproved = true;
        }

        if (trade.buyerApproved && trade.sellerApproved) {
            releaseFunds(tradeID);
        }
    }

    function releaseFunds(uint tradeID) internal validTradeID(tradeID) whenNotPaused {
        Trade storage trade = trades[tradeID];
        require(trade.currentState == State.AWAITING_DELIVERY, "Trade not ready for funds release.");

        uint sellerAmount = trade.amount;
        trade.currentState = State.COMPLETE;
        trade.seller.transfer(sellerAmount + trade.collateral);

        emit FundsReleased(tradeID, trade.seller, sellerAmount + trade.collateral);
    }

    function refundBuyer(uint tradeID) external onlyBuyer(tradeID) validTradeID(tradeID) whenNotPaused nonReentrant {
        Trade storage trade = trades[tradeID];
        require(trade.currentState == State.AWAITING_COLLATERAL, "Cannot refund at this stage.");
        require(!trade.collateralProvided, "Seller has already provided collateral.");

        uint refundAmount = trade.amount;
        trade.currentState = State.REFUNDED;
        payable(trade.buyer).transfer(refundAmount);
    }

    function directRelease(uint tradeID, address payable recipient) external onlyEscrowAgent validTradeID(tradeID) whenNotPaused nonReentrant {
        Trade storage trade = trades[tradeID];
        require(trade.currentState == State.AWAITING_COLLATERAL, "Cannot release funds at this stage.");

        uint amountAfterFee = trade.amount;  // Full amount after fee deduction

        recipient.transfer(amountAfterFee);
        if (recipient == trade.buyer) {
            trade.currentState = State.REFUNDED;
        } else {
            trade.currentState = State.COMPLETE;
        }
        emit FundsReleased(tradeID, recipient, amountAfterFee);
    }


    function getTradeDetails(uint tradeID) external view validTradeID(tradeID) returns (
        address buyer,
        address payable seller,
        uint amount,
        uint collateral,
        bool buyerApproved,
        bool sellerApproved,
        bool collateralProvided,
        State currentState
    ) {
        Trade storage trade = trades[tradeID];
        return (
            trade.buyer,
            trade.seller,
            trade.amount,
            trade.collateral,
            trade.buyerApproved,
            trade.sellerApproved,
            trade.collateralProvided,
            trade.currentState
        );
    }

    function redeemFees() external onlyEscrowAgent whenNotPaused nonReentrant {
        require(collectedFees > 0, "No fees to redeem.");
        uint feesToTransfer = collectedFees;
        collectedFees = 0;
        payable(escrowAgent).transfer(feesToTransfer);
    }

    function setEscrowAgent(address _newEscrowAgent) external onlyEscrowAgent {
        require(_newEscrowAgent != address(0), "Invalid escrow agent address.");
        escrowAgent = _newEscrowAgent;
    }
    function getEscrowAgent() external view returns (address) {
        return escrowAgent;
    }

    function setFeePercentage(uint _newFeePercentage) external onlyEscrowAgent {
        require(_newFeePercentage <= 10, "Fee percentage cannot exceed 10%");
        feePercentage = _newFeePercentage;
    }
    function getFeePercentage() external view returns (uint) {
        return feePercentage;
    }

    function setPaused(bool _paused) external onlyEscrowAgent {
        paused = _paused;
    }
}
