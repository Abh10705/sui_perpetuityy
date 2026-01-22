import { Transaction } from '@mysten/sui/transactions';
import { CONTRACTS } from '@/lib/constants';
import { suiClient } from '@/lib/sui/client';


export interface PlaceOrderResult {
  success: boolean;
  txDigest?: string;
  error?: string;
}


/**
 * ✅ Create user balance
 */
export async function createUserBalance(): Promise<PlaceOrderResult> {
  try {
    const tx = new Transaction();


    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::outcome::create_user_balance`,
      typeArguments: ['0x2::oct::OCT'],
      arguments: [
        tx.object(CONTRACTS.MARKET_ID),
        tx.pure.u64(1),
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
 * ✅ FIXED: Build deposit transaction with coin splitting
 */
export function buildDepositWithCoin(
  marketId: string,
  userBalanceId: string,
  octCoinId: string,
  amount: number
): Transaction {
  const tx = new Transaction();


  console.log('📤 Deposit transaction:');
  console.log('  UserBalance:', userBalanceId);
  console.log('  Coin:', octCoinId);
  console.log('  Amount:', amount, 'OCT');


  const amountMist = BigInt(Math.floor(amount * 1e9));
  
  console.log('  Amount Mist:', amountMist.toString());


  const [depositCoin] = tx.splitCoins(tx.object(octCoinId), [
    tx.pure.u64(amountMist),
  ]);


  tx.moveCall({
    target: `${CONTRACTS.PACKAGE_ID}::outcome::deposit_funds`,
    typeArguments: ['0x2::oct::OCT'],
    arguments: [
      tx.object(marketId),
      tx.object(userBalanceId),
      depositCoin,
    ],
  });


  tx.setGasBudget(100000000);


  return tx;
}


/**
 * ✅ CRITICAL FIX: Use place_order_cli which handles u8 for option
 * 
 * IMPORTANT: Price conversion logic
 * User can input EITHER format:
 *   - Decimal: 0.20 (means 20%)
 *   - Integer: 20 (means 20%)
 * 
 * Both get converted to integer range [1, 99] for contract
 * 
 * Function signature:
 * public fun place_order_cli<CoinType>(
 *   orderbook: &mut OrderBook,
 *   market: &mut Market<CoinType>,
 *   userbalance: &mut UserBalance<CoinType>,
 *   option: u8,           ← 0 or 1
 *   price: u64,           ← Must be > 0 and < 100 (integers 1-99)
 *   quantity: u64,        ← Must be > 0
 *   isbid: bool           ← true for buy, false for sell
 * )
 */
export async function buildPlaceOrderTransaction(
  userBalanceId: string,
  option: number,
  price: number,
  quantity: number,
  isBuy: boolean
): Promise<Transaction> {
  const tx = new Transaction();

  console.log('🚀 buildPlaceOrderTransaction called with:', { userBalanceId, option, price, quantity, isBuy });

  // ✅ VALIDATION: Catch invalid inputs early
  if (!userBalanceId) {
    throw new Error('❌ UserBalance ID is required');
  }
  
  if (typeof option !== 'number' || option < 0 || option > 1) {
    throw new Error(`❌ Option must be 0 (Barca) or 1 (Madrid), got: ${option} (type: ${typeof option})`);
  }
  
  // ✅ FIXED: Handle both decimal (0.20) and integer (20) inputs
  // User can type: 0.20 (means 20) OR 20 (means 20)
  // Internally convert to integer range [1, 99]
  let priceForContract = price;
  
  console.log('📍 Step 1 - Raw price:', priceForContract);
  
  // If price is between 0 and 1 (like 0.20), multiply by 100 to get 20
  if (priceForContract > 0 && priceForContract < 1) {
    priceForContract = priceForContract * 100;
    console.log('📍 Step 2 - Detected decimal, multiplied by 100:', priceForContract);
  } else {
    console.log('📍 Step 2 - Not a decimal, keeping as:', priceForContract);
  }
  
  // Now validate: must be between 1 and 99
  if (!Number.isFinite(priceForContract) || priceForContract <= 0 || priceForContract >= 100) {
    throw new Error(`❌ Price must be > 0 and < 100, got: ${price} (converts to: ${priceForContract})`);
  }
  
  if (typeof quantity !== 'number' || quantity <= 0) {
    throw new Error(`❌ Quantity must be > 0, got: ${quantity} (type: ${typeof quantity})`);
  }


  console.log('📊 Place order transaction:');
  console.log('  ✅ Validation passed!');
  console.log('  Orderbook:', CONTRACTS.ORDERBOOK_ID);
  console.log('  Market:', CONTRACTS.MARKET_ID);
  console.log('  UserBalance:', userBalanceId);
  console.log('  Option:', option === 0 ? 'Barca (0)' : 'Madrid (1)');
  console.log('  User entered price:', price);
  console.log('  Price sent to contract:', priceForContract, '(range: 1-99)');
  console.log('  Quantity:', quantity);
  console.log('  Side:', isBuy ? 'BUY' : 'SELL');


  // ✅ FIXED: Convert to BigInt using the adjusted price
  // If user typed 0.20, priceForContract is now 20
  // If user typed 20, priceForContract is now 20
  const priceValue = BigInt(Math.round(priceForContract));
  const qty = BigInt(Math.round(quantity));

  console.log('🔍 DEBUG - Final values going to contract:');
  console.log('  priceValue (BigInt):', priceValue.toString());
  console.log('  qty (BigInt):', qty.toString());
  console.log('  Will be sent as: tx.pure.u64(' + priceValue.toString() + ')');

  console.log('  Converted to BigInt:');
  console.log('    Price:', priceValue.toString());
  console.log('    Quantity:', qty.toString());


  // ✅ Call place_order_cli which converts u8 to Option internally
  tx.moveCall({
    target: `${CONTRACTS.PACKAGE_ID}::orderbook::place_order_cli`,
    typeArguments: ['0x2::oct::OCT'],
    arguments: [
      tx.object(CONTRACTS.ORDERBOOK_ID),
      tx.object(CONTRACTS.MARKET_ID),
      tx.object(userBalanceId),
      tx.pure.u8(option),      // ← u8: 0 or 1
      tx.pure.u64(priceValue), // ← u64: integer 1-99 (matches CLI)
      tx.pure.u64(qty),        // ← u64: > 0
      tx.pure.bool(isBuy),     // ← bool: true/false
    ],
  });


  tx.setGasBudget(500000000);


  return tx;
}


/**
 * ✅ Build cancel order transaction
 */
export async function buildCancelOrderTransaction(
  userBalanceId: string,
  orderId: number,
): Promise<Transaction> {
  const tx = new Transaction();


  const orderIdValue = BigInt(orderId);


  tx.moveCall({
    target: `${CONTRACTS.PACKAGE_ID}::orderbook::cancel_order`,
    typeArguments: ['0x2::oct::OCT'],
    arguments: [
      tx.object(CONTRACTS.ORDERBOOK_ID),
      tx.object(CONTRACTS.MARKET_ID),
      tx.object(userBalanceId),
      tx.pure.u64(orderIdValue),
    ],
  });


  tx.setGasBudget(500000000);


  return tx;
}


export async function getTopBid(): Promise<number> {
  try {
    return 0;
  } catch (err) {
    console.error('Error getting top bid:', err);
    return 0;
  }
}


export async function getTopAsk(): Promise<number> {
  try {
    return 0;
  } catch (err) {
    console.error('Error getting top ask:', err);
    return 0;
  }
}


export async function getOrderbookDepth(): Promise<[number, number]> {
  try {
    return [0, 0];
  } catch (err) {
    console.error('Error getting orderbook depth:', err);
    return [0, 0];
  }
}
