    # Perpetuity - Decentralized Prediction Market on Sui

    A fully functional decentralized prediction market with on-chain orderbook matching and automatic trade settlement.

    ## 🎯 Overview

    Perpetuity is a prediction market protocol on the Sui blockchain where users can trade outcome predictions with real-time order matching and settlement.

    **Example:** "Which team is better?" 
    - Users buy barca @ 40¢ 
    - Users sell madrid @ 60¢   
    - Orders automatically match on-chain when prices meet

    ## ✨ Features

    ### ✅ Current (Phase 1)
    - **On-Chain Orderbook** - All orders and matching logic on Sui smart contract
    - **Auto-Matching Engine** - Orders automatically match using best-price-first algorithm
    - **Limit Orders** - Buy/sell at specific prices for both bid and ask
    - **Partial Fills** - Orders can fill across multiple price levels
    - **Multi-Level Sweep** - Single order can match across multiple counterorders
    - **Real-Time Events** - `OrderPlaced`, `OrderCancelled`, `AutoMatched`, `TradeSettled`
    - **Collateral Management** - Automatic locking and refunding of funds
    - **Live Orderbook Display** - Frontend shows real-time bid/ask orders

    ### 🔜 Phase 2 (Planned)
    - Per-Option Orderbooks (separate books for YES and NO)
    - Complementary Matching (40¢ YES = 60¢ NO)
    - Order Aggregation by Price
    - Automatic Order Cleanup
    - Historical Trades Display

    ## 🏗️ Architecture

    ### Smart Contract (Move/Sui)
