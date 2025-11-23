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
