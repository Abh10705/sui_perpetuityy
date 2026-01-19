module perpetuity_sui::outcome {
    use one::balance::{Self, Balance};
    use one::coin::{Self, Coin};
    use one::table::{Self, Table};
    use perpetuity_sui::types::Option;
    use perpetuity_sui::types::option_a;
    
    // ============================================================================
    // Events (defined in outcome module)
    // ============================================================================




    public struct SharesTransferred has drop, copy {
        from: address,
        to: address,
        asset: Option,
        quantity: u64,
        market_id: u64,
    }




    public struct SettlementClaimed has drop, copy {
        user: address,
        amount: u64,
        market_id: u64,
    }




    // ============================================================================
    // Error Codes
    // ============================================================================




    const EInsufficientBalance: u64 = 1;
    const EMarketNotFound: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EInvalidAmount: u64 = 4;
    const ENoSettlementFunds: u64 = 6;




    // ============================================================================
    // Struct Definitions
    // ============================================================================




    /// AdminCap grants the holder permission to create markets
    public struct AdminCap has key {
        id: one::object::UID,
    }




    /// User's balance in a specific market
    /// 
    /// # Fields
    /// - trader: Address of the trader who owns this balance
    /// - market_id: Associated market
    /// - balance: Available balance (in collateral coin)
    public struct UserBalance<phantom CoinType> has key {
        id: one::object::UID,
        trader: address,
        market_id: u64,
        balance: Balance<CoinType>,
    }




    /// Represents a binary prediction market
    /// 
    /// # Fields
    /// - market_id: Unique market identifier
    /// - option_a_shares: Share balances for OptionA (trader -> amount)
    /// - option_b_shares: Share balances for OptionB (trader -> amount)
    /// - vault: Collateral vault holding all locked funds
    /// - settlement_pool: Funds awaiting settlement claim (trader -> amount)
    /// - is_active: Whether market accepts new orders
    public struct Market<phantom CoinType> has key {
        id: one::object::UID,
        market_id: u64,
        option_a_shares: Table<address, u64>,
        option_b_shares: Table<address, u64>,
        vault: Balance<CoinType>,
        settlement_pool: Table<address, u64>,
        is_active: bool,
    }




    // ============================================================================
    // Admin Functions
    // ============================================================================




    /// Create the admin capability (call once at deployment)
    /// 
    /// # Arguments
    /// - ctx: Transaction context
    public fun init_admin(ctx: &mut one::tx_context::TxContext) {
        let admin_cap = AdminCap {
            id: one::object::new(ctx),
        };
        one::transfer::transfer(admin_cap, one::tx_context::sender(ctx));
    }




    // ============================================================================
    // Market Management
    // ============================================================================




    /// Create a new binary prediction market
    /// Called by admin during market initialization
    /// 
    /// # Arguments
    /// - _admin: AdminCap (proves caller is authorized)
    /// - market_id: Unique market identifier
    /// - ctx: Transaction context
    public fun create_market<CoinType>(
        _admin: &AdminCap,
        market_id: u64,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let market = Market<CoinType> {
            id: one::object::new(ctx),
            market_id,
            option_a_shares: table::new(ctx),
            option_b_shares: table::new(ctx),
            vault: balance::zero(),
            settlement_pool: table::new(ctx),
            is_active: true,
        };
        one::transfer::share_object(market);
    }




    /// Create a user's balance object for a market
    /// Called when user first deposits to a market
    /// 
    /// ✅ FIXED: Changed market parameter to immutable reference (&Market)
    /// Shared objects on Sui can ONLY be passed by immutable reference, never by value or &mut
    /// 
    /// # Arguments
    /// - market: Reference to the market (immutable - shared objects must be read-only)
    /// - market_id: Market identifier
    /// - ctx: Transaction context
    public fun create_user_balance<CoinType>(
        market: &Market<CoinType>,  // ✅ FIXED: Changed from "market: Market<CoinType>" to reference
        market_id: u64,
        ctx: &mut one::tx_context::TxContext,
    ) {
        assert!(market.market_id == market_id, EMarketNotFound);
        let sender = one::tx_context::sender(ctx);
        
        
        let user_balance: UserBalance<CoinType> = UserBalance {
            id: one::object::new(ctx),
            trader: sender,
            market_id,
            balance: balance::zero(),
        };
        one::transfer::transfer(user_balance, sender);
    }




    // ============================================================================
    // Balance Management (Public Helpers)
    // ============================================================================




    /// Deposit funds into user's balance
    /// Caller must provide the coins
    /// 
    /// # Arguments
    /// - user_balance: User's balance object
    /// - coin: Coin to deposit
    public fun deposit_funds<CoinType>(
        user_balance: &mut UserBalance<CoinType>,
        coin: Coin<CoinType>,
    ) {
        let amount = coin::value(&coin);
        assert!(amount > 0, EInvalidAmount);
        
        balance::join(&mut user_balance.balance, coin::into_balance(coin));
    }




    /// Withdraw funds from user's balance
    /// Returns a Coin object that can be transferred
    /// 
    /// # Arguments
    /// - user_balance: User's balance object
    /// - amount: Amount to withdraw
    /// - ctx: Transaction context
    /// 
    /// # Returns
    /// Coin object containing the withdrawn amount
    public fun withdraw_funds<CoinType>(
        user_balance: &mut UserBalance<CoinType>,
        amount: u64,
        ctx: &mut one::tx_context::TxContext,
    ): Coin<CoinType> {
        assert!(balance::value(&user_balance.balance) >= amount, EInsufficientBalance);
        let withdrawn = balance::split(&mut user_balance.balance, amount);
        coin::from_balance(withdrawn, ctx)
    }




    /// Get user's balance amount
    /// 
    /// # Arguments
    /// - user_balance: User's balance object
    /// 
    /// # Returns
    /// Balance amount
    public fun get_user_balance<CoinType>(
        user_balance: &UserBalance<CoinType>,
    ): u64 {
        balance::value(&user_balance.balance)
    }




    // ============================================================================
    // Share Management (Public Helpers)
    // ============================================================================




    /// Get user's shares from a table
    /// 
    /// # Arguments
    /// - shares_table: Reference to share table
    /// - trader: Trader address
    /// 
    /// # Returns
    /// Number of shares owned (0 if not found)
    public fun get_user_shares(
        shares_table: &Table<address, u64>,
        trader: address,
    ): u64 {
        if (table::contains(shares_table, trader)) {
            *table::borrow(shares_table, trader)
        } else {
            0
        }
    }




    /// Get trader's shares in a specific option
    /// 
    /// # Arguments
    /// - market: The market
    /// - trader: Trader address
    /// - option: Option to check
    /// 
    /// # Returns
    /// Number of shares
    public fun get_user_position<CoinType>(
        market: &Market<CoinType>,
        trader: address,
        option: Option,
    ): u64 {
        let shares_table = if (option == option_a()) {
            &market.option_a_shares
        } else {
            &market.option_b_shares
        };
        get_user_shares(shares_table, trader)
    }




    /// Transfer shares between traders (internal - called from orderbook)
    /// 
    /// # Arguments
    /// - market: The market
    /// - from: Seller address
    /// - to: Buyer address
    /// - option: Option being transferred
    /// - quantity: Number of shares to transfer
    /// - _ctx: Transaction context
    public fun transfer_shares<CoinType>(
        market: &mut Market<CoinType>,
        from: address,
        to: address,
        option: Option,
        quantity: u64,
        _ctx: &mut one::tx_context::TxContext,
    ) {
        let shares_table = if (option == option_a()) {
            &mut market.option_a_shares
        } else {
            &mut market.option_b_shares
        };




        // Remove from sender
        if (table::contains(shares_table, from)) {
            let sender_shares = table::borrow_mut(shares_table, from);
            assert!(*sender_shares >= quantity, EInsufficientBalance);
            *sender_shares = *sender_shares - quantity;
        };




        // Add to receiver
        if (table::contains(shares_table, to)) {
            let receiver_shares = table::borrow_mut(shares_table, to);
            *receiver_shares = *receiver_shares + quantity;
        } else {
            table::add(shares_table, to, quantity);
        };




        one::event::emit(SharesTransferred {
            from,
            to,
            asset: option,
            quantity,
            market_id: market.market_id,
        });
    }




    // ============================================================================
    // Settlement Pool Management (Public Helpers)
    // ============================================================================




    /// Add funds to a trader's settlement pool
    /// Called when a trade is settled
    /// 
    /// # Arguments
    /// - market: The market
    /// - trader: Trader receiving settlement
    /// - amount: Amount to add
    public fun add_to_settlement<CoinType>(
        market: &mut Market<CoinType>,
        trader: address,
        amount: u64,
    ) {
        if (table::contains(&market.settlement_pool, trader)) {
            let existing = table::borrow_mut(&mut market.settlement_pool, trader);
            *existing = *existing + amount;
        } else {
            table::add(&mut market.settlement_pool, trader, amount);
        };
    }




    /// Claim settlement funds
    /// Transfers settlement pool balance to user's available balance
    /// 
    /// # Arguments
    /// - market: The market
    /// - user_balance: User's balance object
    /// - ctx: Transaction context
    public fun claim_settlement<CoinType>(
        market: &mut Market<CoinType>,
        user_balance: &mut UserBalance<CoinType>,
        ctx: &mut one::tx_context::TxContext,
    ) {
        let sender = one::tx_context::sender(ctx);
        assert!(user_balance.trader == sender, EUnauthorized);




        if (table::contains(&market.settlement_pool, sender)) {
            let amount = table::remove(&mut market.settlement_pool, sender);
            assert!(amount > 0, ENoSettlementFunds);




            let settlement_funds = balance::split(&mut market.vault, amount);
            balance::join(&mut user_balance.balance, settlement_funds);




            one::event::emit(SettlementClaimed {
                user: sender,
                amount,
                market_id: market.market_id,
            });
        };
    }
}
