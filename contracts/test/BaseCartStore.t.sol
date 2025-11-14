// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {BaseCartStore} from "../src/BaseCartStore.sol";
import {BaseCartFactory} from "../src/BaseCartFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title BaseCartStore Test Suite
 * @dev Comprehensive tests for BaseCartStore product and order management functions
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

    event ProductAdded(uint256 indexed productId, string name, uint256 price, bool isDigital);
    event ProductUpdated(uint256 indexed productId, string name, uint256 price, bool isActive);
    event InventoryUpdated(uint256 indexed productId, uint256 newInventory);
    event OrderCreated(uint256 indexed orderId, address indexed buyer, uint256 productId, uint256 totalPrice);

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

    // ============ addProduct() TESTS ============

    /**
     * @dev Test successful product addition with valid inputs
     */
    function test_AddProduct_Success_WithValidInputs() public {
        vm.startPrank(owner);

        string memory productName = "Test Product";
        string memory productDescription = "A test product description";
        uint256 productPrice = 100 ether;

        uint256 productId = store.addProduct(
            productName,
            productDescription,
            productPrice,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            100    // inventory
        );

        // Check product ID
        assertEq(productId, 1, "Product ID should be 1");

        // Check product count
        assertEq(store.productCount(), 1, "Product count should be 1");

        // Verify all product fields
        (
            uint256 id,
            string memory name,
            string memory description,
            uint256 price,
            address token,
            bool digital,
            bool unlimited,
            uint256 inv,
            bool active
        ) = _getProduct(productId);

        assertEq(id, productId, "Product ID should match");
        assertEq(name, productName, "Product name should match");
        assertEq(description, productDescription, "Product description should match");
        assertEq(price, productPrice, "Product price should match");
        assertEq(token, address(paymentToken), "Payment token should match");
        assertEq(digital, false, "isDigital should match");
        assertEq(unlimited, false, "isUnlimited should match");
        assertEq(inv, 100, "Inventory should match");
        assertEq(active, true, "Product should be active");

        vm.stopPrank();
    }

    /**
     * @dev Test that productCount increments correctly
     */
    function test_AddProduct_IncrementsProductCount() public {
        vm.startPrank(owner);

        // Add first product
        uint256 productId1 = store.addProduct(
            "Product 1",
            "Description 1",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        assertEq(productId1, 1, "First product ID should be 1");
        assertEq(store.productCount(), 1, "Product count should be 1");

        // Add second product
        uint256 productId2 = store.addProduct(
            "Product 2",
            "Description 2",
            200 ether,
            address(paymentToken),
            true,
            true,
            0
        );

        assertEq(productId2, 2, "Second product ID should be 2");
        assertEq(store.productCount(), 2, "Product count should be 2");

        // Add third product
        uint256 productId3 = store.addProduct(
            "Product 3",
            "Description 3",
            300 ether,
            address(paymentToken),
            false,
            false,
            75
        );

        assertEq(productId3, 3, "Third product ID should be 3");
        assertEq(store.productCount(), 3, "Product count should be 3");

        vm.stopPrank();
    }

    /**
     * @dev Test that correct productId is returned
     */
    function test_AddProduct_ReturnsCorrectProductId() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        assertEq(productId, 1, "Should return product ID 1");
        assertEq(productId, store.productCount(), "Product ID should equal product count");

        vm.stopPrank();
    }

    /**
     * @dev Test that all fields are saved exactly
     */
    function test_AddProduct_SavesAllFieldsExactly() public {
        vm.startPrank(owner);

        string memory productName = "Exact Test Product";
        string memory productDescription = "This is an exact description test with special chars: !@#$%^&*()";
        uint256 productPrice = 123456789 wei;

        uint256 productId = store.addProduct(
            productName,
            productDescription,
            productPrice,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0      // inventory
        );

        (
            uint256 id,
            string memory name,
            string memory description,
            uint256 price,
            address token,
            bool digital,
            bool unlimited,
            uint256 inv,
            bool active
        ) = _getProduct(productId);

        assertEq(id, productId, "ID should match");
        assertEq(name, productName, "Name should match exactly");
        assertEq(description, productDescription, "Description should match exactly");
        assertEq(price, productPrice, "Price should match exactly");
        assertEq(token, address(paymentToken), "Token should match");
        assertEq(digital, true, "isDigital should match");
        assertEq(unlimited, true, "isUnlimited should match");
        assertEq(inv, 0, "Inventory should match");
        assertEq(active, true, "Should be active");

        vm.stopPrank();
    }

    /**
     * @dev Test that ProductAdded event is emitted
     */
    function test_AddProduct_EmitsProductAddedEvent() public {
        vm.startPrank(owner);

        string memory productName = "Event Test Product";
        uint256 productPrice = 100 ether;
        bool isDigital = false;

        vm.expectEmit(true, false, false, true);
        emit ProductAdded(1, productName, productPrice, isDigital);

        store.addProduct(
            productName,
            "Description",
            productPrice,
            address(paymentToken),
            isDigital,
            false,
            50
        );

        vm.stopPrank();
    }

    /**
     * @dev Test adding digital product with unlimited inventory
     */
    function test_AddProduct_DigitalUnlimitedProduct() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Digital Product",
            "A digital product",
            50 ether,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0      // inventory (not needed for digital unlimited)
        );

        (
            ,,,
            ,,
            bool digital,
            bool unlimited,
            uint256 inv,
            bool active
        ) = _getProduct(productId);

        assertEq(digital, true, "Should be digital");
        assertEq(unlimited, true, "Should be unlimited");
        assertEq(inv, 0, "Inventory should be 0");
        assertEq(active, true, "Should be active");

        vm.stopPrank();
    }

    /**
     * @dev Test adding physical product with inventory
     */
    function test_AddProduct_PhysicalProductWithInventory() public {
        vm.startPrank(owner);

        uint256 inventory = 1000;

        uint256 productId = store.addProduct(
            "Physical Product",
            "A physical product",
            75 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            inventory
        );

        (
            ,,,
            ,,
            bool digital,
            bool unlimited,
            uint256 inv,
            bool active
        ) = _getProduct(productId);

        assertEq(digital, false, "Should not be digital");
        assertEq(unlimited, false, "Should not be unlimited");
        assertEq(inv, inventory, "Inventory should match");
        assertEq(active, true, "Should be active");

        vm.stopPrank();
    }

    // ============ addProduct() REVERT CASES ============

    /**
     * @dev Test revert when price is zero
     */
    function test_AddProduct_Revert_ZeroPrice() public {
        vm.startPrank(owner);

        vm.expectRevert("Price must be greater than zero");
        store.addProduct(
            "Test Product",
            "Description",
            0, // Zero price
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when payment token is not supported
     */
    function test_AddProduct_Revert_UnsupportedPaymentToken() public {
        vm.startPrank(owner);

        // Create unsupported token
        ERC20Mock unsupportedToken = new ERC20Mock();

        vm.expectRevert("Payment token not supported");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(unsupportedToken), // Unsupported token
            false,
            false,
            50
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when physical product has zero inventory
     */
    function test_AddProduct_Revert_PhysicalProductZeroInventory() public {
        vm.startPrank(owner);

        vm.expectRevert("Physical products must have inventory");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // Physical product
            false,
            0      // Zero inventory
        );

        vm.stopPrank();
    }

    /**
     * @dev Test that digital products can have zero inventory
     */
    function test_AddProduct_Success_DigitalProductZeroInventory() public {
        vm.startPrank(owner);

        // Digital products can have zero inventory
        uint256 productId = store.addProduct(
            "Digital Product",
            "Description",
            100 ether,
            address(paymentToken),
            true,  // Digital product
            false,
            0      // Zero inventory is OK for digital
        );

        assertEq(productId, 1, "Product should be created");

        vm.stopPrank();
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_AddProduct_Revert_NotOwner() public {
        vm.startPrank(buyer); // Not the owner

        vm.expectRevert("Only store owner can call this function");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_AddProduct_Revert_StoreNotActive() public {
        vm.startPrank(owner);

        // Deactivate store
        store.setStoreActive(false);

        vm.expectRevert("Store is not active");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();
    }

    /**
     * @dev Test that product can be added after reactivating store
     */
    function test_AddProduct_Success_AfterReactivatingStore() public {
        vm.startPrank(owner);

        // Deactivate store
        store.setStoreActive(false);

        // Try to add product (should fail)
        vm.expectRevert("Store is not active");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Reactivate store
        store.setStoreActive(true);

        // Now should succeed
        uint256 productId = store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        assertEq(productId, 1, "Product should be created after reactivation");

        vm.stopPrank();
    }

    /**
     * @dev Test revert when payment token address is zero (factory check)
     */
    function test_AddProduct_Revert_ZeroPaymentToken() public {
        vm.startPrank(owner);

        vm.expectRevert("Payment token not supported");
        store.addProduct(
            "Test Product",
            "Description",
            100 ether,
            address(0), // Zero address
            false,
            false,
            50
        );

        vm.stopPrank();
    }

    // ============ HELPER FUNCTIONS ============

    /**
     * @dev Helper function to get product data - returns tuple directly
     */
    function _getProduct(uint256 _productId)
        internal
        view
        returns (
            uint256,
            string memory,
            string memory,
            uint256,
            address,
            bool,
            bool,
            uint256,
            bool
        )
    {
        // Public mapping getter returns all fields separately
        return store.products(_productId);
    }
}

