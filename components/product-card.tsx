"use client"

import { useState } from "react"
import { ShoppingCart, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { purchaseProduct } from "@/lib/contract"
import { useToast } from "@/hooks/use-toast"
import SearchHighlight from "@/components/search-highlight"

interface ProductCardProps {
  product: {
    id: number
    name: string
    price: number
    inventory: number
  }
  searchTerm?: string
}

export default function ProductCard({ product, searchTerm = "" }: ProductCardProps) {
  const [quantity, setQuantity] = useState(1)
  const [purchasing, setPurchasing] = useState(false)
  const { toast } = useToast()

  const handlePurchase = async () => {
    if (!window.ethereum) {
      toast({
        title: "Wallet Not Connected",
        description: "Please connect your wallet to make a purchase",
        variant: "destructive",
      })
      return
    }

    try {
      setPurchasing(true)
      const success = await purchaseProduct(product.id, quantity, product.price)

      if (success) {
        toast({
          title: "Purchase Successful",
          description: `You purchased ${quantity} ${product.name}`,
          variant: "default",
        })
      }
    } catch (error: any) {
      toast({
        title: "Purchase Failed",
        description: error.message || "Failed to complete purchase",
        variant: "destructive",
      })
    } finally {
      setPurchasing(false)
    }
  }

  // Format price to show in USDC with 6 decimals
  const formatPrice = (price: number) => {
    return (price / 1_000_000).toFixed(2)
  }

  return (
    <Card className="overflow-hidden border border-gray-200 dark:border-gray-800">
      <div className="relative h-48 bg-gradient-to-br from-purple-100 to-pink-100 dark:from-purple-950/30 dark:to-pink-950/30">
        <div className="absolute inset-0 flex items-center justify-center">
          <ShoppingCart className="h-16 w-16 text-purple-500/50" />
        </div>
      </div>
      <CardHeader>
        <CardTitle>
          <SearchHighlight text={product.name} searchTerm={searchTerm} />
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex justify-between items-center mb-4">
          <div className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-purple-600 to-pink-500">
            {formatPrice(product.price)} USDC
          </div>
          <div className="text-sm text-gray-500">{product.inventory} in stock</div>
        </div>
        <div className="flex items-center gap-2">
          <div className="text-sm font-medium">Quantity:</div>
          <Input
            type="number"
            min="1"
            max={product.inventory}
            value={quantity}
            onChange={(e) => setQuantity(Number.parseInt(e.target.value))}
            className="w-20"
          />
        </div>
      </CardContent>
      <CardFooter>
        <Button
          onClick={handlePurchase}
          disabled={purchasing || product.inventory === 0 || quantity > product.inventory}
          className="w-full bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600"
        >
          {purchasing ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Processing...
            </>
          ) : (
            <>
              <ShoppingCart className="mr-2 h-4 w-4" />
              Buy Now
            </>
          )}
        </Button>
      </CardFooter>
    </Card>
  )
}
