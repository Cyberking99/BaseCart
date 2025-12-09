// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {BaseCartStore} from "../src/BaseCartStore.sol";
import {BaseCartFactory} from "../src/BaseCartFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title BaseCartStore Test Suite
 * @dev Comprehensive tests for BaseCartStore functions
 */
contract BaseCartStoreTest is Test {
    BaseCartFactory public factory;
    BaseCartStore public store;
    ERC20Mock public paymentToken;

    address public owner;
    address public buyer;
    address public otherUser;

    string public constant STORE_NAME = "Test Store";
    string public constant STORE_URL = "test-store";
    string public constant STORE_DESCRIPTION = "A test store";

    event OrderStatusUpdated(uint256 indexed orderId, BaseCartStore.OrderStatus status);
    event RevenueSplitAdded(uint256 indexed productId, address recipient, uint256 percentage);
    event RevenueSplitRemoved(uint256 indexed productId, address recipient);
    event FundsWithdrawn(address indexed recipient, address token, uint256 amount);
    event EscrowReleased(uint256 indexed orderId, address indexed buyer, uint256 amount);
    event EscrowRefunded(uint256 indexed orderId, address indexed buyer, uint256 amount);

    function setUp() public {
        // Setup accounts
        owner = address(0x1);
        buyer = address(0x2);
        otherUser = address(0x3);

        // Deploy factory
        vm.prank(owner);
        factory = new BaseCartFactory();

        // Deploy payment token
        paymentToken = new ERC20Mock();

        // Add payment token as supported
        vm.prank(owner);
        factory.addSupportedToken(address(paymentToken));

        // Create store
        vm.prank(owner);
        address storeAddress = factory.createStore(STORE_NAME, STORE_URL, STORE_DESCRIPTION);
        store = BaseCartStore(storeAddress);
    }

    // ============ markOrderShipped() TESTS ============

    /**
     * @dev Test successful marking of order as shipped from Paid status
     */
    function test_MarkOrderShipped_Success_FromPaidStatus() public {
        vm.startPrank(owner);

        // Create a physical product
        uint256 productId = store.addProduct(
            "Physical Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            50     // inventory
        );
        vm.stopPrank();

        // Create order and process payment (non-escrow)
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify order is in Paid status
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Paid), "Order should be Paid");

        // Mark as shipped
        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Shipped);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Verify order status changed to Shipped
        (,,,,,, status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Shipped), "Order should be Shipped");
    }

    /**
     * @dev Test successful marking of order as shipped from InEscrow status
     */
    function test_MarkOrderShipped_Success_FromInEscrowStatus() public {
        vm.startPrank(owner);

        // Create a physical product
        uint256 productId = store.addProduct(
            "Physical Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            50     // inventory
        );
        vm.stopPrank();

        // Create order with escrow and process payment
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify order is in InEscrow status
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.InEscrow), "Order should be InEscrow");

        // Mark as shipped
        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Shipped);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Verify order status changed to Shipped
        (,,,,,, status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Shipped), "Order should be Shipped");
    }

    /**
     * @dev Test that OrderStatusUpdated event is emitted
     */
    function test_MarkOrderShipped_EmitsOrderStatusUpdatedEvent() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Shipped);

        vm.prank(owner);
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test that multiple orders can be marked as shipped
     */
    function test_MarkOrderShipped_Success_MultipleOrders() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 100);
        vm.stopPrank();

        // Create and pay for multiple orders
        paymentToken.mint(buyer, 5000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 5000 ether);

        uint256 orderId1;
        uint256 orderId2;
        uint256 orderId3;

        vm.prank(buyer);
        orderId1 = store.createOrder(productId, 1, false);
        vm.prank(buyer);
        store.processPayment(orderId1);

        vm.prank(buyer);
        orderId2 = store.createOrder(productId, 2, false);
        vm.prank(buyer);
        store.processPayment(orderId2);

        vm.prank(buyer);
        orderId3 = store.createOrder(productId, 3, true); // Escrow order
        vm.prank(buyer);
        store.processPayment(orderId3);

        // Mark all as shipped
        vm.startPrank(owner);
        store.markOrderShipped(orderId1);
        store.markOrderShipped(orderId2);
        store.markOrderShipped(orderId3);
        vm.stopPrank();

        // Verify all orders are shipped
        (,,,,,, BaseCartStore.OrderStatus status1,,) = _getOrder(orderId1);
        (,,,,,, BaseCartStore.OrderStatus status2,,) = _getOrder(orderId2);
        (,,,,,, BaseCartStore.OrderStatus status3,,) = _getOrder(orderId3);

        assertEq(uint256(status1), uint256(BaseCartStore.OrderStatus.Shipped), "Order 1 should be Shipped");
        assertEq(uint256(status2), uint256(BaseCartStore.OrderStatus.Shipped), "Order 2 should be Shipped");
        assertEq(uint256(status3), uint256(BaseCartStore.OrderStatus.Shipped), "Order 3 should be Shipped");
    }

    // ============ markOrderShipped() REVERT CASES ============

    /**
     * @dev Test revert when order ID is invalid (zero)
     */
    function test_MarkOrderShipped_Revert_InvalidOrderId_Zero() public {
        vm.prank(owner);
        vm.expectRevert("Invalid order ID");
        store.markOrderShipped(0);
    }

    /**
     * @dev Test revert when order ID is invalid (too high)
     */
    function test_MarkOrderShipped_Revert_InvalidOrderId_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        vm.expectRevert("Invalid order ID");
        store.markOrderShipped(999); // Non-existent order ID
    }

    /**
     * @dev Test revert when order status is not Paid or InEscrow (Pending)
     */
    function test_MarkOrderShipped_Revert_OrderStatusPending() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        // Order is still Pending, not paid
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when order status is already Shipped
     */
    function test_MarkOrderShipped_Revert_OrderAlreadyShipped() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Try to mark as shipped again
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when order status is Cancelled
     */
    function test_MarkOrderShipped_Revert_OrderCancelled() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        // Cancel the order
        vm.prank(buyer);
        store.cancelOrder(orderId);

        // Try to mark cancelled order as shipped
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when order status is Refunded
     * Note: For escrow orders, platform fee is transferred immediately, so we need to
     * add funds to store to cover the full refund amount
     */
    function test_MarkOrderShipped_Revert_OrderRefunded() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create escrow order
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify order is in InEscrow status (needed for refund)
        (,,,,,, BaseCartStore.OrderStatus statusBeforeRefund,,) = _getOrder(orderId);
        assertEq(uint256(statusBeforeRefund), uint256(BaseCartStore.OrderStatus.InEscrow), "Order should be InEscrow");

        // Calculate platform fee that was transferred
        uint256 platformFee = factory.calculatePlatformFee(100 ether);
        
        // Add platform fee back to store so it can refund the full amount
        paymentToken.mint(address(store), platformFee);

        // Refund the order
        vm.prank(owner);
        store.refundOrder(orderId);

        // Verify order is refunded
        (,,,,,, BaseCartStore.OrderStatus statusAfterRefund,,) = _getOrder(orderId);
        assertEq(uint256(statusAfterRefund), uint256(BaseCartStore.OrderStatus.Refunded), "Order should be Refunded");

        // Try to mark refunded order as shipped
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when product is digital
     * Note: Digital products are auto-completed on payment, so status check happens first
     */
    function test_MarkOrderShipped_Revert_DigitalProduct() public {
        vm.startPrank(owner);
        // Create a digital product
        uint256 productId = store.addProduct(
            "Digital Product",
            "Description",
            50 ether,
            address(paymentToken),
            true,  // isDigital
            false,
            10
        );
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Digital products are auto-completed, so status check happens before digital check
        // Try to mark digital product order as shipped
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_MarkOrderShipped_Revert_NotOwner() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Try to mark as shipped as non-owner
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.markOrderShipped(orderId);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_MarkOrderShipped_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Deactivate store
        vm.prank(owner);
        store.setStoreActive(false);

        // Try to mark as shipped when store is inactive
        vm.prank(owner);
        vm.expectRevert("Store is not active");
        store.markOrderShipped(orderId);
    }

    // ============ markOrderShipped() EDGE CASES ============

    /**
     * @dev Test that order can be marked as shipped after store reactivation
     */
    function test_MarkOrderShipped_Success_AfterReactivatingStore() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Deactivate store
        vm.prank(owner);
        store.setStoreActive(false);

        // Try to mark as shipped (should fail)
        vm.prank(owner);
        vm.expectRevert("Store is not active");
        store.markOrderShipped(orderId);

        // Reactivate store
        vm.prank(owner);
        store.setStoreActive(true);

        // Now should succeed
        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Verify order is shipped
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Shipped), "Order should be Shipped");
    }

    /**
     * @dev Test that digital product orders cannot be marked as shipped
     */
    function test_MarkOrderShipped_Revert_CannotShipDigitalProducts() public {
        vm.startPrank(owner);
        // Create digital product with unlimited inventory
        uint256 productId = store.addProduct(
            "Digital Product",
            "Description",
            50 ether,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0
        );
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify order is completed (digital products are auto-completed)
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Completed), "Digital order should be Completed");

        // Try to mark as shipped (should fail even if status allowed it)
        vm.prank(owner);
        vm.expectRevert("Invalid order status");
        store.markOrderShipped(orderId);
    }

    // ============ addRevenueSplit() TESTS ============

    /**
     * @dev Test successful addition of revenue split
     */
    function test_AddRevenueSplit_Success() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient = address(0x100);
        uint256 percentage = 1000; // 10%
        
        vm.expectEmit(true, false, false, true);
        emit RevenueSplitAdded(productId, recipient, percentage);
        
        store.addRevenueSplit(productId, recipient, percentage);
        vm.stopPrank();
        
        // Verify split was added
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 1, "Should have 1 split");
        assertEq(splits[0].recipient, recipient, "Recipient should match");
        assertEq(splits[0].percentage, percentage, "Percentage should match");
    }

    /**
     * @dev Test adding multiple revenue splits
     */
    function test_AddRevenueSplit_Success_MultipleSplits() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient1 = address(0x100);
        address recipient2 = address(0x200);
        address recipient3 = address(0x300);
        
        store.addRevenueSplit(productId, recipient1, 2000); // 20%
        store.addRevenueSplit(productId, recipient2, 3000); // 30%
        store.addRevenueSplit(productId, recipient3, 1500); // 15%
        vm.stopPrank();
        
        // Verify all splits were added
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 3, "Should have 3 splits");
        assertEq(splits[0].recipient, recipient1, "Recipient 1 should match");
        assertEq(splits[1].recipient, recipient2, "Recipient 2 should match");
        assertEq(splits[2].recipient, recipient3, "Recipient 3 should match");
    }

    /**
     * @dev Test adding revenue split that totals exactly 100%
     */
    function test_AddRevenueSplit_Success_Total100Percent() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        store.addRevenueSplit(productId, address(0x100), 5000); // 50%
        store.addRevenueSplit(productId, address(0x200), 5000); // 50% - totals 100%
        vm.stopPrank();
        
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 2, "Should have 2 splits");
    }

    /**
     * @dev Test that RevenueSplitAdded event is emitted
     */
    function test_AddRevenueSplit_EmitsEvent() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient = address(0x100);
        uint256 percentage = 2500; // 25%
        
        vm.expectEmit(true, false, false, true);
        emit RevenueSplitAdded(productId, recipient, percentage);
        
        store.addRevenueSplit(productId, recipient, percentage);
        vm.stopPrank();
    }

    // ============ addRevenueSplit() REVERT CASES ============

    /**
     * @dev Test revert when product ID is zero
     */
    function test_AddRevenueSplit_Revert_InvalidProductId_Zero() public {
        vm.prank(owner);
        vm.expectRevert("Invalid product ID");
        store.addRevenueSplit(0, address(0x100), 1000);
    }

    /**
     * @dev Test revert when product ID is too high
     */
    function test_AddRevenueSplit_Revert_InvalidProductId_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid product ID");
        store.addRevenueSplit(productId + 1, address(0x100), 1000);
    }

    /**
     * @dev Test revert when recipient is zero address
     */
    function test_AddRevenueSplit_Revert_InvalidRecipient() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid recipient address");
        store.addRevenueSplit(productId, address(0), 1000);
    }

    /**
     * @dev Test revert when percentage is zero
     */
    function test_AddRevenueSplit_Revert_InvalidPercentage_Zero() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid percentage");
        store.addRevenueSplit(productId, address(0x100), 0);
    }

    /**
     * @dev Test revert when percentage is >= 10000 (100%)
     */
    function test_AddRevenueSplit_Revert_InvalidPercentage_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid percentage");
        store.addRevenueSplit(productId, address(0x100), 10000);
    }

    /**
     * @dev Test revert when total percentage exceeds 100%
     */
    function test_AddRevenueSplit_Revert_TotalPercentageExceeds100() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        store.addRevenueSplit(productId, address(0x100), 6000); // 60%
        store.addRevenueSplit(productId, address(0x200), 3000); // 30% - total 90%
        
        // Try to add another 20% which would exceed 100%
        vm.expectRevert("Total percentage exceeds 100%");
        store.addRevenueSplit(productId, address(0x300), 2000); // 20%
        vm.stopPrank();
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_AddRevenueSplit_Revert_NotOwner() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.addRevenueSplit(productId, address(0x100), 1000);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_AddRevenueSplit_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        store.setStoreActive(false);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Store is not active");
        store.addRevenueSplit(productId, address(0x100), 1000);
    }

    // ============ removeRevenueSplit() TESTS ============

    /**
     * @dev Test successful removal of revenue split
     */
    function test_RemoveRevenueSplit_Success() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient = address(0x100);
        store.addRevenueSplit(productId, recipient, 1000);
        
        vm.expectEmit(true, false, false, true);
        emit RevenueSplitRemoved(productId, recipient);
        
        store.removeRevenueSplit(productId, 0);
        vm.stopPrank();
        
        // Verify split was removed
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 0, "Should have no splits");
    }

    /**
     * @dev Test removing split from middle of array
     */
    function test_RemoveRevenueSplit_Success_FromMiddle() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient1 = address(0x100);
        address recipient2 = address(0x200);
        address recipient3 = address(0x300);
        
        store.addRevenueSplit(productId, recipient1, 2000);
        store.addRevenueSplit(productId, recipient2, 3000);
        store.addRevenueSplit(productId, recipient3, 1500);
        
        // Remove middle split (index 1)
        store.removeRevenueSplit(productId, 1);
        vm.stopPrank();
        
        // Verify split was removed and array was reordered
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 2, "Should have 2 splits");
        assertEq(splits[0].recipient, recipient1, "First split should remain");
        assertEq(splits[1].recipient, recipient3, "Last split should move to middle");
    }

    /**
     * @dev Test removing last split
     */
    function test_RemoveRevenueSplit_Success_LastSplit() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient1 = address(0x100);
        address recipient2 = address(0x200);
        
        store.addRevenueSplit(productId, recipient1, 2000);
        store.addRevenueSplit(productId, recipient2, 3000);
        
        store.removeRevenueSplit(productId, 1); // Remove last
        vm.stopPrank();
        
        BaseCartStore.RevenueSplit[] memory splits = store.getProductRevenueSplits(productId);
        assertEq(splits.length, 1, "Should have 1 split");
        assertEq(splits[0].recipient, recipient1, "First split should remain");
    }

    /**
     * @dev Test that RevenueSplitRemoved event is emitted
     */
    function test_RemoveRevenueSplit_EmitsEvent() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        
        address recipient = address(0x100);
        store.addRevenueSplit(productId, recipient, 1000);
        
        vm.expectEmit(true, false, false, true);
        emit RevenueSplitRemoved(productId, recipient);
        
        store.removeRevenueSplit(productId, 0);
        vm.stopPrank();
    }

    // ============ removeRevenueSplit() REVERT CASES ============

    /**
     * @dev Test revert when product ID is zero
     */
    function test_RemoveRevenueSplit_Revert_InvalidProductId_Zero() public {
        vm.prank(owner);
        vm.expectRevert("Invalid product ID");
        store.removeRevenueSplit(0, 0);
    }

    /**
     * @dev Test revert when product ID is too high
     */
    function test_RemoveRevenueSplit_Revert_InvalidProductId_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid product ID");
        store.removeRevenueSplit(productId + 1, 0);
    }

    /**
     * @dev Test revert when split index is invalid
     */
    function test_RemoveRevenueSplit_Revert_InvalidIndex() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        store.addRevenueSplit(productId, address(0x100), 1000);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid split index");
        store.removeRevenueSplit(productId, 1); // Index 1 doesn't exist (only 0)
    }

    /**
     * @dev Test revert when trying to remove from empty array
     */
    function test_RemoveRevenueSplit_Revert_EmptyArray() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Invalid split index");
        store.removeRevenueSplit(productId, 0);
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_RemoveRevenueSplit_Revert_NotOwner() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        store.addRevenueSplit(productId, address(0x100), 1000);
        vm.stopPrank();
        
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.removeRevenueSplit(productId, 0);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_RemoveRevenueSplit_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        store.addRevenueSplit(productId, address(0x100), 1000);
        store.setStoreActive(false);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Store is not active");
        store.removeRevenueSplit(productId, 0);
    }

    // ============ withdrawFunds() TESTS ============

    /**
     * @dev Test successful withdrawal of funds
     */
    function test_WithdrawFunds_Success() public {
        // Send tokens directly to store
        paymentToken.mint(address(store), 500 ether);
        
        uint256 ownerBalanceBefore = paymentToken.balanceOf(owner);
        
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(owner, address(paymentToken), 500 ether);
        
        vm.prank(owner);
        store.withdrawFunds(address(paymentToken));
        
        uint256 ownerBalanceAfter = paymentToken.balanceOf(owner);
        uint256 storeBalanceAfter = paymentToken.balanceOf(address(store));
        
        assertEq(storeBalanceAfter, 0, "Store balance should be zero");
        assertEq(ownerBalanceAfter, ownerBalanceBefore + 500 ether, "Owner should receive funds");
    }

    /**
     * @dev Test withdrawal after revenue distribution
     * Note: For non-escrow orders, revenue is distributed immediately, so store balance is zero
     */
    function test_WithdrawFunds_Success_AfterRevenueDistribution() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();
        
        // Create order and process payment (non-escrow, so revenue is distributed immediately)
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);
        
        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);
        
        // Verify store balance is zero (revenue was distributed immediately)
        uint256 storeBalance = paymentToken.balanceOf(address(store));
        assertEq(storeBalance, 0, "Store balance should be zero after revenue distribution");
        
        // Add some additional funds to store for withdrawal test
        paymentToken.mint(address(store), 200 ether);
        
        // Now withdraw should succeed
        uint256 ownerBalanceBefore = paymentToken.balanceOf(owner);
        vm.prank(owner);
        store.withdrawFunds(address(paymentToken));
        
        assertEq(paymentToken.balanceOf(address(store)), 0, "Store balance should be zero");
        assertEq(paymentToken.balanceOf(owner), ownerBalanceBefore + 200 ether, "Owner should receive funds");
    }

    /**
     * @dev Test withdrawal of multiple token types
     */
    function test_WithdrawFunds_Success_MultipleTokens() public {
        // Create second token
        ERC20Mock token2 = new ERC20Mock();
        vm.startPrank(owner);
        factory.addSupportedToken(address(token2));
        vm.stopPrank();
        
        // Send both tokens to store
        paymentToken.mint(address(store), 300 ether);
        token2.mint(address(store), 200 ether);
        
        // Withdraw first token
        vm.prank(owner);
        store.withdrawFunds(address(paymentToken));
        assertEq(paymentToken.balanceOf(address(store)), 0, "First token balance should be zero");
        assertEq(paymentToken.balanceOf(owner), 300 ether, "Owner should receive first token");
        
        // Withdraw second token
        vm.prank(owner);
        store.withdrawFunds(address(token2));
        assertEq(token2.balanceOf(address(store)), 0, "Second token balance should be zero");
        assertEq(token2.balanceOf(owner), 200 ether, "Owner should receive second token");
    }

    /**
     * @dev Test that FundsWithdrawn event is emitted
     */
    function test_WithdrawFunds_EmitsEvent() public {
        paymentToken.mint(address(store), 500 ether);
        
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(owner, address(paymentToken), 500 ether);
        
        vm.prank(owner);
        store.withdrawFunds(address(paymentToken));
    }

    // ============ withdrawFunds() REVERT CASES ============

    /**
     * @dev Test revert when token address is zero
     */
    function test_WithdrawFunds_Revert_InvalidTokenAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid token address");
        store.withdrawFunds(address(0));
    }

    /**
     * @dev Test revert when no funds to withdraw
     */
    function test_WithdrawFunds_Revert_NoFunds() public {
        vm.prank(owner);
        vm.expectRevert("No funds to withdraw");
        store.withdrawFunds(address(paymentToken));
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_WithdrawFunds_Revert_NotOwner() public {
        paymentToken.mint(address(store), 500 ether);
        
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.withdrawFunds(address(paymentToken));
    }

    // ============ confirmDelivery() TESTS ============

    /**
     * @dev Test successful confirmation of delivery for escrow order
     */
    function test_ConfirmDelivery_Success_EscrowOrder() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create escrow order
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Mark as shipped
        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Confirm delivery
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 platformFee = factory.calculatePlatformFee(100 ether);
        uint256 sellerAmount = 100 ether - platformFee;

        vm.expectEmit(true, true, false, true);
        emit EscrowReleased(orderId, buyer, sellerAmount);
        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Completed);

        vm.prank(buyer);
        store.confirmDelivery(orderId);

        // Verify order status is Completed
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Completed), "Order should be Completed");
    }

    /**
     * @dev Test successful confirmation of delivery for non-escrow order
     */
    function test_ConfirmDelivery_Success_NonEscrowOrder() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create non-escrow order
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Mark as shipped
        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Confirm delivery (should not emit EscrowReleased)
        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Completed);

        vm.prank(buyer);
        store.confirmDelivery(orderId);

        // Verify order status is Completed
        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Completed), "Order should be Completed");
    }

    // ============ confirmDelivery() REVERT CASES ============

    /**
     * @dev Test revert when order ID is zero
     */
    function test_ConfirmDelivery_Revert_InvalidOrderId_Zero() public {
        vm.prank(buyer);
        vm.expectRevert("Invalid order ID");
        store.confirmDelivery(0);
    }

    /**
     * @dev Test revert when order ID is too high
     */
    function test_ConfirmDelivery_Revert_InvalidOrderId_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.prank(buyer);
        vm.expectRevert("Invalid order ID");
        store.confirmDelivery(orderId + 1);
    }

    /**
     * @dev Test revert when caller is not the buyer
     */
    function test_ConfirmDelivery_Revert_NotBuyer() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        vm.prank(otherUser);
        vm.expectRevert("Not the order buyer");
        store.confirmDelivery(orderId);
    }

    /**
     * @dev Test revert when order is not shipped
     */
    function test_ConfirmDelivery_Revert_OrderNotShipped() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Try to confirm delivery before shipping
        vm.prank(buyer);
        vm.expectRevert("Order not shipped");
        store.confirmDelivery(orderId);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_ConfirmDelivery_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        store.setStoreActive(false);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        vm.prank(buyer);
        vm.expectRevert("Store is not active");
        store.confirmDelivery(orderId);
    }

    // ============ refundOrder() TESTS ============

    /**
     * @dev Test successful refund of escrow order in InEscrow status
     */
    function test_RefundOrder_Success_InEscrowStatus() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create escrow order
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify order is in InEscrow status
        (,,,,,, BaseCartStore.OrderStatus statusBefore,,) = _getOrder(orderId);
        assertEq(uint256(statusBefore), uint256(BaseCartStore.OrderStatus.InEscrow), "Order should be InEscrow");

        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 platformFee = factory.calculatePlatformFee(100 ether);
        
        // Add platform fee back to store so it can refund the full amount
        paymentToken.mint(address(store), platformFee);

        vm.expectEmit(true, true, false, true);
        emit EscrowRefunded(orderId, buyer, 100 ether);
        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Refunded);

        vm.prank(owner);
        store.refundOrder(orderId);

        // Verify order status is Refunded
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Refunded), "Order should be Refunded");

        // Verify buyer received refund
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore + 100 ether, "Buyer should receive full refund");
    }

    /**
     * @dev Test successful refund of escrow order in Shipped status
     */
    function test_RefundOrder_Success_ShippedStatus() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create escrow order
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Mark as shipped
        vm.prank(owner);
        store.markOrderShipped(orderId);

        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 platformFee = factory.calculatePlatformFee(100 ether);
        
        // Add platform fee back to store so it can refund the full amount
        paymentToken.mint(address(store), platformFee);

        vm.prank(owner);
        store.refundOrder(orderId);

        // Verify order status is Refunded
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Refunded), "Order should be Refunded");

        // Verify buyer received refund
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore + 100 ether, "Buyer should receive full refund");
    }

    /**
     * @dev Test refund returns inventory for physical products
     */
    function test_RefundOrder_Success_ReturnsInventory() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, true); // Order 2 items

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        // Verify inventory decreased
        (,,,,,uint256 inventoryBefore,,,) = store.products(productId);
        assertEq(inventoryBefore, 48, "Inventory should be 48");

        uint256 platformFee = factory.calculatePlatformFee(200 ether);
        paymentToken.mint(address(store), platformFee);

        vm.prank(owner);
        store.refundOrder(orderId);

        // Verify inventory was returned
        (,,,,,uint256 inventoryAfter,,,) = store.products(productId);
        assertEq(inventoryAfter, 50, "Inventory should be restored to 50");
    }

    // ============ HELPER FUNCTIONS ============

    /**
     * @dev Helper function to get order data
     */
    function _getOrder(uint256 _orderId)
        internal
        view
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            address,
            BaseCartStore.OrderStatus,
            uint256,
            bool
        )
    {
        return store.orders(_orderId);
    }
}
