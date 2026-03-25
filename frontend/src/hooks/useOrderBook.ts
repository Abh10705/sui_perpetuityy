import { useState, useEffect } from 'react';
import { suiClient } from '@/lib/one/client';
import { CONTRACTS } from '@/lib/constants';
import { Order, OrderBookData } from '@/lib/one/types';

interface TableFields {
  fields: {
    id: { id: string };
    size: string;
  };
}

export interface TradeEvent {
  id: string;
  txDigest: string;
  price: number;
  quantity: number;
  option: string;
  timestamp: number;
  type: string;
  is_bid: boolean; // Added to satisfy Requirement 2
}

interface EventParsedJson {
  price?: string;
  price_a?: string;
  quantity?: string;
  option?: { variant: 'OptionA' | 'OptionB' };
  bid_option?: { variant: 'OptionA' | 'OptionB' };
  buyer_order_id?: string;
  seller_order_id?: string;
  bid_order_id?: string;
  ask_order_id?: string;
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
          variant: 'OptionA' | 'OptionB';
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
        options: { showContent: true },
      });

      if (!obj.data?.content) throw new Error('OrderBook not found');

      const content = obj.data.content as Record<string, unknown>;
      const fields = content.fields as Record<string, unknown>;
      
      const bid_ids = (fields?.bid_ids as string[]) || [];
      const ask_ids = (fields?.ask_ids as string[]) || [];
      const ordersTable = (fields?.orders as TableFields);
      const orders_table_id = ordersTable?.fields?.id?.id;

      const bidsData: Order[] = [];
      const asksData: Order[] = [];
      let topBid = 0;
      let topAsk = Number.MAX_SAFE_INTEGER;

      // =========================================================
      // 1. FETCH ACTIVE ORDERS
      // =========================================================
      const dynamicFields = await suiClient.getDynamicFields({
        parentId: orders_table_id,
        limit: 100,
      });

      for (const field of dynamicFields.data) {
        try {
          if (!field.objectId) continue;

          const orderObj = await suiClient.getObject({
            id: field.objectId,
            options: { showContent: true },
          });

          if (orderObj.data?.content?.dataType === 'moveObject') {
            const dynamicField = orderObj.data.content as unknown as DynamicFieldOrder;
            const orderFields = dynamicField.fields?.value?.fields;
            
            if (!orderFields) continue;

            // FIX 1: Ensure orderId is strictly defined for the UI keys
            const orderId = String(orderFields.order_id || field.name || '');
            const isBid = bid_ids.includes(orderId);
            const isAsk = ask_ids.includes(orderId);

            if (!isBid && !isAsk) continue;
            
            const price = parseInt(orderFields.price || '0') / 100;
            const quantity = parseInt(orderFields.quantity || '0');
            const filled_quantity = parseInt(orderFields.filled_quantity || '0');

            const order: Order = {
              order_id: orderId, // Strictly assigned here
              price,
              quantity,
              filled_quantity,
              trader: orderFields.trader || '',
              market_id: orderFields.market_id || '1',
              option: orderFields.option?.variant || 'OptionA',
              is_bid: orderFields.is_bid,
            };

            if (isBid && filled_quantity < quantity) {
              bidsData.push(order);
              topBid = Math.max(topBid, price);
            } else if (!isBid && filled_quantity < quantity) {  
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

      const barcaBids = bidsData.filter(bid => bid.option === 'OptionA');
      const barcaAsks = asksData.filter(ask => ask.option === 'OptionA');
      const madridBids = bidsData.filter(bid => bid.option === 'OptionB');
      const madridAsks = asksData.filter(ask => ask.option === 'OptionB');

      // =========================================================
      // 2. FETCH REAL ON-CHAIN EVENTS
      // =========================================================
      const eventPage = await suiClient.queryEvents({
        query: {
          MoveModule: {
            package: CONTRACTS.PACKAGE_ID,
            module: 'orderbook'
          }
        },
        order: 'descending',
        limit: 100, // FIX 2: Increased limit to prevent truncation
      });

      const trueRecentTrades: TradeEvent[] = [];

      eventPage.data.forEach((event) => {
        const parsedJson = event.parsedJson as EventParsedJson;
        const eventType = event.type.split('::').pop(); 
        
        if (eventType === 'AutoMatched' || eventType === 'TradeSettled') {
          // FIX 3: Taker logic. The new order (taker) always has a higher ID than the resting order (maker).
          const buyerId = Number(parsedJson.buyer_order_id || 0);
          const sellerId = Number(parsedJson.seller_order_id || 0);
          const is_bid = buyerId > sellerId; // If buyer is the newer order, it's a BUY trade.

          trueRecentTrades.push({
            id: `${event.id.txDigest}-${event.id.eventSeq}`,
            txDigest: event.id.txDigest,
            price: Number(parsedJson.price || 0) / 100,
            quantity: Number(parsedJson.quantity || 0),
            option: parsedJson.option?.variant || 'OptionA',
            timestamp: Number(event.timestampMs) || Date.now(),
            type: eventType,
            is_bid,
          });
        } else if (eventType === 'CrossAssetMatched') {
          const bidId = Number(parsedJson.bid_order_id || 0);
          const askId = Number(parsedJson.ask_order_id || 0);
          const is_bid = bidId > askId;

          trueRecentTrades.push({
            id: `${event.id.txDigest}-${event.id.eventSeq}`,
            txDigest: event.id.txDigest,
            price: Number(parsedJson.price_a || 0) / 100, 
            quantity: Number(parsedJson.quantity || 0),
            option: parsedJson.bid_option?.variant || 'OptionA',
            timestamp: Number(event.timestampMs) || Date.now(),
            type: eventType,
            is_bid,
          });
        }
      });

      setOrderbook({
        topBid: topBid || 0,
        topAsk: topAsk === Number.MAX_SAFE_INTEGER ? 0 : topAsk,
        bidDepth: bidsData.length,
        askDepth: asksData.length,
        bids: bidsData,
        asks: asksData,
        barcaBids,
        barcaAsks,
        madridBids,
        madridAsks,
        recentTrades: trueRecentTrades, 
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
    const interval = setInterval(fetchOrderBook, 15000);
    return () => clearInterval(interval);
  }, []);

  return { orderbook, loading, error, refetch: fetchOrderBook };
}