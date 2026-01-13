'use client';

import { useState } from 'react';
import { useSignAndExecuteTransaction } from '@mysten/dapp-kit';
import { Transaction } from '@mysten/sui/transactions';
import { useSuiClient } from '@mysten/dapp-kit';
import { SuiObjectChange } from '@mysten/sui/client';
import { CONTRACTS } from '@/lib/constants';

interface TxResult {
  digest?: string;
}

interface TradingPanelProps {
  userBalance: string | null; 
  onBalanceChange: (id: string) => void;
  selectedTeam: 'barca' | 'madrid';
}

export function TradingPanel({ userBalance, onBalanceChange, selectedTeam }: TradingPanelProps) {
  const [depositAmount, setDepositAmount] = useState('');
  const [side, setSide] = useState<'buy' | 'sell'>('buy');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const suiClient = useSuiClient();

  const collateral = price && quantity ? (parseFloat(price) * parseFloat(quantity)).toFixed(4) : '0';

  const extractUserBalanceFromDigest = async (
    digest: string,
    maxRetries: number = 5
  ): Promise<string | null> => {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await new Promise((resolve) =>
          setTimeout(resolve, 1000 * Math.pow(2, attempt))
        );

        console.log(`Attempt ${attempt + 1}/${maxRetries}: Querying transaction...`);

        const txResult = await suiClient.getTransactionBlock({
          digest,
          options: {
            showObjectChanges: true,
          },
        });

        if (!txResult) {
          console.log(`Attempt ${attempt + 1}: Transaction not found yet...`);
          continue;
        }

        if (txResult.objectChanges) {
          const userBalance = txResult.objectChanges.find(
            (change: SuiObjectChange) => {
              if ('objectType' in change && 'objectId' in change) {
                return (
                  change.type === 'created' &&
                  typeof change.objectType === 'string' &&
                  change.objectType.includes('UserBalance')
                );
              }
              return false;
            }
          );

          if (userBalance && 'objectId' in userBalance) {
            console.log('✅ UserBalance found:', userBalance.objectId);
            return userBalance.objectId;
          }
        }

        console.log(
          `Attempt ${attempt + 1}: UserBalance not in transaction changes`
        );
      } catch (error) {
        console.log(
          `Attempt ${attempt + 1} failed:`,
          (error as Error).message
        );
      }
    }

    console.error('❌ Could not extract UserBalance after retries');
    return null;
  };

  const handleDeposit = async () => {
    if (!depositAmount) {
      setMessage({ type: 'error', text: 'Please enter deposit amount' });
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const amountMist = Math.floor(parseFloat(depositAmount) * 1e9);
      const tx = new Transaction();
      const [coin] = tx.splitCoins(tx.gas, [amountMist]);

      tx.moveCall({
        target: `${CONTRACTS.PACKAGE_ID}::orderbook::deposit_funds`,
        typeArguments: ['0x2::oct::OCT'],
        arguments: [
          tx.object(CONTRACTS.MARKET_ID),
          coin,
        ],
      });

      signAndExecute(
        { transaction: tx },
        {
          onSuccess: async (result: TxResult) => {
            console.log('Deposit success:', result);
            
            if (!result.digest) {
              setMessage({
                type: 'error',
                text: 'No transaction digest received',
              });
              setLoading(false);
              return;
            }

            try {
              setMessage({
                type: 'success',
                text: `Deposit sent! Extracting UserBalance...`,
              });

              const extractedBalance = await extractUserBalanceFromDigest(result.digest);
              
              if (extractedBalance) {
                onBalanceChange(extractedBalance);
                setMessage({
                  type: 'success',
                  text: `✅ Deposited ${depositAmount} OCT! UserBalance: ${extractedBalance.slice(0, 10)}...`,
                });
                setDepositAmount('');
              } else {
                setMessage({
                  type: 'error',
                  text: `Deposit successful but UserBalance not found. Please paste the ID manually from Explorer (TX: ${result.digest.slice(0, 10)}...)`,
                });
              }
            } catch (err) {
              console.error('Error extracting balance:', err);
              setMessage({
                type: 'success',
                text: `Deposited ${depositAmount} OCT! TX: ${result.digest.slice(0, 10)}... (Please paste UserBalance ID manually)`,
              });
            }
            
            setLoading(false);
          },
          onError: (error: Error) => {
            console.error('Deposit error:', error);
            setMessage({
              type: 'error',
              text: error instanceof Error ? error.message : 'Failed to deposit',
            });
            setLoading(false);
          },
        }
      );
    } catch (err) {
      console.error('Deposit exception:', err);
      const errorMsg = err instanceof Error ? err.message : 'Unknown error';
      setMessage({
        type: 'error',
        text: errorMsg,
      });
      setLoading(false);
    }
  };

  const handlePlaceOrder = async () => {
    if (!userBalance) {
      setMessage({ type: 'error', text: 'Please deposit funds first' });
      return;
    }

    if (!price || !quantity) {
      setMessage({ type: 'error', text: 'Please fill in price and quantity' });
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const priceInCents = Math.floor(parseFloat(price) * 100);
      const qty = Math.floor(parseFloat(quantity));
      
      console.log('📝 Placing order with:', {
        orderbook: CONTRACTS.ORDERBOOK_ID,
        market: CONTRACTS.MARKET_ID,
        userBalance,
        option: 0,
        price: priceInCents,
        quantity: qty,
        isBid: side === 'buy',
      });

      const tx = new Transaction();

      tx.moveCall({
        target: `${CONTRACTS.PACKAGE_ID}::orderbook::place_order_cli`,
        typeArguments: ['0x2::oct::OCT'],
        arguments: [
          tx.object(CONTRACTS.ORDERBOOK_ID),
          tx.object(CONTRACTS.MARKET_ID),
          tx.object(userBalance),
          tx.pure.u8(selectedTeam === 'barca' ? 0 : 1),
          tx.pure.u64(priceInCents),
          tx.pure.u64(qty),
          tx.pure.bool(side === 'buy'),
        ],
      });

      console.log('📝 Placing order with:', {
        orderbook: CONTRACTS.ORDERBOOK_ID,
        market: CONTRACTS.MARKET_ID,
        userBalance,
        option: selectedTeam === 'barca' ? 0 : 1,  // ← UPDATE THIS TOO
        price: priceInCents,
        quantity: qty,
        isBid: side === 'buy',
      });

      signAndExecute(
        { transaction: tx },
        {
          onSuccess: (result: TxResult) => {
            console.log('✅ Order placed successfully:', result);
            setMessage({
              type: 'success',
              text: `Order placed! TX: ${result.digest?.slice(0, 10)}...`,
            });
            setPrice('');
            setQuantity('');
            setLoading(false);
          },
          onError: (error: Error | unknown) => {
            console.error('❌ Order error (full):', error);
            console.error('Error type:', typeof error);
            console.error('Error keys:', error && typeof error === 'object' ? Object.keys(error as Record<string, unknown>) : 'null');
            if (error && typeof error === 'object') {
              console.error('Error.code:', (error as Record<string, unknown>)?.code);
              console.error('Error.message:', (error as Record<string, unknown>)?.message);
            }
            console.error('Full error JSON:', JSON.stringify(error, null, 2));
            
            let errorMsg = 'Failed to place order';
            if (error instanceof Error) {
              errorMsg = error.message;
            } else if (typeof error === 'string') {
              errorMsg = error;
            } else if (error && typeof error === 'object') {
              const errObj = error as Record<string, unknown>;
              if (errObj.message) {
                errorMsg = String(errObj.message);
              } else if (errObj.code) {
                errorMsg = `Error code: ${errObj.code}`;
              }
            }
            
            setMessage({
              type: 'error',
              text: errorMsg || 'Transaction failed. Check console for details.',
            });
            setLoading(false);
          },
        }
      );
    } catch (err) {
      console.error('❌ Order exception (full):', err);
      const errorMsg = err instanceof Error ? err.message : String(err);
      setMessage({
        type: 'error',
        text: errorMsg || 'Unknown error',
      });
      setLoading(false);
    }
  };

  return (
    <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
      <h3 className="mb-6 text-lg font-bold text-white">Trading Panel</h3>

      <div className="mb-6 rounded-lg bg-gray-800 p-4">
        <h4 className="mb-3 text-sm font-semibold text-gray-300">Step 1: Deposit Funds</h4>
        <div className="flex gap-2">
          <input
            type="number"
            placeholder="Amount (OCT)"
            value={depositAmount}
            onChange={(e) => setDepositAmount(e.target.value)}
            className="flex-1 rounded-lg border border-gray-600 bg-gray-700 px-3 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
            step="0.1"
            min="0"
          />
          <button
            onClick={handleDeposit}
            disabled={loading || !depositAmount}
            className="rounded-lg bg-purple-600 px-4 py-2 font-semibold text-white hover:bg-purple-700 disabled:bg-gray-600 disabled:text-gray-400"
          >
            {loading ? 'Processing...' : 'Deposit'}
          </button>
        </div>
      </div>

      <div className="mb-6">
        <label className="mb-2 block text-sm text-gray-400">UserBalance ID</label>
        <input
          type="text"
          placeholder="0x..."
          value={userBalance || ''}
          readOnly
          className="w-full rounded-lg border border-gray-600 bg-gray-800 px-4 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none text-xs opacity-75"
        />
        <p className="mt-1 text-xs text-gray-500">
          {userBalance ? '✓ Set automatically' : 'Auto-extracted after deposit'}
        </p>
      </div>

      <div className="mb-6 border-t border-gray-700 pt-6">
        <h4 className="mb-4 text-sm font-semibold text-gray-300">Step 2: Place Order</h4>

        <div className="mb-6 flex gap-2">
          <button
            onClick={() => setSide('buy')}
            className={`flex-1 rounded-lg py-2 font-semibold transition-all ${
              side === 'buy'
                ? 'border-2 border-green-500 bg-green-500/10 text-green-400'
                : 'border border-gray-600 bg-gray-800 text-gray-400'
            }`}
          >
            Buy
          </button>
          <button
            onClick={() => setSide('sell')}
            className={`flex-1 rounded-lg py-2 font-semibold transition-all ${
              side === 'sell'
                ? 'border-2 border-red-500 bg-red-500/10 text-red-400'
                : 'border border-gray-600 bg-gray-800 text-gray-400'
            }`}
          >
            Sell
          </button>
        </div>

        <div className="mb-4">
          <label className="mb-2 block text-sm text-gray-400">Price (OCT)</label>
          <input
            type="number"
            placeholder="0.00"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            className="w-full rounded-lg border border-gray-600 bg-gray-800 px-4 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
            step="0.01"
            min="0"
          />
        </div>

        <div className="mb-4">
          <label className="mb-2 block text-sm text-gray-400">Quantity</label>
          <input
            type="number"
            placeholder="0"
            value={quantity}
            onChange={(e) => setQuantity(e.target.value)}
            className="w-full rounded-lg border border-gray-600 bg-gray-800 px-4 py-2 text-white placeholder-gray-500 focus:border-purple-500 focus:outline-none"
            step="1"
            min="0"
          />
        </div>

        <div className="mb-6 rounded-lg bg-gray-800 p-4">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Collateral</span>
            <span className="font-semibold text-white">{collateral} OCT</span>
          </div>
        </div>
      </div>

      {message && (
        <div
          className={`mb-4 rounded-lg p-3 text-sm ${
            message.type === 'success'
              ? 'bg-green-500/10 text-green-400'
              : 'bg-red-500/10 text-red-400'
          }`}
        >
          {message.text}
        </div>
      )}

      <button
        onClick={handlePlaceOrder}
        disabled={loading || !price || !quantity || !userBalance}
        className={`w-full rounded-lg py-3 font-bold ${
          side === 'buy'
            ? 'bg-green-500 hover:bg-green-600 disabled:bg-gray-600'
            : 'bg-red-500 hover:bg-red-600 disabled:bg-gray-600'
        } text-white disabled:text-gray-400 disabled:cursor-not-allowed transition-all`}
      >
        {loading ? 'Processing...' : `${side === 'buy' ? 'Buy' : 'Sell'} ${quantity || '0'} ${selectedTeam === 'barca' ? 'Barca' : 'Madrid'} @ ${price || '0.00'} OCT`}
      </button>
    </div>
  );
}
