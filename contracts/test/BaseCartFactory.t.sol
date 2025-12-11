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
}

