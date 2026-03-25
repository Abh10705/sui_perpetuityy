export interface Order {
  order_id: string;
  trader: string;
  market_id: string;
  option: 'OptionA' | 'OptionB';
  price: number;
  quantity: number;
  filled_quantity: number;
  is_bid: boolean;
}

export interface OrderBookData {
  topBid: number;
  topAsk: number;
  bidDepth: number;
  askDepth: number;
  bids: Order[];
  asks: Order[];
  barcaBids: Order[];
  barcaAsks: Order[];
  madridBids: Order[];
  madridAsks: Order[];
  recentTrades: TradeEvent[]; // <-- Change this from Order[] to TradeEvent[]
}


export interface UserBalance {
  id: string;
  market_id: string;
  trader: string;
  balance: number;
}

export interface UserPosition {
  barcarShares: number;
  madridShares: number;
  balance: number;
  loading: boolean;
  error: string | null;
}

export interface TradeEvent {
  id: string;
  txDigest: string;
  price: number;
  quantity: number;
  option: string;
  timestamp: number;
  type: string;
  is_bid: boolean; // <--- ADD THIS LINE
}