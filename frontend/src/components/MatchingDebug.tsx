'use client';

import { useOrderBook } from '@/hooks/useOrderBook';

export function MatchingDebug() {
  const { orderbook } = useOrderBook();

  if (!orderbook) return null;

  return (
    <div className="mt-8 p-4 bg-gray-800 rounded">
      <h3 className="text-lg font-bold mb-4">Matching Analysis</h3>
      
      <div className="space-y-4">
        <div>
          <h4 className="font-bold text-green-400 mb-2">Bid Orders (Buyers):</h4>
          {orderbook.bids.map(bid => (
            <div key={bid.order_id} className="text-sm text-gray-300">
              ID {bid.order_id}: Price ${(bid.price / 1e9).toFixed(6)} | 
              Qty: {bid.quantity} | Filled: {bid.filled_quantity} | 
              <span className={bid.filled_quantity > 0 ? 'text-yellow-400' : 'text-gray-500'}>
                {bid.filled_quantity > 0 ? ' ✅ MATCHED' : ' ⏳ OPEN'}
              </span>
            </div>
          ))}
        </div>

        <div>
          <h4 className="font-bold text-red-400 mb-2">Ask Orders (Sellers):</h4>
          {orderbook.asks.map(ask => (
            <div key={ask.order_id} className="text-sm text-gray-300">
              ID {ask.order_id}: Price ${(ask.price / 1e9).toFixed(6)} | 
              Qty: {ask.quantity} | Filled: {ask.filled_quantity} | 
              <span className={ask.filled_quantity > 0 ? 'text-yellow-400' : 'text-gray-500'}>
                {ask.filled_quantity > 0 ? ' ✅ MATCHED' : ' ⏳ OPEN'}
              </span>
            </div>
          ))}
        </div>

        <div className="border-t border-gray-700 pt-4">
          <h4 className="font-bold mb-2">Summary:</h4>
          <p className="text-sm">
            Total Filled Bids: <span className="text-yellow-400">{orderbook.bids.filter(b => b.filled_quantity > 0).length}</span>
          </p>
          <p className="text-sm">
            Total Filled Asks: <span className="text-yellow-400">{orderbook.asks.filter(a => a.filled_quantity > 0).length}</span>
          </p>
        </div>
      </div>
    </div>
  );
}
