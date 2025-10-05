"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { Package, Clock, CheckCircle, XCircle, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { getEscrows, getProducts, confirmDelivery, requestRefund } from "@/lib/contract"
import { useToast } from "@/hooks/use-toast"

export default function DashboardPage() {
  const [escrows, setEscrows] = useState<any[]>([])
  const [products, setProducts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [account, setAccount] = useState<string | null>(null)
  const { toast } = useToast()

  useEffect(() => {
    async function checkWallet() {
      if (typeof window.ethereum !== "undefined") {
        try {
          const accounts = await window.ethereum.request({ method: "eth_accounts" })
          if (accounts.length > 0) {
            setAccount(accounts[0])
          }
        } catch (error) {
          console.error("Error checking wallet:", error)
        }
      }
    }

    checkWallet()
  }, [])

  useEffect(() => {
    async function loadData() {
      if (!account) return

      try {
        setLoading(true)
        const [escrowData, productData] = await Promise.all([getEscrows(account), getProducts()])

        setEscrows(escrowData)
        setProducts(productData)
      } catch (error) {
        console.error("Failed to load data:", error)
      } finally {
        setLoading(false)
      }
    }

    if (account) {
      loadData()
    } else {
      setLoading(false)
    }
  }, [account])

  const handleConfirmDelivery = async (escrowIndex: number) => {
    try {
      const success = await confirmDelivery(escrowIndex)
      if (success) {
        toast({
          title: "Delivery Confirmed",
          description: "Payment has been released to the seller",
        })

        // Update the escrow status locally
        setEscrows(escrows.map((escrow, i) => (escrow.index === escrowIndex ? { ...escrow, delivered: true } : escrow)))
      }
    } catch (error: any) {
      toast({
        title: "Confirmation Failed",
        description: error.message || "Failed to confirm delivery",
        variant: "destructive",
      })
    }
  }

  const handleRequestRefund = async (escrowIndex: number) => {
    try {
      const success = await requestRefund(escrowIndex)
      if (success) {
        toast({
          title: "Refund Processed",
          description: "Your refund has been processed successfully",
        })

        // Update the escrow status locally
        setEscrows(escrows.map((escrow, i) => (escrow.index === escrowIndex ? { ...escrow, refunded: true } : escrow)))
      }
    } catch (error: any) {
      toast({
        title: "Refund Failed",
        description: error.message || "Failed to process refund. Deadline may not have been reached.",
        variant: "destructive",
      })
    }
  }

  // Format timestamp to readable date
  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString()
  }

  // Format price to show in USDC with 6 decimals
  const formatPrice = (price: number) => {
    return (price / 1_000_000).toFixed(2)
  }

  // Get product name by ID
  const getProductName = (productId: number) => {
    const product = products.find((p) => p.id === productId)
    return product ? product.name : `Product #${productId}`
  }

  // Check if deadline has passed
  const isDeadlinePassed = (deadline: number) => {
    return Date.now() > deadline * 1000
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-600 to-pink-500">
          Your Orders
        </h1>
        <Link href="/products">
          <Button className="bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600">
            Shop More
          </Button>
        </Link>
      </div>

      {loading ? (
        <div className="flex justify-center items-center h-64">
          <Loader2 className="h-8 w-8 animate-spin text-purple-600" />
        </div>
      ) : !account ? (
        <div className="text-center py-12">
          <Package className="h-12 w-12 mx-auto text-gray-400 mb-4" />
          <h2 className="text-2xl font-bold text-gray-500">Wallet Not Connected</h2>
          <p className="text-gray-400 mt-2 mb-6">Please connect your wallet to view your orders</p>
          <Button className="bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600">
            Connect Wallet
          </Button>
        </div>
      ) : escrows.length === 0 ? (
        <div className="text-center py-12">
          <Package className="h-12 w-12 mx-auto text-gray-400 mb-4" />
          <h2 className="text-2xl font-bold text-gray-500">No Orders Found</h2>
          <p className="text-gray-400 mt-2 mb-6">You haven't made any purchases yet</p>
          <Link href="/products">
            <Button className="bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600">
              Browse Products
            </Button>
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {escrows.map((escrow) => (
            <Card key={escrow.index} className="overflow-hidden">
              <CardHeader
                className={`
                ${
                  escrow.delivered
                    ? "bg-green-50 dark:bg-green-950/20"
                    : escrow.refunded
                      ? "bg-red-50 dark:bg-red-950/20"
                      : "bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-950/20 dark:to-pink-950/20"
                }
              `}
              >
                <CardTitle className="flex items-center gap-2">
                  {escrow.delivered ? (
                    <CheckCircle className="h-5 w-5 text-green-500" />
                  ) : escrow.refunded ? (
                    <XCircle className="h-5 w-5 text-red-500" />
                  ) : (
                    <Clock className="h-5 w-5 text-purple-500" />
                  )}
                  {getProductName(escrow.productId)}
                </CardTitle>
                <CardDescription>Order placed on {formatDate(escrow.timestamp)}</CardDescription>
              </CardHeader>
              <CardContent className="pt-6">
                <div className="grid gap-4">
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Quantity:</span>
                    <span>{escrow.quantity}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Total Amount:</span>
                    <span className="font-bold">{formatPrice(escrow.amount)} USDC</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Status:</span>
                    <span
                      className={`
                      ${escrow.delivered ? "text-green-500" : escrow.refunded ? "text-red-500" : "text-yellow-500"}
                    `}
                    >
                      {escrow.delivered ? "Delivered" : escrow.refunded ? "Refunded" : "In Escrow"}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Deadline:</span>
                    <span
                      className={
                        isDeadlinePassed(escrow.deadline) && !escrow.delivered && !escrow.refunded ? "text-red-500" : ""
                      }
                    >
                      {formatDate(escrow.deadline)}
                    </span>
                  </div>
                </div>
              </CardContent>
              <CardFooter className="flex gap-2">
                {!escrow.delivered && !escrow.refunded && (
                  <>
                    <Button
                      onClick={() => handleConfirmDelivery(escrow.index)}
                      className="flex-1 bg-gradient-to-r from-green-600 to-emerald-500 hover:from-green-700 hover:to-emerald-600"
                    >
                      Confirm Delivery
                    </Button>
                    <Button
                      onClick={() => handleRequestRefund(escrow.index)}
                      variant="outline"
                      className="flex-1"
                      disabled={!isDeadlinePassed(escrow.deadline)}
                    >
                      Request Refund
                    </Button>
                  </>
                )}
              </CardFooter>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
