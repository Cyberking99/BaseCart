# BaseCart 🛒

A decentralized e-commerce platform built on the Base blockchain with secure escrow functionality. Shop with confidence using cryptocurrency while enjoying the security of smart contract-based escrow services.

![BaseCart Banner](https://via.placeholder.com/800x200/8B5CF6/FFFFFF?text=BaseCart+-+Secure+Escrow+Shopping+on+Base)

## ✨ Features

- **🔐 Secure Escrow System**: Smart contract-based escrow ensures safe transactions
- **💰 Cryptocurrency Payments**: Pay with USDC on Base blockchain
- **🌐 Multi-Wallet Support**: Connect with MetaMask, Trust Wallet, Coinbase Wallet, or WalletConnect
- **📱 Responsive Design**: Beautiful, modern UI that works on all devices
- **🛍️ Product Management**: Add, browse, and manage products
- **📊 Order Tracking**: Real-time order status and delivery confirmation
- **🔄 Refund System**: Automated refund processing for undelivered items
- **👤 User Dashboard**: Track your orders and transaction history

## 🏗️ Tech Stack

### Frontend
- **Next.js 15** - React framework with App Router
- **TypeScript** - Type-safe development
- **Tailwind CSS** - Utility-first CSS framework
- **Radix UI** - Accessible component primitives
- **Lucide React** - Beautiful icons

### Blockchain & Web3
- **Base Network** - Layer 2 Ethereum scaling solution
- **Ethers.js** - Ethereum library for smart contract interaction
- **Reown AppKit** - Wallet connection and management
- **Wagmi** - React hooks for Ethereum
- **Viem** - TypeScript interface for Ethereum

### Smart Contracts
- **Solidity** - Smart contract language
- **USDC** - Stablecoin for payments
- **Escrow System** - Secure transaction handling

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Git
- A Web3 wallet (MetaMask, Trust Wallet, etc.)
- **Foundry** (for smart contract testing) - See [Testing](#-testing) section for installation

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Cyberking99/BaseCart.git
   cd BaseCart
   ```

2. **Install dependencies**
   ```bash
   npm install
   # or
   yarn install
   ```

3. **Set up environment variables**
   Create a `.env.local` file in the root directory:
   ```env
   NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id_here
   ```

4. **Get your WalletConnect Project ID**
   - Visit [WalletConnect Cloud](https://cloud.walletconnect.com/)
   - Create a new project
   - Copy your Project ID to the `.env.local` file

5. **Configure the smart contract**
   Update the contract address in `lib/contract.ts`:
   ```typescript
   const STOREFRONT_ADDRESS = "your_deployed_contract_address"
   ```

6. **Start the development server**
   ```bash
   npm run dev
   # or
   yarn dev
   ```

7. **Open your browser**
   Navigate to [http://localhost:3000](http://localhost:3000)

## 📁 Project Structure

```
basecart/
├── contracts/            # Smart contracts (Foundry project)
│   ├── src/             # Solidity source files
│   │   ├── BaseCartFactory.sol
│   │   └── BaseCartStore.sol
│   ├── test/            # Test files
│   │   └── BaseCartStore.t.sol
│   ├── script/          # Deployment scripts
│   ├── lib/             # Dependencies (forge-std, openzeppelin-contracts)
│   └── foundry.toml     # Foundry configuration
├── frontend/             # Next.js frontend application
│   ├── app/             # Next.js App Router
│   │   ├── admin/       # Admin panel for product management
│   │   ├── dashboard/   # User dashboard for orders
│   │   ├── products/    # Product catalog
│   │   ├── globals.css  # Global styles
│   │   ├── layout.tsx   # Root layout
│   │   └── page.tsx     # Home page
│   ├── components/      # Reusable React components
│   │   ├── ui/         # Base UI components (Radix UI)
│   │   ├── connect-wallet.tsx
│   │   └── product-card.tsx
│   ├── hooks/          # Custom React hooks
│   │   ├── use-wallet.tsx
│   │   └── use-toast.ts
│   ├── lib/            # Utility libraries
│   │   ├── contract.ts # Smart contract interactions
│   │   └── utils.ts
│   └── public/         # Static assets
└── README.md           # This file
```

## 🔧 Configuration

### Wallet Setup

The application supports multiple wallet types:

- **MetaMask**: Browser extension
- **Trust Wallet**: Mobile and browser extension
- **Coinbase Wallet**: Browser extension
- **WalletConnect**: QR code connection for mobile wallets

### Smart Contract Configuration

Update the contract address and ABI in `lib/contract.ts`:

```typescript
const STOREFRONT_ADDRESS = "0x..." // Your deployed contract address
const STOREFRONT_ABI = [...] // Your contract ABI
```

### Network Configuration

The app is configured for Base network by default. To add other networks, update `hooks/use-wallet.tsx`:

```typescript
export const networks: [AppKitNetwork, ...AppKitNetwork[]] = [
  base,           // Base Mainnet
  baseSepolia,    // Base Testnet
  // Add more networks as needed
]
```

## 🛍️ Usage

### For Customers

1. **Connect Wallet**: Click "Connect Wallet" and choose your preferred wallet
2. **Browse Products**: Explore available products on the Products page
3. **Make Purchase**: Select products and complete payment in USDC
4. **Track Orders**: Monitor order status in your Dashboard
5. **Confirm Delivery**: Mark items as delivered once received
6. **Request Refunds**: Get automatic refunds for undelivered items

### For Admins

1. **Access Admin Panel**: Navigate to `/admin`
2. **Add Products**: Create new product listings
3. **Manage Inventory**: Update product quantities and prices
4. **Monitor Orders**: Track all customer orders and transactions

## 🔒 Security Features

- **Escrow Protection**: Funds are held in smart contracts until delivery confirmation
- **Automated Refunds**: Automatic refund processing for failed deliveries
- **Multi-signature Approvals**: Secure transaction validation
- **Smart Contract Auditing**: All contracts are designed for security

## 📝 Smart Contract

The BaseCart smart contract includes:

- **Product Management**: Add and manage product listings
- **Escrow System**: Secure payment holding mechanism
- **Order Processing**: Track order lifecycle
- **Refund System**: Automated refund processing
- **USDC Integration**: Stablecoin payment processing

### Contract Functions

- `addProduct(name, price, inventory)` - Add new products
- `purchase(productId, quantity)` - Make a purchase
- `confirmDelivery(escrowIndex)` - Confirm item delivery
- `refund(escrowIndex)` - Request a refund

## 🧪 Testing

The project includes comprehensive test coverage for all smart contract functions using Foundry.

### Prerequisites for Testing

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
   
   For more details, visit the [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation).

2. **Verify Installation**
   ```bash
   forge --version
   ```

### Setting Up Tests

1. **Navigate to the contracts directory**
   ```bash
   cd contracts
   ```

2. **Install dependencies**
   ```bash
   forge install foundry-rs/forge-std openzeppelin/openzeppelin-contracts
   ```
   
   This installs:
   - `forge-std` - Foundry's standard testing library
   - `openzeppelin-contracts` - OpenZeppelin contracts for testing

### Running Tests

1. **Run all tests**
   ```bash
   forge test
   ```
   
   This will run all test files in the `test/` directory.

2. **Run tests for a specific file**
   ```bash
   forge test --match-path test/BaseCartStore.t.sol
   ```

3. **Run tests matching a pattern**
   ```bash
   # Run all tests for addProduct function
   forge test --match-test test_AddProduct
   
   # Run all tests for createOrder function
   forge test --match-test test_CreateOrder
   
   # Run all tests for updateInventory function
   forge test --match-test test_UpdateInventory
   ```

4. **Run with verbose output**
   ```bash
   # Level 1: Print logs for failing tests
   forge test -v
   
   # Level 2: Print logs for all tests
   forge test -vv
   
   # Level 3: Print execution traces
   forge test -vvv
   
   # Level 4: Print execution traces and setup traces
   forge test -vvvv
   
   # Level 5: Print execution traces, setup traces, and stack traces
   forge test -vvvvv
   ```

5. **Run tests with gas reporting**
   ```bash
   forge test --gas-report
   ```

### Test Coverage

The test suite includes comprehensive coverage for:

#### Product Management Functions
- ✅ `addProduct` - 15 tests covering success cases, validation, and edge cases
- ✅ `updateProduct` - 12 tests covering field updates, validation, and access control
- ✅ `updateInventory` - 12 tests covering inventory management and restrictions

#### Order Management Functions
- ✅ `createOrder` - 18 tests covering order creation, inventory reduction, escrow handling, and validation

**Total: 59 tests** covering all core marketplace functions.

### Test Structure

Tests are organized in `contracts/test/BaseCartStore.t.sol` with the following structure:

```
BaseCartStoreTest
├── setUp()                    # Test setup and initialization
├── addProduct() Tests         # Product creation tests
│   ├── Success Cases
│   └── Revert Cases
├── updateProduct() Tests     # Product update tests
│   ├── Success Cases
│   └── Revert Cases
├── updateInventory() Tests    # Inventory management tests
│   ├── Success Cases
│   └── Revert Cases
├── createOrder() Tests       # Order creation tests
│   ├── Success Cases
│   └── Revert Cases
└── Helper Functions          # Utility functions for tests
```

### Example Test Output

```
[PASS] test_AddProduct_Success_WithValidInputs() (gas: 216818)
[PASS] test_CreateOrder_Success_PhysicalProduct() (gas: 413247)
[PASS] test_UpdateInventory_Success_PhysicalProduct() (gas: 217391)
Suite result: ok. 59 passed; 0 failed; 0 skipped
```

### Additional Testing Commands

- **Format code**: `forge fmt`
- **Build contracts**: `forge build`
- **Generate gas snapshots**: `forge snapshot`
- **Run specific test with detailed output**:
  ```bash
  forge test --match-test test_CreateOrder_Success_PhysicalProduct -vvv
  ```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow TypeScript best practices
- Use conventional commit messages
- Add tests for new features
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues:

1. **Check the Issues** tab on GitHub
2. **Create a new issue** with detailed information
3. **Join our Discord** community for real-time support

## 🙏 Acknowledgments

- **Base Network** - For providing fast, low-cost transactions
- **Reown** - For excellent wallet connection tools
- **Radix UI** - For accessible component primitives
- **Tailwind CSS** - For beautiful, utility-first styling

## 🔮 Roadmap

- [ ] **Multi-chain Support** - Expand to other EVM-compatible chains
- [ ] **NFT Integration** - Support for NFT-based products
- [ ] **Advanced Analytics** - Detailed sales and user analytics
- [ ] **Mobile App** - Native mobile application
- [ ] **API Integration** - RESTful API for third-party integrations
- [ ] **Advanced Escrow** - Multi-party escrow for complex transactions

---

**Built with ❤️ on Base Network**
