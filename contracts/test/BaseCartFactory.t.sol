// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {BaseCartFactory} from "../src/BaseCartFactory.sol";
import {BaseCartStore} from "../src/BaseCartStore.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title BaseCartFactory Test Suite
 * @dev Comprehensive tests for BaseCartFactory functions
 */
contract BaseCartFactoryTest is Test {
    BaseCartFactory public factory;

    address public owner;
    address public user1;
    address public user2;

    string public constant STORE_NAME = "Test Store";
    string public constant STORE_URL = "test-store";
    string public constant STORE_DESCRIPTION = "A test store";

    event StoreCreated(address indexed owner, address storeAddress, string storeName, string storeUrl);
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    event TokenSupportAdded(address token);
    event TokenSupportRemoved(address token);

    function setUp() public {
        // Setup accounts
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);

        // Deploy factory as owner
        vm.prank(owner);
        factory = new BaseCartFactory();
    }

    // ============ createStore() TESTS ============

    /**
     * @dev Test successful store creation
     */
    function test_CreateStore_Success() public {
        vm.prank(user1);
        address storeAddress = factory.createStore(STORE_NAME, STORE_URL, STORE_DESCRIPTION);

        // Verify store address is not zero
        assertNotEq(storeAddress, address(0), "Store address should not be zero");

        // Verify store is registered
        assertTrue(factory.isValidStore(storeAddress), "Store should be registered as valid");

        // Verify store owner
        BaseCartStore store = BaseCartStore(storeAddress);
        assertEq(store.owner(), user1, "Store owner should be user1");
        assertEq(store.factory(), address(factory), "Store factory should be factory address");
        assertEq(store.storeName(), STORE_NAME, "Store name should match");
        assertEq(store.storeUrl(), STORE_URL, "Store URL should match");
        assertEq(store.storeDescription(), STORE_DESCRIPTION, "Store description should match");
    }

    /**
     * @dev Test that StoreCreated event is emitted
     */
    function test_CreateStore_EmitsEvent() public {
        // Only assert that the event is emitted and the indexed owner matches.
        vm.expectEmit(true, false, false, false);
        emit StoreCreated(user1, address(0), "", "");

        vm.prank(user1);
        factory.createStore(STORE_NAME, STORE_URL, STORE_DESCRIPTION);
    }

    /**
     * @dev Test that multiple stores can be created by same user
     */
    function test_CreateStore_Success_MultipleStores() public {
        vm.startPrank(user1);
        address store1 = factory.createStore("Store 1", "store-1", "Description 1");
        address store2 = factory.createStore("Store 2", "store-2", "Description 2");
        address store3 = factory.createStore("Store 3", "store-3", "Description 3");
        vm.stopPrank();

        // Verify all stores are registered
        assertTrue(factory.isValidStore(store1), "Store 1 should be valid");
        assertTrue(factory.isValidStore(store2), "Store 2 should be valid");
        assertTrue(factory.isValidStore(store3), "Store 3 should be valid");

        // Verify total stores count
        assertEq(factory.getTotalStores(), 3, "Total stores should be 3");

        // Verify stores by owner
        address[] memory stores = factory.getStoresByOwner(user1);
        assertEq(stores.length, 3, "User1 should have 3 stores");
        assertEq(stores[0], store1, "First store should match");
        assertEq(stores[1], store2, "Second store should match");
        assertEq(stores[2], store3, "Third store should match");
    }

    /**
     * @dev Test that different users can create stores
     */
    function test_CreateStore_Success_DifferentUsers() public {
        vm.prank(user1);
        address store1 = factory.createStore("User1 Store", "user1-store", "User1 Description");

        vm.prank(user2);
        address store2 = factory.createStore("User2 Store", "user2-store", "User2 Description");

        // Verify both stores are registered
        assertTrue(factory.isValidStore(store1), "Store 1 should be valid");
        assertTrue(factory.isValidStore(store2), "Store 2 should be valid");

        // Verify total stores count
        assertEq(factory.getTotalStores(), 2, "Total stores should be 2");

        // Verify stores by owner
        address[] memory user1Stores = factory.getStoresByOwner(user1);
        address[] memory user2Stores = factory.getStoresByOwner(user2);
        assertEq(user1Stores.length, 1, "User1 should have 1 store");
        assertEq(user2Stores.length, 1, "User2 should have 1 store");
        assertEq(user1Stores[0], store1, "User1 store should match");
        assertEq(user2Stores[0], store2, "User2 store should match");
    }

    // ============ getStoresByOwner() TESTS ============

    /**
     * @dev Test getting stores for owner with multiple stores
     */
    function test_GetStoresByOwner_Success() public {
        vm.startPrank(user1);
        address store1 = factory.createStore("Store 1", "store-1", "Desc 1");
        address store2 = factory.createStore("Store 2", "store-2", "Desc 2");
        vm.stopPrank();

        address[] memory stores = factory.getStoresByOwner(user1);
        assertEq(stores.length, 2, "Should return 2 stores");
        assertEq(stores[0], store1, "First store should match");
        assertEq(stores[1], store2, "Second store should match");
    }

    /**
     * @dev Test getting stores for owner with no stores
     */
    function test_GetStoresByOwner_Empty() public {
        address[] memory stores = factory.getStoresByOwner(user1);
        assertEq(stores.length, 0, "Should return empty array");
    }

    // ============ getTotalStores() TESTS ============

    /**
     * @dev Test getting total stores count
     */
    function test_GetTotalStores_Success() public {
        assertEq(factory.getTotalStores(), 0, "Initial total should be 0");

        vm.prank(user1);
        factory.createStore("Store 1", "store-1", "Desc 1");
        assertEq(factory.getTotalStores(), 1, "Total should be 1");

        vm.prank(user2);
        factory.createStore("Store 2", "store-2", "Desc 2");
        assertEq(factory.getTotalStores(), 2, "Total should be 2");

        vm.prank(user1);
        factory.createStore("Store 3", "store-3", "Desc 3");
        assertEq(factory.getTotalStores(), 3, "Total should be 3");
    }

    // ============ calculatePlatformFee() TESTS ============

    /**
     * @dev Test platform fee calculation with default fee (2.5%)
     */
    function test_CalculatePlatformFee_Success_DefaultFee() public {
        uint256 amount = 1000 ether;
        uint256 expectedFee = (amount * 250) / 10000; // 2.5% = 25 ether

        uint256 fee = factory.calculatePlatformFee(amount);
        assertEq(fee, expectedFee, "Fee should be 25 ether (2.5% of 1000)");
    }

    /**
     * @dev Test platform fee calculation with different amounts
     */
    function test_CalculatePlatformFee_Success_DifferentAmounts() public {
        assertEq(factory.calculatePlatformFee(100 ether), 2.5 ether, "Fee for 100 should be 2.5");
        assertEq(factory.calculatePlatformFee(1000 ether), 25 ether, "Fee for 1000 should be 25");
        assertEq(factory.calculatePlatformFee(10000 ether), 250 ether, "Fee for 10000 should be 250");
    }

    // ============ isTokenSupported() TESTS ============

    /**
     * @dev Test checking if token is supported
     */
    function test_IsTokenSupported_Success() public {
        ERC20Mock token = new ERC20Mock();
        // Token should not be supported initially
        assertFalse(factory.isTokenSupported(address(token)), "Token should not be supported");

        // Add token support
        vm.prank(owner);
        factory.addSupportedToken(address(token));

        // Token should now be supported
        assertTrue(factory.isTokenSupported(address(token)), "Token should be supported");
    }

    // ============ NEW BASIC TESTS FOR COVERAGE ============

    /**
     * @dev Test that the initial fee collector is the deployer (owner)
     */
    function test_InitialFeeCollector_IsOwner() public {
        // setUp deploys the factory with msg.sender = owner
        assertEq(factory.feeCollector(), owner, "Initial feeCollector should be owner");
    }

    /**
     * @dev Test that only the owner can update the platform fee
     */
    function test_UpdatePlatformFee_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        factory.updatePlatformFee(500);
    }

    /**
     * @dev Test that updatePlatformFee updates the fee and emits the event
     */
    function test_UpdatePlatformFee_UpdatesAndEmits() public {
        uint256 newFee = 500;

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit PlatformFeeUpdated(newFee);
        factory.updatePlatformFee(newFee);

        assertEq(
            factory.platformFeePercentage(),
            newFee,
            "platformFeePercentage should be updated"
        );
    }

    /**
     * @dev Test that updateFeeCollector updates the collector address
     */
    function test_UpdateFeeCollector_UpdatesCollector() public {
        vm.prank(owner);
        factory.updateFeeCollector(user1);

        assertEq(factory.feeCollector(), user1, "feeCollector should be updated to user1");
    }
}

