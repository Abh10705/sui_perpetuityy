'use client';

import { useState, useEffect } from 'react';
import { useSignAndExecuteTransaction, useCurrentAccount } from '@mysten/dapp-kit';
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

interface ErrorWithCode extends Error {
  code?: string;
}

export function TradingPanel({ userBalance, onBalanceChange, selectedTeam }: TradingPanelProps) {
  const [depositAmount, setDepositAmount] = useState('');
  const [side, setSide] = useState<'buy' | 'sell'>('buy');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [isCheckingExisting, setIsCheckingExisting] = useState(false);
  
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const suiClient = useSuiClient();
  const currentAccount = useCurrentAccount();

  const collateral = price && quantity ? (parseFloat(price) * parseFloat(quantity)).toFixed(4) : '0';

  // ✅ Auto-detect existing UserBalance for connected wallet
  useEffect(() => {
    const loadExistingUserBalance = async () => {
      if (!currentAccount?.address) {
        return;
      }

      // Check if we already have it in state
      if (userBalance) {
        return;
      }

      setIsCheckingExisting(true);

      try {
        // Get all objects owned by the wallet
        const ownedObjects = await suiClient.getOwnedObjects({
          owner: currentAccount.address,
          filter: {
            StructType: `${CONTRACTS.PACKAGE_ID}::orderbook::UserBalance<0x2::oct::OCT>`
          },
          options: {
            showContent: true,
            showType: true,
          }
        });

        if (ownedObjects.data.length > 0) {
          const userBalanceId = ownedObjects.data[0].data?.objectId;
          
          if (userBalanceId) {
            // Save to localStorage and state
            localStorage.setItem(`userBalance_${currentAccount.address}`, userBalanceId);
            onBalanceChange(userBalanceId);
            
            setMessage({
              type: 'success',
              text: `✅ Loaded existing account: ${userBalanceId.slice(0, 10)}...`
            });
          }
        }
      } catch (err) {
        console.error('Error checking for UserBalance:', err);
      } finally {
        setIsCheckingExisting(false);
      }
    };

    loadExistingUserBalance();
  }, [currentAccount?.address, suiClient, userBalance, onBalanceChange]);

  const extractUserBalanceFromDigest = async (
    digest: string,
    maxRetries: number = 5
  ): Promise<string | null> => {
    
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const delay = 1000 * Math.pow(2, attempt);
        
        await new Promise((resolve) => setTimeout(resolve, delay));
        
        const txResult = await suiClient.getTransactionBlock({
          digest,
          options: {
            showObjectChanges: true,
          },
        });

        if (!txResult) {
          continue;
        }

        if (txResult.objectChanges) {
          const userBalance = txResult.objectChanges.find(
            (change: SuiObjectChange) => {
              if ('objectType' in change && 'objectId' in change) {
                const isMatch = change.type === 'created' &&
                  typeof change.objectType === 'string' &&
                  change.objectType.includes('UserBalance');
                
                return isMatch;
              }
              return false;
            }
          );

          if (userBalance && 'objectId' in userBalance) {
            return userBalance.objectId;
          }
        }
      } catch (err) {
        console.error(`Attempt ${attempt + 1} error:`, err);
      }
    }

    return null;
  };

  // ✅ Step 0 - Create UserBalance
  const handleCreateUserBalance = async () => {
    
    if (!currentAccount?.address) {
      setMessage({ type: 'error', text: 'Please connect your wallet first' });
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const tx = new Transaction();

      const targetFunction = `${CONTRACTS.PACKAGE_ID}::orderbook::create_user_balance`;

      // ✅ FIXED: Contract handles transfer internally now!
      tx.moveCall({
        target: targetFunction,
        typeArguments: ['0x2::oct::OCT'],
        arguments: [
          tx.object(CONTRACTS.MARKET_ID),
        ],
      });
      
      // Set gas budget to prevent endpoint failures
      tx.setGasBudget(1000000000); // 1 SUI

      let timeoutId: NodeJS.Timeout;
      const timeoutPromise = new Promise<void>((_, reject) => {
        timeoutId = setTimeout(() => {
          reject(new Error('Wallet did not respond within 60 seconds'));
        }, 60000);
      });

      signAndExecute(
        { transaction: tx },
        {
          onSuccess: async (result: TxResult) => {
            clearTimeout(timeoutId);
            
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
                text: `Creating account...`,
              });

              const extractedBalance = await extractUserBalanceFromDigest(result.digest);
              
              if (extractedBalance) {
                // ✅ SAVE TO LOCALSTORAGE WITH WALLET ADDRESS KEY
                localStorage.setItem(`userBalance_${currentAccount.address}`, extractedBalance);
                
                onBalanceChange(extractedBalance);
                setMessage({
                  type: 'success',
                  text: `✅ Account created! UserBalance: ${extractedBalance.slice(0, 10)}...`,
                });
              } else {
                setMessage({
                  type: 'error',
                  text: `Account created but ID not found. Check Explorer: ${result.digest.slice(0, 10)}...`,
                });
              }
            } catch (err) {
              setMessage({
                type: 'error',
                text: 'Created but could not extract ID. Check Explorer manually.',
              });
            }
            
            setLoading(false);
          },
          onError: (error: ErrorWithCode) => {
            clearTimeout(timeoutId);
            
            // ✅ IMPROVED: Check if account already exists
            if (error.message.includes('EUnauthorized') || error.message.includes('already')) {
              setMessage({
                type: 'error',
                text: 'Account already exists. Refreshing page to load it...',
              });
              
              // Reload after 2 seconds to trigger the auto-detect
              setTimeout(() => {
                window.location.reload();
              }, 2000);
            } else {
              setMessage({
                type: 'error',
                text: error instanceof Error ? error.message : 'Failed to create account',
              });
            }
            
            setLoading(false);
          },
        }
      );
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Unknown error';
      setMessage({
        type: 'error',
        text: errorMsg,
      });
      setLoading(false);
    }
  };

  // ✅ Step 1 - Deposit
  const handleDeposit = async () => {
    if (!userBalance) {
      setMessage({ type: 'error', text: 'Please create account first (Step 0)' });
      return;
    }

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

      const targetFunction = `${CONTRACTS.PACKAGE_ID}::orderbook::deposit_funds`;

      tx.moveCall({
        target: targetFunction,
        typeArguments: ['0x2::oct::OCT'],
        arguments: [
          tx.object(CONTRACTS.MARKET_ID),
          tx.object(userBalance),
          coin,
        ],
      });

      tx.setGasBudget(1000000000); // 1 SUI

      let timeoutId: NodeJS.Timeout;
      const timeoutPromise = new Promise<void>((_, reject) => {
        timeoutId = setTimeout(() => {
          reject(new Error('Wallet did not respond within 60 seconds'));
        }, 60000);
      });

      signAndExecute(
        { transaction: tx },
        {
          onSuccess: (result: TxResult) => {
            clearTimeout(timeoutId);
            
            setMessage({
              type: 'success',
              text: `✅ Deposited ${depositAmount} OCT! TX: ${result.digest?.slice(0, 10)}...`,
            });
            setDepositAmount('');
            setLoading(false);
          },
          onError: (error: ErrorWithCode) => {
            clearTimeout(timeoutId);
            
            setMessage({
              type: 'error',
              text: error instanceof Error ? error.message : 'Failed to deposit',
            });
            setLoading(false);
          },
        }
      );
    } catch (err) {
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

      tx.setGasBudget(1000000000);

      signAndExecute(
        { transaction: tx },
        {
          onSuccess: (result: TxResult) => {
            setMessage({
              type: 'success',
              text: `Order placed! TX: ${result.digest?.slice(0, 10)}...`,
            });
            setPrice('');
            setQuantity('');
            setLoading(false);
          },
          onError: (error: Error | unknown) => {
            let errorMsg = 'Failed to place order';
            if (error instanceof Error) {
              errorMsg = error.message;
            } else if (typeof error === 'string') {
              errorMsg = error;
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
      const errorMsg = err instanceof Error ? err.message : 'Unknown error';
      setMessage({
        type: 'error',
        text: errorMsg || 'Unknown error',
      });
      setLoading(false);
    }
  };

  // ✅ Handle logout/clear account
  const handleLogout = () => {
    if (currentAccount?.address) {
      localStorage.removeItem(`userBalance_${currentAccount.address}`);
    }
    onBalanceChange('');
    setDepositAmount('');
    setPrice('');
    setQuantity('');
    setMessage(null);
  };

  return (
    <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-lg font-bold text-white">Trading Panel</h3>
        {userBalance && (
          <button
            onClick={handleLogout}
            className="text-xs px-3 py-1 rounded bg-red-500/20 text-red-400 hover:bg-red-500/30 transition-all"
          >
            🚪 Logout
          </button>
        )}
      </div>

      {/* ✅ Loading indicator while checking for existing account */}
      {isCheckingExisting && (
        <div className="mb-6 rounded-lg bg-blue-900/20 border border-blue-700 p-4">
          <p className="text-sm text-blue-300 flex items-center gap-2">
            <span className="animate-spin">⏳</span>
            Checking for existing account...
          </p>
        </div>
      )}

      {/* Step 0 - Create Account */}
      {!userBalance && !isCheckingExisting && (
        <div className="mb-6 rounded-lg bg-blue-900/20 border border-blue-700 p-4">
          <h4 className="mb-3 text-sm font-semibold text-blue-300">Step 0: Initialize Account</h4>
          <p className="mb-3 text-xs text-gray-400">First time? Create your trading account</p>
          <button
            onClick={handleCreateUserBalance}
            disabled={loading}
            className="w-full rounded-lg bg-blue-600 px-4 py-2 font-semibold text-white hover:bg-blue-700 disabled:bg-gray-600 disabled:text-gray-400"
          >
            {loading ? 'Creating Account...' : 'Create Account'}
          </button>
        </div>
      )}

      {/* Step 1: Deposit */}
      {userBalance && (
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
      )}

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
          {userBalance ? '✓ Account active' : 'Create account first'}
        </p>
      </div>

      {userBalance && (
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
      )}

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

      {userBalance && (
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
      )}
    </div>
  );
}
