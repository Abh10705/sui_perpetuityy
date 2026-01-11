module perpetuity_sui::orderbook {
    use one::balance::{Self, Balance};
    use one::coin::{Self, Coin};
    use one::table::{Self, Table};
    use one::event;
    use std::string::String;
    use one::object::{Self, UID};
    use one::transfer;
    use one::tx_context::{Self, TxContext};
    use std::vector;


    const EInvalidPrice: u64 = 1;
    const EInvalidQuantity: u64 = 2;
    const EOrderNotFound: u64 = 3;
    const EMarketNotFound: u64 = 4;
    const EInsufficientFunds: u64 = 5;
    const EUnauthorized: u64 = 6;
    const EInvalidComplementaryPrice: u64 = 7;
    const EInsufficientShares: u64 = 8;


    public enum Option has copy, drop, store {
        OptionA,
        OptionB,
    }


    public struct OrderPlaced has copy, drop {
        order_id: u64,
        trader: address,
        market_id: u64,
        option: Option,
        price: u64,
        quantity: u64,
        is_bid: bool,
    }


    public struct OrderCancelled has copy, drop {
        order_id: u64,
        trader: address,
        market_id: u64,
    }


    public struct TradeSettled has copy, drop {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
        option: Option,
    }


    public struct AutoMatched has copy, drop {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
        option: Option,
    }


    public struct SharesTransferred has copy, drop {
        from: address,
        to: address,
        asset: Option,
        quantity: u64,
        market_id: u64,
    }


    public struct BatchMatched has copy, drop {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
        option: Option,
        is_cross_asset: bool,
    }


    public struct MatchRecord has copy, drop {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        option: Option,
        is_cross_asset: bool,
    }


    public struct BatchMatchResult has copy, drop {
        matches: vector<MatchRecord>,
        total_matches: u64,
        total_quantity_matched: u64,
    }


    public struct AdminCap has key {
        id: UID,
    }


    public struct Market<phantom CoinType> has key {
        id: UID,
        market_id: u64,
        admin: address,
        question: String,
        option_a_name: String,
        option_b_name: String,
        vault: Balance<CoinType>,
        is_active: bool,
        created_at: u64,
        option_a_shares: Table<address, u64>,
        option_b_shares: Table<address, u64>,
    }


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
    }


    public struct OrderBook has key {
        id: UID,
        market_id: u64,
        orders: Table<u64, Order>,
        active_orders: Table<u64, bool>,
        bid_ids: vector<u64>,
        ask_ids: vector<u64>,
        next_order_id: u64,
    }


    public struct UserBalance<phantom CoinType> has key {
        id: UID,
        market_id: u64,
        trader: address,
        balance: Balance<CoinType>,
    }


    public fun init_admin(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }


    fun validate_complementary_price(price_a: u64, price_b: u64) {
        assert!(price_a + price_b == 100, EInvalidComplementaryPrice);
    }


    fun get_complementary_price(price: u64): u64 {
        100 - price
    }


    fun get_complementary_option(option: Option): Option {
        if (option == Option::OptionA) {
            Option::OptionB
        } else {
            Option::OptionA
        }
    }


    public fun create_market<CoinType>(
        _admin_cap: &AdminCap,
        market_id: u64,
        question: String,
        option_a_name: String,
        option_b_name: String,
        ctx: &mut TxContext,
    ) {
        let market = Market<CoinType> {
            id: object::new(ctx),
            market_id,
            admin: tx_context::sender(ctx),
            question,
            option_a_name,
            option_b_name,
            vault: balance::zero(),
            is_active: true,
            created_at: 0,
            option_a_shares: table::new(ctx),
            option_b_shares: table::new(ctx),
        };


        let orderbook = OrderBook {
            id: object::new(ctx),
            market_id,
            orders: table::new(ctx),
            active_orders: table::new(ctx),
            bid_ids: vector::empty(),
            ask_ids: vector::empty(),
            next_order_id: 1,
        };


        transfer::share_object(market);
        transfer::share_object(orderbook);
    }


    public fun deposit_funds<CoinType>(
        market_id: u64,
        coins: Coin<CoinType>,
        ctx: &mut TxContext,
    ) {
        let amount = coin::value(&coins);
        assert!(amount > 0, EInsufficientFunds);


        let user_balance = UserBalance<CoinType> {
            id: object::new(ctx),
            market_id,
            trader: tx_context::sender(ctx),
            balance: coin::into_balance(coins),
        };


        transfer::transfer(user_balance, tx_context::sender(ctx));
    }


    public fun withdraw_funds<CoinType>(
        user_balance: &mut UserBalance<CoinType>,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        assert!(balance::value(&user_balance.balance) >= amount, EInsufficientFunds);
        let withdrawn = balance::split(&mut user_balance.balance, amount);
        coin::from_balance(withdrawn, ctx)
    }


    fun update_user_shares(
        shares_table: &mut Table<address, u64>,
        user: address,
        amount: u64,
        is_add: bool,
    ) {
        if (table::contains(shares_table, user)) {
            let current = table::borrow_mut(shares_table, user);
            if (is_add) {
                *current = *current + amount;
            } else {
                assert!(*current >= amount, EInsufficientShares);
                *current = *current - amount;
            }
        } else {
            assert!(is_add, EInsufficientShares);
            table::add(shares_table, user, amount);
        }
    }


    fun get_user_shares(
        shares_table: &Table<address, u64>,
        user: address,
    ): u64 {
        if (table::contains(shares_table, user)) {
            *table::borrow(shares_table, user)
        } else {
            0
        }
    }


    

    fun transfer_shares<CoinType>(
        market: &mut Market<CoinType>,
        from: address,
        to: address,
        option: Option,
        quantity: u64,
        _ctx: &mut TxContext,
    ) {
        if (option == Option::OptionA) {
            // If seller doesn't have shares, create them (cross-asset match)
            let from_shares = get_user_shares(&market.option_a_shares, from);
            if (from_shares < quantity) {
                // Mint missing shares
                update_user_shares(&mut market.option_a_shares, from, quantity, true);
            };
            
            // Now transfer
            update_user_shares(&mut market.option_a_shares, from, quantity, false);
            update_user_shares(&mut market.option_a_shares, to, quantity, true);
        } else {
            let from_shares = get_user_shares(&market.option_b_shares, from);
            if (from_shares < quantity) {
                update_user_shares(&mut market.option_b_shares, from, quantity, true);
            };
            
            update_user_shares(&mut market.option_b_shares, from, quantity, false);
            update_user_shares(&mut market.option_b_shares, to, quantity, true);
        };

        event::emit(SharesTransferred {
            from,
            to,
            asset: option,
            quantity,
            market_id: market.market_id,
        });
    }




    fun auto_match_orders<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        new_order_id: u64,
        is_bid: bool,
        ctx: &mut TxContext,
    ) {
        let new_order_price = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.price
        };


        let new_order_option = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.option
        };


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


                        event::emit(AutoMatched {
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
                    break
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


                        event::emit(AutoMatched {
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
                    break
                };


                bid_index = bid_index + 1;
            };
        };
    }


    public fun place_order<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        option: Option,
        price: u64,
        quantity: u64,
        is_bid: bool,
        ctx: &mut TxContext,
    ) {
        let complementary_price = get_complementary_price(price);
        validate_complementary_price(price, complementary_price);


        assert!(price > 0 && price < 100, EInvalidPrice);
        assert!(quantity > 0, EInvalidQuantity);
        assert!(user_balance.market_id == orderbook.market_id, EMarketNotFound);
        assert!(market.is_active, EMarketNotFound);


        let required_collateral = price * quantity;
        assert!(balance::value(&user_balance.balance) >= required_collateral, EInsufficientFunds);


        let collateral = balance::split(&mut user_balance.balance, required_collateral);
        balance::join(&mut market.vault, collateral);


        let order = Order {
            order_id: orderbook.next_order_id,
            trader: tx_context::sender(ctx),
            market_id: orderbook.market_id,
            option,
            price,
            quantity,
            filled_quantity: 0,
            is_bid,
            created_at: tx_context::epoch(ctx),
        };


        let order_id = orderbook.next_order_id;
        table::add(&mut orderbook.orders, order_id, order);
        table::add(&mut orderbook.active_orders, order_id, true);


        if (is_bid) {
            vector::push_back(&mut orderbook.bid_ids, order_id);
        } else {
            vector::push_back(&mut orderbook.ask_ids, order_id);
        };


        event::emit(OrderPlaced {
            order_id,
            trader: tx_context::sender(ctx),
            market_id: orderbook.market_id,
            option,
            price,
            quantity,
            is_bid,
        });


        orderbook.next_order_id = orderbook.next_order_id + 1;


        auto_match_orders(orderbook, market, order_id, is_bid, ctx);


        let unfilled_qty = {
            let order = table::borrow(&orderbook.orders, order_id);
            order.quantity - order.filled_quantity
        };


        if (unfilled_qty > 0) {
            let refund_amount = price * unfilled_qty;
            if (refund_amount > 0) {
                let refund = balance::split(&mut market.vault, refund_amount);
                balance::join(&mut user_balance.balance, refund);
            };
        };
    }


    public fun place_order_cli<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        option_u8: u8,
        price: u64,
        quantity: u64,
        is_bid: bool,
        ctx: &mut TxContext,
    ) {
        let option = if (option_u8 == 0) { Option::OptionA } else { Option::OptionB };
        
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


    public fun cancel_order<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        order_id: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&orderbook.orders, order_id), EOrderNotFound);


        let order = table::borrow(&orderbook.orders, order_id);
        assert!(order.trader == sender, EUnauthorized);


        let is_bid = order.is_bid;
        let unfilled = order.quantity - order.filled_quantity;
        let refund_amount = order.price * unfilled;


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
        } else {
            let ask_len = vector::length(&orderbook.ask_ids);
            let mut ask_i = 0;
            while (ask_i < ask_len) {
                if (*vector::borrow(&orderbook.ask_ids, ask_i) == order_id) {
                    vector::remove(&mut orderbook.ask_ids, ask_i);
                    break
                };
                ask_i = ask_i + 1;
            };
        };


        if (refund_amount > 0) {
            let refund = balance::split(&mut market.vault, refund_amount);
            balance::join(&mut user_balance.balance, refund);
        };


        event::emit(OrderCancelled {
            order_id,
            trader: sender,
            market_id: orderbook.market_id,
        });
    }


    public fun settle_trade<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        buyer_order_id: u64,
        seller_order_id: u64,
        matched_price: u64,
        matched_quantity: u64,
        buyer_balance: &mut UserBalance<CoinType>,
        seller_balance: &mut UserBalance<CoinType>,
        ctx: &mut TxContext,
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


        let buyer_refund_amt = {
            let buyer_order = table::borrow(&orderbook.orders, buyer_order_id);
            let buyer_unfilled = buyer_order.quantity - buyer_order.filled_quantity;
            buyer_order.price * buyer_unfilled
        };


        let seller_refund_amt = {
            let seller_order = table::borrow(&orderbook.orders, seller_order_id);
            let seller_unfilled = seller_order.quantity - seller_order.filled_quantity;
            seller_order.price * seller_unfilled
        };


        if (buyer_refund_amt > 0) {
            let refund = balance::split(&mut market.vault, buyer_refund_amt);
            balance::join(&mut buyer_balance.balance, refund);
        };
        if (seller_refund_amt > 0) {
            let refund = balance::split(&mut market.vault, seller_refund_amt);
            balance::join(&mut seller_balance.balance, refund);
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


        event::emit(TradeSettled {
            buyer_order_id,
            seller_order_id,
            price: matched_price,
            quantity: matched_quantity,
            market_id: orderbook.market_id,
            option: buyer_order_option,
        });
    }


    public fun batch_match_orders<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        ctx: &mut TxContext,
    ): BatchMatchResult {
        let mut matches = vector::empty<MatchRecord>();


        let active_bids = collect_active_orders(&orderbook.orders, &orderbook.bid_ids, &orderbook.active_orders);
        let active_asks = collect_active_orders(&orderbook.orders, &orderbook.ask_ids, &orderbook.active_orders);


        let sorted_bids = sort_orders_by_price(&orderbook.orders, active_bids, false);
        let sorted_asks = sort_orders_by_price(&orderbook.orders, active_asks, true);


        let same_asset_matches = match_same_asset_orders(
            &mut orderbook.orders,
            sorted_bids,
            sorted_asks,
            market,
            ctx,
        );
        vector::append(&mut matches, same_asset_matches);


        let cross_asset_matches = match_cross_asset_orders(
            &mut orderbook.orders,
            &orderbook.bid_ids,
            &orderbook.ask_ids,
            &orderbook.active_orders,
            market,
            ctx,
        );
        vector::append(&mut matches, cross_asset_matches);


        let mut match_index = 0;
        while (match_index < vector::length(&matches)) {
            let match_record = *vector::borrow(&matches, match_index);
            
            {
                let buyer_order = table::borrow_mut(&mut orderbook.orders, match_record.buyer_order_id);
                buyer_order.filled_quantity = buyer_order.filled_quantity + match_record.quantity;
            };


            {
                let seller_order = table::borrow_mut(&mut orderbook.orders, match_record.seller_order_id);
                seller_order.filled_quantity = seller_order.filled_quantity + match_record.quantity;
            };


            event::emit(BatchMatched {
                buyer_order_id: match_record.buyer_order_id,
                seller_order_id: match_record.seller_order_id,
                price: match_record.price,
                quantity: match_record.quantity,
                market_id: orderbook.market_id,
                option: match_record.option,
                is_cross_asset: match_record.is_cross_asset,
            });


            match_index = match_index + 1;
        };


        let total_qty = calculate_total_matched_qty(&matches);
        
        BatchMatchResult {
            matches,
            total_matches: vector::length(&matches),
            total_quantity_matched: total_qty,
        }
    }


    fun collect_active_orders(
        orders: &Table<u64, Order>,
        order_ids: &vector<u64>,
        active_orders: &Table<u64, bool>,
    ): vector<u64> {
        let mut active = vector::empty<u64>();
        let mut i = 0;
        
        while (i < vector::length(order_ids)) {
            let order_id = *vector::borrow(order_ids, i);
            if (table::contains(active_orders, order_id)) {
                let order = table::borrow(orders, order_id);
                let unfilled = order.quantity - order.filled_quantity;
                if (unfilled > 0) {
                    vector::push_back(&mut active, order_id);
                }
            };
            i = i + 1;
        };
        
        active
    }


    fun sort_orders_by_price(
        orders: &Table<u64, Order>,
        mut order_ids: vector<u64>,
        ascending: bool,
    ): vector<u64> {
        let len = vector::length(&order_ids);
        let mut i = 0;
        
        while (i < len) {
            let mut j = 0;
            while (j < len - i - 1) {
                let order_a_id = *vector::borrow(&order_ids, j);
                let order_b_id = *vector::borrow(&order_ids, j + 1);
                
                let order_a = table::borrow(orders, order_a_id);
                let order_b = table::borrow(orders, order_b_id);
                
                let should_swap = if (ascending) {
                    if (order_a.price == order_b.price) {
                        order_a.created_at > order_b.created_at
                    } else {
                        order_a.price > order_b.price
                    }
                } else {
                    if (order_a.price == order_b.price) {
                        order_a.created_at > order_b.created_at
                    } else {
                        order_a.price < order_b.price
                    }
                };
                
                if (should_swap) {
                    vector::swap(&mut order_ids, j, j + 1);
                };
                
                j = j + 1;
            };
            i = i + 1;
        };
        
        order_ids
    }


    fun match_same_asset_orders<CoinType>(
        orders: &mut Table<u64, Order>,
        bids: vector<u64>,
        asks: vector<u64>,
        market: &mut Market<CoinType>,
        ctx: &mut TxContext,
    ): vector<MatchRecord> {
        let mut matches = vector::empty<MatchRecord>();
        
        let mut bid_index = 0;
        let bid_len = vector::length(&bids);
        
        while (bid_index < bid_len) {
            let bid_order_id = *vector::borrow(&bids, bid_index);
            let bid_order = table::borrow(orders, bid_order_id);
            let bid_remaining = bid_order.quantity - bid_order.filled_quantity;
            let bid_price = bid_order.price;
            let bid_option = bid_order.option;
            let bid_trader = bid_order.trader;
            
            if (bid_remaining == 0) {
                bid_index = bid_index + 1;
                continue
            };
            
            let mut ask_index = 0;
            let ask_len = vector::length(&asks);
            
            while (ask_index < ask_len) {
                let ask_order_id = *vector::borrow(&asks, ask_index);
                let ask_order = table::borrow(orders, ask_order_id);
                let ask_remaining = ask_order.quantity - ask_order.filled_quantity;
                let ask_price = ask_order.price;
                let ask_option = ask_order.option;
                let ask_trader = ask_order.trader;
                
                if (ask_remaining == 0) {
                    ask_index = ask_index + 1;
                    continue
                };
                
                if (bid_option == ask_option && ask_price <= bid_price) {
                    let match_qty = if (bid_remaining < ask_remaining) {
                        bid_remaining
                    } else {
                        ask_remaining
                    };
                    
                    vector::push_back(&mut matches, MatchRecord {
                        buyer_order_id: bid_order_id,
                        seller_order_id: ask_order_id,
                        price: bid_price,
                        quantity: match_qty,
                        option: bid_option,
                        is_cross_asset: false,
                    });
                    
                    transfer_shares(market, ask_trader, bid_trader, ask_option, match_qty, ctx);
                };
                
                ask_index = ask_index + 1;
            };
            
            bid_index = bid_index + 1;
        };
        
        matches
    }


    fun match_cross_asset_orders<CoinType>(
        orders: &mut Table<u64, Order>,
        bid_ids: &vector<u64>,
        ask_ids: &vector<u64>,
        active_orders: &Table<u64, bool>,
        market: &mut Market<CoinType>,
        ctx: &mut TxContext,
    ): vector<MatchRecord> {
        let mut matches = vector::empty<MatchRecord>();
        
        let mut bid_index = 0;
        while (bid_index < vector::length(bid_ids)) {
            let bid_order_id = *vector::borrow(bid_ids, bid_index);
            
            if (!table::contains(active_orders, bid_order_id)) {
                bid_index = bid_index + 1;
                continue
            };
            
            let bid_order = table::borrow(orders, bid_order_id);
            let bid_remaining = bid_order.quantity - bid_order.filled_quantity;
            
            if (bid_remaining == 0) {
                bid_index = bid_index + 1;
                continue
            };
            
            let bid_price = bid_order.price;
            let bid_option = bid_order.option;
            let bid_trader = bid_order.trader;
            let complementary_option = get_complementary_option(bid_option);
            let complementary_price = 100 - bid_price;
            
            let mut ask_index = 0;
            while (ask_index < vector::length(ask_ids)) {
                let ask_order_id = *vector::borrow(ask_ids, ask_index);
                
                if (!table::contains(active_orders, ask_order_id)) {
                    ask_index = ask_index + 1;
                    continue
                };
                
                let ask_order = table::borrow(orders, ask_order_id);
                let ask_remaining = ask_order.quantity - ask_order.filled_quantity;
                
                if (ask_remaining == 0) {
                    ask_index = ask_index + 1;
                    continue
                };
                
                let ask_price = ask_order.price;
                let ask_option = ask_order.option;
                let ask_trader = ask_order.trader;
                
                if (ask_option == complementary_option && ask_price <= complementary_price) {
                    let match_qty = if (bid_remaining < ask_remaining) {
                        bid_remaining
                    } else {
                        ask_remaining
                    };
                    
                    vector::push_back(&mut matches, MatchRecord {
                        buyer_order_id: bid_order_id,
                        seller_order_id: ask_order_id,
                        price: bid_price,
                        quantity: match_qty,
                        option: bid_option,
                        is_cross_asset: true,
                    });
                    
                    transfer_shares(market, ask_trader, bid_trader, bid_option, match_qty, ctx);
                };
                
                ask_index = ask_index + 1;
            };
            
            bid_index = bid_index + 1;
        };
        
        matches
    }


    fun calculate_total_matched_qty(matches: &vector<MatchRecord>): u64 {
        let mut total = 0;
        let mut i = 0;
        while (i < vector::length(matches)) {
            let match_record = vector::borrow(matches, i);
            total = total + match_record.quantity;
            i = i + 1;
        };
        total
    }


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


    public fun get_user_balance<CoinType>(user_balance: &UserBalance<CoinType>): u64 {
        balance::value(&user_balance.balance)
    }


    public fun get_market_vault_balance<CoinType>(market: &Market<CoinType>): u64 {
        balance::value(&market.vault)
    }


    public fun get_user_position<CoinType>(
        market: &Market<CoinType>,
        user_balance: &UserBalance<CoinType>,
        user: address,
    ): (u64, u64, u64) {
        let option_a_shares = get_user_shares(&market.option_a_shares, user);
        let option_b_shares = get_user_shares(&market.option_b_shares, user);
        let usdc_balance = balance::value(&user_balance.balance);
        (option_a_shares, option_b_shares, usdc_balance)
    }
}
