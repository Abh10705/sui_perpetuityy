'use client';

import { useOrderBook } from '@/hooks/useOrderBook';

export function OrderBook() {
  const { orderbook, loading, error } = useOrderBook();

  if (loading) return <div className="card p-4">Loading orderbook...</div>;
  if (error) return <div className="card p-4 text-red-500">Error: {error}</div>;
  if (!orderbook) return <div className="card p-4">No data</div>;

  // Helper to convert MIST to SUI with proper formatting
  const formatPrice = (mistValue: number): string => {
    const sui = mistValue / 1e9; // Convert MIST to SUI
    return sui.toFixed(6); // Show 6 decimals
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="card">
        <h2 className="text-xl font-bold mb-4">Order Book</h2>
        
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-sm text-gray-400">Top Bid</p>
            <p className="text-lg font-bold text-green-400">
              {orderbook.topBid > 0 ? `$${formatPrice(orderbook.topBid)}` : '$0.000000'}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Top Ask</p>
            <p className="text-lg font-bold text-red-400">
              {orderbook.topAsk > 0 ? `$${formatPrice(orderbook.topAsk)}` : '$0.000000'}
            </p>
          </div>
        </div>
      </div>

      {/* Bids/Asks */}
      <div className="grid grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-green-400 mb-3">Bids ({orderbook.bidDepth})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.bids.length > 0 ? (
              orderbook.bids.map((bid) => (
                <div key={bid.order_id} className="flex justify-between">
                  <span>${formatPrice(bid.price)}</span>
                  <span>{bid.quantity - bid.filled_quantity}</span>
                </div>
              ))
            ) : (
              <p className="text-gray-500">No bids</p>
            )}
          </div>
        </div>

        <div className="card">
          <h3 className="font-bold text-red-400 mb-3">Asks ({orderbook.askDepth})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.asks.length > 0 ? (
              orderbook.asks.map((ask) => (
                <div key={ask.order_id} className="flex justify-between">
                  <span>${formatPrice(ask.price)}</span>
                  <span>{ask.quantity - ask.filled_quantity}</span>
                </div>
              ))
            ) : (
              <p className="text-gray-500">No asks</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
