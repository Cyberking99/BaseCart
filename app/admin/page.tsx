"use client"

import type React from "react"

import { useState, useEffect } from "react"
import Link from "next/link"
import { PlusCircle, ShieldAlert, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { addProduct, getProducts } from "@/lib/contract"
import { useToast } from "@/hooks/use-toast"

export default function AdminPage() {
  const [products, setProducts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [isOwner, setIsOwner] = useState(false)
  const [formData, setFormData] = useState({
    name: "",
    price: "",
    inventory: "",
  })
  const [submitting, setSubmitting] = useState(false)
  const { toast } = useToast()

  useEffect(() => {
    // In a real app, you would check if the connected wallet is the owner
    // For demo purposes, we'll just set it to true
    setIsOwner(true)

    async function loadProducts() {
      try {
        const productData = await getProducts()
        setProducts(productData)
      } catch (error) {
        console.error("Failed to load products:", error)
      } finally {
        setLoading(false)
      }
    }

    loadProducts()
  }, [])

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setFormData({
      ...formData,
      [name]: value,
    })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!formData.name || !formData.price || !formData.inventory) {
      toast({
        title: "Missing Fields",
        description: "Please fill in all fields",
        variant: "destructive",
      })
      return
    }

    try {
      setSubmitting(true)

      // Convert price to USDC with 6 decimals
      const priceInUSDC = Math.floor(Number.parseFloat(formData.price) * 1_000_000)

      const success = await addProduct(formData.name, priceInUSDC, Number.parseInt(formData.inventory))

      if (success) {
        toast({
          title: "Product Added",
          description: `${formData.name} has been added to the store`,
        })

        // Reset form
        setFormData({
          name: "",
          price: "",
          inventory: "",
        })

        // Refresh products
        const productData = await getProducts()
        setProducts(productData)
      }
    } catch (error: any) {
      toast({
        title: "Failed to Add Product",
        description: error.message || "An error occurred while adding the product",
        variant: "destructive",
      })
    } finally {
      setSubmitting(false)
    }
  }

  // Format price to show in USDC with 6 decimals
  const formatPrice = (price: number) => {
    return (price / 1_000_000).toFixed(2)
  }

  if (!isOwner) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-center items-center h-64">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ShieldAlert className="h-5 w-5 text-red-500" />
                Access Denied
              </CardTitle>
              <CardDescription>Only the store owner can access this page</CardDescription>
            </CardHeader>
            <CardFooter>
              <Link href="/" className="w-full">
                <Button variant="outline" className="w-full">
                  Back to Home
                </Button>
              </Link>
            </CardFooter>
          </Card>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-600 to-pink-500">
          Admin Dashboard
        </h1>
        <Link href="/">
          <Button variant="outline">Back to Home</Button>
        </Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <Card>
          <CardHeader>
            <CardTitle>Add New Product</CardTitle>
            <CardDescription>Add a new product to your storefront</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Product Name</Label>
                <Input
                  id="name"
                  name="name"
                  placeholder="Premium Headphones"
                  value={formData.name}
                  onChange={handleInputChange}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="price">Price (USDC)</Label>
                <Input
                  id="price"
                  name="price"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="199.99"
                  value={formData.price}
                  onChange={handleInputChange}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="inventory">Inventory</Label>
                <Input
                  id="inventory"
                  name="inventory"
                  type="number"
                  min="1"
                  placeholder="10"
                  value={formData.inventory}
                  onChange={handleInputChange}
                  required
                />
              </div>
              <Button
                type="submit"
                disabled={submitting}
                className="w-full bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600"
              >
                {submitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Adding Product...
                  </>
                ) : (
                  <>
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Add Product
                  </>
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Current Products</CardTitle>
            <CardDescription>Manage your existing products</CardDescription>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex justify-center items-center h-32">
                <Loader2 className="h-8 w-8 animate-spin text-purple-600" />
              </div>
            ) : products.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-500">No products available</p>
              </div>
            ) : (
              <div className="space-y-4">
                {products.map((product) => (
                  <div key={product.id} className="flex justify-between items-center p-4 border rounded-lg">
                    <div>
                      <h3 className="font-medium">{product.name}</h3>
                      <div className="text-sm text-gray-500">{product.inventory} in stock</div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold">{formatPrice(product.price)} USDC</div>
                      <div className="text-sm text-gray-500">ID: {product.id}</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
