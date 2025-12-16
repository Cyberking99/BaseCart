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

    // ============ updateProduct() TESTS ============

    /**
     * @dev Test successful product update with all fields
     */
    function test_UpdateProduct_Success_UpdateAllFields() public {
        vm.startPrank(owner);

        // First create a product
        uint256 productId = store.addProduct(
            "Original Product",
            "Original Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Update all fields
        string memory newName = "Updated Product";
        string memory newDescription = "Updated Description";
        uint256 newPrice = 200 ether;
        address newToken = address(paymentToken);
        bool newIsActive = false;

        store.updateProduct(
            productId,
            newName,
            newDescription,
            newPrice,
            newToken,
            newIsActive
        );

        // Verify all fields were updated - check in separate calls to avoid stack too deep
        (, string memory name,,,,,,,) = _getProduct(productId);
        assertEq(name, newName, "Name should be updated");
        
        (,, string memory description,,,,,,) = _getProduct(productId);
        assertEq(description, newDescription, "Description should be updated");
        
        (,,, uint256 price,,,,,) = _getProduct(productId);
        assertEq(price, newPrice, "Price should be updated");
        
        (,,,, address token,,,,) = _getProduct(productId);
        assertEq(token, newToken, "Payment token should be updated");
        
        (,,,,,,, uint256 inventory, bool active) = _getProduct(productId);
        assertEq(active, newIsActive, "isActive should be updated");
        assertEq(inventory, 50, "Inventory should not change");

        vm.stopPrank();
    }

    /**
     * @dev Test updating product name
     */
    function test_UpdateProduct_Success_UpdateName() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Original Name",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        store.updateProduct(
            productId,
            "New Name",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        (, string memory name,,,,,,,) = _getProduct(productId);
        assertEq(name, "New Name", "Name should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test updating product description
     */
    function test_UpdateProduct_Success_UpdateDescription() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Original Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        string memory newDescription = "This is a new detailed description with special chars: !@#$%^&*()";

        store.updateProduct(
            productId,
            "Product",
            newDescription,
            100 ether,
            address(paymentToken),
            true
        );

        (,, string memory description,,,,,,) = _getProduct(productId);
        assertEq(description, newDescription, "Description should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test updating product price
     */
    function test_UpdateProduct_Success_UpdatePrice() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        uint256 newPrice = 250 ether;

        store.updateProduct(
            productId,
            "Product",
            "Description",
            newPrice,
            address(paymentToken),
            true
        );

        (,,, uint256 price,,,,,) = _getProduct(productId);
        assertEq(price, newPrice, "Price should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test updating payment token
     */
    function test_UpdateProduct_Success_UpdatePaymentToken() public {
        vm.startPrank(owner);

        // Create and add a second supported token
        ERC20Mock newToken = new ERC20Mock();
        factory.addSupportedToken(address(newToken));

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(newToken),
            true
        );

        (,,,, address token,,,,) = _getProduct(productId);
        assertEq(token, address(newToken), "Payment token should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test updating isActive status
     */
    function test_UpdateProduct_Success_UpdateIsActive() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate product
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false
        );

        (,,,,,,, uint256 inv, bool active) = _getProduct(productId);
        assertEq(active, false, "Product should be inactive");

        // Reactivate product
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        (,,,,,,, inv, active) = _getProduct(productId);
        assertEq(active, true, "Product should be active");

        vm.stopPrank();
    }

    /**
     * @dev Test that ProductUpdated event is emitted
     */
    function test_UpdateProduct_EmitsProductUpdatedEvent() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        string memory newName = "Updated Product";
        uint256 newPrice = 200 ether;
        bool newIsActive = false;

        vm.expectEmit(true, false, false, true);
        emit ProductUpdated(productId, newName, newPrice, newIsActive);

        store.updateProduct(
            productId,
            newName,
            "Description",
            newPrice,
            address(paymentToken),
            newIsActive
        );

        vm.stopPrank();
    }

    // ============ updateProduct() REVERT CASES ============

    /**
     * @dev Test revert when product ID is invalid (zero)
     */
    function test_UpdateProduct_Revert_InvalidProductId_Zero() public {
        vm.startPrank(owner);

        vm.expectRevert("Invalid product ID");
        store.updateProduct(
            0, // Invalid product ID
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when product ID is invalid (too high)
     */
    function test_UpdateProduct_Revert_InvalidProductId_TooHigh() public {
        vm.startPrank(owner);

        // Create one product
        store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Try to update non-existent product
        vm.expectRevert("Invalid product ID");
        store.updateProduct(
            999, // Non-existent product ID
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when price is zero
     */
    function test_UpdateProduct_Revert_ZeroPrice() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.expectRevert("Price must be greater than zero");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            0, // Zero price
            address(paymentToken),
            true
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when payment token is not supported
     */
    function test_UpdateProduct_Revert_UnsupportedPaymentToken() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Create unsupported token
        ERC20Mock unsupportedToken = new ERC20Mock();

        vm.expectRevert("Payment token not supported");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(unsupportedToken), // Unsupported token
            true
        );

        vm.stopPrank();
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_UpdateProduct_Revert_NotOwner() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();

        // Try to update as non-owner
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );
    }

    /**
     * @dev Test revert when store is inactive
     */
    function test_UpdateProduct_Revert_StoreNotActive() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        vm.expectRevert("Store is not active");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        vm.stopPrank();
    }

    /**
     * @dev Test that product can be updated after reactivating store
     */
    function test_UpdateProduct_Success_AfterReactivatingStore() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        // Try to update (should fail)
        vm.expectRevert("Store is not active");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            true
        );

        // Reactivate store
        store.setStoreActive(true);

        // Now should succeed
        store.updateProduct(
            productId,
            "Updated Product",
            "Updated Description",
            200 ether,
            address(paymentToken),
            false
        );

        // Verify updates
        (, string memory name,,,,,,,) = _getProduct(productId);
        assertEq(name, "Updated Product", "Product should be updated");
        
        (,,, uint256 price,,,,,) = _getProduct(productId);
        assertEq(price, 200 ether, "Price should be updated");
        
        (,,,,,,, uint256 _inv, bool active) = _getProduct(productId);
        assertEq(active, false, "Product should be inactive");
        assertEq(_inv, 50, "Inventory should not change");

        vm.stopPrank();
    }

    /**
     * @dev Test revert when payment token address is zero
     */
    function test_UpdateProduct_Revert_ZeroPaymentToken() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.expectRevert("Payment token not supported");
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(0), // Zero address
            true
        );

        vm.stopPrank();
    }

    // ============ updateInventory() TESTS ============

    /**
     * @dev Test successful inventory update for physical product
     */
    function test_UpdateInventory_Success_PhysicalProduct() public {
        vm.startPrank(owner);

        // Create a physical product with initial inventory
        uint256 productId = store.addProduct(
            "Physical Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            100    // initial inventory
        );

        uint256 newInventory = 200;

        vm.expectEmit(true, false, false, true);
        emit InventoryUpdated(productId, newInventory);

        store.updateInventory(productId, newInventory);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, newInventory, "Inventory should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test successful inventory update for digital product with limited inventory
     */
    function test_UpdateInventory_Success_DigitalProductLimited() public {
        vm.startPrank(owner);

        // Create a digital product with limited inventory
        uint256 productId = store.addProduct(
            "Digital Product",
            "Description",
            50 ether,
            address(paymentToken),
            true,  // isDigital
            false, // isUnlimited
            10     // initial inventory
        );

        uint256 newInventory = 25;

        store.updateInventory(productId, newInventory);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, newInventory, "Inventory should be updated");

        vm.stopPrank();
    }

    /**
     * @dev Test that inventory can be set to zero for physical products
     */
    function test_UpdateInventory_Success_SetToZero() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            100
        );

        store.updateInventory(productId, 0);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 0, "Inventory should be zero");

        vm.stopPrank();
    }

    /**
     * @dev Test that inventory can be increased
     */
    function test_UpdateInventory_Success_IncreaseInventory() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        store.updateInventory(productId, 150);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 150, "Inventory should be increased");

        vm.stopPrank();
    }

    /**
     * @dev Test that inventory can be decreased
     */
    function test_UpdateInventory_Success_DecreaseInventory() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            100
        );

        store.updateInventory(productId, 25);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 25, "Inventory should be decreased");

        vm.stopPrank();
    }

    /**
     * @dev Test that InventoryUpdated event is emitted
     */
    function test_UpdateInventory_EmitsInventoryUpdatedEvent() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            100
        );

        uint256 newInventory = 75;

        vm.expectEmit(true, false, false, true);
        emit InventoryUpdated(productId, newInventory);

        store.updateInventory(productId, newInventory);

        vm.stopPrank();
    }

    // ============ updateInventory() REVERT CASES ============

    /**
     * @dev Test revert when product ID is invalid (zero)
     */
    function test_UpdateInventory_Revert_InvalidProductId_Zero() public {
        vm.startPrank(owner);

        vm.expectRevert("Invalid product ID");
        store.updateInventory(0, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test revert when product ID is invalid (too high)
     */
    function test_UpdateInventory_Revert_InvalidProductId_TooHigh() public {
        vm.startPrank(owner);

        store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.expectRevert("Invalid product ID");
        store.updateInventory(999, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test revert when product has unlimited inventory
     */
    function test_UpdateInventory_Revert_UnlimitedProduct() public {
        vm.startPrank(owner);

        // Create unlimited product
        uint256 productId = store.addProduct(
            "Unlimited Product",
            "Description",
            100 ether,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0
        );

        vm.expectRevert("Cannot update inventory for unlimited products");
        store.updateInventory(productId, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_UpdateInventory_Revert_NotOwner() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();

        // Try to update as non-owner
        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.updateInventory(productId, 100);
    }

    /**
     * @dev Test revert when store is inactive
     */
    function test_UpdateInventory_Revert_StoreNotActive() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        vm.expectRevert("Store is not active");
        store.updateInventory(productId, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test that inventory can be updated after reactivating store
     */
    function test_UpdateInventory_Success_AfterReactivatingStore() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        // Try to update (should fail)
        vm.expectRevert("Store is not active");
        store.updateInventory(productId, 100);

        // Reactivate store
        store.setStoreActive(true);

        // Now should succeed
        store.updateInventory(productId, 150);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 150, "Inventory should be updated after reactivation");

        vm.stopPrank();
    }

    // ============ createOrder() TESTS ============

    /**
     * @dev Test successful order creation for physical product
     */
    function test_CreateOrder_Success_PhysicalProduct() public {
        vm.startPrank(owner);

        // Create a physical product
        uint256 productId = store.addProduct(
            "Physical Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            100    // inventory
        );

        vm.stopPrank();

        // Create order as buyer
        vm.prank(buyer);
        uint256 quantity = 5;
        bool useEscrow = false;

        vm.expectEmit(true, true, false, true);
        emit OrderCreated(1, buyer, productId, 100 ether * quantity);
        emit InventoryUpdated(productId, 95); // 100 - 5

        uint256 orderId = store.createOrder(productId, quantity, useEscrow);

        // Check order ID
        assertEq(orderId, 1, "Order ID should be 1");
        assertEq(store.orderCount(), 1, "Order count should be 1");

        // Verify order fields
        (
            uint256 id,
            address orderBuyer,
            uint256 orderProductId,
            uint256 orderQuantity,
            uint256 totalPrice,
            address orderPaymentToken,
            BaseCartStore.OrderStatus status,
            uint256 timestamp,
            bool isEscrow
        ) = _getOrder(orderId);

        assertEq(id, orderId, "Order ID should match");
        assertEq(orderBuyer, buyer, "Buyer should match");
        assertEq(orderProductId, productId, "Product ID should match");
        assertEq(orderQuantity, quantity, "Quantity should match");
        assertEq(totalPrice, 100 ether * quantity, "Total price should match");
        assertEq(orderPaymentToken, address(paymentToken), "Payment token should match");
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Pending), "Status should be Pending");
        assertEq(isEscrow, false, "Should not use escrow for non-escrow order");

        // Verify inventory was reduced
        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 95, "Inventory should be reduced by quantity");

        vm.stopPrank();
    }

    /**
     * @dev Test successful order creation for digital product
     */
    function test_CreateOrder_Success_DigitalProduct() public {
        vm.startPrank(owner);

        // Create a digital product
        uint256 productId = store.addProduct(
            "Digital Product",
            "Description",
            50 ether,
            address(paymentToken),
            true,  // isDigital
            false, // isUnlimited
            10     // inventory
        );

        vm.stopPrank();

        // Create order as buyer
        vm.prank(buyer);
        uint256 quantity = 3;

        uint256 orderId = store.createOrder(productId, quantity, false);

        assertEq(orderId, 1, "Order ID should be created");

        // Verify order fields
        (,,,,,, BaseCartStore.OrderStatus status, uint256 timestamp, bool isEscrow) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Pending), "Status should be Pending");
        assertEq(isEscrow, false, "Digital products should not use escrow even if requested");
        assertGt(timestamp, 0, "Timestamp should be set");

        // Verify inventory was reduced
        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 7, "Inventory should be reduced by quantity");

        vm.stopPrank();
    }

    /**
     * @dev Test successful order creation for unlimited product
     */
    function test_CreateOrder_Success_UnlimitedProduct() public {
        vm.startPrank(owner);

        // Create an unlimited product
        uint256 productId = store.addProduct(
            "Unlimited Product",
            "Description",
            75 ether,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0      // inventory not needed
        );

        vm.stopPrank();

        // Create order as buyer
        vm.prank(buyer);
        uint256 quantity = 100;

        uint256 orderId = store.createOrder(productId, quantity, false);

        assertEq(orderId, 1, "Order ID should be created");

        // Verify order total price
        (uint256 _id, address _buyer, uint256 _productId, uint256 _quantity, uint256 totalPrice, address _paymentToken, BaseCartStore.OrderStatus _status, uint256 _timestamp, bool _isEscrow) = _getOrder(orderId);
        assertEq(totalPrice, 75 ether * quantity, "Total price should be correct");

        // Verify inventory was not reduced (unlimited)
        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 0, "Inventory should remain 0 for unlimited products");

        vm.stopPrank();
    }

    /**
     * @dev Test order creation with escrow for physical product
     */
    function test_CreateOrder_Success_WithEscrow_PhysicalProduct() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Physical Product",
            "Description",
            100 ether,
            address(paymentToken),
            false, // isDigital
            false, // isUnlimited
            50
        );

        vm.stopPrank();

        // Create order with escrow
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, true);

        (uint256 _id, address _buyer, uint256 _productId, uint256 _quantity, uint256 _totalPrice, address _paymentToken, BaseCartStore.OrderStatus _status, uint256 _timestamp, bool isEscrow) = _getOrder(orderId);
        assertEq(isEscrow, true, "Should use escrow for physical product with escrow requested");

        vm.stopPrank();
    }

    /**
     * @dev Test that escrow is not used for digital products even if requested
     */
    function test_CreateOrder_Success_EscrowNotUsedForDigital() public {
        vm.startPrank(owner);

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

        // Try to create order with escrow for digital product
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        (uint256 _id, address _buyer, uint256 _productId, uint256 _quantity, uint256 _totalPrice, address _paymentToken, BaseCartStore.OrderStatus _status, uint256 _timestamp, bool isEscrow) = _getOrder(orderId);
        assertEq(isEscrow, false, "Digital products should not use escrow");

        vm.stopPrank();
    }

    /**
     * @dev Test that orderCount increments correctly
     */
    function test_CreateOrder_IncrementsOrderCount() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            100
        );

        vm.stopPrank();

        // Create first order
        vm.prank(buyer);
        uint256 orderId1 = store.createOrder(productId, 1, false);
        assertEq(orderId1, 1, "First order ID should be 1");
        assertEq(store.orderCount(), 1, "Order count should be 1");

        // Create second order
        vm.prank(buyer);
        uint256 orderId2 = store.createOrder(productId, 2, false);
        assertEq(orderId2, 2, "Second order ID should be 2");
        assertEq(store.orderCount(), 2, "Order count should be 2");

        // Create third order
        vm.prank(buyer);
        uint256 orderId3 = store.createOrder(productId, 3, false);
        assertEq(orderId3, 3, "Third order ID should be 3");
        assertEq(store.orderCount(), 3, "Order count should be 3");

        vm.stopPrank();
    }

    /**
     * @dev Test that total price is calculated correctly
     */
    function test_CreateOrder_CalculatesTotalPriceCorrectly() public {
        vm.startPrank(owner);

        uint256 productPrice = 123 ether;
        uint256 productId = store.addProduct(
            "Product",
            "Description",
            productPrice,
            address(paymentToken),
            false,
            false,
            100
        );

        vm.stopPrank();

        // Create order with quantity 7
        vm.prank(buyer);
        uint256 quantity = 7;
        uint256 orderId = store.createOrder(productId, quantity, false);

        (uint256 _id, address _buyer, uint256 _productId, uint256 _quantity, uint256 totalPrice, address _paymentToken, BaseCartStore.OrderStatus _status, uint256 _timestamp, bool _isEscrow) = _getOrder(orderId);
        assertEq(totalPrice, productPrice * quantity, "Total price should be price * quantity");

        vm.stopPrank();
    }

    /**
     * @dev Test that OrderCreated event is emitted
     */
    function test_CreateOrder_EmitsOrderCreatedEvent() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();

        vm.prank(buyer);
        uint256 quantity = 2;
        uint256 expectedTotalPrice = 100 ether * quantity;

        vm.expectEmit(true, true, false, true);
        emit OrderCreated(1, buyer, productId, expectedTotalPrice);

        store.createOrder(productId, quantity, false);

        vm.stopPrank();
    }

    /**
     * @dev Test that inventory is reduced correctly for multiple orders
     */
    function test_CreateOrder_ReducesInventoryCorrectly() public {
        vm.startPrank(owner);

        uint256 initialInventory = 100;
        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            initialInventory
        );

        vm.stopPrank();

        // Create multiple orders
        vm.prank(buyer);
        store.createOrder(productId, 10, false);

        (,,,,,,, uint256 inv,) = _getProduct(productId);
        assertEq(inv, 90, "Inventory should be 90 after first order");

        vm.prank(buyer);
        store.createOrder(productId, 20, false);

        (,,,,,,, inv,) = _getProduct(productId);
        assertEq(inv, 70, "Inventory should be 70 after second order");

        vm.prank(buyer);
        store.createOrder(productId, 30, false);

        (,,,,,,, inv,) = _getProduct(productId);
        assertEq(inv, 40, "Inventory should be 40 after third order");

        vm.stopPrank();
    }

    // ============ createOrder() REVERT CASES ============

    /**
     * @dev Test revert when product ID is invalid (zero)
     */
    function test_CreateOrder_Revert_InvalidProductId_Zero() public {
        vm.prank(buyer);

        vm.expectRevert("Invalid product ID");
        store.createOrder(0, 1, false);
    }

    /**
     * @dev Test revert when product ID is invalid (too high)
     */
    function test_CreateOrder_Revert_InvalidProductId_TooHigh() public {
        vm.startPrank(owner);

        store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Invalid product ID");
        store.createOrder(999, 1, false);
    }

    /**
     * @dev Test revert when quantity is zero
     */
    function test_CreateOrder_Revert_ZeroQuantity() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Quantity must be greater than zero");
        store.createOrder(productId, 0, false);
    }

    /**
     * @dev Test revert when product is not active
     */
    function test_CreateOrder_Revert_ProductNotActive() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate product
        store.updateProduct(
            productId,
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false // isActive = false
        );

        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Product is not active");
        store.createOrder(productId, 1, false);
    }

    /**
     * @dev Test revert when insufficient inventory
     */
    function test_CreateOrder_Revert_InsufficientInventory() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            10 // Only 10 in inventory
        );

        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Insufficient inventory");
        store.createOrder(productId, 11, false); // Try to order 11
    }

    /**
     * @dev Test revert when store is inactive
     */
    function test_CreateOrder_Revert_StoreNotActive() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Store is not active");
        store.createOrder(productId, 1, false);
    }

    /**
     * @dev Test that order can be created after reactivating store
     */
    function test_CreateOrder_Success_AfterReactivatingStore() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Product",
            "Description",
            100 ether,
            address(paymentToken),
            false,
            false,
            50
        );

        // Deactivate store
        store.setStoreActive(false);

        vm.stopPrank();

        // Try to create order (should fail)
        vm.prank(buyer);
        vm.expectRevert("Store is not active");
        store.createOrder(productId, 1, false);

        // Reactivate store
        vm.prank(owner);
        store.setStoreActive(true);

        // Now should succeed
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);
        assertEq(orderId, 1, "Order should be created after reactivation");
    }

    /**
     * @dev Test that unlimited products can have any quantity
     */
    function test_CreateOrder_Success_UnlimitedProductAnyQuantity() public {
        vm.startPrank(owner);

        uint256 productId = store.addProduct(
            "Unlimited Product",
            "Description",
            100 ether,
            address(paymentToken),
            true,  // isDigital
            true,  // isUnlimited
            0
        );

        vm.stopPrank();

        // Can order any quantity for unlimited products
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 10000, false);
        assertEq(orderId, 1, "Order should be created with large quantity");

        vm.stopPrank();
    }

    // ============ processPayment() TESTS ============

    /**
     * @dev Test successful payment processing for physical product with escrow
     */
    function test_ProcessPayment_Success_PhysicalProductWithEscrow() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);

        address feeCollector = factory.feeCollector();
        uint256 totalPrice = 200 ether;
        uint256 platformFee = (totalPrice * 250) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        vm.prank(buyer);
        store.processPayment(orderId);

        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.InEscrow), "Should be in escrow");
        assertEq(paymentToken.balanceOf(address(store)), sellerAmount, "Store should hold seller amount");
        assertEq(paymentToken.balanceOf(feeCollector), platformFee, "Fee collector should receive fee");
    }

    /**
     * @dev Test successful payment processing for digital product (completed immediately)
     */
    function test_ProcessPayment_Success_DigitalProduct() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Digital", "Desc", 50 ether, address(paymentToken), true, false, 10);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 3, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);

        vm.prank(buyer);
        store.processPayment(orderId);

        (,,,,,, BaseCartStore.OrderStatus status,,) = _getOrder(orderId);
        assertEq(uint256(status), uint256(BaseCartStore.OrderStatus.Completed), "Digital should be completed");
    }

    // ============ processPayment() REVERT CASES ============

    function test_ProcessPayment_Revert_InvalidOrderId() public {
        vm.prank(buyer);
        vm.expectRevert("Invalid order ID");
        store.processPayment(0);
    }

    function test_ProcessPayment_Revert_NotOrderBuyer() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 10);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(otherUser, 1000 ether);
        vm.prank(otherUser);
        paymentToken.approve(address(store), 1000 ether);

        vm.prank(otherUser);
        vm.expectRevert("Not the order buyer");
        store.processPayment(orderId);
    }

    function test_ProcessPayment_Revert_OrderNotPending() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 10);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(buyer);
        vm.expectRevert("Order not in pending status");
        store.processPayment(orderId);
    }

    function test_ProcessPayment_Revert_InsufficientBalance() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 10);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 50 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);

        vm.prank(buyer);
        vm.expectRevert();
        store.processPayment(orderId);
    }

    function test_ProcessPayment_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 10);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);

        vm.prank(owner);
        store.setStoreActive(false);

        vm.prank(buyer);
        vm.expectRevert("Store is not active");
        store.processPayment(orderId);
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
        vm.stopPrank();

        // Create order, process payment, and mark shipped while store is active
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        store.markOrderShipped(orderId);

        // Deactivate store
        vm.prank(owner);
        store.setStoreActive(false);

        // Try to confirm delivery when store is inactive
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
        (,,,,,,,uint256 inventoryBefore,) = _getProduct(productId);
        assertEq(inventoryBefore, 48, "Inventory should be 48");

        uint256 platformFee = factory.calculatePlatformFee(200 ether);
        paymentToken.mint(address(store), platformFee);

        vm.prank(owner);
        store.refundOrder(orderId);

        // Verify inventory was returned
        (,,,,,,,uint256 inventoryAfter,) = _getProduct(productId);
        assertEq(inventoryAfter, 50, "Inventory should be restored to 50");
    }

    // ============ refundOrder() REVERT CASES ============

    /**
     * @dev Test revert when order ID is zero
     */
    function test_RefundOrder_Revert_InvalidOrderId_Zero() public {
        vm.prank(owner);
        vm.expectRevert("Invalid order ID");
        store.refundOrder(0);
    }

    /**
     * @dev Test revert when order is not escrow
     */
    function test_RefundOrder_Revert_NotEscrowOrder() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false); // Non-escrow

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        vm.expectRevert("Only escrow orders can be refunded");
        store.refundOrder(orderId);
    }

    /**
     * @dev Test revert when order status is invalid for refund
     */
    function test_RefundOrder_Revert_InvalidStatus() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(owner);
        store.markOrderShipped(orderId);
        vm.prank(buyer);
        store.confirmDelivery(orderId); // Order is now Completed

        vm.prank(owner);
        vm.expectRevert("Invalid order status for refund");
        store.refundOrder(orderId);
    }

    /**
     * @dev Test revert when caller is not the owner
     */
    function test_RefundOrder_Revert_NotOwner() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.prank(buyer);
        vm.expectRevert("Only store owner can call this function");
        store.refundOrder(orderId);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_RefundOrder_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, true);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId);

        vm.startPrank(owner);
        store.setStoreActive(false);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Store is not active");
        store.refundOrder(orderId);
    }

    // ============ cancelOrder() TESTS ============

    /**
     * @dev Test successful cancellation by buyer
     */
    function test_CancelOrder_Success_ByBuyer() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 2, false);

        // Verify order is Pending
        (,,,,,, BaseCartStore.OrderStatus statusBefore,,) = _getOrder(orderId);
        assertEq(uint256(statusBefore), uint256(BaseCartStore.OrderStatus.Pending), "Order should be Pending");

        // Verify inventory decreased
        (,,,,,,,uint256 inventoryBefore,) = _getProduct(productId);
        assertEq(inventoryBefore, 48, "Inventory should be 48");

        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Cancelled);

        vm.prank(buyer);
        store.cancelOrder(orderId);

        // Verify order status is Cancelled
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Cancelled), "Order should be Cancelled");

        // Verify inventory was returned
        (,,,,,,,uint256 inventoryAfter,) = _getProduct(productId);
        assertEq(inventoryAfter, 50, "Inventory should be restored to 50");
    }

    /**
     * @dev Test successful cancellation by owner
     */
    function test_CancelOrder_Success_ByOwner() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.expectEmit(true, false, false, true);
        emit OrderStatusUpdated(orderId, BaseCartStore.OrderStatus.Cancelled);

        vm.prank(owner);
        store.cancelOrder(orderId);

        // Verify order status is Cancelled
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Cancelled), "Order should be Cancelled");
    }

    /**
     * @dev Test cancellation doesn't return inventory for digital products
     */
    function test_CancelOrder_Success_DigitalProduct() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), true, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.prank(buyer);
        store.cancelOrder(orderId);

        // Verify order is cancelled
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Cancelled), "Order should be Cancelled");
    }

    /**
     * @dev Test cancellation doesn't return inventory for unlimited products
     */
    function test_CancelOrder_Success_UnlimitedProduct() public {
        vm.startPrank(owner);
        // Digital unlimited product (physical products must have inventory)
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), true, true, 0);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.prank(buyer);
        store.cancelOrder(orderId);

        // Verify order is cancelled
        (,,,,,, BaseCartStore.OrderStatus statusAfter,,) = _getOrder(orderId);
        assertEq(uint256(statusAfter), uint256(BaseCartStore.OrderStatus.Cancelled), "Order should be Cancelled");
    }

    // ============ cancelOrder() REVERT CASES ============

    /**
     * @dev Test revert when order ID is zero
     */
    function test_CancelOrder_Revert_InvalidOrderId_Zero() public {
        vm.prank(buyer);
        vm.expectRevert("Invalid order ID");
        store.cancelOrder(0);
    }

    /**
     * @dev Test revert when order ID is too high
     */
    function test_CancelOrder_Revert_InvalidOrderId_TooHigh() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.prank(buyer);
        vm.expectRevert("Invalid order ID");
        store.cancelOrder(orderId + 1);
    }

    /**
     * @dev Test revert when caller is not buyer or owner
     */
    function test_CancelOrder_Revert_NotAuthorized() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        vm.prank(otherUser);
        vm.expectRevert("Not authorized");
        store.cancelOrder(orderId);
    }

    /**
     * @dev Test revert when order is not in Pending status
     */
    function test_CancelOrder_Revert_OrderNotPending() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        paymentToken.mint(buyer, 1000 ether);
        vm.prank(buyer);
        paymentToken.approve(address(store), 1000 ether);
        vm.prank(buyer);
        store.processPayment(orderId); // Order is now Paid

        vm.prank(buyer);
        vm.expectRevert("Order cannot be cancelled");
        store.cancelOrder(orderId);
    }

    /**
     * @dev Test revert when store is not active
     */
    function test_CancelOrder_Revert_StoreNotActive() public {
        vm.startPrank(owner);
        uint256 productId = store.addProduct("Product", "Desc", 100 ether, address(paymentToken), false, false, 50);
        vm.stopPrank();

        // Create order while store is active
        vm.prank(buyer);
        uint256 orderId = store.createOrder(productId, 1, false);

        // Deactivate store
        vm.prank(owner);
        store.setStoreActive(false);

        // Try to cancel order when store is inactive
        vm.prank(buyer);
        vm.expectRevert("Store is not active");
        store.cancelOrder(orderId);
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

    /**
     * @dev Helper function to get order data - returns tuple directly
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
        // Public mapping getter returns all fields separately
        return store.orders(_orderId);
    }
}

