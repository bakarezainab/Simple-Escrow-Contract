// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// A simple escrow contract where a buyer can deposit funds and the seller can withdraw them after the buyer approves the transaction.
contract SimpleEscrow {
    address public buyer;
    address public seller;
    address public arbiter;
    
    uint256 public amount;
    bool public isApproved;
    bool public isDisputed;
    bool public isResolved;
    
    event Deposited(address indexed buyer, uint256 amount);
    event Approved(address indexed buyer, address indexed seller, uint256 amount);
    event Disputed(address indexed buyer, address indexed seller, uint256 amount);
    event Resolved(address indexed arbiter, address indexed recipient, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);
    
    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }
    
    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }
    
    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this function");
        _;
    }
    
    modifier notResolved() {
        require(!isResolved, "Escrow is already resolved");
        _;
    }
    
    
    // arbiter (or arbitrator) is a trusted third party who has the authority to resolve disputes and decide the outcome if the buyer and seller disagree
    constructor(address _seller, address _arbiter) payable {
        require(_seller != address(0), "Invalid seller address");
        require(_arbiter != address(0), "Invalid arbiter address");
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
        amount = msg.value;
        
        emit Deposited(buyer, amount);
    }
    
    // ......................Approves the transaction and transfers funds to the seller................
    function approve() external onlyBuyer notResolved {
        isApproved = true;
        isResolved = true;
        
        emit Approved(buyer, seller, amount);
        
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer to seller failed");
    }
    
    //....................Raises a dispute that needs to be resolved by the arbiter..................
    function dispute() external onlyBuyer notResolved {
        isDisputed = true;
        
        emit Disputed(buyer, seller, amount);
    }
    
    /**
     * @dev Resolves a dispute by transferring funds to the specified recipient
     * @param recipient Address to receive the funds (either buyer or seller)
     */
    function resolveDispute(address payable recipient) external onlyArbiter notResolved {
        require(isDisputed, "No active dispute");
        require(recipient == buyer || recipient == seller, "Recipient must be buyer or seller");
        
        isResolved = true;
        
        emit Resolved(arbiter, recipient, amount);
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer to recipient failed");
    }
    
    /**
     * @dev Allows the buyer to get a refund if the transaction hasn't been approved yet
     * This is a safety mechanism if the seller becomes unresponsive
     */
    function refund() external onlyBuyer notResolved {
        require(!isApproved, "Transaction already approved");
        
        isResolved = true;
        
        emit Refunded(buyer, amount);
        
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Refund to buyer failed");
    }
}