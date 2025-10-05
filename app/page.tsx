import Link from "next/link"
import { ArrowRight, ShoppingBag, Shield, Clock } from "lucide-react"
import { Button } from "@/components/ui/button"
import ConnectWallet from "@/components/connect-wallet"

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      <header className="px-4 lg:px-6 h-16 flex items-center justify-between border-b">
        <Link href="/" className="flex items-center gap-2 font-bold text-xl">
          <ShoppingBag className="h-6 w-6" />
          <span className="bg-clip-text text-transparent bg-gradient-to-r from-purple-600 to-pink-500">
            BaseCart
          </span>
        </Link>
        <nav className="hidden md:flex gap-6">
          <Link href="/products" className="text-sm font-medium hover:underline underline-offset-4">
            Products
          </Link>
          <Link href="/dashboard" className="text-sm font-medium hover:underline underline-offset-4">
            Dashboard
          </Link>
          <Link href="/admin" className="text-sm font-medium hover:underline underline-offset-4">
            Admin
          </Link>
        </nav>
        <div className="flex items-center gap-4">
          <ConnectWallet />
        </div>
      </header>
      <main className="flex-1">
        <section className="w-full py-12 md:py-24 lg:py-32 xl:py-48">
          <div className="container px-4 md:px-6">
            <div className="grid gap-6 lg:grid-cols-2 lg:gap-12 xl:grid-cols-2">
              <div className="flex flex-col justify-center space-y-4">
                <div className="space-y-2">
                  <h1 className="text-3xl font-bold tracking-tighter sm:text-5xl xl:text-6xl/none bg-clip-text text-transparent bg-gradient-to-r from-purple-600 via-blue-500 to-pink-500">
                    Secure Escrow Shopping on Base. Empowering Commerce, On-Chain
                  </h1>
                  <p className="max-w-[600px] text-gray-500 md:text-xl dark:text-gray-400">
                    Shop with confidence using our escrow-based storefront. Your funds are secure until you confirm
                    delivery.
                  </p>
                </div>
                <div className="flex flex-col gap-2 min-[400px]:flex-row">
                  <Link href="/products">
                    <Button className="bg-gradient-to-r from-purple-600 to-pink-500 hover:from-purple-700 hover:to-pink-600">
                      Browse Products
                      <ArrowRight className="ml-2 h-4 w-4" />
                    </Button>
                  </Link>
                  <Link href="/dashboard">
                    <Button variant="outline">View Your Orders</Button>
                  </Link>
                </div>
              </div>
              <div className="flex items-center justify-center">
                <div className="relative w-full h-[350px] md:h-[450px] bg-gradient-to-br from-purple-100 via-blue-100 to-pink-100 dark:from-purple-950/30 dark:via-blue-950/30 dark:to-pink-950/30 rounded-lg overflow-hidden">
                  <div className="absolute inset-0 flex items-center justify-center">
                    <ShoppingBag className="h-32 w-32 text-purple-500/50" />
                  </div>
                  <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-background/80 to-background/0 p-6">
                    <div className="flex items-center justify-between">
                      <div>
                        <div className="text-sm font-medium">Featured Product</div>
                        <div className="text-2xl font-bold">Premium Headphones</div>
                      </div>
                      <div className="text-2xl font-bold">$199 USDC</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <section className="w-full py-12 md:py-24 lg:py-32 bg-gradient-to-br from-purple-50 to-pink-50 dark:from-purple-950/10 dark:to-pink-950/10">
          <div className="container px-4 md:px-6">
            <div className="flex flex-col items-center justify-center space-y-4 text-center">
              <div className="space-y-2">
                <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl bg-clip-text text-transparent bg-gradient-to-r from-purple-600 to-pink-500">
                  How It Works
                </h2>
                <p className="max-w-[900px] text-gray-500 md:text-xl/relaxed lg:text-base/relaxed xl:text-xl/relaxed dark:text-gray-400">
                  Our decentralized storefront uses smart contracts to ensure secure transactions
                </p>
              </div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-12">
              <div className="flex flex-col items-center space-y-2 border p-6 rounded-lg bg-white dark:bg-gray-950">
                <div className="p-3 rounded-full bg-gradient-to-br from-purple-500 to-pink-500">
                  <ShoppingBag className="h-6 w-6 text-white" />
                </div>
                <h3 className="text-xl font-bold">1. Browse & Purchase</h3>
                <p className="text-gray-500 dark:text-gray-400 text-center">
                  Browse our products and purchase using USDC on Base network
                </p>
              </div>
              <div className="flex flex-col items-center space-y-2 border p-6 rounded-lg bg-white dark:bg-gray-950">
                <div className="p-3 rounded-full bg-gradient-to-br from-blue-500 to-purple-500">
                  <Shield className="h-6 w-6 text-white" />
                </div>
                <h3 className="text-xl font-bold">2. Escrow Protection</h3>
                <p className="text-gray-500 dark:text-gray-400 text-center">
                  Your payment is held in escrow until you confirm delivery
                </p>
              </div>
              <div className="flex flex-col items-center space-y-2 border p-6 rounded-lg bg-white dark:bg-gray-950">
                <div className="p-3 rounded-full bg-gradient-to-br from-pink-500 to-blue-500">
                  <Clock className="h-6 w-6 text-white" />
                </div>
                <h3 className="text-xl font-bold">3. Confirm or Refund</h3>
                <p className="text-gray-500 dark:text-gray-400 text-center">
                  Confirm delivery to release payment or get refunded after 7 days
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>
      <footer className="flex flex-col gap-2 sm:flex-row py-6 w-full border-t px-4 md:px-6">
        <p className="text-xs text-gray-500 dark:text-gray-400">© 2025 CryptoStore. All rights reserved.</p>
        <nav className="sm:ml-auto flex gap-4 sm:gap-6">
          <Link href="#" className="text-xs hover:underline underline-offset-4">
            Terms of Service
          </Link>
          <Link href="#" className="text-xs hover:underline underline-offset-4">
            Privacy
          </Link>
        </nav>
      </footer>
    </div>
  )
}
