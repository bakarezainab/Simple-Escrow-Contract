// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleEscrow.sol";

contract SimpleEscrowFuzzTest is Test {
    SimpleEscrow escrow;
    
    address buyer = address(1);
    address seller = address(2);
    address arbiter = address(3);
    
    function setUp() public {
        vm.deal(buyer, 100 ether); // Give buyer a large amount of ETH for fuzz tests
    }
    
    function testFuzz_Constructor(uint256 _depositAmount) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.amount(), _depositAmount);
        assertEq(address(escrow).balance, _depositAmount);
    }
    
    function testFuzz_ConstructorRevertsWithZeroAmount() public {
        vm.prank(buyer);
        vm.expectRevert("Deposit amount must be greater than 0");
        escrow = new SimpleEscrow{value: 0}(seller, arbiter);
    }
    
    function testFuzz_ConstructorRevertsWithZeroAddresses(address _seller, address _arbiter) public {
        vm.assume(_seller != address(0) && _arbiter != address(0));
        
        vm.prank(buyer);
        // Should work with valid addresses
        escrow = new SimpleEscrow{value: 1 ether}(_seller, _arbiter);
        
        vm.prank(buyer);
        // Should fail with zero seller address
        vm.expectRevert("Invalid seller address");
        escrow = new SimpleEscrow{value: 1 ether}(address(0), _arbiter);
        
        vm.prank(buyer);
        // Should fail with zero arbiter address
        vm.expectRevert("Invalid arbiter address");
        escrow = new SimpleEscrow{value: 1 ether}(_seller, address(0));
    }
    
    function testFuzz_ApproveTransfer(uint256 _depositAmount) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        uint256 sellerBalanceBefore = seller.balance;
        
        vm.prank(buyer);
        escrow.approve();
        
        assertEq(seller.balance, sellerBalanceBefore + _depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isApproved(), true);
        assertEq(escrow.isResolved(), true);
    }
    
    function testFuzz_Dispute(uint256 _depositAmount) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        vm.prank(buyer);
        escrow.dispute();
        
        assertEq(escrow.isDisputed(), true);
        assertEq(escrow.isResolved(), false);
        assertEq(address(escrow).balance, _depositAmount);
    }
    
    function testFuzz_ResolveDispute(
        uint256 _depositAmount, 
        bool _resolveToSeller
    ) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        // Create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        uint256 buyerBalanceBefore = buyer.balance;
        uint256 sellerBalanceBefore = seller.balance;
        
        // Resolve the dispute
        vm.prank(arbiter);
        if (_resolveToSeller) {
            escrow.resolveDispute(payable(seller));
            assertEq(seller.balance, sellerBalanceBefore + _depositAmount);
            assertEq(buyer.balance, buyerBalanceBefore);
        } else {
            escrow.resolveDispute(payable(buyer));
            assertEq(buyer.balance, buyerBalanceBefore + _depositAmount);
            assertEq(seller.balance, sellerBalanceBefore);
        }
        
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testFuzz_Refund(uint256 _depositAmount) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        uint256 buyerBalanceBefore = buyer.balance;
        
        vm.prank(buyer);
        escrow.refund();
        
        assertEq(buyer.balance, buyerBalanceBefore + _depositAmount);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testFuzz_DisputeScenarios(
        uint256 _depositAmount,
        uint8 _scenario
    ) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        // Track balances before
        uint256 buyerBalanceBefore = buyer.balance;
        uint256 sellerBalanceBefore = seller.balance;
        
        // Four possible scenarios:
        // 0: Buyer approves, seller gets funds
        // 1: Buyer disputes, arbiter resolves to seller
        // 2: Buyer disputes, arbiter resolves to buyer
        // 3: Buyer gets refund
        
        _scenario = _scenario % 4; // Ensure scenario is within range
        
        if (_scenario == 0) {
            vm.prank(buyer);
            escrow.approve();
            
            assertEq(seller.balance, sellerBalanceBefore + _depositAmount);
            assertEq(buyer.balance, buyerBalanceBefore);
            assertEq(escrow.isApproved(), true);
        } 
        else if (_scenario == 1) {
            vm.prank(buyer);
            escrow.dispute();
            
            vm.prank(arbiter);
            escrow.resolveDispute(payable(seller));
            
            assertEq(seller.balance, sellerBalanceBefore + _depositAmount);
            assertEq(buyer.balance, buyerBalanceBefore);
            assertEq(escrow.isDisputed(), true);
        }
        else if (_scenario == 2) {
            vm.prank(buyer);
            escrow.dispute();
            
            vm.prank(arbiter);
            escrow.resolveDispute(payable(buyer));
            
            assertEq(seller.balance, sellerBalanceBefore);
            assertEq(buyer.balance, buyerBalanceBefore + _depositAmount);
            assertEq(escrow.isDisputed(), true);
        }
        else { // _scenario == 3
            vm.prank(buyer);
            escrow.refund();
            
            assertEq(seller.balance, sellerBalanceBefore);
            assertEq(buyer.balance, buyerBalanceBefore + _depositAmount);
        }
        
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.isResolved(), true);
    }
    
    function testFuzz_MultipleDisputeAttempts(uint256 _depositAmount) public {
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        // First dispute succeeds
        vm.prank(buyer);
        escrow.dispute();
        assertEq(escrow.isDisputed(), true);
        
        // Resolve the dispute
        vm.prank(arbiter);
        escrow.resolveDispute(payable(seller));
        assertEq(escrow.isResolved(), true);
        
        // Try to dispute again after resolution
        vm.prank(buyer);
        vm.expectRevert("Escrow is already resolved");
        escrow.dispute();
    }
    
    function testFuzz_InvalidResolveDispute(
        uint256 _depositAmount,
        address _invalidRecipient
    ) public {
        // Ensure _invalidRecipient is neither buyer nor seller
        vm.assume(_invalidRecipient != buyer && _invalidRecipient != seller && _invalidRecipient != address(0));
        
        // Bound the input to reasonable values (1 wei to 10 ether)
        _depositAmount = bound(_depositAmount, 1, 10 ether);
        
        vm.prank(buyer);
        escrow = new SimpleEscrow{value: _depositAmount}(seller, arbiter);
        
        // Create a dispute
        vm.prank(buyer);
        escrow.dispute();
        
        // Try to resolve with invalid recipient
        vm.prank(arbiter);
        vm.expectRevert("Recipient must be buyer or seller");
        escrow.resolveDispute(payable(_invalidRecipient));
    }
}