'use client';

import dynamic from 'next/dynamic';
import Link from 'next/link';
import Image from 'next/image';
import { MARKETS } from '@/lib/constants';

// Dynamically import ConnectButton to avoid hydration mismatch
const ConnectButton = dynamic(
  () => import('@mysten/dapp-kit').then(mod => ({ default: mod.ConnectButton })),
  { ssr: false }
);

export default function HomePage() {
  return (
    <main className="min-h-screen bg-black text-white flex flex-col font-sans">
      <div className="max-w-6xl mx-auto w-full py-8 px-4 sm:px-6 lg:px-8 flex-grow">
        
        {/* Header - Updated with Bigger Logo & Text */}
        <header className="flex justify-between items-center mb-24 pt-6">
          <div className="flex items-center gap-5">
            {/* Logo Container: w-14 is 56px */}
            <div className="relative w-14 h-14">
              <Image 
                src="/logo.png" 
                alt="Perpetuity Logo" 
                width={56} 
                height={56} 
                className="object-contain"
                priority
              />
            </div>
            {/* Heading: text-4xl is much bolder */}
            <h1 className="text-4xl font-bold tracking-tight text-white">
              Perpetuity
            </h1>
          </div>
          <ConnectButton />
        </header>

        {/* Hero Section */}
        <div className="text-center mb-24">
          <h2 className="text-5xl md:text-6xl font-bold mb-6 tracking-tight">
            Trade Your Beliefs
          </h2>
          <p className="text-xl text-neutral-400 max-w-2xl mx-auto">
            The world&apos;s first perpetual market on Sui.
          </p>
        </div>

        {/* Debates Section */}
        <div className="mb-20">
          <h3 className="text-xl font-bold mb-8 text-neutral-200">Debates</h3>

          {/* GRID LAYOUT */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {MARKETS.map((market) => {
              // Placeholder percentage for UI demo. In real app, calculate from price.
              const percentage = 50; 

              return (
              <Link key={market.id} href={`/markets/${market.id}`}>
                <div className="group h-full flex flex-col justify-between p-6 rounded-2xl bg-neutral-900 hover:bg-neutral-800/80 transition-all cursor-pointer border border-neutral-800">
                  
                  {/* Card Top: Title & Percentage */}
                  <div className="flex justify-between items-start mb-6 gap-4">
                    <h4 className="text-lg font-bold text-white leading-snug">
                      {market.title}
                    </h4>
                    {/* Percentage Circle */}
                    <div className="flex-shrink-0 w-12 h-12 rounded-full border-2 border-neutral-700 flex items-center justify-center text-sm font-bold text-neutral-300">
                      {percentage}%
                    </div>
                  </div>

                  {/* Volume Icon */}
                  <div className="flex items-center gap-2 mb-8 text-neutral-500 text-sm font-medium">
                     <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                       <path d="M15.5 2A1.5 1.5 0 0014 3.5v13a1.5 1.5 0 001.5 1.5h1a1.5 1.5 0 001.5-1.5v-13A1.5 1.5 0 0016.5 2h-1zM9.5 6A1.5 1.5 0 008 7.5v9A1.5 1.5 0 009.5 18h1a1.5 1.5 0 001.5-1.5v-9A1.5 1.5 0 0010.5 6h-1zM3.5 10A1.5 1.5 0 002 11.5v5A1.5 1.5 0 003.5 18h1A1.5 1.5 0 006 16.5v-5A1.5 1.5 0 004.5 10h-1z" />
                     </svg>
                     <span>$1.2k Volume</span>
                  </div>

                  {/* YES / NO Buttons */}
                  <div className="grid grid-cols-2 gap-3 mt-auto">
                    <button className="bg-white text-black font-bold py-3 rounded-xl hover:bg-neutral-200 transition-colors">
                      barca
                    </button>
                    <button className="bg-neutral-800 text-white font-bold py-3 rounded-xl hover:bg-neutral-700 transition-colors border border-neutral-700">
                      madrid
                    </button>
                  </div>
                </div>
              </Link>
            )})}
          </div>
        </div>
      </div>

      {/* Simple Footer */}
      <footer className="py-12 text-center text-neutral-500 text-sm">
        <div className="mb-4 flex items-center justify-center gap-6 font-medium text-neutral-400">
          <a href="#" className="hover:text-white">Markets</a>
          <a href="#" className="hover:text-white">Twitter</a>
          <a href="#" className="hover:text-white">Discord</a>
        </div>
        © 2024 Perpetuity.
      </footer>
    </main>
  );
}