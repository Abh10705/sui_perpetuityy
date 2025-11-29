'use client';

import { useEffect, useState } from 'react';
import { useSuiClient } from '@mysten/dapp-kit';
import { CONTRACTS } from '@/lib/constants';

export function DebugOrderBook() {
  const suiClient = useSuiClient();
  const [data, setData] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const debug = async () => {
      try {
        const obj = await suiClient.getObject({
          id: CONTRACTS.ORDERBOOK_ID,
          options: { 
            showContent: true,
            showType: true,
          },
        });
        console.log('📋 Full OrderBook object:', obj);
        setData(obj);
      } catch (err) {
        console.error('Error:', err);
      } finally {
        setLoading(false);
      }
    };
    debug();
  }, [suiClient]);

  if (loading) return <div className="p-4">Loading...</div>;

  return (
    <div className="p-4 bg-gray-800 rounded text-xs text-gray-300 max-h-96 overflow-auto">
      <pre>{JSON.stringify(data, null, 2)}</pre>
    </div>
  );
}
