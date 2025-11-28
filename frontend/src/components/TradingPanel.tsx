'use client';

import { useState } from 'react';
import { placeOrder } from '@/lib/sui/contracts';

export function TradingPanel() {
  const [side, setSide] = useState<'buy' | 'sell'>('buy');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const collateral = price && quantity ? (parseFloat(price) * parseFloat(quantity)).toFixed(4) : '0';

  const handlePlaceOrder = async () => {
    if (!price || !quantity) {
      setMessage({ type: 'error', text: 'Please fill in price and quantity' });
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const result = await placeOrder(
        parseFloat(price),
        parseFloat(quantity),
        side === 'buy',
        'OptionA' // Default to OptionA for now
      );

      if (result.success) {
        setMessage({
          type: 'success',
          text: `Order placed! TX: ${result.txDigest?.slice(0, 10)}...`,
        });
        setPrice('');
        setQuantity('');
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to place order' });
      }
    } catch (err) {
      setMessage({
        type: 'error',
        text: err instanceof Error ? err.message : 'Unknown error',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
      <h3 className="mb-6 text-lg font-bold text-white">Place Order</h3>

      {/* Buy/Sell Tabs */}
      <div className="mb-6 flex gap-2">
        <button
          onClick={() => setSide('buy')}
          className={`flex-1 rounded-lg py-2 font-semibold transition-all ${
            side === 'buy'
              ? 'border-2 border-green-500 bg-green-500/10 text-green-400'
              : 'border border-gray-600 bg-gray-800 text-gray-400 hover:border-gray-500'
          }`}
        >
          Buy
        </button>
        <button
          onClick={() => setSide('sell')}
          className={`flex-1 rounded-lg py-2 font-semibold transition-all ${
            side === 'sell'
              ? 'border-2 border-red-500 bg-red-500/10 text-red-400'
              : 'border border-gray-600 bg-gray-800 text-gray-400 hover:border-gray-500'
          }`}
        >
          Sell
        </button>
      </div>

      {/* Price Input */}
      <div className="mb-4">
        <label className="mb-2 block text-sm text-gray-400">Price (SUI)</label>
        <input
          type="number"
          placeholder="0.00"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          className="w-full rounded-lg border border-gray-600 bg-gray-800 px-4 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
          step="0.01"
          min="0"
        />
      </div>

      {/* Quantity Input */}
      <div className="mb-4">
        <label className="mb-2 block text-sm text-gray-400">Quantity</label>
        <input
          type="number"
          placeholder="0"
          value={quantity}
          onChange={(e) => setQuantity(e.target.value)}
          className="w-full rounded-lg border border-gray-600 bg-gray-800 px-4 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
          step="1"
          min="0"
        />
      </div>

      {/* Collateral Display */}
      <div className="mb-6 rounded-lg bg-gray-800 p-4">
        <div className="mb-2 flex justify-between text-sm">
          <span className="text-gray-400">Collateral Required</span>
          <span className="font-semibold text-white">{collateral} SUI</span>
        </div>
        <div className="h-1 w-full bg-gray-700 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-purple-500 to-blue-500 transition-all"
            style={{ width: `${Math.min(parseFloat(collateral) * 10, 100)}%` }}
          />
        </div>
      </div>

      {/* Message Display */}
      {message && (
        <div
          className={`mb-4 rounded-lg p-3 text-sm font-medium ${
            message.type === 'success'
              ? 'border border-green-500/30 bg-green-500/10 text-green-400'
              : 'border border-red-500/30 bg-red-500/10 text-red-400'
          }`}
        >
          {message.text}
        </div>
      )}

      {/* Submit Button */}
      <button
        onClick={handlePlaceOrder}
        disabled={loading || !price || !quantity}
        className={`w-full rounded-lg py-3 font-bold transition-all ${
          side === 'buy'
            ? 'bg-green-500 text-white hover:bg-green-600 disabled:bg-gray-600 disabled:text-gray-400'
            : 'bg-red-500 text-white hover:bg-red-600 disabled:bg-gray-600 disabled:text-gray-400'
        }`}
      >
        {loading ? (
          <span className="flex items-center justify-center gap-2">
            <div className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
            Placing order...
          </span>
        ) : (
          `${side === 'buy' ? 'Buy' : 'Sell'} ${quantity || '0'} @ ${price || '0.00'} SUI`
        )}
      </button>

      {/* Info Text */}
      <p className="mt-4 text-xs text-gray-500">
        💡 Connected wallet required to place orders. Collateral will be reserved.
      </p>
    </div>
  );
}