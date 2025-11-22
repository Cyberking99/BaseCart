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
