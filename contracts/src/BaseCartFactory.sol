// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BaseCartStore.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BaseCartFactory
 * @dev Factory contract for creating and managing BaseCart stores
 */
contract BaseCartFactory is Ownable {
    // Fee configuration
    uint256 public platformFeePercentage = 250; // 2.5% (using basis points: 100 = 1%)
    address public feeCollector;
    
    // Mapping from store owner to their stores
    mapping(address => address[]) private storesByOwner;
    
    // All stores created through this factory
    address[] public allStores;
    
    // Mapping to check if an address is a valid store
    mapping(address => bool) public isValidStore;
    
    // Supported tokens (stablecoins)
    mapping(address => bool) public supportedTokens;
    
    // Events
    event StoreCreated(address indexed owner, address storeAddress, string storeName, string storeUrl);
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    event TokenSupportAdded(address token);
    event TokenSupportRemoved(address token);

    /**
     * @dev Constructor sets the fee collector to the contract deployer
     */
    constructor() {
        feeCollector = msg.sender;
    }
    
    /**
     * @dev Creates a new BaseCart store
     * @param storeName Name of the store
     * @param storeUrl URL suffix for the store
     * @param storeDescription Description of the store
     * @return The address of the newly created store
     */
    function createStore(
        string memory storeName,
        string memory storeUrl,
        string memory storeDescription
    ) external returns (address) {
        BaseCartStore newStore = new BaseCartStore(
            msg.sender,
            address(this),
            storeName,
            storeUrl,
            storeDescription
        );
        
        address storeAddress = address(newStore);
        
        // Register the store
        storesByOwner[msg.sender].push(storeAddress);
        allStores.push(storeAddress);
        isValidStore[storeAddress] = true;
        
        emit StoreCreated(msg.sender, storeAddress, storeName, storeUrl);
        
        return storeAddress;
    }
    
    /**
     * @dev Returns all stores owned by a specific address
     * @param owner The address of the store owner
     * @return Array of store addresses owned by the specified address
     */
    function getStoresByOwner(address owner) external view returns (address[] memory) {
        return storesByOwner[owner];
    }
    
    /**
     * @dev Returns the total number of stores created
     * @return The total number of stores
     */
    function getTotalStores() external view returns (uint256) {
        return allStores.length;
    }
    
    /**
     * @dev Updates the platform fee percentage
     * @param newFeePercentage New fee percentage in basis points (100 = 1%)
     */
    function updatePlatformFee(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }
    
    /**
     * @dev Updates the fee collector address
     * @param newFeeCollector New address to collect fees
     */
    function updateFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Invalid address");
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(newFeeCollector);
    }
    
    /**
     * @dev Adds support for a token (stablecoin)
     * @param token Address of the token to support
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
        emit TokenSupportAdded(token);
    }
    
    /**
     * @dev Removes support for a token
     * @param token Address of the token to remove support for
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenSupportRemoved(token);
    }
    
    /**
     * @dev Calculates the platform fee for a given amount
     * @param amount The amount to calculate the fee for
     * @return The fee amount
     */
    function calculatePlatformFee(uint256 amount) public view returns (uint256) {
        return (amount * platformFeePercentage) / 10000;
    }
    
    /**
     * @dev Checks if a token is supported
     * @param token The token address to check
     * @return True if the token is supported, false otherwise
     */
    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }
}
