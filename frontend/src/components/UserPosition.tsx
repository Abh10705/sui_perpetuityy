'use client';

import { useUserPosition } from '@/hooks/useUserPosition';
import { CONTRACTS } from '@/lib/constants';
import { useCurrentAccount } from '@mysten/dapp-kit';

interface UserPositionProps {
  userBalanceId: string | null;
}

export function UserPosition({ userBalanceId }: UserPositionProps) {
  const account = useCurrentAccount();
  const userAddress = account?.address || null;

  const { barcarShares, madridShares, balance, loading, error } = useUserPosition(
    userAddress,
    userBalanceId
  );

  if (loading) {
    return (
      <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
        <h3 className="mb-4 text-lg font-bold text-white">Your Position</h3>
        <div className="text-center text-gray-400">Loading position...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
        <h3 className="mb-4 text-lg font-bold text-white">Your Position</h3>
        <div className="text-sm text-red-400">Error: {error}</div>
      </div>
    );
  }

  // Format numbers for display
  const formatShares = (num: number) => num.toLocaleString();
  const formatBalance = (num: number) => num.toFixed(4);

  return (
    <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
      <h3 className="mb-6 text-lg font-bold text-white">Your Position</h3>

      {/* Barca Shares */}
      <div className="mb-4 rounded-lg bg-gray-800 p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-400">{CONTRACTS.OPTION_A}</p>
            <p className="text-2xl font-bold text-green-400">
              {formatShares(barcarShares)}
            </p>
            <p className="text-xs text-gray-500">shares</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-gray-500">Value (est.)</p>
            <p className="text-lg font-semibold text-green-400">
              {(barcarShares * 0.5).toFixed(2)} OCT
            </p>
          </div>
        </div>
      </div>

      {/* Madrid Shares */}
      <div className="mb-4 rounded-lg bg-gray-800 p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-400">{CONTRACTS.OPTION_B}</p>
            <p className="text-2xl font-bold text-red-400">
              {formatShares(madridShares)}
            </p>
            <p className="text-xs text-gray-500">shares</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-gray-500">Value (est.)</p>
            <p className="text-lg font-semibold text-red-400">
              {(madridShares * 0.5).toFixed(2)} OCT
            </p>
          </div>
        </div>
      </div>

      {/* Available Balance */}
      <div className="mb-4 rounded-lg border border-gray-600 bg-gray-800/50 p-4">
        <p className="text-sm text-gray-400">Available Balance</p>
        <p className="text-2xl font-bold text-purple-400">
          {formatBalance(balance)} OCT
        </p>
      </div>

      {/* Total Value */}
      <div className="rounded-lg border-t border-gray-600 bg-gray-800/50 p-4 pt-4">
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-300">Total Position Value</p>
          <p className="text-xl font-bold text-white">
            {(barcarShares * 0.5 + madridShares * 0.5 + balance).toFixed(2)} OCT
          </p>
        </div>
      </div>

      {/* Auto-refresh indicator */}
      <p className="mt-4 text-xs text-gray-500 text-center">
        Updates every 30 seconds
      </p>
    </div>
  );
}
