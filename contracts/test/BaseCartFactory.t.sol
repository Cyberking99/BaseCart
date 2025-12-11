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
        vm.expectEmit(true, true, false, true);
        emit StoreCreated(user1, address(0), STORE_NAME, STORE_URL);

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
}

