import { Transaction } from '@mysten/sui/transactions';
import { CONTRACTS } from '@/lib/constants';

export interface PlaceOrderResult {
  success: boolean;
  txDigest?: string;
  error?: string;
}

/**
 * Create UserBalance (do this once, first time)
 */
export async function createUserBalance(): Promise<PlaceOrderResult> {
  try {
    const tx = new Transaction();

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::orderbook::create_user_balance`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        tx.object(CONTRACTS.MARKET_ID),
      ],
    });

    console.log('Transaction built for create_user_balance');
    
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
 */
export async function depositFunds(
  userBalanceId: string,
  amount: number
): Promise<PlaceOrderResult> {
  try {
    const amountMist = Math.floor(amount * 1e9);

    const tx = new Transaction();
    const [coin] = tx.splitCoins(tx.gas, [amountMist]);

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::orderbook::deposit_funds`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        tx.object(CONTRACTS.MARKET_ID),
        tx.object(userBalanceId),
        coin,
      ],
    });

    console.log('Transaction built for deposit_funds');
    
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
        tx.object(CONTRACTS.ORDERBOOK_ID),
        tx.object(CONTRACTS.MARKET_ID),
        tx.object(userBalanceId),
        tx.pure.u8(option),
        tx.pure.u64(priceInCents),
        tx.pure.u64(qty),
        tx.pure.bool(isBuy),
      ],
    });

    console.log('Transaction built for place_order_cli');
    
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
 * Get top bid price
 */
export async function getTopBid(): Promise<number> {
  try {
    return 0;
  } catch (err) {
    console.error('Error getting top bid:', err);
    return 0;
  }
}

/**
 * Get top ask price
 */
export async function getTopAsk(): Promise<number> {
  try {
    return 0;
  } catch (err) {
    console.error('Error getting top ask:', err);
    return 0;
  }
}
