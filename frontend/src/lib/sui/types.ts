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
}

export interface UserBalance {
  id: string;
  market_id: string;
  trader: string;
  balance: number;
}
