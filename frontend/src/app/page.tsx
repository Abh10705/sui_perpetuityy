'use client';

import { useState } from 'react';
import Link from 'next/link';

// Mock markets data
const MOCK_MARKETS = [
  {
    id: '1',
    title: 'Will AI achieve AGI before 2030?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.52,
    priceB: 0.48,
    volume24h: 12450,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365),
  },
  {
    id: '2',
    title: 'Will Bitcoin reach $100k in 2025?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.68,
    priceB: 0.32,
    volume24h: 8320,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30),
  },
  {
    id: '3',
    title: 'Will Sui TVL exceed $1B?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.45,
    priceB: 0.55,
    volume24h: 5150,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 90),
  },
  {
    id: '4',
    title: 'Will US pass AI regulation in 2025?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.35,
    priceB: 0.65,
    volume24h: 3890,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 60),
  },
  {
    id: '5',
    title: 'Will Ethereum reach $5k?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.42,
    priceB: 0.58,
    volume24h: 6720,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 120),
  },
  {
    id: '6',
    title: 'Will crypto market cap reach $5T?',
    optionA: 'Yes',
    optionB: 'No',
    priceA: 0.58,
    priceB: 0.42,
    volume24h: 4210,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 180),
  },
];

export default function HomePage() {
  const formatTimeRemaining = (endTime: Date) => {
    const now = new Date();
    const diff = endTime.getTime() - now.getTime();
    
    if (diff < 0) return 'Expired';
    
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days > 0) return `${days}d`;
    
    const hours = Math.floor(diff / (1000 * 60 * 60));
    if (hours > 0) return `${hours}h`;
    
    const minutes = Math.floor(diff / (1000 * 60));
    return `${minutes}m`;
  };

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
          <button className="px-6 py-2 bg-purple-600 hover:bg-purple-700 rounded-lg font-semibold transition-all">
            Connect Wallet
          </button>
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

        {/* Markets Section */}
        <div>
          <div className="flex items-center justify-between mb-8">
            <div>
              <h3 className="text-2xl font-bold">Active Markets</h3>
              <p className="text-gray-400 text-sm mt-1">{MOCK_MARKETS.length} markets available</p>
            </div>
            <Link href="/markets" className="text-purple-400 hover:text-purple-300 font-semibold">
              View All →
            </Link>
          </div>

          {/* Markets Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {MOCK_MARKETS.map((market) => (
              <Link href={`/markets/${market.id}`} key={market.id}>
                <div className="group h-full p-6 rounded-lg border border-gray-700 bg-gray-900 hover:border-purple-500 hover:bg-gray-800/50 transition-all cursor-pointer">
                  
                  {/* Title */}
                  <h4 className="text-lg font-semibold mb-4 group-hover:text-purple-400 transition-colors line-clamp-2">
                    {market.title}
                  </h4>

                  {/* Options with Prices */}
                  <div className="space-y-3 mb-6">
                    <div className="flex items-center justify-between">
                      <span className="text-gray-300">{market.optionA}</span>
                      <span className="font-mono text-green-400 font-semibold">
                        {(market.priceA * 100).toFixed(0)}¢
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-gray-300">{market.optionB}</span>
                      <span className="font-mono text-red-400 font-semibold">
                        {(market.priceB * 100).toFixed(0)}¢
                      </span>
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="border-t border-gray-700 pt-4 mb-4">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <p className="text-gray-500 text-xs">24h Volume</p>
                        <p className="text-white font-semibold">{market.volume24h.toLocaleString()} SUI</p>
                      </div>
                      <div>
                        <p className="text-gray-500 text-xs">Time Left</p>
                        <p className="text-white font-semibold">{formatTimeRemaining(market.endTime)}</p>
                      </div>
                    </div>
                  </div>

                  {/* CTA */}
                  <button className="w-full py-2 px-4 rounded-lg bg-purple-600 text-white font-semibold hover:bg-purple-700 transition-all group-hover:shadow-lg group-hover:shadow-purple-500/50">
                    Trade Now →
                  </button>
                </div>
              </Link>
            ))}
          </div>
        </div>

        {/* Footer CTA */}
        <div className="mt-20 text-center py-12 rounded-lg border border-gray-700 bg-gray-900/50">
          <h3 className="text-2xl font-bold mb-4">Ready to start?</h3>
          <p className="text-gray-400 mb-6">Connect your wallet and place your first trade</p>
          <button className="px-8 py-3 bg-purple-600 hover:bg-purple-700 rounded-lg font-semibold transition-all">
            Connect Wallet
          </button>
        </div>
      </div>
    </main>
  );
}