import { Transaction } from '@mysten/sui/transactions';
import { CONTRACTS } from '@/lib/constants';


export interface PlaceOrderResult {
  success: boolean;
  txDigest?: string;
  error?: string;
}


export async function createUserBalance(): Promise<PlaceOrderResult> {
  try {
    const tx = new Transaction();

    tx.moveCall({
      target: `${CONTRACTS.PACKAGE_ID}::outcome::create_user_balance`,
      typeArguments: ['0x8b76fc2a2317d45118770cefed7e57171a08c477ed16283616b15f099391f120::hackathon::HACKATHON'],
      arguments: [
        tx.object(CONTRACTS.MARKET_ID),
        tx.pure.u64(1),
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


export function buildDepositWithCoin(
  marketId: string,
  userBalanceId: string,
  hackathonCoinIds: string[],
  amount: number
): Transaction {
  const tx = new Transaction();

  console.log(' Deposit transaction:');
  console.log('  UserBalance:', userBalanceId);
  console.log('  Amount:', amount, 'HACKATHON');
  console.log('  Available HACKATHON coins:', hackathonCoinIds.length);

  if (hackathonCoinIds.length === 0) {
    throw new Error('❌ No HACKATHON coins found! You need HACKATHON coins to deposit.');
  }

  const amountMist = BigInt(Math.floor(amount * 1e9));
  console.log('  Amount Mist:', amountMist.toString());


  const baseCoin = tx.object(hackathonCoinIds[0]);
  
  // Merge all HACKATHON coins if user has multiple
  if (hackathonCoinIds.length > 1) {
    const coinsToMerge = hackathonCoinIds.slice(1).map(id => tx.object(id));
    tx.mergeCoins(baseCoin, coinsToMerge);
    console.log(`✅ Merged ${hackathonCoinIds.length} HACKATHON coins`);
  }
  
  // Split the deposit amount from merged HACKATHON coin
  const [depositCoin] = tx.splitCoins(baseCoin, [tx.pure.u64(amountMist)]);
  console.log('✅ Split deposit amount from HACKATHON coins');

  // ✅ Call deposit with HACKATHON coin
  tx.moveCall({
    target: `${CONTRACTS.PACKAGE_ID}::outcome::deposit_funds`,
    typeArguments: ['0x8b76fc2a2317d45118770cefed7e57171a08c477ed16283616b15f099391f120::hackathon::HACKATHON'],
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
  let priceForContract = price;
  
  console.log('📍 Step 1 - Raw price:', priceForContract);
  
  if (priceForContract > 0 && priceForContract < 1) {
    priceForContract = priceForContract * 100;
    console.log('📍 Step 2 - Detected decimal, multiplied by 100:', priceForContract);
  } else {
    console.log('📍 Step 2 - Not a decimal, keeping as:', priceForContract);
  }
  
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
  console.log('  Price sent to contract:', priceForContract, '(range: 1-99)');
  console.log('  Quantity:', quantity);

  const priceValue = BigInt(Math.round(priceForContract));
  const qty = BigInt(Math.round(quantity));

  tx.moveCall({
    target: `${CONTRACTS.PACKAGE_ID}::orderbook::place_order_cli`,
    typeArguments: ['0x8b76fc2a2317d45118770cefed7e57171a08c477ed16283616b15f099391f120::hackathon::HACKATHON'],
    arguments: [
      tx.object(CONTRACTS.ORDERBOOK_ID),
      tx.object(CONTRACTS.MARKET_ID),
      tx.object(userBalanceId),
      tx.pure.u8(option),
      tx.pure.u64(priceValue),
      tx.pure.u64(qty),
      tx.pure.bool(isBuy),
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
    typeArguments: ['0x8b76fc2a2317d45118770cefed7e57171a08c477ed16283616b15f099391f120::hackathon::HACKATHON'],
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
