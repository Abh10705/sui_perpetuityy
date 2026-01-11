import { useState, useEffect, useCallback } from 'react';
import { suiClient } from '@/lib/sui/client';
import { CONTRACTS } from '@/lib/constants';
import { UserPosition } from '@/lib/sui/types';

interface TableFields {
  fields: {
    id: {
      id: string;
    };
    size: string;
  };
}

interface FieldNameObject {
  type: string;
  value: string;
}

interface DynamicFieldValue {
  fields?: {
    id: { id: string };
    name: string | FieldNameObject;
    value: {
      type: string;
      fields: {
        value: string;
      };
    };
  };
}

export function useUserPosition(
  userAddress: string | null,
  userBalanceId: string | null
) {
  const [position, setPosition] = useState<UserPosition>({
    barcarShares: 0,
    madridShares: 0,
    balance: 0,
    loading: true,
    error: null,
  });

  const fetchUserPosition = useCallback(async () => {
    if (!userAddress || !userBalanceId) {
      setPosition({
        barcarShares: 0,
        madridShares: 0,
        balance: 0,
        loading: false,
        error: 'User address or balance ID not provided',
      });
      return;
    }

    try {
      setPosition((prev) => ({ ...prev, loading: true, error: null }));

      // 1. Fetch Market object to get shares tables
      const marketObj = await suiClient.getObject({
        id: CONTRACTS.MARKET_ID,
        options: {
          showContent: true,
        },
      });

      if (!marketObj.data?.content) {
        throw new Error('Market object not found');
      }

      const marketContent = marketObj.data.content as Record<string, unknown>;
      const marketFields = marketContent.fields as Record<string, unknown>;

      // Extract table IDs for shares
      const option_a_shares = marketFields?.option_a_shares as TableFields;
      const option_b_shares = marketFields?.option_b_shares as TableFields;

      const option_a_table_id = option_a_shares?.fields?.id?.id;
      const option_b_table_id = option_b_shares?.fields?.id?.id;

      if (!option_a_table_id || !option_b_table_id) {
        throw new Error('Could not find shares table IDs');
      }

      console.log('📊 Fetching user position for:', userAddress);
      console.log('  Option A table:', option_a_table_id);
      console.log('  Option B table:', option_b_table_id);

      // 2. Query user's Barca shares (OptionA)
      let barcarShares = 0;
      try {
        const barcarDynamicFields = await suiClient.getDynamicFields({
          parentId: option_a_table_id,
          limit: 100,
        });

        // Find the field matching user address
        for (const field of barcarDynamicFields.data) {
          if (!field.objectId) continue;

          const fieldObj = await suiClient.getObject({
            id: field.objectId,
            options: { showContent: true },
          });

          if (fieldObj.data?.content?.dataType === 'moveObject') {
            const dynamicField = fieldObj.data.content as unknown as DynamicFieldValue;
            const fieldName = dynamicField.fields?.name;

            // Extract address from field name
            let addressFromField = '';
            if (typeof fieldName === 'string') {
              addressFromField = fieldName;
            } else if (fieldName && typeof fieldName === 'object') {
              const fieldNameObj = fieldName as FieldNameObject;
              addressFromField = fieldNameObj.value;
            }

            if (addressFromField.toLowerCase() === userAddress.toLowerCase()) {
              const shareValue = dynamicField.fields?.value?.fields?.value;
              barcarShares = parseInt(shareValue || '0');
              console.log('✅ Barca shares found:', barcarShares);
              break;
            }
          }
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch Barca shares:', err);
      }

      // 3. Query user's Madrid shares (OptionB)
      let madridShares = 0;
      try {
        const madridDynamicFields = await suiClient.getDynamicFields({
          parentId: option_b_table_id,
          limit: 100,
        });

        // Find the field matching user address
        for (const field of madridDynamicFields.data) {
          if (!field.objectId) continue;

          const fieldObj = await suiClient.getObject({
            id: field.objectId,
            options: { showContent: true },
          });

          if (fieldObj.data?.content?.dataType === 'moveObject') {
            const dynamicField = fieldObj.data.content as unknown as DynamicFieldValue;
            const fieldName = dynamicField.fields?.name;

            // Extract address from field name
            let addressFromField = '';
            if (typeof fieldName === 'string') {
              addressFromField = fieldName;
            } else if (fieldName && typeof fieldName === 'object') {
              const fieldNameObj = fieldName as FieldNameObject;
              addressFromField = fieldNameObj.value;
            }

            if (addressFromField.toLowerCase() === userAddress.toLowerCase()) {
              const shareValue = dynamicField.fields?.value?.fields?.value;
              madridShares = parseInt(shareValue || '0');
              console.log('✅ Madrid shares found:', madridShares);
              break;
            }
          }
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch Madrid shares:', err);
      }

      // 4. Fetch user balance (available collateral)
      let balance = 0;
      try {
        const userBalanceObj = await suiClient.getObject({
          id: userBalanceId,
          options: { showContent: true },
        });

        if (userBalanceObj.data?.content) {
          const balanceContent = userBalanceObj.data.content as Record<
            string,
            unknown
          >;
          const balanceFields = balanceContent.fields as Record<string, unknown>;

          // The balance is stored as a nested Balance<CoinType>
          const balanceData = balanceFields?.balance as Record<string, unknown>;
          const balanceFieldsNested = balanceData?.fields as Record<string, unknown>;
          const balanceValue = balanceFieldsNested?.value as string;

          balance = parseInt(balanceValue || '0') / 1e9; // Convert from MIST to OCT
          console.log('✅ User balance found:', balance, 'OCT');
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch user balance:', err);
      }

      setPosition({
        barcarShares,
        madridShares,
        balance,
        loading: false,
        error: null,
      });

      console.log('📈 Final position:', {
        barcarShares,
        madridShares,
        balance,
      });
    } catch (err) {
      console.error('❌ Error fetching user position:', err);
      setPosition((prev) => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to fetch position',
      }));
    }
  }, [userAddress, userBalanceId]);

  useEffect(() => {
    fetchUserPosition();

    // Refresh every 30 seconds
    const interval = setInterval(fetchUserPosition, 30000);
    return () => clearInterval(interval);
  }, [fetchUserPosition]);

  return { ...position, refetch: fetchUserPosition };
}
