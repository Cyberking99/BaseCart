"use client"

import { createContext, useContext, useState, useEffect, ReactNode } from "react"
import { useAppKitWallet } from "@reown/appkit-wallet-button/react"

interface WalletContextType {
  account: string | null
  isConnected: boolean
  isReady: boolean
  isPending: boolean
  connect: () => Promise<void>
  disconnect: () => Promise<void>
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

export function WalletProvider({ children }: { children: ReactNode }) {
  const [account, setAccount] = useState<string | null>(null)

  const { data, error, isReady, isPending, connect: wcConnect } = useAppKitWallet({
    namespace: 'eip155',
    onSuccess(parsedCaipAddress) {
      // Extract address from CAIP format (eip155:1:0x...)
      const address = parsedCaipAddress?.address || parsedCaipAddress
      setAccount(address)
    },
    onError(error) {
      console.error("Connection error:", error)
    }
  })

  useEffect(() => {
    if (data?.address) {
      setAccount(data.address)
    } else if (!data) {
      setAccount(null)
    }
  }, [data])

  const connect = async () => {
    try {
      await wcConnect("walletConnect")
    } catch (error) {
      console.error("Error connecting:", error)
      throw error
    }
  }

  const disconnect = async () => {
    try {
      // For now, just clear the local state
      // The actual disconnect will be handled by the wallet
      setAccount(null)
    } catch (error) {
      console.error("Error disconnecting:", error)
      throw error
    }
  }

  return (
    <WalletContext.Provider value={{
      account,
      isConnected: !!data?.address,
      isReady: isReady || false,
      isPending: isPending || false,
      connect,
      disconnect
    }}>
      {children}
    </WalletContext.Provider>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider')
  }
  return context
}
