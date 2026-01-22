/// OrderBook Module for Perpetuity Prediction Market
/// 
/// This module implements the order matching engine and order book management.
/// It handles:
/// - Order placement and cancellation
/// - Automatic order matching (same-option and cross-option)
/// - Trade settlement
/// - Order queries (top bid/ask, depth)
///
/// The OrderBook module works with the Outcome module for financial state management.

module perpetuity_sui::orderbook {
    use one::table::{Self, Table};
    use one::balance;
    use perpetuity_sui::types::Option;
    use perpetuity_sui::types::{option_a, option_b, complement};
    use perpetuity_sui::outcome::{
        Market,
        UserBalance,
        transfer_shares,
        add_to_settlement,
        get_user_balance,
        get_user_position,
        get_user_balance_trader,
        get_user_balance_market_id,
        refund_bid_collateral,
        lock_bid_collateral,        // ⭐ NEW IMPORT
        settle_trade_immediate,     // ⭐ NEW IMPORT
    };

    // ============================================================================
    // Events (DEFINED IN THIS MODULE - required for emission)
    // ============================================================================

    public struct OrderPlaced has drop, copy {
        order_id: u64,
        trader: address,
        market_id: u64,
        option: Option,
        price: u64,
        quantity: u64,
        is_bid: bool,
    }

    public struct OrderCancelled has drop, copy {
        order_id: u64,
        trader: address,
        market_id: u64,
    }

    /// ✅ NEW: Event for refunds when bid orders are cancelled
    public struct OrderRefunded has drop, copy {
        order_id: u64,
        trader: address,
        market_id: u64,
        refund_amount: u64,
    }

    public struct AutoMatched has drop, copy {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
        option: Option,
    }

    public struct CrossAssetMatched has drop, copy {
        bid_order_id: u64,
        ask_order_id: u64,
        price_a: u64,
        price_b: u64,
        quantity: u64,
        market_id: u64,
        bid_option: Option,
        ask_option: Option,
    }

    public struct TradeSettled has drop, copy {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
        option: Option,
    }

    // ============================================================================
    // Error Codes
    // ============================================================================

    const EInvalidPrice: u64 = 1;
    const EInvalidQuantity: u64 = 2;
    const EOrderNotFound: u64 = 3;
    const EMarketNotFound: u64 = 4;
    const EInsufficientFunds: u64 = 5;
    const EUnauthorized: u64 = 6;
    const EInvalidComplementaryPrice: u64 = 7;
    const EInsufficientShares: u64 = 8;
    const EOrderPartiallyFilled: u64 = 10;

    // ============================================================================
    // Struct Definitions
    // ============================================================================

    /// Represents a single order in the order book
    /// 
    /// # Fields
    /// - order_id: Unique order identifier
    /// - trader: Trader who placed the order
    /// - market_id: Associated market
    /// - option: Option being traded (OptionA or OptionB)
    /// - price: Order price (0-100 scale)
    /// - quantity: Total order quantity
    /// - filled_quantity: Amount already filled
    /// - is_bid: True for buy orders, false for sell orders
    /// - created_at: Creation epoch
    /// - locked_collateral: Amount of collateral locked for bids
    public struct Order has store, drop {
        order_id: u64,
        trader: address,
        market_id: u64,
        option: Option,
        price: u64,
        quantity: u64,
        filled_quantity: u64,
        is_bid: bool,
        created_at: u64,
        locked_collateral: u64,
    }

    /// The order book containing all active orders and price levels
    /// 
    /// # Fields
    /// - market_id: Associated market
    /// - orders: All orders by order_id
    /// - active_orders: Flags for active orders (prevents double-processing)
    /// - bid_ids: Vector of all bid order IDs in insertion order
    /// - ask_ids: Vector of all ask order IDs in insertion order
    /// - bid_levels: Table mapping price -> vector of order IDs at that price
    /// - ask_levels: Table mapping price -> vector of order IDs at that price
    /// - next_order_id: Counter for generating unique order IDs
    public struct OrderBook has key {
        id: one::object::UID,
        market_id: u64,
        orders: Table<u64, Order>,
        active_orders: Table<u64, bool>,
        bid_ids: vector<u64>,
        ask_ids: vector<u64>,
        bid_levels: Table<u64, vector<u64>>,
        ask_levels: Table<u64, vector<u64>>,
        next_order_id: u64,
    }

    // ============================================================================
    // Internal Helper Functions
    // ============================================================================

    /// Validate that two prices are complementary (sum to 100)
    /// 
    /// # Arguments
    /// - price_a: First price
    /// - price_b: Second price
    fun validate_complementary_price(price_a: u64, price_b: u64) {
        assert!(price_a + price_b == 100, EInvalidComplementaryPrice);
    }

    /// Calculate the complementary price
    /// Used for cross-asset matching (prices must sum to 100)
    /// 
    /// # Arguments
    /// - price: Base price
    /// 
    /// # Returns
    /// 100 - price
    fun get_complementary_price(price: u64): u64 {
        100 - price
    }

    /// Get the complementary option
    /// 
    /// # Arguments
    /// - option: Option to complement
    /// 
    /// # Returns
    /// Complementary option (A->B or B->A)
    fun get_complementary_option(option: Option): Option {
        complement(option)
    }

    // ============================================================================
    // Market Initialization
    // ============================================================================

    /// Create a new order book for a market
    /// Called by market admin during market creation
    /// 
    /// # Arguments
    /// - market_id: Market identifier
    /// - ctx: Transaction context
    public fun create_orderbook(
        market_id: u64,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let orderbook = OrderBook {
            id: one::object::new(ctx),
            market_id,
            orders: table::new(ctx),
            active_orders: table::new(ctx),
            bid_ids: vector::empty<u64>(),
            ask_ids: vector::empty<u64>(),
            bid_levels: table::new(ctx),
            ask_levels: table::new(ctx),
            next_order_id: 1,
        };

        one::transfer::share_object(orderbook);
    }

    // ============================================================================
    // Order Placement & Matching
    // ============================================================================

    /// Place a new order and attempt automatic matching
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// - market: The market
    /// - user_balance: User's balance
    /// - option: Option to trade
    /// - price: Order price (1-99, excluding 0 and 100)
    /// - quantity: Order quantity
    /// - is_bid: True for buy order, false for sell
    /// - ctx: Transaction context
    public fun place_order<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        option: Option,
        price: u64,
        quantity: u64,
        is_bid: bool,
        ctx: &mut one::tx_context::TxContext,
    ) {
        // Validate order parameters
        let complementary_price = get_complementary_price(price);
        validate_complementary_price(price, complementary_price);
        assert!(price > 0 && price < 100, EInvalidPrice);
        assert!(quantity > 0, EInvalidQuantity);

        let sender = one::tx_context::sender(ctx);

        // ✅ PERMISSION CHECK #1: Verify UserBalance belongs to sender
        assert!(get_user_balance_trader(user_balance) == sender, EUnauthorized);

        // ✅ PERMISSION CHECK #2: Verify market matches
        assert!(get_user_balance_market_id(user_balance) == orderbook.market_id, EMarketNotFound);

        // Check collateral for bid orders, shares for ask orders
        if (is_bid) {
            let required_collateral = price * quantity;
            let user_balance_amount = get_user_balance(user_balance);
            assert!(user_balance_amount >= required_collateral, EInsufficientFunds);
            
            // ⭐ NEW: Lock coins in vault when bid is placed
            lock_bid_collateral(market, user_balance, required_collateral);
        } else {
            let seller_shares = get_user_position(market, sender, option);
            assert!(seller_shares >= quantity, EInsufficientShares);
        };

        // Create order
        let locked_amount = if (is_bid) { price * quantity } else { 0 };
        let order = Order {
            order_id: orderbook.next_order_id,
            trader: sender,
            market_id: orderbook.market_id,
            option,
            price,
            quantity,
            filled_quantity: 0,
            is_bid,
            created_at: one::tx_context::epoch(ctx),
            locked_collateral: locked_amount,
        };

        let order_id = orderbook.next_order_id;
        table::add(&mut orderbook.orders, order_id, order);
        table::add(&mut orderbook.active_orders, order_id, true);

        // Add to price levels
        if (is_bid) {
            vector::push_back(&mut orderbook.bid_ids, order_id);
            if (!table::contains(&orderbook.bid_levels, price)) {
                table::add(&mut orderbook.bid_levels, price, vector::empty<u64>());
            };
            let bid_level = table::borrow_mut(&mut orderbook.bid_levels, price);
            vector::push_back(bid_level, order_id);
        } else {
            vector::push_back(&mut orderbook.ask_ids, order_id);
            if (!table::contains(&orderbook.ask_levels, price)) {
                table::add(&mut orderbook.ask_levels, price, vector::empty<u64>());
            };
            let ask_level = table::borrow_mut(&mut orderbook.ask_levels, price);
            vector::push_back(ask_level, order_id);
        };

        one::event::emit(OrderPlaced {
            order_id,
            trader: sender,
            market_id: orderbook.market_id,
            option,
            price,
            quantity,
            is_bid,
        });

        orderbook.next_order_id = orderbook.next_order_id + 1;
        auto_match_orders(orderbook, market, order_id, is_bid, ctx);
    }

    /// Place an order using CLI-compatible u8 for option encoding
    /// Convenience wrapper for command-line tools
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// - market: The market
    /// - user_balance: User's balance
    /// - option_u8: 0 for OptionA, 1 for OptionB
    /// - price: Order price
    /// - quantity: Order quantity
    /// - is_bid: True for buy order
    /// - ctx: Transaction context
    public fun place_order_cli<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        option_u8: u8,
        price: u64,
        quantity: u64,
        is_bid: bool,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let option = if (option_u8 == 0) { option_a() } else { option_b() };
        place_order(
            orderbook,
            market,
            user_balance,
            option,
            price,
            quantity,
            is_bid,
            ctx
        );
    }

    // ============================================================================
    // Order Cancellation (HARDENED)
    // ============================================================================

    /// Cancel an unfilled order
    /// SECURITY: Orders can only be cancelled if they have not been filled at all
    /// (filled_quantity must be 0)
    /// ✅ NEW: Refunds locked collateral for bid orders back to user's balance
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// - market: The market (used to access vault for refunds)
    /// - user_balance: User's balance (to receive refund)
    /// - order_id: Order to cancel
    /// - ctx: Transaction context
    public fun cancel_order<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        order_id: u64,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let sender = one::tx_context::sender(ctx);
        assert!(table::contains(&orderbook.orders, order_id), EOrderNotFound);

        let order = table::borrow(&orderbook.orders, order_id);
        assert!(order.trader == sender, EUnauthorized);
        
        // SECURITY: Prevent cancellation of partially filled orders
        assert!(order.filled_quantity == 0, EOrderPartiallyFilled);

        let is_bid = order.is_bid;
        let price = order.price;
        let locked_collateral = order.locked_collateral;

        table::remove(&mut orderbook.orders, order_id);
        table::remove(&mut orderbook.active_orders, order_id);

        // Remove from bid/ask lists and price levels
        if (is_bid) {
            let bid_len = vector::length(&orderbook.bid_ids);
            let mut bid_i = 0;
            while (bid_i < bid_len) {
                if (*vector::borrow(&orderbook.bid_ids, bid_i) == order_id) {
                    vector::remove(&mut orderbook.bid_ids, bid_i);
                    break
                };
                bid_i = bid_i + 1;
            };
            
            if (table::contains(&orderbook.bid_levels, price)) {
                let level = table::borrow_mut(&mut orderbook.bid_levels, price);
                let level_len = vector::length(level);
                let mut level_i = 0;
                while (level_i < level_len) {
                    if (*vector::borrow(level, level_i) == order_id) {
                        vector::remove(level, level_i);
                        break
                    };
                    level_i = level_i + 1;
                };
            };
        };

        if (!is_bid) {
            let ask_len = vector::length(&orderbook.ask_ids);
            let mut ask_i = 0;
            while (ask_i < ask_len) {
                if (*vector::borrow(&orderbook.ask_ids, ask_i) == order_id) {
                    vector::remove(&mut orderbook.ask_ids, ask_i);
                    break
                };
                ask_i = ask_i + 1;
            };
            
            if (table::contains(&orderbook.ask_levels, price)) {
                let level = table::borrow_mut(&mut orderbook.ask_levels, price);
                let level_len = vector::length(level);
                let mut level_i = 0;
                while (level_i < level_len) {
                    if (*vector::borrow(level, level_i) == order_id) {
                        vector::remove(level, level_i);
                        break
                    };
                    level_i = level_i + 1;
                };
            };
        };

        // ✅ NEW: REFUND LOGIC - If it's a bid order, refund the locked collateral
        if (is_bid && locked_collateral > 0) {
            // Call public refund function from outcome module
            refund_bid_collateral(market, user_balance, locked_collateral);
            
            // Emit refund event
            one::event::emit(OrderRefunded {
                order_id,
                trader: sender,
                market_id: orderbook.market_id,
                refund_amount: locked_collateral,
            });
        };

        one::event::emit(OrderCancelled {
            order_id,
            trader: sender,
            market_id: orderbook.market_id,
        });
    }

    // ============================================================================
    // Automatic Order Matching
    // ============================================================================

    /// Core matching engine: attempts to match a new order against existing orders
    /// Handles both same-option and cross-option (complementary) matching
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// - market: The market
    /// - new_order_id: Newly placed order
    /// - is_bid: Whether new order is a bid
    /// - ctx: Transaction context
    fun auto_match_orders<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        new_order_id: u64,
        is_bid: bool,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let new_order_price = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.price
        };

        let new_order_option = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.option
        };

        // Phase 1: Match same-option orders
        if (is_bid) {
            let ask_len = vector::length(&orderbook.ask_ids);
            let mut ask_index = 0;

            while (ask_index < ask_len) {
                let ask_order_id = *vector::borrow(&orderbook.ask_ids, ask_index);
                
                if (!table::contains(&orderbook.active_orders, ask_order_id)) {
                    ask_index = ask_index + 1;
                    continue
                };

                let ask_price = {
                    let order = table::borrow(&orderbook.orders, ask_order_id);
                    order.price
                };

                let ask_option = {
                    let order = table::borrow(&orderbook.orders, ask_order_id);
                    order.option
                };

                if (ask_option == new_order_option && ask_price <= new_order_price) {
                    let new_order_remaining = {
                        let order = table::borrow(&orderbook.orders, new_order_id);
                        order.quantity - order.filled_quantity
                    };

                    let ask_order_remaining = {
                        let order = table::borrow(&orderbook.orders, ask_order_id);
                        order.quantity - order.filled_quantity
                    };

                    if (new_order_remaining > 0 && ask_order_remaining > 0) {
                        let match_qty = if (new_order_remaining < ask_order_remaining) {
                            new_order_remaining
                        } else {
                            ask_order_remaining
                        };

                        {
                            let new_order = table::borrow_mut(&mut orderbook.orders, new_order_id);
                            new_order.filled_quantity = new_order.filled_quantity + match_qty;
                        };

                        {
                            let ask_order = table::borrow_mut(&mut orderbook.orders, ask_order_id);
                            ask_order.filled_quantity = ask_order.filled_quantity + match_qty;
                        };

                        let buyer_addr = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.trader
                        };

                        let seller_addr = {
                            let order = table::borrow(&orderbook.orders, ask_order_id);
                            order.trader
                        };

                        transfer_shares(market, seller_addr, buyer_addr, new_order_option, match_qty, ctx);
                        
                        let payment_amount = ask_price * match_qty;
                        // ⭐ REPLACED: add_to_settlement → settle_trade_immediate
                        settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                        one::event::emit(AutoMatched {
                            buyer_order_id: new_order_id,
                            seller_order_id: ask_order_id,
                            price: ask_price,
                            quantity: match_qty,
                            market_id: orderbook.market_id,
                            option: new_order_option,
                        });

                        let new_remaining = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.quantity - order.filled_quantity
                        };
                        
                        if (new_remaining == 0) {
                            break
                        };
                    }
                } else {
                    ask_index = ask_index + 1;
                    continue
                };

                ask_index = ask_index + 1;
            };
        } else {
            let bid_len = vector::length(&orderbook.bid_ids);
            let mut bid_index = 0;

            while (bid_index < bid_len) {
                let bid_order_id = *vector::borrow(&orderbook.bid_ids, bid_index);
                
                if (!table::contains(&orderbook.active_orders, bid_order_id)) {
                    bid_index = bid_index + 1;
                    continue
                };

                let bid_price = {
                    let order = table::borrow(&orderbook.orders, bid_order_id);
                    order.price
                };

                let bid_option = {
                    let order = table::borrow(&orderbook.orders, bid_order_id);
                    order.option
                };

                if (bid_option == new_order_option && bid_price >= new_order_price) {
                    let new_order_remaining = {
                        let order = table::borrow(&orderbook.orders, new_order_id);
                        order.quantity - order.filled_quantity
                    };

                    let bid_order_remaining = {
                        let order = table::borrow(&orderbook.orders, bid_order_id);
                        order.quantity - order.filled_quantity
                    };

                    if (new_order_remaining > 0 && bid_order_remaining > 0) {
                        let match_qty = if (new_order_remaining < bid_order_remaining) {
                            new_order_remaining
                        } else {
                            bid_order_remaining
                        };

                        {
                            let bid_order = table::borrow_mut(&mut orderbook.orders, bid_order_id);
                            bid_order.filled_quantity = bid_order.filled_quantity + match_qty;
                        };

                        {
                            let new_order = table::borrow_mut(&mut orderbook.orders, new_order_id);
                            new_order.filled_quantity = new_order.filled_quantity + match_qty;
                        };

                        let buyer_addr = {
                            let order = table::borrow(&orderbook.orders, bid_order_id);
                            order.trader
                        };

                        let seller_addr = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.trader
                        };

                        transfer_shares(market, seller_addr, buyer_addr, new_order_option, match_qty, ctx);

                        let payment_amount = bid_price * match_qty;
                        // ⭐ REPLACED: add_to_settlement → settle_trade_immediate
                        settle_trade_immediate(market, buyer_addr, payment_amount, ctx);

                        one::event::emit(AutoMatched {
                            buyer_order_id: bid_order_id,
                            seller_order_id: new_order_id,
                            price: bid_price,
                            quantity: match_qty,
                            market_id: orderbook.market_id,
                            option: new_order_option,
                        });

                        let new_remaining = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.quantity - order.filled_quantity
                        };
                        
                        if (new_remaining == 0) {
                            break
                        };
                    }
                } else {
                    bid_index = bid_index + 1;
                    continue
                };

                bid_index = bid_index + 1;
            };
        };

        // Phase 2: Cross-asset (complementary) matching for remaining quantity
        let new_order_remaining = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.quantity - order.filled_quantity
        };
        
        if (new_order_remaining > 0) {
            let complementary_option = get_complementary_option(new_order_option);
            let complementary_price = get_complementary_price(new_order_price);
            
            if (is_bid) {
                let ask_len = vector::length(&orderbook.ask_ids);
                let mut ask_index = 0;

                while (ask_index < ask_len) {
                    let ask_order_id = *vector::borrow(&orderbook.ask_ids, ask_index);
                    
                    if (!table::contains(&orderbook.active_orders, ask_order_id)) {
                        ask_index = ask_index + 1;
                        continue
                    };

                    let ask_order = table::borrow(&orderbook.orders, ask_order_id);
                    let ask_price = ask_order.price;
                    let ask_option = ask_order.option;

                    if (ask_option == complementary_option && ask_price <= complementary_price) {
                        let new_order_remaining_now = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.quantity - order.filled_quantity
                        };

                        let ask_order_remaining = {
                            let order = table::borrow(&orderbook.orders, ask_order_id);
                            order.quantity - order.filled_quantity
                        };

                        if (new_order_remaining_now > 0 && ask_order_remaining > 0) {
                            let match_qty = if (new_order_remaining_now < ask_order_remaining) {
                                new_order_remaining_now
                            } else {
                                ask_order_remaining
                            };

                            {
                                let new_order = table::borrow_mut(&mut orderbook.orders, new_order_id);
                                new_order.filled_quantity = new_order.filled_quantity + match_qty;
                            };

                            {
                                let ask_order = table::borrow_mut(&mut orderbook.orders, ask_order_id);
                                ask_order.filled_quantity = ask_order.filled_quantity + match_qty;
                            };

                            let buyer_addr = {
                                let order = table::borrow(&orderbook.orders, new_order_id);
                                order.trader
                            };

                            let seller_addr = {
                                let order = table::borrow(&orderbook.orders, ask_order_id);
                                order.trader
                            };

                            transfer_shares(market, seller_addr, buyer_addr, complementary_option, match_qty, ctx);

                            let payment_amount = new_order_price * match_qty;
                            // ⭐ REPLACED: add_to_settlement → settle_trade_immediate
                            settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                            one::event::emit(CrossAssetMatched {
                                bid_order_id: new_order_id,
                                ask_order_id,
                                price_a: new_order_price,
                                price_b: complementary_price,
                                quantity: match_qty,
                                market_id: orderbook.market_id,
                                bid_option: new_order_option,
                                ask_option: complementary_option,
                            });

                            let new_remaining = {
                                let order = table::borrow(&orderbook.orders, new_order_id);
                                order.quantity - order.filled_quantity
                            };
                            
                            if (new_remaining == 0) {
                                break
                            };
                        }
                    };

                    ask_index = ask_index + 1;
                };
            } else {
                let bid_len = vector::length(&orderbook.bid_ids);
                let mut bid_index = 0;

                while (bid_index < bid_len) {
                    let bid_order_id = *vector::borrow(&orderbook.bid_ids, bid_index);
                    
                    if (!table::contains(&orderbook.active_orders, bid_order_id)) {
                        bid_index = bid_index + 1;
                        continue
                    };

                    let bid_order = table::borrow(&orderbook.orders, bid_order_id);
                    let bid_price = bid_order.price;
                    let bid_option = bid_order.option;

                    if (bid_option == complementary_option && bid_price >= complementary_price) {
                        let new_order_remaining_now = {
                            let order = table::borrow(&orderbook.orders, new_order_id);
                            order.quantity - order.filled_quantity
                        };

                        let bid_order_remaining = {
                            let order = table::borrow(&orderbook.orders, bid_order_id);
                            order.quantity - order.filled_quantity
                        };

                        if (new_order_remaining_now > 0 && bid_order_remaining > 0) {
                            let match_qty = if (new_order_remaining_now < bid_order_remaining) {
                                new_order_remaining_now
                            } else {
                                bid_order_remaining
                            };

                            {
                                let bid_order = table::borrow_mut(&mut orderbook.orders, bid_order_id);
                                bid_order.filled_quantity = bid_order.filled_quantity + match_qty;
                            };

                            {
                                let new_order = table::borrow_mut(&mut orderbook.orders, new_order_id);
                                new_order.filled_quantity = new_order.filled_quantity + match_qty;
                            };

                            let buyer_addr = {
                                let order = table::borrow(&orderbook.orders, bid_order_id);
                                order.trader
                            };

                            let seller_addr = {
                                let order = table::borrow(&orderbook.orders, new_order_id);
                                order.trader
                            };

                            transfer_shares(market, seller_addr, buyer_addr, complementary_option, match_qty, ctx);

                            let payment_amount = bid_price * match_qty;
                            // ⭐ REPLACED: add_to_settlement → settle_trade_immediate
                            settle_trade_immediate(market, buyer_addr, payment_amount, ctx);

                            one::event::emit(CrossAssetMatched {
                                bid_order_id,
                                ask_order_id: new_order_id,
                                price_a: complementary_price,
                                price_b: new_order_price,
                                quantity: match_qty,
                                market_id: orderbook.market_id,
                                bid_option: complementary_option,
                                ask_option: new_order_option,
                            });

                            let new_remaining = {
                                let order = table::borrow(&orderbook.orders, new_order_id);
                                order.quantity - order.filled_quantity
                            };
                            
                            if (new_remaining == 0) {
                                break
                            };
                        }
                    };

                    bid_index = bid_index + 1;
                };
            };
        };
    }

    // ============================================================================
    // Trade Settlement
    // ============================================================================

    /// Manually settle a trade between two orders
    /// Fills both orders and transfers shares
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// - market: The market
    /// - buyer_order_id: Buying order ID
    /// - seller_order_id: Selling order ID
    /// - matched_price: Price to settle at
    /// - matched_quantity: Quantity to settle
    /// - ctx: Transaction context
    public fun settle_trade<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        buyer_order_id: u64,
        seller_order_id: u64,
        matched_price: u64,
        matched_quantity: u64,
        ctx: &mut one::tx_context::TxContext,
    ) {
        assert!(table::contains(&orderbook.orders, buyer_order_id), EOrderNotFound);
        assert!(table::contains(&orderbook.orders, seller_order_id), EOrderNotFound);

        let buyer_order_option = {
            let buyer_order = table::borrow(&orderbook.orders, buyer_order_id);
            assert!(buyer_order.is_bid, EUnauthorized);
            buyer_order.option
        };

        let seller_order_option = {
            let seller_order = table::borrow(&orderbook.orders, seller_order_id);
            assert!(!seller_order.is_bid, EUnauthorized);
            seller_order.option
        };

        assert!(buyer_order_option == seller_order_option, EMarketNotFound);

        {
            let buyer_order = table::borrow_mut(&mut orderbook.orders, buyer_order_id);
            buyer_order.filled_quantity = buyer_order.filled_quantity + matched_quantity;
        };

        {
            let seller_order = table::borrow_mut(&mut orderbook.orders, seller_order_id);
            seller_order.filled_quantity = seller_order.filled_quantity + matched_quantity;
        };

        let buyer_addr = {
            let buyer_order = table::borrow(&orderbook.orders, buyer_order_id);
            buyer_order.trader
        };

        let seller_addr = {
            let seller_order = table::borrow(&orderbook.orders, seller_order_id);
            seller_order.trader
        };

        transfer_shares(market, seller_addr, buyer_addr, buyer_order_option, matched_quantity, ctx);

        one::event::emit(TradeSettled {
            buyer_order_id,
            seller_order_id,
            price: matched_price,
            quantity: matched_quantity,
            market_id: orderbook.market_id,
            option: buyer_order_option,
        });
    }

    // ============================================================================
    // Query Functions
    // ============================================================================

    /// Get the highest active bid price
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// 
    /// # Returns
    /// Top bid price (0 if no active bids)
    public fun get_top_bid(orderbook: &OrderBook): u64 {
        if (vector::length(&orderbook.bid_ids) > 0) {
            let order_id = *vector::borrow(&orderbook.bid_ids, 0);
            if (table::contains(&orderbook.active_orders, order_id)) {
                let order = table::borrow(&orderbook.orders, order_id);
                return order.price
            }
        };
        0
    }

    /// Get the lowest active ask price
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// 
    /// # Returns
    /// Top ask price (0 if no active asks)
    public fun get_top_ask(orderbook: &OrderBook): u64 {
        if (vector::length(&orderbook.ask_ids) > 0) {
            let order_id = *vector::borrow(&orderbook.ask_ids, 0);
            if (table::contains(&orderbook.active_orders, order_id)) {
                let order = table::borrow(&orderbook.orders, order_id);
                return order.price
            }
        };
        0
    }

    /// Get order book depth (number of bids and asks)
    /// 
    /// # Arguments
    /// - orderbook: The order book
    /// 
    /// # Returns
    /// (number_of_bids, number_of_asks)
    public fun get_orderbook_depth(orderbook: &OrderBook): (u64, u64) {
        (vector::length(&orderbook.bid_ids), vector::length(&orderbook.ask_ids))
    }
}
