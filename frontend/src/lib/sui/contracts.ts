
import { Transaction } from '@mysten/sui/transactions';

import { CONTRACTS } from '@/lib/constants';

export interface PlaceOrderResult {
  success: boolean;
  txDigest?: string;
  error?: string;
}

/**
 * Place an order on the orderbook
 * @param price Price in SUI
 * @param quantity Quantity of contracts
 * @param isBuy true for buy, false for sell
 */
export async function placeOrder(
  price: number,
  quantity: number,
  isBuy: boolean
): Promise<PlaceOrderResult> {
  try {
    // Convert to MIST (1 SUI = 1e9 MIST)
    const priceMist = Math.floor(price * 1e9);
    
    const tx = new Transaction();

    // Build the transaction
    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::orderbook::placeordercli`,
      arguments: [
        tx.object(CONTRACTS.ORDERBOOK_ID), // OrderBook
        tx.object(CONTRACTS.MARKET_ID),    // Market
        // UserBalance - user will need to have deposited first
        tx.pure.u64(priceMist),           // Price in MIST
        tx.pure.u64(quantity),             // Quantity
        tx.pure.u8(isBuy ? 0 : 1),        // Side: 0 = buy, 1 = sell
      ],
    });

    // Wallet signer integration needed
    console.error('Wallet integration needed - cannot sign transaction yet');
    
    return {
      success: false,
      error: 'Wallet not connected. Connect wallet to place orders.',
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
  amount: number
): Promise<PlaceOrderResult> {
  try {
    const amountMist = Math.floor(amount * 1e9);

    const tx = new Transaction();

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::orderbook::depositfunds`,
      arguments: [
        tx.object(CONTRACTS.MARKET_ID),
        tx.pure.u64(amountMist),
      ],
    });

    console.error('Wallet integration needed - cannot sign transaction yet');
    
    return {
      success: false,
      error: 'Wallet not connected. Connect wallet to deposit.',
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
