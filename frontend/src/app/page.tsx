'use client';

import dynamic from 'next/dynamic';
import Link from 'next/link';
import { MARKETS } from '@/lib/constants';
import { DebugOrderBook } from '@/components/DebugOrderBook';

// Dynamically import ConnectButton to avoid hydration mismatch
const ConnectButton = dynamic(
  () => import('@mysten/dapp-kit').then(mod => ({ default: mod.ConnectButton })),
  { ssr: false }
);

export default function HomePage() {
  const market = MARKETS[0];

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <header className="flex justify-between items-center mb-16 pb-8 border-b border-gray-700">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-purple-600 to-blue-600 flex items-center justify-center">
              <span className="text-lg font-bold">P</span>
            </div>
            <h1 className="text-3xl font-bold tracking-tight">Perpetuity</h1>
          </div>
          <ConnectButton />
        </header>

        {/* Hero Section */}
        <div className="text-center mb-16">
          <h2 className="text-6xl font-extrabold mb-4 bg-gradient-to-r from-purple-400 to-blue-400 bg-clip-text text-transparent">
            Trade Your Beliefs
          </h2>
          <p className="text-lg text-neutral-400 max-w-2xl mx-auto">
            Orderbook-based prediction markets on Sui. Buy and sell binary outcomes. 
            No AMM. Pure price discovery.
          </p>
        </div>

        {/* Market Section */}
        <div>
          <div className="flex items-center justify-between mb-8">
            <div>
              <h3 className="text-2xl font-bold">Active Market</h3>
              <p className="text-gray-400 text-sm mt-1">1 market available</p>
            </div>
          </div>

          {/* Single Market Card */}
          <Link href={`/markets/${market.id}`}>
            <div className="group max-w-md p-6 rounded-lg border border-gray-700 bg-gray-900 hover:border-purple-500 hover:bg-gray-800/50 transition-all cursor-pointer">
              
              {/* Title */}
              <h4 className="text-lg font-semibold mb-4 group-hover:text-purple-400 transition-colors">
                {market.title}
              </h4>

              {/* Options with Prices */}
              <div className="space-y-3 mb-6">
                <div className="flex items-center justify-between">
                  <span className="text-gray-300">{market.optionA}</span>
                  <span className="font-mono text-green-400 font-semibold">50¢</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-gray-300">{market.optionB}</span>
                  <span className="font-mono text-red-400 font-semibold">50¢</span>
                </div>
              </div>

              {/* Stats */}
              <div className="border-t border-gray-700 pt-4 mb-4">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-500 text-xs">Market ID</p>
                    <p className="text-white font-mono text-xs">{market.id}</p>
                  </div>
                  <div>
                    <p className="text-gray-500 text-xs">Status</p>
                    <p className="text-green-400 font-semibold">Active</p>
                  </div>
                </div>
              </div>

              {/* CTA */}
              <button className="w-full py-2 px-4 rounded-lg bg-purple-600 text-white font-semibold hover:bg-purple-700 transition-all group-hover:shadow-lg group-hover:shadow-purple-500/50">
                Trade Now →
              </button>
            </div>
          </Link>
        </div>

        {/* Debug OrderBook Section */}
        <div className="mt-16">
          <h3 className="text-2xl font-bold mb-4">Debug Info</h3>
          <DebugOrderBook />
        </div>

        {/* Footer CTA */}
        <div className="mt-20 text-center py-12 rounded-lg border border-gray-700 bg-gray-900/50">
          <h3 className="text-2xl font-bold mb-4">Ready to start trading?</h3>
          <p className="text-gray-400 mb-6">Connect your wallet above to place your first order</p>
        </div>
      </div>
    </main>
  );
}
