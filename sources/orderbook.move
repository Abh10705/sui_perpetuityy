

module perpetuity_one::orderbook {
    use one::table::{Self, Table};
    use perpetuity_one::types::Option;
    use perpetuity_one::types::{option_a, option_b, complement};
    use perpetuity_one::outcome::{
        Market,
        UserBalance,
        transfer_shares,
        get_user_balance,
        get_user_position,
        get_user_balance_trader,
        get_user_balance_market_id,
        refund_bid_collateral,
        lock_bid_collateral,
        settle_trade_immediate,
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

    fun validate_complementary_price(price_a: u64, price_b: u64) {
        assert!(price_a + price_b == 100, EInvalidComplementaryPrice);
    }

    fun get_complementary_price(price: u64): u64 {
        100 - price
    }

    fun get_complementary_option(option: Option): Option {
        complement(option)
    }

    // ============================================================================
    // Market Initialization
    // ============================================================================

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
        let complementary_price = get_complementary_price(price);
        validate_complementary_price(price, complementary_price);
        assert!(price > 0 && price < 100, EInvalidPrice);
        assert!(quantity > 0, EInvalidQuantity);

        let sender = one::tx_context::sender(ctx);

        assert!(get_user_balance_trader(user_balance) == sender, EUnauthorized);
        assert!(get_user_balance_market_id(user_balance) == orderbook.market_id, EMarketNotFound);

        if (is_bid) {
            let required_collateral = price * quantity;
            let user_balance_amount = get_user_balance(user_balance);
            assert!(user_balance_amount >= required_collateral, EInsufficientFunds);
            lock_bid_collateral(market, user_balance, required_collateral);
        } else {
            let seller_shares = get_user_position(market, sender, option);
            assert!(seller_shares >= quantity, EInsufficientShares);
        };

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
    // Order Cancellation
    // ============================================================================

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

        let unfilled_quantity = order.quantity - order.filled_quantity;
        assert!(unfilled_quantity > 0, EOrderPartiallyFilled);

        let is_bid = order.is_bid;
        let price = order.price;

        let refund_amount = if (is_bid) {
            unfilled_quantity * price
        } else {
            0
        };

        table::remove(&mut orderbook.orders, order_id);
        table::remove(&mut orderbook.active_orders, order_id);

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

        if (is_bid && refund_amount > 0) {
            refund_bid_collateral(market, user_balance, refund_amount);

            one::event::emit(OrderRefunded {
                order_id,
                trader: sender,
                market_id: orderbook.market_id,
                refund_amount,
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
        let mut keep_matching = true;

        // ============================================================================
        // Phase 1: Match same-option orders using strict Price Level Scanning
        // ============================================================================
        if (is_bid) {
            // BUY ORDER: Scan asks starting from the lowest price (1) up to the buy limit price.
            let mut current_price = 1;
            while (current_price <= new_order_price && keep_matching) {
                if (table::contains(&orderbook.ask_levels, current_price)) {
                    let level_ids = *table::borrow(&orderbook.ask_levels, current_price);
                    let len = vector::length(&level_ids);
                    let mut idx = 0;
                    
                    while (idx < len && keep_matching) {
                        let ask_order_id = *vector::borrow(&level_ids, idx);
                        
                        if (!table::contains(&orderbook.active_orders, ask_order_id)) {
                            idx = idx + 1; continue;
                        };

                        let (ask_option, ask_qty, ask_filled) = {
                            let ask = table::borrow(&orderbook.orders, ask_order_id);
                            (ask.option, ask.quantity, ask.filled_quantity)
                        };

                        if (ask_option != new_order_option) {
                            idx = idx + 1; continue;
                        };

                        let ask_remaining = ask_qty - ask_filled;
                        if (ask_remaining == 0) {
                            idx = idx + 1; continue;
                        };

                        let new_remaining = {
                            let new_ord = table::borrow(&orderbook.orders, new_order_id);
                            new_ord.quantity - new_ord.filled_quantity
                        };

                        if (new_remaining == 0) {
                            keep_matching = false; break;
                        };

                        let match_qty = if (new_remaining < ask_remaining) { new_remaining } else { ask_remaining };

                        // Update quantities
                        {
                            let new_ord = table::borrow_mut(&mut orderbook.orders, new_order_id);
                            new_ord.filled_quantity = new_ord.filled_quantity + match_qty;
                        };
                        {
                            let ask_ord = table::borrow_mut(&mut orderbook.orders, ask_order_id);
                            ask_ord.filled_quantity = ask_ord.filled_quantity + match_qty;
                            if (ask_ord.filled_quantity == ask_ord.quantity) {
                                table::remove(&mut orderbook.active_orders, ask_order_id);
                            };
                        };

                        let buyer_addr = { let o = table::borrow(&orderbook.orders, new_order_id); o.trader };
                        let seller_addr = { let o = table::borrow(&orderbook.orders, ask_order_id); o.trader };

                        transfer_shares(market, seller_addr, buyer_addr, new_order_option, match_qty, ctx);
                        
                        let payment_amount = current_price * match_qty; // Executed at Maker's price
                        settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                        one::event::emit(AutoMatched {
                            buyer_order_id: new_order_id,
                            seller_order_id: ask_order_id,
                            price: current_price, 
                            quantity: match_qty,
                            market_id: orderbook.market_id,
                            option: new_order_option,
                        });

                        let check_new_rem = {
                            let new_ord = table::borrow(&orderbook.orders, new_order_id);
                            new_ord.quantity - new_ord.filled_quantity
                        };
                        if (check_new_rem == 0) {
                            keep_matching = false; break;
                        };

                        idx = idx + 1;
                    };
                };
                current_price = current_price + 1;
            };

        } else {
            // SELL ORDER: Scan bids starting from highest price (99) down to sell limit price.
            let mut current_price = 99;
            while (current_price >= new_order_price && keep_matching) {
                if (table::contains(&orderbook.bid_levels, current_price)) {
                    let level_ids = *table::borrow(&orderbook.bid_levels, current_price);
                    let len = vector::length(&level_ids);
                    let mut idx = 0;
                    
                    while (idx < len && keep_matching) {
                        let bid_order_id = *vector::borrow(&level_ids, idx);
                        
                        if (!table::contains(&orderbook.active_orders, bid_order_id)) {
                            idx = idx + 1; continue;
                        };

                        let (bid_option, bid_qty, bid_filled) = {
                            let bid = table::borrow(&orderbook.orders, bid_order_id);
                            (bid.option, bid.quantity, bid.filled_quantity)
                        };

                        if (bid_option != new_order_option) {
                            idx = idx + 1; continue;
                        };

                        let bid_remaining = bid_qty - bid_filled;
                        if (bid_remaining == 0) {
                            idx = idx + 1; continue;
                        };

                        let new_remaining = {
                            let new_ord = table::borrow(&orderbook.orders, new_order_id);
                            new_ord.quantity - new_ord.filled_quantity
                        };

                        if (new_remaining == 0) {
                            keep_matching = false; break;
                        };

                        let match_qty = if (new_remaining < bid_remaining) { new_remaining } else { bid_remaining };

                        // Update quantities
                        {
                            let new_ord = table::borrow_mut(&mut orderbook.orders, new_order_id);
                            new_ord.filled_quantity = new_ord.filled_quantity + match_qty;
                        };
                        {
                            let bid_ord = table::borrow_mut(&mut orderbook.orders, bid_order_id);
                            bid_ord.filled_quantity = bid_ord.filled_quantity + match_qty;
                            if (bid_ord.filled_quantity == bid_ord.quantity) {
                                table::remove(&mut orderbook.active_orders, bid_order_id);
                            };
                        };

                        let buyer_addr = { let o = table::borrow(&orderbook.orders, bid_order_id); o.trader };
                        let seller_addr = { let o = table::borrow(&orderbook.orders, new_order_id); o.trader };

                        transfer_shares(market, seller_addr, buyer_addr, new_order_option, match_qty, ctx);

                        let payment_amount = current_price * match_qty; // Executed at Maker's price
                        settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                        one::event::emit(AutoMatched {
                            buyer_order_id: bid_order_id,
                            seller_order_id: new_order_id,
                            price: current_price,
                            quantity: match_qty,
                            market_id: orderbook.market_id,
                            option: new_order_option,
                        });

                        let check_new_rem = {
                            let new_ord = table::borrow(&orderbook.orders, new_order_id);
                            new_ord.quantity - new_ord.filled_quantity
                        };
                        if (check_new_rem == 0) {
                            keep_matching = false; break;
                        };

                        idx = idx + 1;
                    };
                };
                if (current_price == 1) { break }; // Prevent u64 underflow
                current_price = current_price - 1;
            };
        };

        // ============================================================================
        // Phase 2: Cross-Asset Matching (Complementary)
        // ============================================================================
        let new_order_remaining_phase2 = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.quantity - order.filled_quantity
        };

        if (new_order_remaining_phase2 > 0) {
            let comp_option = get_complementary_option(new_order_option);
            let comp_price_limit = get_complementary_price(new_order_price);

            if (is_bid) {
                // CROSS BUY: Scan complementary asks from 1 up to comp_price_limit
                let mut current_price = 1;
                while (current_price <= comp_price_limit && keep_matching) {
                    if (table::contains(&orderbook.ask_levels, current_price)) {
                        let level_ids = *table::borrow(&orderbook.ask_levels, current_price);
                        let len = vector::length(&level_ids);
                        let mut idx = 0;

                        while (idx < len && keep_matching) {
                            let ask_order_id = *vector::borrow(&level_ids, idx);
                            
                            if (!table::contains(&orderbook.active_orders, ask_order_id)) {
                                idx = idx + 1; continue;
                            };

                            let (ask_option, ask_qty, ask_filled) = {
                                let ask = table::borrow(&orderbook.orders, ask_order_id);
                                (ask.option, ask.quantity, ask.filled_quantity)
                            };

                            if (ask_option != comp_option) {
                                idx = idx + 1; continue;
                            };

                            let ask_remaining = ask_qty - ask_filled;
                            if (ask_remaining == 0) {
                                idx = idx + 1; continue;
                            };

                            let new_remaining = {
                                let new_ord = table::borrow(&orderbook.orders, new_order_id);
                                new_ord.quantity - new_ord.filled_quantity
                            };

                            if (new_remaining == 0) {
                                keep_matching = false; break;
                            };

                            let match_qty = if (new_remaining < ask_remaining) { new_remaining } else { ask_remaining };

                            // Update quantities
                            {
                                let new_ord = table::borrow_mut(&mut orderbook.orders, new_order_id);
                                new_ord.filled_quantity = new_ord.filled_quantity + match_qty;
                            };
                            {
                                let ask_ord = table::borrow_mut(&mut orderbook.orders, ask_order_id);
                                ask_ord.filled_quantity = ask_ord.filled_quantity + match_qty;
                                if (ask_ord.filled_quantity == ask_ord.quantity) {
                                    table::remove(&mut orderbook.active_orders, ask_order_id);
                                };
                            };

                            let buyer_addr = { let o = table::borrow(&orderbook.orders, new_order_id); o.trader };
                            let seller_addr = { let o = table::borrow(&orderbook.orders, ask_order_id); o.trader };

                            transfer_shares(market, seller_addr, buyer_addr, comp_option, match_qty, ctx);
                            
                            let payment_amount = current_price * match_qty;
                            settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                            one::event::emit(CrossAssetMatched {
                                bid_order_id: new_order_id,
                                ask_order_id: ask_order_id,
                                price_a: get_complementary_price(current_price),
                                price_b: current_price,
                                quantity: match_qty,
                                market_id: orderbook.market_id,
                                bid_option: new_order_option,
                                ask_option: comp_option,
                            });

                            let check_new_rem = {
                                let new_ord = table::borrow(&orderbook.orders, new_order_id);
                                new_ord.quantity - new_ord.filled_quantity
                            };
                            if (check_new_rem == 0) {
                                keep_matching = false; break;
                            };

                            idx = idx + 1;
                        };
                    };
                    current_price = current_price + 1;
                };

            } else {
                // CROSS SELL: Scan complementary bids from 99 down to comp_price_limit
                let mut current_price = 99;
                while (current_price >= comp_price_limit && keep_matching) {
                    if (table::contains(&orderbook.bid_levels, current_price)) {
                        let level_ids = *table::borrow(&orderbook.bid_levels, current_price);
                        let len = vector::length(&level_ids);
                        let mut idx = 0;

                        while (idx < len && keep_matching) {
                            let bid_order_id = *vector::borrow(&level_ids, idx);
                            
                            if (!table::contains(&orderbook.active_orders, bid_order_id)) {
                                idx = idx + 1; continue;
                            };

                            let (bid_option, bid_qty, bid_filled) = {
                                let bid = table::borrow(&orderbook.orders, bid_order_id);
                                (bid.option, bid.quantity, bid.filled_quantity)
                            };

                            if (bid_option != comp_option) {
                                idx = idx + 1; continue;
                            };

                            let bid_remaining = bid_qty - bid_filled;
                            if (bid_remaining == 0) {
                                idx = idx + 1; continue;
                            };

                            let new_remaining = {
                                let new_ord = table::borrow(&orderbook.orders, new_order_id);
                                new_ord.quantity - new_ord.filled_quantity
                            };

                            if (new_remaining == 0) {
                                keep_matching = false; break;
                            };

                            let match_qty = if (new_remaining < bid_remaining) { new_remaining } else { bid_remaining };

                            // Update quantities
                            {
                                let new_ord = table::borrow_mut(&mut orderbook.orders, new_order_id);
                                new_ord.filled_quantity = new_ord.filled_quantity + match_qty;
                            };
                            {
                                let bid_ord = table::borrow_mut(&mut orderbook.orders, bid_order_id);
                                bid_ord.filled_quantity = bid_ord.filled_quantity + match_qty;
                                if (bid_ord.filled_quantity == bid_ord.quantity) {
                                    table::remove(&mut orderbook.active_orders, bid_order_id);
                                };
                            };

                            let buyer_addr = { let o = table::borrow(&orderbook.orders, bid_order_id); o.trader };
                            let seller_addr = { let o = table::borrow(&orderbook.orders, new_order_id); o.trader };

                            transfer_shares(market, seller_addr, buyer_addr, comp_option, match_qty, ctx);

                            let payment_amount = current_price * match_qty;
                            settle_trade_immediate(market, seller_addr, payment_amount, ctx);

                            one::event::emit(CrossAssetMatched {
                                bid_order_id: bid_order_id,
                                ask_order_id: new_order_id,
                                price_a: current_price,
                                price_b: get_complementary_price(current_price),
                                quantity: match_qty,
                                market_id: orderbook.market_id,
                                bid_option: comp_option,
                                ask_option: new_order_option,
                            });

                            let check_new_rem = {
                                let new_ord = table::borrow(&orderbook.orders, new_order_id);
                                new_ord.quantity - new_ord.filled_quantity
                            };
                            if (check_new_rem == 0) {
                                keep_matching = false; break;
                            };

                            idx = idx + 1;
                        };
                    };
                    if (current_price == 1) { break }; 
                    current_price = current_price - 1;
                };
            };
        };
    }
    // ============================================================================
    // Trade Settlement
    // ============================================================================

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

    public fun get_orderbook_depth(orderbook: &OrderBook): (u64, u64) {
        (vector::length(&orderbook.bid_ids), vector::length(&orderbook.ask_ids))
    }
}
