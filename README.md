# SimpleEscrow Contract
The escrow contract facilitates secure transactions between a buyer and seller with an arbiter for dispute resolution:

Participants: Buyer (initiates and funds), Seller (receives funds), Arbiter (resolves disputes)
###Key Features:

Buyer deposits funds during contract creation
Buyer can approve the transaction to release funds to seller
Buyer can raise disputes that an arbiter can resolve
Buyer can get a refund if needed
Proper state tracking with isApproved, isDisputed, and isResolved flags


### Unit Tests (SimpleEscrowTest.sol)

Tests all contract functions with specific inputs
Verifies correct state transitions
Tests access control (only specific roles can call certain functions)
Tests proper event emissions
Verifies proper revert conditions

### Fuzz Tests (SimpleEscrowFuzzTest.sol)
# Kindly check the test-images to check the passed tests
Tests with randomized inputs to find edge cases
Uses bound() function to keep test values reasonable
Tests various scenarios with randomized deposit amounts
Tests interaction sequences and failure conditions
Combines multiple functions to test complex scenarios