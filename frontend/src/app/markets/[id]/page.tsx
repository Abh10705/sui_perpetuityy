'use client';

import { use } from 'react';
import { OrderBook } from '@/components/OrderBook';
import { TradingPanel } from '@/components/TradingPanel';
import { MatchingDebug } from '@/components/MatchingDebug';

export default function MarketPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);

  return (
    <div className="min-h-screen bg-black">
      {/* Header */}
      <div className="border-b border-gray-700 bg-gray-900 py-8">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-start justify-between gap-4 md:flex-row md:items-center">
            <div>
              <h1 className="text-4xl font-bold text-white">Who wins? Barca vs Madrid</h1>
              <p className="mt-2 text-gray-400">Market ID: {id}</p>
            </div>
            <div className="flex gap-3">
              <button className="px-4 py-2 border border-gray-600 bg-gray-800 text-white rounded-lg hover:border-gray-500">Barca</button>
              <button className="px-4 py-2 border border-gray-600 bg-gray-800 text-white rounded-lg hover:border-gray-500">Madrid</button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid gap-8 lg:grid-cols-3">
          {/* OrderBook - Takes 2 columns on large screens */}
          <div className="lg:col-span-2">
            <OrderBook />
          </div>

          {/* Trading Panel - 1 column */}
          <div>
            <TradingPanel />
          </div>
        </div>

        {/* Matching Debug */}
        <MatchingDebug />

        {/* Info Section */}
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {/* Volume */}
          <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
            <h4 className="mb-2 text-sm text-gray-400">24h Volume</h4>
            <p className="text-3xl font-bold text-white">2,450 SUI</p>
            <p className="mt-2 text-xs text-green-400">+12.5% from yesterday</p>
          </div>

          {/* Spread */}
          <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
            <h4 className="mb-2 text-sm text-gray-400">Bid-Ask Spread</h4>
            <p className="text-3xl font-bold text-white">0.01 SUI</p>
            <p className="mt-2 text-xs text-gray-400">~0.02% of price</p>
          </div>

          {/* Positions */}
          <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
            <h4 className="mb-2 text-sm text-gray-400">Your Position</h4>
            <p className="text-3xl font-bold text-white">0</p>
            <p className="mt-2 text-xs text-gray-400">No active orders</p>
          </div>
        </div>

        {/* Recent Trades */}
        <div className="mt-8">
          <h2 className="mb-6 text-2xl font-bold">Recent Trades</h2>
          <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
            <div className="space-y-4">
              {/* Header */}
              <div className="grid grid-cols-4 gap-4 border-b border-gray-700 pb-4 text-sm font-semibold text-gray-400">
                <div>Price</div>
                <div>Quantity</div>
                <div>Side</div>
                <div>Time</div>
              </div>

              {/* Empty state */}
              <div className="py-8 text-center text-gray-500">
                No trades yet. Be the first to trade!
              </div>
            </div>
          </div>
        </div>

        {/* Market Info */}
        <div className="mt-8">
          <h2 className="mb-6 text-2xl font-bold">Market Details</h2>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="rounded-lg border border-gray-700 bg-gray-900 p-4">
              <h4 className="text-sm text-gray-400">Question</h4>
              <p className="mt-2 text-white">Who wins? Barca vs Madrid</p>
            </div>
            <div className="rounded-lg border border-gray-700 bg-gray-900 p-4">
              <h4 className="text-sm text-gray-400">Status</h4>
              <div className="mt-2 flex items-center gap-2">
                <div className="h-2 w-2 rounded-full bg-green-400" />
                <span className="text-white">Active</span>
              </div>
            </div>
            <div className="rounded-lg border border-gray-700 bg-gray-900 p-4">
              <h4 className="text-sm text-gray-400">Resolution Date</h4>
              <p className="mt-2 text-white">TBD</p>
            </div>
            <div className="rounded-lg border border-gray-700 bg-gray-900 p-4">
              <h4 className="text-sm text-gray-400">Total Volume</h4>
              <p className="mt-2 text-white">12,500 SUI</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
