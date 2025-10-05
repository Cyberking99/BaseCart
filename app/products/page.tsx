"use client"

import type React from "react"

import { useState, useEffect } from "react"
import Link from "next/link"
import { ShoppingBag, Loader2, Search, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { getProducts } from "@/lib/contract"
import ProductCard from "@/components/product-card"

export default function ProductsPage() {
  const [products, setProducts] = useState<any[]>([])
  const [filteredProducts, setFilteredProducts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")

  useEffect(() => {
    async function loadProducts() {
      try {
        const productData = await getProducts()
        setProducts(productData)
        setFilteredProducts(productData)
      } catch (error) {
        console.error("Failed to load products:", error)
      } finally {
        setLoading(false)
      }
    }

    loadProducts()
  }, [])

  // Filter products based on search term
  useEffect(() => {
    if (searchTerm.trim() === "") {
      setFilteredProducts(products)
    } else {
      const filtered = products.filter((product) => product.name.toLowerCase().includes(searchTerm.toLowerCase()))
      setFilteredProducts(filtered)
    }
  }, [searchTerm, products])

  const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchTerm(e.target.value)
  }

  const clearSearch = () => {
    setSearchTerm("")
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-600 to-pink-500">
          Available Products
        </h1>
        <Link href="/">
          <Button variant="outline">Back to Home</Button>
        </Link>
      </div>

      <div className="relative mb-8">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search products..."
            value={searchTerm}
            onChange={handleSearch}
            className="pl-10 pr-10 bg-white dark:bg-gray-950 border-gray-200 dark:border-gray-800 focus-visible:ring-purple-500"
          />
          {searchTerm && (
            <button
              onClick={clearSearch}
              className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              aria-label="Clear search"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center items-center h-64">
          <Loader2 className="h-8 w-8 animate-spin text-purple-600" />
        </div>
      ) : filteredProducts.length === 0 ? (
        <div className="text-center py-12">
          {searchTerm ? (
            <>
              <Search className="h-12 w-12 mx-auto text-gray-400 mb-4" />
              <h2 className="text-2xl font-bold text-gray-500">No Results Found</h2>
              <p className="text-gray-400 mt-2">No products match "{searchTerm}"</p>
              <Button onClick={clearSearch} variant="outline" className="mt-4">
                Clear Search
              </Button>
            </>
          ) : (
            <>
              <ShoppingBag className="h-12 w-12 mx-auto text-gray-400 mb-4" />
              <h2 className="text-2xl font-bold text-gray-500">No Products Available</h2>
              <p className="text-gray-400 mt-2">Check back later for new products</p>
            </>
          )}
        </div>
      ) : (
        <>
          {searchTerm && (
            <div className="mb-4 flex items-center">
              <p className="text-sm text-gray-500">
                Showing {filteredProducts.length} {filteredProducts.length === 1 ? "result" : "results"} for "
                {searchTerm}"
              </p>
              <Button onClick={clearSearch} variant="ghost" size="sm" className="ml-2">
                <X className="h-3 w-3 mr-1" />
                Clear
              </Button>
            </div>
          )}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredProducts.map((product) => (
              <ProductCard key={product.id} product={product} searchTerm={searchTerm} />
            ))}
          </div>
        </>
      )}
    </div>
  )
}
