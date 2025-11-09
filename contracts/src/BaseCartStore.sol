// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BaseCartFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BaseCartStore
 * @dev Contract for individual BaseCart stores
 */
contract BaseCartStore is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Store information
    address public owner;
    address public factory;
    string public storeName;
    string public storeUrl;
    string public storeDescription;
    bool public isActive = true;
    
    // Product structure
    struct Product {
        uint256 id;
        string name;
        string description;
        uint256 price;
        address paymentToken; // USDC
        bool isDigital;
        bool isUnlimited; // For digital products with unlimited inventory
        uint256 inventory; // For physical products
        bool isActive;
    }
    
    // Order structure
    struct Order {
        uint256 id;
        address buyer;
        uint256 productId;
        uint256 quantity;
        uint256 totalPrice;
        address paymentToken;
        OrderStatus status;
        uint256 timestamp;
        bool isEscrow; // Whether the order uses escrow
    }
    
    // Order status enum
    enum OrderStatus {
        Pending,
        Paid,
        InEscrow,
        Shipped,
        Delivered,
        Completed,
        Refunded,
        Cancelled
    }
    
    // Revenue split structure
    struct RevenueSplit {
        address recipient;
        uint256 percentage; // In basis points (100 = 1%)
    }
    
    // Product data
    mapping(uint256 => Product) public products;
    uint256 public productCount;
    
    // Order data
    mapping(uint256 => Order) public orders;
    uint256 public orderCount;
    
    // Revenue splits for products
    mapping(uint256 => RevenueSplit[]) public productRevenueSplits;
    
    // Events
    event ProductAdded(uint256 indexed productId, string name, uint256 price, bool isDigital);
    event ProductUpdated(uint256 indexed productId, string name, uint256 price, bool isActive);
    event InventoryUpdated(uint256 indexed productId, uint256 newInventory);
    event OrderCreated(uint256 indexed orderId, address indexed buyer, uint256 productId, uint256 totalPrice);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus status);
    event RevenueSplitAdded(uint256 indexed productId, address recipient, uint256 percentage);
    event RevenueSplitRemoved(uint256 indexed productId, address recipient);
    event FundsWithdrawn(address indexed recipient, address token, uint256 amount);
    event StoreUpdated(string name, string url, string description);
    event EscrowReleased(uint256 indexed orderId, address indexed buyer, uint256 amount);
    event EscrowRefunded(uint256 indexed orderId, address indexed buyer, uint256 amount);
    
    /**
     * @dev Modifier to restrict function access to the store owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only store owner can call this function");
        _;
    }
    
    /**
     * @dev Modifier to check if the store is active
     */
    modifier storeActive() {
        require(isActive, "Store is not active");
        _;
    }
    
    /**
     * @dev Constructor to initialize the store
     * @param _owner Address of the store owner
     * @param _factory Address of the factory contract
     * @param _storeName Name of the store
     * @param _storeUrl URL suffix for the store
     * @param _storeDescription Description of the store
     */
    constructor(
        address _owner,
        address _factory,
        string memory _storeName,
        string memory _storeUrl,
        string memory _storeDescription
    ) {
        owner = _owner;
        factory = _factory;
        storeName = _storeName;
        storeUrl = _storeUrl;
        storeDescription = _storeDescription;
    }
    
    /**
     * @dev Adds a new product to the store
     * @param name Product name
     * @param description Product description
     * @param price Product price
     * @param paymentToken Address of the token used for payment
     * @param isDigital Whether the product is digital
     * @param isUnlimited Whether the product has unlimited inventory
     * @param inventory Initial inventory for physical products
     * @return The ID of the newly added product
     */
    function addProduct(
        string memory name,
        string memory description,
        uint256 price,
        address paymentToken,
        bool isDigital,
        bool isUnlimited,
        uint256 inventory
    ) external onlyOwner storeActive returns (uint256) {
        require(price > 0, "Price must be greater than zero");
        require(
            BaseCartFactory(factory).isTokenSupported(paymentToken),
            "Payment token not supported"
        );
        
        if (!isDigital) {
            require(inventory > 0, "Physical products must have inventory");
        }
        
        uint256 productId = productCount + 1;
        products[productId] = Product({
            id: productId,
            name: name,
            description: description,
            price: price,
            paymentToken: paymentToken,
            isDigital: isDigital,
            isUnlimited: isUnlimited,
            inventory: inventory,
            isActive: true
        });
        
        productCount = productId;
        
        emit ProductAdded(productId, name, price, isDigital);
        
        return productId;
    }
    
    /**
     * @dev Updates an existing product
     * @param productId ID of the product to update
     * @param name New product name
     * @param description New product description
     * @param price New product price
     * @param paymentToken New payment token address
     * @param isActive Whether the product is active
     */
    function updateProduct(
        uint256 productId,
        string memory name,
        string memory description,
        uint256 price,
        address paymentToken,
        bool _isActive
    ) external onlyOwner storeActive {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        require(price > 0, "Price must be greater than zero");
        require(
            BaseCartFactory(factory).isTokenSupported(paymentToken),
            "Payment token not supported"
        );
        
        Product storage product = products[productId];
        
        product.name = name;
        product.description = description;
        product.price = price;
        product.paymentToken = paymentToken;
        product.isActive = _isActive;
        
        emit ProductUpdated(productId, name, price, _isActive);
    }
    
    /**
     * @dev Updates the inventory of a product
     * @param productId ID of the product
     * @param newInventory New inventory amount
     */
    function updateInventory(uint256 productId, uint256 newInventory) external onlyOwner storeActive {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        
        Product storage product = products[productId];
        require(!product.isUnlimited, "Cannot update inventory for unlimited products");
        
        product.inventory = newInventory;
        
        emit InventoryUpdated(productId, newInventory);
    }
    
    /**
     * @dev Creates a new order
     * @param productId ID of the product to order
     * @param quantity Quantity to order
     * @param useEscrow Whether to use escrow for the order
     * @return The ID of the newly created order
     */
    function createOrder(
        uint256 productId,
        uint256 quantity,
        bool useEscrow
    ) external storeActive nonReentrant returns (uint256) {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        require(quantity > 0, "Quantity must be greater than zero");
        
        Product storage product = products[productId];
        require(product.isActive, "Product is not active");
        
        if (!product.isUnlimited) {
            require(product.inventory >= quantity, "Insufficient inventory");
            // Reduce inventory
            product.inventory -= quantity;
            emit InventoryUpdated(productId, product.inventory);
        }
        
        uint256 totalPrice = product.price * quantity;
        
        // Create the order
        uint256 orderId = orderCount + 1;
        orders[orderId] = Order({
            id: orderId,
            buyer: msg.sender,
            productId: productId,
            quantity: quantity,
            totalPrice: totalPrice,
            paymentToken: product.paymentToken,
            status: OrderStatus.Pending,
            timestamp: block.timestamp,
            isEscrow: useEscrow && !product.isDigital // Escrow only for physical products
        });
        
        orderCount = orderId;
        
        emit OrderCreated(orderId, msg.sender, productId, totalPrice);
        
        return orderId;
    }
    
    /**
     * @dev Processes payment for an order
     * @param orderId ID of the order to pay for
     */
    function processPayment(uint256 orderId) external storeActive nonReentrant {
        require(orderId > 0 && orderId <= orderCount, "Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.buyer == msg.sender, "Not the order buyer");
        require(order.status == OrderStatus.Pending, "Order not in pending status");
        
        Product storage product = products[order.productId];
        
        // Calculate platform fee
        uint256 platformFee = BaseCartFactory(factory).calculatePlatformFee(order.totalPrice);
        uint256 sellerAmount = order.totalPrice - platformFee;
        
        // Transfer payment token from buyer to this contract
        IERC20 paymentToken = IERC20(order.paymentToken);
        paymentToken.safeTransferFrom(msg.sender, address(this), order.totalPrice);
        
        // Transfer platform fee to fee collector
        address feeCollector = BaseCartFactory(factory).feeCollector();
        paymentToken.safeTransfer(feeCollector, platformFee);
        
        // Update order status
        if (order.isEscrow) {
            order.status = OrderStatus.InEscrow;
        } else {
            order.status = OrderStatus.Paid;
            
            // For digital products or non-escrow orders, distribute revenue immediately
            if (product.isDigital || !order.isEscrow) {
                _distributeRevenue(order.productId, sellerAmount, order.paymentToken);
                
                // Mark digital products as completed immediately
                if (product.isDigital) {
                    order.status = OrderStatus.Completed;
                }
            }
        }
        
        emit OrderStatusUpdated(orderId, order.status);
    }
    
    /**
     * @dev Marks an order as shipped
     * @param orderId ID of the order to mark as shipped
     */
    function markOrderShipped(uint256 orderId) external onlyOwner storeActive {
        require(orderId > 0 && orderId <= orderCount, "Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Paid || order.status == OrderStatus.InEscrow, "Invalid order status");
        
        Product storage product = products[order.productId];
        require(!product.isDigital, "Digital products cannot be shipped");
        
        order.status = OrderStatus.Shipped;
        
        emit OrderStatusUpdated(orderId, OrderStatus.Shipped);
    }
    
    /**
     * @dev Confirms delivery of an order (by buyer)
     * @param orderId ID of the order to confirm delivery
     */
    function confirmDelivery(uint256 orderId) external storeActive nonReentrant {
        require(orderId > 0 && orderId <= orderCount, "Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.buyer == msg.sender, "Not the order buyer");
        require(order.status == OrderStatus.Shipped, "Order not shipped");
        
        order.status = OrderStatus.Delivered;
        
        // If this was an escrow order, release the funds
        if (order.isEscrow) {
            uint256 platformFee = BaseCartFactory(factory).calculatePlatformFee(order.totalPrice);
            uint256 sellerAmount = order.totalPrice - platformFee;
            
            _distributeRevenue(order.productId, sellerAmount, order.paymentToken);
            
            emit EscrowReleased(orderId, order.buyer, sellerAmount);
        }
        
        order.status = OrderStatus.Completed;
        
        emit OrderStatusUpdated(orderId, OrderStatus.Completed);
    }
    
    /**
     * @dev Refunds an order (only for escrow orders)
     * @param orderId ID of the order to refund
     */
    function refundOrder(uint256 orderId) external onlyOwner storeActive nonReentrant {
        require(orderId > 0 && orderId <= orderCount, "Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.isEscrow, "Only escrow orders can be refunded");
        require(
            order.status == OrderStatus.InEscrow || order.status == OrderStatus.Shipped,
            "Invalid order status for refund"
        );
        
        // Return the funds to the buyer
        IERC20 paymentToken = IERC20(order.paymentToken);
        paymentToken.safeTransfer(order.buyer, order.totalPrice);
        
        // Update order status
        order.status = OrderStatus.Refunded;
        
        // If this was a physical product, return the inventory
        Product storage product = products[order.productId];
        if (!product.isDigital && !product.isUnlimited) {
            product.inventory += order.quantity;
            emit InventoryUpdated(order.productId, product.inventory);
        }
        
        emit EscrowRefunded(orderId, order.buyer, order.totalPrice);
        emit OrderStatusUpdated(orderId, OrderStatus.Refunded);
    }
    
    /**
     * @dev Cancels a pending order
     * @param orderId ID of the order to cancel
     */
    function cancelOrder(uint256 orderId) external storeActive {
        require(orderId > 0 && orderId <= orderCount, "Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.buyer == msg.sender || msg.sender == owner, "Not authorized");
        require(order.status == OrderStatus.Pending, "Order cannot be cancelled");
        
        // Update order status
        order.status = OrderStatus.Cancelled;
        
        // Return inventory for physical products
        Product storage product = products[order.productId];
        if (!product.isDigital && !product.isUnlimited) {
            product.inventory += order.quantity;
            emit InventoryUpdated(order.productId, product.inventory);
        }
        
        emit OrderStatusUpdated(orderId, OrderStatus.Cancelled);
    }
    
    /**
     * @dev Adds a revenue split for a product
     * @param productId ID of the product
     * @param recipient Address to receive a portion of the revenue
     * @param percentage Percentage of revenue in basis points (100 = 1%)
     */
    function addRevenueSplit(
        uint256 productId,
        address recipient,
        uint256 percentage
    ) external onlyOwner storeActive {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        require(recipient != address(0), "Invalid recipient address");
        require(percentage > 0 && percentage < 10000, "Invalid percentage");
        
        // Check total percentage doesn't exceed 100%
        RevenueSplit[] storage splits = productRevenueSplits[productId];
        uint256 totalPercentage = percentage;
        
        for (uint256 i = 0; i < splits.length; i++) {
            totalPercentage += splits[i].percentage;
        }
        
        require(totalPercentage <= 10000, "Total percentage exceeds 100%");
        
        // Add the new split
        splits.push(RevenueSplit({
            recipient: recipient,
            percentage: percentage
        }));
        
        emit RevenueSplitAdded(productId, recipient, percentage);
    }
    
    /**
     * @dev Removes a revenue split for a product
     * @param productId ID of the product
     * @param index Index of the split to remove
     */
    function removeRevenueSplit(uint256 productId, uint256 index) external onlyOwner storeActive {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        
        RevenueSplit[] storage splits = productRevenueSplits[productId];
        require(index < splits.length, "Invalid split index");
        
        address recipient = splits[index].recipient;
        
        // Remove the split by replacing it with the last one and popping
        if (index < splits.length - 1) {
            splits[index] = splits[splits.length - 1];
        }
        splits.pop();
        
        emit RevenueSplitRemoved(productId, recipient);
    }
    
    /**
     * @dev Updates store information
     * @param _storeName New store name
     * @param _storeUrl New store URL
     * @param _storeDescription New store description
     */
    function updateStoreInfo(
        string memory _storeName,
        string memory _storeUrl,
        string memory _storeDescription
    ) external onlyOwner {
        storeName = _storeName;
        storeUrl = _storeUrl;
        storeDescription = _storeDescription;
        
        emit StoreUpdated(_storeName, _storeUrl, _storeDescription);
    }
    
    /**
     * @dev Sets the active status of the store
     * @param _isActive New active status
     */
    function setStoreActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
    }
    
    /**
     * @dev Withdraws accumulated funds for the owner
     * @param token Address of the token to withdraw
     */
    function withdrawFunds(address token) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token address");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        
        tokenContract.safeTransfer(owner, balance);
        
        emit FundsWithdrawn(owner, token, balance);
    }
    
    /**
     * @dev Internal function to distribute revenue according to splits
     * @param productId ID of the product
     * @param amount Amount to distribute
     * @param token Token to distribute
     */
    function _distributeRevenue(uint256 productId, uint256 amount, address token) internal {
        RevenueSplit[] storage splits = productRevenueSplits[productId];
        
        if (splits.length == 0) {
            // If no splits, send everything to the owner
            IERC20(token).safeTransfer(owner, amount);
            return;
        }
        
        uint256 remainingAmount = amount;
        IERC20 tokenContract = IERC20(token);
        
        // Distribute according to splits
        for (uint256 i = 0; i < splits.length; i++) {
            uint256 splitAmount = (amount * splits[i].percentage) / 10000;
            if (splitAmount > 0) {
                tokenContract.safeTransfer(splits[i].recipient, splitAmount);
                remainingAmount -= splitAmount;
            }
        }
        
        // Send remaining amount to owner
        if (remainingAmount > 0) {
            tokenContract.safeTransfer(owner, remainingAmount);
        }
    }
    
    /**
     * @dev Gets all revenue splits for a product
     * @param productId ID of the product
     * @return Array of revenue splits
     */
    function getProductRevenueSplits(uint256 productId) external view returns (RevenueSplit[] memory) {
        require(productId > 0 && productId <= productCount, "Invalid product ID");
        return productRevenueSplits[productId];
    }
    
    /**
     * @dev Gets orders by buyer
     * @param buyer Address of the buyer
     * @param startIndex Start index for pagination
     * @param count Number of orders to return
     * @return Array of order IDs
     */
    function getOrdersByBuyer(
        address buyer,
        uint256 startIndex,
        uint256 count
    ) external view returns (uint256[] memory) {
        require(startIndex <= orderCount, "Invalid start index");
        
        // Count matching orders first
        uint256 matchCount = 0;
        for (uint256 i = 1; i <= orderCount; i++) {
            if (orders[i].buyer == buyer) {
                matchCount++;
            }
        }
        
        // Adjust count if needed
        if (count > matchCount) {
            count = matchCount;
        }
        
        // Create result array
        uint256[] memory result = new uint256[](count);
        uint256 resultIndex = 0;
        
        // Skip to startIndex
        uint256 skipped = 0;
        for (uint256 i = 1; i <= orderCount && resultIndex < count; i++) {
            if (orders[i].buyer == buyer) {
                if (skipped < startIndex) {
                    skipped++;
                } else {
                    result[resultIndex] = i;
                    resultIndex++;
                }
            }
        }
        
        return result;
    }
}
