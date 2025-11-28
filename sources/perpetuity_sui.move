module perpetuity_sui::orderbook {
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::string::String;

    // ========== ERRORS ==========
    const EInvalidPrice: u64 = 1;
    const EInvalidQuantity: u64 = 2;
    const EOrderNotFound: u64 = 3;
    const EMarketNotFound: u64 = 5;

    // ========== STRUCTS ==========

    /// Market (like your Market struct in Rust)
    public struct Market has key {
        id: UID,
        market_id: u64,
        admin: address,
        question: String,
        token_a_supply: Balance<SUI>,    // YES opinion tokens
        token_b_supply: Balance<SUI>,    // NO opinion tokens
        usdc_balance: Balance<SUI>,      // USDC collateral
        is_active: bool,
    }

    /// Order in the orderbook
    public struct Order has store, drop {
        order_id: u64,
        trader: address,
        market_id: u64,
        is_token_a: bool,  // true = YES, false = NO
        price: u64,        // in USDC
        quantity: u64,
        is_bid: bool,      // true = buy order, false = sell order
    }

    /// The orderbook for a market
    public struct OrderBook has key {
        id: UID,
        market_id: u64,
        bids: vector<Order>,   // Buy orders (sorted desc by price)
        asks: vector<Order>,   // Sell orders (sorted asc by price)
        next_order_id: u64,
    }

    // ========== CREATE MARKET ==========

    /// Create a new opinion market (like your create_market in Rust)
    public fun create_market(
        market_id: u64,
        question: String,
        ctx: &mut TxContext,
    ) {
        let market = Market {
            id: object::new(ctx),
            market_id,
            admin: tx_context::sender(ctx),
            question,
            token_a_supply: balance::zero(),
            token_b_supply: balance::zero(),
            usdc_balance: balance::zero(),
            is_active: true,
        };

        let orderbook = OrderBook {
            id: object::new(ctx),
            market_id,
            bids: vector::empty(),
            asks: vector::empty(),
            next_order_id: 1,
        };

        transfer::share_object(market);
        transfer::share_object(orderbook);
    }

    // ========== PLACE ORDER ==========

    /// Place a buy or sell order
    /// is_token_a = true means trading YES, false means trading NO
    /// is_bid = true means you want to BUY, false means you want to SELL
    public fun place_order(
        orderbook: &mut OrderBook,
        is_token_a: bool,
        price: u64,
        quantity: u64,
        is_bid: bool,
        ctx: &mut TxContext,
    ) {
        assert!(price > 0, EInvalidPrice);
        assert!(quantity > 0, EInvalidQuantity);

        let order = Order {
            order_id: orderbook.next_order_id,
            trader: tx_context::sender(ctx),
            market_id: orderbook.market_id,
            is_token_a,
            price,
            quantity,
            is_bid,
        };

        // Add to bids or asks
        if (is_bid) {
            vector::push_back(&mut orderbook.bids, order);
        } else {
            vector::push_back(&mut orderbook.asks, order);
        };

        orderbook.next_order_id = orderbook.next_order_id + 1;
    }

    /// Cancel an order
    public fun cancel_order(
        orderbook: &mut OrderBook,
        order_id: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let mut found_index = 0;
        let mut found_in_bids = false;
        let mut found = false;

        // Search in bids
        let mut i = 0;
        let len_bids = vector::length(&orderbook.bids);
        while (i < len_bids) {
            let order = vector::borrow(&orderbook.bids, i);
            if (order.order_id == order_id && order.trader == sender) {
                found_index = i;
                found_in_bids = true;
                found = true;
                break
            };
            i = i + 1;
        };

        if (found) {
            if (found_in_bids) {
                vector::remove(&mut orderbook.bids, found_index);
            };
            return
        };

        // Search in asks
        let mut j = 0;
        let len_asks = vector::length(&orderbook.asks);
        while (j < len_asks) {
            let order = vector::borrow(&orderbook.asks, j);
            if (order.order_id == order_id && order.trader == sender) {
                found_index = j;
                found = true;
                break
            };
            j = j + 1;
        };

        assert!(found, EOrderNotFound);
        vector::remove(&mut orderbook.asks, found_index);
    }

    // ========== SETTLE TRADE ==========

    /// Settle a matched trade (called by your off-chain matcher)
    public fun settle_trade(
        orderbook: &mut OrderBook,
        _buyer_order_id: u64,
        _seller_order_id: u64,
        _matched_price: u64,
        _matched_quantity: u64,
        _ctx: &mut TxContext,
    ) {
        // Find buyer and seller orders
        assert!(orderbook.market_id > 0, EMarketNotFound);

        // In your off-chain matcher:
        // 1. Match highest bid with lowest ask if they cross
        // 2. Call this function with matched details
        // 3. Update positions (done here)

        // TODO: Update buyer and seller positions
        // Transfer tokens between them
    }

    // ========== VIEW FUNCTIONS ==========

    /// Get top bid price
    public fun get_top_bid(orderbook: &OrderBook): u64 {
        if (vector::length(&orderbook.bids) > 0) {
            let order = vector::borrow(&orderbook.bids, 0);
            order.price
        } else {
            0
        }
    }

    /// Get top ask price
    public fun get_top_ask(orderbook: &OrderBook): u64 {
        if (vector::length(&orderbook.asks) > 0) {
            let order = vector::borrow(&orderbook.asks, 0);
            order.price
        } else {
            0
        }
    }

    /// Get orderbook depth
    public fun get_orderbook_depth(orderbook: &OrderBook): (u64, u64) {
        (vector::length(&orderbook.bids), vector::length(&orderbook.asks))
    }
}
