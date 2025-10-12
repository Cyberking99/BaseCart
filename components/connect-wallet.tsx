"use client"

import { Button } from "@/components/ui/button"
import { Wallet } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { useWallet } from "@/hooks/use-wallet"

export default function ConnectWallet() {
  const { account, isReady, isPending, connect, disconnect } = useWallet()
  const { toast } = useToast()

  const handleConnect = async () => {
    try {
      await connect()
      toast({
        title: "Wallet Connected",
        description: `Connected to ${shortenAddress(account!)}`,
      })
    } catch (error: any) {
      console.error("Error connecting:", error)
      toast({
        title: "Connection Failed",
        description: error.message || "Failed to connect wallet",
        variant: "destructive",
      })
    }
  }

  const handleDisconnect = async () => {
    try {
      await disconnect()
      toast({
        title: "Wallet Disconnected",
        description: "Your wallet has been disconnected",
      })
    } catch (error: any) {
      console.error("Error disconnecting:", error)
      toast({
        title: "Disconnect Failed",
        description: "Failed to disconnect wallet",
        variant: "destructive",
      })
    }
  }

  const shortenAddress = (address: string) => {
    if (!address) return ""
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`
  }

  return (
    <div>
      {account ? (
        <Button variant="outline" onClick={handleDisconnect} className="flex items-center gap-2">
          <Wallet className="h-4 w-4" />
          {shortenAddress(account)}
        </Button>
      ) : (
        <Button
          onClick={handleConnect}
          disabled={!isReady || isPending}
          className="bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600"
        >
          <Wallet className="mr-2 h-4 w-4" />
          {!isReady ? "Loading..." : isPending ? "Connecting..." : "Connect Wallet"}
        </Button>
      )}
    </div>
  )
}
