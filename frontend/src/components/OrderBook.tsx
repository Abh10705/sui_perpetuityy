'use client';

import { useOrderBook } from '@/hooks/useOrderBook';

interface OrderBookProps {
  optionALabel: string;
  optionBLabel: string;
}

export function OrderBook({ optionALabel, optionBLabel }: OrderBookProps) {
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
        {/* TOP LEFT - Option A Bids */}
        <div className="card">
          <h3 className="font-bold text-blue-400 mb-3">
            {optionALabel} Bids ({orderbook.barcaBids.length})
          </h3>
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

        {/* TOP RIGHT - Option A Asks */}
        <div className="card">
          <h3 className="font-bold text-blue-400 mb-3">
            {optionALabel} Asks ({orderbook.barcaAsks.length})
          </h3>
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

        {/* BOTTOM LEFT - Option B Bids */}
        <div className="card">
          <h3 className="font-bold text-red-400 mb-3">
            {optionBLabel} Bids ({orderbook.madridBids.length})
          </h3>
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

        {/* BOTTOM RIGHT - Option B Asks */}
        <div className="card">
          <h3 className="font-bold text-red-400 mb-3">
            {optionBLabel} Asks ({orderbook.madridAsks.length})
          </h3>
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

      {/* Recent Trades (Using your UI style + Event Data) */}
      <div className="mt-8">
        <h2 className="mb-6 text-2xl font-bold">Recent Trades</h2>
        <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
          <div className="space-y-4">
            {/* Header */}
            <div className="grid grid-cols-4 gap-4 border-b border-gray-700 pb-4 text-sm font-semibold text-gray-400">
              <div>Price</div>
              <div>Quantity</div>
              <div>Asset</div>
              <div>Time</div>
            </div>

            {/* Empty state or Trades */}
            <div className="py-2 text-center text-gray-500">
              {!orderbook.recentTrades || orderbook.recentTrades.length === 0 ? (
                <div className="py-8 text-center text-gray-500">
                  No trades yet. Be the first to trade!
                </div>
              ) : (
                <div className="space-y-1 text-sm text-left">
                  {orderbook.recentTrades.map((t) => (
                    <div
                      key={t.id}
                      className="grid grid-cols-4 gap-4 py-2 border-b border-gray-800 last:border-b-0 items-center"
                    >
                      <div className="font-mono">${t.price.toFixed(2)}</div>
                      <div className="font-mono">{t.quantity}</div>
                      <div className={t.option === 'OptionA' ? 'text-blue-400 font-bold' : 'text-red-400 font-bold'}>
                        {t.option === 'OptionA' ? optionALabel : optionBLabel}
                      </div>
                      <div className="text-gray-500 text-xs">
                        {new Date(t.timestamp).toLocaleTimeString()}
                        <div className="mt-1">
                          ...{t.txDigest.slice(-6)}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}