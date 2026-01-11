import { useState, useEffect } from 'react';
import { suiClient } from '@/lib/sui/client';
import { CONTRACTS } from '@/lib/constants';
import { Order, OrderBookData } from '@/lib/sui/types';

interface TableFields {
  fields: {
    id: {
      id: string;
    };
    size: string;
  };
}

interface DynamicFieldOrder {
  fields?: {
    id: { id: string };
    name: string;
    value: {
      type: string;
      fields: {
        created_at: string;
        filled_quantity: string;
        is_bid: boolean;
        market_id: string;
        option: {
          type: string;
          variant: 'OptionA' | 'OptionB';
          fields: Record<string, unknown>;
        };
        order_id: string;
        price: string;
        quantity: string;
        trader: string;
      };
    };
  };
}

export function useOrderBook() {
  const [orderbook, setOrderbook] = useState<OrderBookData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOrderBook = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const obj = await suiClient.getObject({
        id: CONTRACTS.ORDERBOOK_ID,
        options: {
          showContent: true,
        },
      });

      if (!obj.data?.content) throw new Error('OrderBook not found');

      const content = obj.data.content as Record<string, unknown>;
      const fields = content.fields as Record<string, unknown>;
      
      const bid_ids = (fields?.bid_ids as string[]) || [];
      const ask_ids = (fields?.ask_ids as string[]) || [];
      const ordersTable = (fields?.orders as TableFields);
      const orders_table_id = ordersTable?.fields?.id?.id;

      console.log('📊 OrderBook fetched:');
      console.log('  Bid IDs:', bid_ids);
      console.log('  Ask IDs:', ask_ids);

      const bidsData: Order[] = [];
      const asksData: Order[] = [];
      let topBid = 0;
      let topAsk = Number.MAX_SAFE_INTEGER;

      const dynamicFields = await suiClient.getDynamicFields({
        parentId: orders_table_id,
        limit: 100,
      });

      console.log('📋 Dynamic fields count:', dynamicFields.data.length);

      for (const field of dynamicFields.data) {
        try {
          if (!field.objectId) continue;

          const orderObj = await suiClient.getObject({
            id: field.objectId,
            options: { showContent: true },
          });

          if (orderObj.data?.content?.dataType === 'moveObject') {
            const dynamicField = orderObj.data.content as unknown as DynamicFieldOrder;
            
            // Extract from nested value.fields
            const orderFields = dynamicField.fields?.value?.fields;
            
            if (!orderFields) {
              console.warn(`⚠️ Order has no fields structure`);
              continue;
            }

            const orderId = String(orderFields.order_id || '');
            const isBid = bid_ids.includes(orderId);
            const isAsk = ask_ids.includes(orderId);

            if (!isBid && !isAsk) continue;

            
            const price = parseInt(orderFields.price || '0')/ 100;
            console.log(`Price value: ${price}, Formatted: ${price.toFixed(6)}`);


            const quantity = parseInt(orderFields.quantity || '0');
            const filled_quantity = parseInt(orderFields.filled_quantity || '0');

            const order: Order = {
              order_id: orderId,
              price,
              quantity,
              filled_quantity,
              trader: orderFields.trader || '',
              market_id: orderFields.market_id || '1',
              option: orderFields.option?.variant || 'OptionA',
              is_bid: orderFields.is_bid,
            };

            console.log(`✅ Order ${orderId}: price=$${price.toFixed(2)}, qty=${quantity}, option=${orderFields.option?.variant}, is_bid=${orderFields.is_bid}`);
              

            if (isBid) {
              bidsData.push(order);
              topBid = Math.max(topBid, price);
            } else {
              asksData.push(order);
              topAsk = Math.min(topAsk, price);
            }
          }
        } catch (err) {
          console.warn('⚠️ Failed to fetch order:', err);
        }
      }

      bidsData.sort((a, b) => b.price - a.price);
      asksData.sort((a, b) => a.price - b.price);
      // Separate by team (option)
      const barcaBids = bidsData.filter(bid => bid.option === 'OptionA');
      const barcaAsks = asksData.filter(ask => ask.option === 'OptionA');
      const madridBids = bidsData.filter(bid => bid.option === 'OptionB');
      const madridAsks = asksData.filter(ask => ask.option === 'OptionB');


      setOrderbook({
        topBid: topBid || 0,
        topAsk: topAsk === Number.MAX_SAFE_INTEGER ? 0 : topAsk,
        bidDepth: bid_ids.length,
        askDepth: ask_ids.length,
        bids: bidsData,
        asks: asksData,
        barcaBids,
        barcaAsks,
        madridBids,
        madridAsks,
      });

      console.log('📈 Final OrderBook:', { 
        bidsCount: bidsData.length, 
        asksCount: asksData.length,
        topBid: topBid || 0,
        topAsk: topAsk === Number.MAX_SAFE_INTEGER ? 0 : topAsk,
      });
    } catch (err) {
      console.error('❌ Error fetching orderbook:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch orderbook');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOrderBook();
    
    const interval = setInterval(fetchOrderBook, 30000);
    return () => clearInterval(interval);
  }, []);

  return { orderbook, loading, error, refetch: fetchOrderBook };
}
