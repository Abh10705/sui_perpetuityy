import { useState, useEffect } from 'react';
import { suiClient } from '@/lib/sui/client';
import { CONTRACTS } from '@/lib/constants';
import { OrderBookData } from '@/lib/sui/types';

export function useOrderBook() {
  const [orderbook, setOrderbook] = useState<OrderBookData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOrderBook = async () => {
    try {
      setLoading(true);
      
      // Query the OrderBook object
      const obj = await suiClient.getObject({
        id: CONTRACTS.ORDERBOOK_ID,
        options: {
          showContent: true,
        },
      });

      if (!obj.data?.content) throw new Error('OrderBook not found');

      // Parse the data (adjust based on your contract structure)
      const content = obj.data.content as Record<string, unknown>;
      const fields = content.fields as Record<string, unknown>;
      
      setOrderbook({
        topBid: Number((fields?.bid_ids as unknown[])?.[0] || 0),
        topAsk: Number((fields?.ask_ids as unknown[])?.[0] || 0),
        bidDepth: ((fields?.bid_ids as unknown[]) || []).length,
        askDepth: ((fields?.ask_ids as unknown[]) || []).length,
        bids: [],
        asks: [],
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch orderbook');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOrderBook();
    
    // Poll every 30 seconds
    const interval = setInterval(fetchOrderBook, 30000);
    return () => clearInterval(interval);
  }, []);

  return { orderbook, loading, error, refetch: fetchOrderBook };
}