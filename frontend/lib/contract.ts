import { ethers } from "ethers"

// ABI for the Storefront contract
const STOREFRONT_ABI = [
  "function usdc() external view returns (address)",
  "function productCount() external view returns (uint256)",
  "function products(uint256) external view returns (string, uint256, uint256)",
  "function escrows(address, uint256) external view returns (uint256, uint256, uint256, uint256, uint256, bool, bool)",
  "function addProduct(string memory, uint256, uint256) external",
  "function purchase(uint256, uint256) external",
  "function confirmDelivery(uint256) external",
  "function refund(uint256) external",
  "function getEscrows(address) external view returns (tuple(uint256, uint256, uint256, uint256, uint256, bool, bool)[])",
]

// ABI for ERC20 (USDC)
const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function approve(address, uint256) external returns (bool)",
  "function allowance(address, address) external view returns (uint256)",
]

const STOREFRONT_ADDRESS = "0x0000000000000000000000000000000000000000"

export async function getContract(withSigner = false) {
  if (typeof window === "undefined") {
    throw new Error("Window is undefined")
  }
  
  let provider: ethers.Provider
  
  if (window.ethereum) {
    provider = new ethers.BrowserProvider(window.ethereum)
  } else {
    throw new Error("No Ethereum provider found. Please connect a wallet.")
  }

  if (withSigner) {
    const signer = await provider.getSigner()
    return new ethers.Contract(STOREFRONT_ADDRESS, STOREFRONT_ABI, signer)
  }

  return new ethers.Contract(STOREFRONT_ADDRESS, STOREFRONT_ABI, provider)
}

export async function getUsdcContract(withSigner = false) {
  const contract = await getContract()
  const usdcAddress = await contract.usdc()

  if (typeof window === "undefined") {
    throw new Error("Window is undefined")
  }

  let provider: ethers.Provider
  
  if (window.ethereum) {
    provider = new ethers.BrowserProvider(window.ethereum)
  } else {
    throw new Error("No Ethereum provider found. Please connect a wallet.")
  }

  if (withSigner) {
    const signer = await provider.getSigner()
    return new ethers.Contract(usdcAddress, ERC20_ABI, signer)
  }

  return new ethers.Contract(usdcAddress, ERC20_ABI, provider)
}

export async function getProducts() {
  try {
    const contract = await getContract()
    const count = await contract.productCount()

    const products = []
    for (let i = 1; i <= count; i++) {
      const product = await contract.products(i)
      products.push({
        id: i,
        name: product[0],
        price: product[1],
        inventory: product[2],
      })
    }

    return products
  } catch (error) {
    console.error("Error fetching products:", error)
    return []
  }
}

export async function getEscrows(address: string) {
  try {
    const contract = await getContract()
    const escrows = await contract.getEscrows(address)

    return escrows.map((escrow: any, index: number) => ({
      index,
      productId: escrow[0],
      quantity: escrow[1],
      amount: escrow[2],
      timestamp: escrow[3],
      deadline: escrow[4],
      delivered: escrow[5],
      refunded: escrow[6],
    }))
  } catch (error) {
    console.error("Error fetching escrows:", error)
    return []
  }
}

export async function addProduct(name: string, price: number, inventory: number) {
  try {
    const contract = await getContract(true)
    const tx = await contract.addProduct(name, price, inventory)
    await tx.wait()
    return true
  } catch (error) {
    console.error("Error adding product:", error)
    return false
  }
}

export async function purchaseProduct(productId: number, quantity: number, price: number) {
  try {
    // First approve USDC transfer
    const usdcContract = await getUsdcContract(true)
    const totalPrice = price * quantity
    const approveTx = await usdcContract.approve(STOREFRONT_ADDRESS, totalPrice)
    await approveTx.wait()

    // Then purchase
    const contract = await getContract(true)
    const tx = await contract.purchase(productId, quantity)
    await tx.wait()
    return true
  } catch (error) {
    console.error("Error purchasing product:", error)
    return false
  }
}

export async function confirmDelivery(escrowIndex: number) {
  try {
    const contract = await getContract(true)
    const tx = await contract.confirmDelivery(escrowIndex)
    await tx.wait()
    return true
  } catch (error) {
    console.error("Error confirming delivery:", error)
    return false
  }
}

export async function requestRefund(escrowIndex: number) {
  try {
    const contract = await getContract(true)
    const tx = await contract.refund(escrowIndex)
    await tx.wait()
    return true
  } catch (error) {
    console.error("Error requesting refund:", error)
    return false
  }
}
