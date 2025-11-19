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

