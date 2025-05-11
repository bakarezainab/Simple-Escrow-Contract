// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleEscrow.sol";

contract SimpleEscrowTest is Test {
    SimpleEscrow escrow;
    
    address buyer = address(1);
    address seller = address(2);
    address arbiter = address(3);
    uint256 depositAmount = 1 ether;
    
    event Deposited(address indexed buyer, uint256 amount);
    event Approved(address indexed buyer, address indexed seller, uint256 amount);
    event Disputed(address indexed buyer, address indexed seller, uint256 amount);
    event Resolved(address indexed arbiter, address indexed recipient, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);
    
    function setUp() public {
        vm.deal(buyer, 10 ether); // Give buyer some ETH to use
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: depositAmount}(seller, arbiter);
    }
    
    function testInitialState() public {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.amount(), depositAmount);
        assertEq(escrow.isApproved(), false);
        assertEq(escrow.isDisputed(), false);
        assertEq(escrow.isResolved(), false);
        assertEq(address(escrow).balance, depositAmount);
    }
    
    function testApproveTransfer() public {
        uint256 sellerBalanceBefore = seller.balance;
        
        vm.prank(buyer);
        vm.expectEmit(true, true, false, true);
        emit Approved(buyer, seller, depositAmount);
        escrow.approve();
        
        assertEq(seller.balance, sellerBalanceBefore + depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isApproved(), true);
        assertEq(escrow.isResolved(), true);
    }
    
    function testApproveFailsWhenNotBuyer() public {
        vm.prank(seller);
        vm.expectRevert("Only buyer can call this function");
        escrow.approve();
        
        vm.prank(arbiter);
        vm.expectRevert("Only buyer can call this function");
        escrow.approve();
    }
    
    function testDispute() public {
        vm.prank(buyer);
        vm.expectEmit(true, true, false, true);
        emit Disputed(buyer, seller, depositAmount);
        escrow.dispute();
        
        assertEq(escrow.isDisputed(), true);
        assertEq(escrow.isResolved(), false);
        assertEq(address(escrow).balance, depositAmount);
    }
    
    function testDisputeFailsWhenNotBuyer() public {
        vm.prank(seller);
        vm.expectRevert("Only buyer can call this function");
        escrow.dispute();
        
        vm.prank(arbiter);
        vm.expectRevert("Only buyer can call this function");
        escrow.dispute();
    }
    
    function testResolveDisputeToSeller() public {
        // First create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        uint256 sellerBalanceBefore = seller.balance;
        
        // Resolve the dispute in favor of the seller
        vm.prank(arbiter);
        vm.expectEmit(true, true, false, true);
        emit Resolved(arbiter, seller, depositAmount);
        escrow.resolveDispute(payable(seller));
        
        assertEq(seller.balance, sellerBalanceBefore + depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testResolveDisputeToBuyer() public {
        // First create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        uint256 buyerBalanceBefore = buyer.balance;
        
        // Resolve the dispute in favor of the buyer
        vm.prank(arbiter);
        vm.expectEmit(true, true, false, true);
        emit Resolved(arbiter, buyer, depositAmount);
        escrow.resolveDispute(payable(buyer));
        
        assertEq(buyer.balance, buyerBalanceBefore + depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testResolveDisputeFailsWhenNoDispute() public {
        vm.prank(arbiter);
        vm.expectRevert("No active dispute");
        escrow.resolveDispute(payable(seller));
    }
    
    function testResolveDisputeFailsWhenNotArbiter() public {
        // First create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        vm.prank(buyer);
        vm.expectRevert("Only arbiter can call this function");
        escrow.resolveDispute(payable(seller));
        
        vm.prank(seller);
        vm.expectRevert("Only arbiter can call this function");
        escrow.resolveDispute(payable(seller));
    }
    
    function testResolveDisputeFailsWithInvalidRecipient() public {
        // First create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        address invalidRecipient = address(4);
        
        vm.prank(arbiter);
        vm.expectRevert("Recipient must be buyer or seller");
        escrow.resolveDispute(payable(invalidRecipient));
    }
    
    function testRefund() public {
        uint256 buyerBalanceBefore = buyer.balance;
        
        vm.prank(buyer);
        vm.expectEmit(true, false, false, true);
        emit Refunded(buyer, depositAmount);
        escrow.refund();
        
        assertEq(buyer.balance, buyerBalanceBefore + depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testRefundFailsWhenNotBuyer() public {
        vm.prank(seller);
        vm.expectRevert("Only buyer can call this function");
        escrow.refund();
        
        vm.prank(arbiter);
        vm.expectRevert("Only buyer can call this function");
        escrow.refund();
    }
    
    function testRefundFailsAfterApproval() public {
        vm.prank(buyer);
        escrow.approve();
        
        vm.prank(buyer);
        vm.expectRevert("Escrow is already resolved");
        escrow.refund();
    }
    
    function testCannotCallFunctionsAfterResolution() public {
        // Resolve the escrow by approving the transaction
        vm.prank(buyer);
        escrow.approve();
        
        // Try to call functions after resolution
        vm.prank(buyer);
        vm.expectRevert("Escrow is already resolved");
        escrow.dispute();
        
        vm.prank(arbiter);
        vm.expectRevert("Escrow is already resolved");
        escrow.resolveDispute(payable(seller));
        
        vm.prank(buyer);
        vm.expectRevert("Escrow is already resolved");
        escrow.refund();
    }
}