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

    // ========== ERRORS ==========
    const EInvalidPrice: u64 = 1;
    const EInvalidQuantity: u64 = 2;
    const EOrderNotFound: u64 = 3;
    const EMarketNotFound: u64 = 4;
    const EInsufficientFunds: u64 = 5;
    const EUnauthorized: u64 = 6;

    // ========== ENUMS ==========
    public enum Option has copy, drop, store {
        OptionA,
        OptionB,
    }

    // ========== EVENTS ==========
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
    }

    public struct AutoMatched has copy, drop {
        buyer_order_id: u64,
        seller_order_id: u64,
        price: u64,
        quantity: u64,
        market_id: u64,
    }

    // ========== STRUCTS ==========
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

    // ========== INITIALIZATION ==========
    public fun init_admin(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // ========== CREATE MARKET ==========
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

    // ========== DEPOSIT FUNDS ==========
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

    // ========== WITHDRAW FUNDS ==========
    public fun withdraw_funds<CoinType>(
        user_balance: &mut UserBalance<CoinType>,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        assert!(balance::value(&user_balance.balance) >= amount, EInsufficientFunds);
        let withdrawn = balance::split(&mut user_balance.balance, amount);
        coin::from_balance(withdrawn, ctx)
    }

    // ========== AUTO-MATCHING LOGIC ==========
    fun auto_match_orders<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        new_order_id: u64,
        is_bid: bool,
    ) {
        let new_order_price = {
            let order = table::borrow(&orderbook.orders, new_order_id);
            order.price
        };

        if (is_bid) {
            // New order is BID (BUY), look for ASK (SELL) orders with best price (lowest)
            let mut ask_index = 0;
            let ask_len = vector::length(&orderbook.ask_ids);

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

                if (ask_price <= new_order_price) {
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

                        event::emit(AutoMatched {
                            buyer_order_id: new_order_id,
                            seller_order_id: ask_order_id,
                            price: ask_price,
                            quantity: match_qty,
                            market_id: orderbook.market_id,
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
            // New order is ASK (SELL), look for BID (BUY) orders with best price (highest)
            let mut bid_index = 0;
            let bid_len = vector::length(&orderbook.bid_ids);

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

                if (bid_price >= new_order_price) {
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

                        event::emit(AutoMatched {
                            buyer_order_id: bid_order_id,
                            seller_order_id: new_order_id,
                            price: bid_price,
                            quantity: match_qty,
                            market_id: orderbook.market_id,
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

    // ========== PLACE ORDER ==========
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
        assert!(price > 0, EInvalidPrice);
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
            created_at: 0,
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

        // AUTO-MATCHING HAPPENS HERE!
        auto_match_orders(orderbook, market, order_id, is_bid);

        // Handle refunds for unfilled portions
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

    // ========== PLACE ORDER CLI WRAPPER ==========
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

    // ========== CANCEL ORDER ==========
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

    // ========== SETTLE TRADE ==========
    public fun settle_trade<CoinType>(
        orderbook: &mut OrderBook,
        market: &mut Market<CoinType>,
        buyer_order_id: u64,
        seller_order_id: u64,
        matched_price: u64,
        matched_quantity: u64,
        buyer_balance: &mut UserBalance<CoinType>,
        seller_balance: &mut UserBalance<CoinType>,
        _ctx: &mut TxContext,
    ) {
        assert!(table::contains(&orderbook.orders, buyer_order_id), EOrderNotFound);
        assert!(table::contains(&orderbook.orders, seller_order_id), EOrderNotFound);

        {
            let buyer_order = table::borrow(&orderbook.orders, buyer_order_id);
            assert!(buyer_order.is_bid, EUnauthorized);
        };

        {
            let seller_order = table::borrow(&orderbook.orders, seller_order_id);
            assert!(!seller_order.is_bid, EUnauthorized);
        };

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

        event::emit(TradeSettled {
            buyer_order_id,
            seller_order_id,
            price: matched_price,
            quantity: matched_quantity,
            market_id: orderbook.market_id,
        });
    }

    // ========== VIEW FUNCTIONS ==========
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
}
