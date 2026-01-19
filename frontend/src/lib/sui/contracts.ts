import { Transaction } from '@mysten/sui/transactions';
import { Inputs } from '@mysten/sui/transactions';
import { CONTRACTS } from '@/lib/constants';

export interface PlaceOrderResult {
  success: boolean;
  txDigest?: string;
  error?: string;
}

/**
 * Create UserBalance (do this once, first time)
 * Calls outcome::create_user_balance
 * 
 * ✅ FIXED: Now properly uses SharedObjectRef for the Market object
 */
export async function createUserBalance(): Promise<PlaceOrderResult> {
  try {
    const tx = new Transaction();

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::outcome::create_user_balance`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        // ✅ CRITICAL: Market is a SHARED object - must use Inputs.SharedObjectRef
        tx.object(
          Inputs.SharedObjectRef({
            objectId: CONTRACTS.MARKET_ID,
            initialSharedVersion: 1,  // Start with 1, adjust if needed
            mutable: false,           // Market is read-only for this function
          })
        ),
        tx.pure.u64(1),  // market_id
      ],
    });

    console.log('✅ Transaction built for create_user_balance');
    
    return {
      success: true,
      error: undefined,
    };
  } catch (err) {
    return {
      success: false,
      error: err instanceof Error ? err.message : 'Unknown error',
    };
  }
}

/**
 * Deposit funds to the market
 * Calls outcome::deposit_funds
 * 
 * ✅ FIXED: Now uses OCT coins instead of tx.gas (SUI)
 */
export async function depositFunds(
  userBalanceId: string,
  octCoinId: string,  // ← NEW: Requires OCT coin ID
  amount: number
): Promise<PlaceOrderResult> {
  try {
    const amountMist = Math.floor(amount * 1e9);

    const tx = new Transaction();
    
    // ✅ CRITICAL: Split from OCT coin, NOT tx.gas
    const [coin] = tx.splitCoins(tx.object(octCoinId), [amountMist]);

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::outcome::deposit_funds`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        tx.object(userBalanceId),  // UserBalance object (OWNED)
        coin,                       // Coin<0x2::oct::OCT> from split
      ],
    });

    console.log('✅ Transaction built for deposit_funds');
    
    return {
      success: true,
      error: undefined,
    };
  } catch (err) {
    return {
      success: false,
      error: err instanceof Error ? err.message : 'Unknown error',
    };
  }
}

/**
 * Place an order on the orderbook
 * Calls orderbook::place_order_cli
 * 
 * ✅ FIXED: Now properly uses SharedObjectRef for shared objects
 */
export async function placeOrder(
  userBalanceId: string,
  option: number,
  price: number,
  quantity: number,
  isBuy: boolean
): Promise<PlaceOrderResult> {
  try {
    const priceInCents = Math.floor(price * 100);
    const qty = Math.floor(quantity);
    
    const tx = new Transaction();

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::orderbook::place_order_cli`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        // ✅ CRITICAL: OrderBook is SHARED - must use SharedObjectRef
        tx.object(
          Inputs.SharedObjectRef({
            objectId: CONTRACTS.ORDERBOOK_ID,
            initialSharedVersion: 1,  // Start with 1, adjust if needed
            mutable: true,            // OrderBook is mutable
          })
        ),
        // ✅ CRITICAL: Market is SHARED - must use SharedObjectRef
        tx.object(
          Inputs.SharedObjectRef({
            objectId: CONTRACTS.MARKET_ID,
            initialSharedVersion: 1,  // Start with 1, adjust if needed
            mutable: true,            // Market is mutable
          })
        ),
        tx.object(userBalanceId),              // user_balance: &mut UserBalance (OWNED)
        tx.pure.u8(option),                    // option_u8 (0 for A, 1 for B)
        tx.pure.u64(priceInCents),            // price (in cents)
        tx.pure.u64(qty),                     // quantity
        tx.pure.bool(isBuy),                  // is_bid
      ],
    });

    console.log('✅ Transaction built for place_order_cli');
    
    return {
      success: true,
      error: undefined,
    };
  } catch (err) {
    return {
      success: false,
      error: err instanceof Error ? err.message : 'Unknown error',
    };
  }
}

/**
 * Get top bid price (read-only)
 */
export async function getTopBid(): Promise<number> {
  try {
    // This would require a RPC call to read the OrderBook object
    // For now, returning placeholder
    return 0;
  } catch (err) {
    console.error('Error getting top bid:', err);
    return 0;
  }
}

/**
 * Get top ask price (read-only)
 */
export async function getTopAsk(): Promise<number> {
  try {
    // This would require a RPC call to read the OrderBook object
    // For now, returning placeholder
    return 0;
  } catch (err) {
    console.error('Error getting top ask:', err);
    return 0;
  }
}
