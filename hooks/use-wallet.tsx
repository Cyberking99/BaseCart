"use client"

import { createContext, useContext, useState, useEffect, ReactNode } from "react"
import { createAppKit } from "@reown/appkit/react"
// import { base, baseSepolia } from "viem/chains"
import { base, baseSepolia } from "@reown/appkit/networks"
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi"
import type { AppKitNetwork } from "@reown/appkit/networks"

// Get project ID from environment variables
const PROJECT_ID = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || ""

export const networks: [AppKitNetwork, ...AppKitNetwork[]] = [base, baseSepolia]

const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId: PROJECT_ID,
  ssr: true,
})

// Configure AppKit
const appKit = createAppKit({
  adapters: [wagmiAdapter],
  projectId: PROJECT_ID,
  networks: [base, baseSepolia],
  metadata: {
    name: "BaseCart",
    description: "Secure Escrow Shopping on Base",
    url: typeof window !== "undefined" ? window.location.origin : "",
    icons: ["/placeholder-logo.png"]
  },
  features: {
    analytics: true,
  }
})

interface WalletContextType {
  account: string | null
  isConnected: boolean
  isReady: boolean
  isPending: boolean
  connect: () => Promise<void>
  disconnect: () => Promise<void>
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

function WalletProviderInner({ children }: { children: ReactNode }) {
  const [account, setAccount] = useState<string | null>(null)
  const [isReady, setIsReady] = useState(false)

  const connect = async () => {
    try {
      // Open the AppKit modal
      await appKit.open()
    } catch (error) {
      console.error("Error connecting:", error)
      throw error
    }
  }

  const disconnect = async () => {
    try {
      await appKit.disconnect()
      setAccount(null)
    } catch (error) {
      console.error("Error disconnecting:", error)
      throw error
    }
  }

  useEffect(() => {
    // Check if wallet is already connected on mount
    const checkConnection = async () => {
      try {
        if (typeof window !== "undefined" && window.ethereum) {
          const accounts = await window.ethereum.request({ method: "eth_accounts" })
          if (accounts.length > 0) {
            setAccount(accounts[0])
          }
        }
      } catch (error) {
        console.error("Error checking wallet connection:", error)
      }
      setIsReady(true)
    }

    checkConnection()
  }, [])

  return (
    <WalletContext.Provider value={{
      account,
      isConnected: !!account,
      isReady,
      isPending: false,
      connect,
      disconnect
    }}>
      {children}
    </WalletContext.Provider>
  )
}

export function WalletProvider({ children }: { children: ReactNode }) {
  return (
    <WalletProviderInner>
      {children}
    </WalletProviderInner>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider')
  }
  return context
}
