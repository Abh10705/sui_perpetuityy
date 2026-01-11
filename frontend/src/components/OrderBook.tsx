'use client';

import { useOrderBook } from '@/hooks/useOrderBook';

export function OrderBook() {
  const { orderbook, loading, error } = useOrderBook();

  if (loading) return <div className="card p-4">Loading orderbook...</div>;
  if (error) return <div className="card p-4 text-red-500">Error: {error}</div>;
  if (!orderbook) return <div className="card p-4">No data</div>;

  const formatPrice = (price: number): string => {
    return price.toFixed(2);
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="card">
        <h2 className="text-xl font-bold mb-4">Order Book</h2>
      </div>

      {/* 4-Quadrant Layout */}
      <div className="grid grid-cols-2 gap-4">
        {/* TOP LEFT - Barca Bids */}
        <div className="card">
          <h3 className="font-bold text-blue-400 mb-3">Barca Bids ({orderbook.barcaBids.length})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.barcaBids.length > 0 ? (
              orderbook.barcaBids.map((bid) => (
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

        {/* TOP RIGHT - Barca Asks */}
        <div className="card">
          <h3 className="font-bold text-blue-400 mb-3">Barca Asks ({orderbook.barcaAsks.length})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.barcaAsks.length > 0 ? (
              orderbook.barcaAsks.map((ask) => (
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

        {/* BOTTOM LEFT - Madrid Bids */}
        <div className="card">
          <h3 className="font-bold text-red-400 mb-3">Madrid Bids ({orderbook.madridBids.length})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.madridBids.length > 0 ? (
              orderbook.madridBids.map((bid) => (
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

        {/* BOTTOM RIGHT - Madrid Asks */}
        <div className="card">
          <h3 className="font-bold text-red-400 mb-3">Madrid Asks ({orderbook.madridAsks.length})</h3>
          <div className="space-y-2 text-sm">
            {orderbook.madridAsks.length > 0 ? (
              orderbook.madridAsks.map((ask) => (
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
