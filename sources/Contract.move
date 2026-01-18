module perpetuity_sui::orderbook {
    use one::balance::{Self, Balance};
    use one::coin::{Self, Coin};
    use one::table::{Self, Table};
    use one::event;
    use std::string::String;
    use std::vector;

    const EInvalidPrice: u64 = 1;
    const EInvalidQuantity: u64 = 2;
    const EOrderNotFound: u64 = 3;
    const EMarketNotFound: u64 = 4;
    const EInsufficientFunds: u64 = 5;
    const EUnauthorized: u64 = 6;
    const EInvalidComplementaryPrice: u64 = 7;
    const EInsufficientShares: u64 = 8;
    const EInsufficientSettlementFunds: u64 = 9;

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

    public struct CrossAssetMatched has copy, drop {
        bid_order_id: u64,
        ask_order_id: u64,
        price_a: u64,
        price_b: u64,
        quantity: u64,
        market_id: u64,
        bid_option: Option,
        ask_option: Option,
    }

    public struct SharesTransferred has copy, drop {
        from: address,
        to: address,
        asset: Option,
        quantity: u64,
        market_id: u64,
    }

    public struct SharesMinted has copy, drop {
        trader: address,
        amount: u64,
        option_a_shares: u64,
        option_b_shares: u64,
        market_id: u64,
    }

    // NEW EVENT: Settlement Claimed
    public struct SettlementClaimed has copy, drop {
        user: address,
        amount: u64,
        market_id: u64,
    }

    public struct AdminCap has key {
        id: one::object::UID,
    }

    public struct Market<phantom CoinType> has key {
        id: one::object::UID,
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
        trader_balances: Table<address, one::object::ID>,
        // NEW FIELD: Settlement Pool
        settlement_pool: Table<address, u64>,
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
        locked_collateral: u64,
    }

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

    public struct UserBalance<phantom CoinType> has key {
        id: one::object::UID,
        market_id: u64,
        trader: address,
        balance: Balance<CoinType>,
    }

    public fun init_admin(ctx: &mut one::tx_context::TxContext) {
        let admin_cap = AdminCap {
            id: one::object::new(ctx),
        };
        one::transfer::transfer(admin_cap, one::tx_context::sender(ctx));
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

    // NEW HELPER FUNCTION: Add to Settlement Pool
    fun add_to_settlement_pool(
        pool: &mut Table<address, u64>,
        user: address,
        amount: u64,
    ) {
        if (table::contains(pool, user)) {
            let current = table::borrow_mut(pool, user);
            *current = *current + amount;
        } else {
            table::add(pool, user, amount);
        }
    }

    public fun create_market<CoinType>(
        _admin_cap: &AdminCap,
        market_id: u64,
        question: String,
        option_a_name: String,
        option_b_name: String,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let market = Market<CoinType> {
            id: one::object::new(ctx),
            market_id,
            admin: one::tx_context::sender(ctx),
            question,
            option_a_name,
            option_b_name,
            vault: balance::zero(),
            is_active: true,
            created_at: 0,
            option_a_shares: table::new(ctx),
            option_b_shares: table::new(ctx),
            trader_balances: table::new(ctx),
            settlement_pool: table::new(ctx),
        };

        let orderbook = OrderBook {
            id: one::object::new(ctx),
            market_id,
            orders: table::new(ctx),
            active_orders: table::new(ctx),
            bid_ids: vector::empty(),
            ask_ids: vector::empty(),
            bid_levels: table::new(ctx),
            ask_levels: table::new(ctx),
            next_order_id: 1,
        };

        one::transfer::share_object(market);
        one::transfer::share_object(orderbook);
    }

    public fun deposit_funds<CoinType>(
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        coins: Coin<CoinType>,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let amount = coin::value(&coins);
        assert!(amount > 0, EInsufficientFunds);

        let sender = one::tx_context::sender(ctx);
        assert!(user_balance.trader == sender, EUnauthorized);
        assert!(user_balance.market_id == market.market_id, EMarketNotFound);

        // Add to existing balance
        balance::join(&mut user_balance.balance, coin::into_balance(coins));

        update_user_shares(&mut market.option_a_shares, sender, amount, true);
        update_user_shares(&mut market.option_b_shares, sender, amount, true);

        event::emit(SharesMinted {
            trader: sender,
            amount,
            option_a_shares: amount,
            option_b_shares: amount,
            market_id: market.market_id,
        });
    }

    public fun create_user_balance<CoinType>(
        market: &mut Market<CoinType>,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let sender = one::tx_context::sender(ctx);
        
        assert!(
            !table::contains(&market.trader_balances, sender),
            EUnauthorized
        );

        let user_balance = UserBalance<CoinType> {
            id: one::object::new(ctx),
            market_id: market.market_id,
            trader: sender,
            balance: balance::zero(),
        };

        let user_balance_id = one::object::id(&user_balance);
        table::add(&mut market.trader_balances, sender, user_balance_id);
        
        one::transfer::transfer(user_balance, sender);
    }

    public fun withdraw_funds<CoinType>(
        user_balance: &mut UserBalance<CoinType>,
        amount: u64,
        ctx: &mut one::tx_context::TxContext,
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
        _ctx: &mut one::tx_context::TxContext,
    ) {
        if (option == Option::OptionA) {
            let from_shares = get_user_shares(&market.option_a_shares, from);
            assert!(from_shares >= quantity, EInsufficientShares);
            update_user_shares(&mut market.option_a_shares, from, quantity, false);
            update_user_shares(&mut market.option_a_shares, to, quantity, true);
        } else {
            let from_shares = get_user_shares(&market.option_b_shares, from);
            assert!(from_shares >= quantity, EInsufficientShares);
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
        caller_balance: &mut UserBalance<CoinType>,
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

                        // MODIFIED: Use settlement pool instead of direct transfer
                        let payment_amount = ask_price * match_qty;
                        add_to_settlement_pool(&mut market.settlement_pool, seller_addr, payment_amount);

                        assert!(table::contains(&market.trader_balances, seller_addr), EMarketNotFound);

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

                        // Transfer coins from vault to caller (ASK seller)
                        let payment_amount = bid_price * match_qty;
                        let payment = balance::split(&mut market.vault, payment_amount);
                        balance::join(&mut caller_balance.balance, payment);

                        assert!(table::contains(&market.trader_balances, seller_addr), EMarketNotFound);

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
                    bid_index = bid_index + 1;
                    continue
                };

                bid_index = bid_index + 1;
            };
        };

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

                            // MODIFIED: Use settlement pool for cross-asset match
                            let payment_amount = new_order_price * match_qty;
                            add_to_settlement_pool(&mut market.settlement_pool, seller_addr, payment_amount);

                            assert!(table::contains(&market.trader_balances, seller_addr), EMarketNotFound);

                            event::emit(CrossAssetMatched {
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

                            // MODIFIED: Use settlement pool for cross-asset match
                            let payment_amount = bid_price * match_qty;
                            add_to_settlement_pool(&mut market.settlement_pool, buyer_addr, payment_amount);

                            assert!(table::contains(&market.trader_balances, seller_addr), EMarketNotFound);

                            event::emit(CrossAssetMatched {
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
        assert!(user_balance.market_id == orderbook.market_id, EMarketNotFound);
        assert!(market.is_active, EMarketNotFound);

        let sender = one::tx_context::sender(ctx);
        assert!(user_balance.trader == sender, EUnauthorized);

        if (is_bid) {
            let required_collateral = price * quantity;
            assert!(balance::value(&user_balance.balance) >= required_collateral, EInsufficientFunds);
            let collateral = balance::split(&mut user_balance.balance, required_collateral);
            balance::join(&mut market.vault, collateral);
        } else {
            let seller_shares = get_user_shares(
                if (option == Option::OptionA) &market.option_a_shares else &market.option_b_shares,
                sender
            );
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
                table::add(&mut orderbook.bid_levels, price, vector::empty());
            };
            let bid_level = table::borrow_mut(&mut orderbook.bid_levels, price);
            vector::push_back(bid_level, order_id);
        } else {
            vector::push_back(&mut orderbook.ask_ids, order_id);
            if (!table::contains(&orderbook.ask_levels, price)) {
                table::add(&mut orderbook.ask_levels, price, vector::empty());
            };
            let ask_level = table::borrow_mut(&mut orderbook.ask_levels, price);
            vector::push_back(ask_level, order_id);
        };

        event::emit(OrderPlaced {
            order_id,
            trader: sender,
            market_id: orderbook.market_id,
            option,
            price,
            quantity,
            is_bid,
        });

        orderbook.next_order_id = orderbook.next_order_id + 1;
        auto_match_orders(orderbook, market, order_id, is_bid, user_balance, ctx);
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

    // NEW PUBLIC FUNCTION: Claim Settlement
    public fun claim_settlement<CoinType>(
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let sender = one::tx_context::sender(ctx);
        assert!(user_balance.trader == sender, EUnauthorized);

        if (table::contains(&market.settlement_pool, sender)) {
            let amount = table::remove(&mut market.settlement_pool, sender);
            
            if (amount > 0) {
                assert!(balance::value(&market.vault) >= amount, EInsufficientSettlementFunds);
                let payment = balance::split(&mut market.vault, amount);
                balance::join(&mut user_balance.balance, payment);
                
                event::emit(SettlementClaimed {
                    user: sender,
                    amount,
                    market_id: market.market_id,
                });
            }
        }
    }

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

        let is_bid = order.is_bid;
        let price = order.price;
        let unfilled = order.quantity - order.filled_quantity;
        let refund_amount = price * unfilled;

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

    // NEW PUBLIC FUNCTION: Get Pending Settlement
    public fun get_pending_settlement<CoinType>(
        market: &Market<CoinType>,
        user: address,
    ): u64 {
        if (table::contains(&market.settlement_pool, user)) {
            *table::borrow(&market.settlement_pool, user)
        } else {
            0
        }
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
