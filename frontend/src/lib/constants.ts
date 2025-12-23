// lib/constants.ts
// Sui Devnet Perpetuity Market Constants

export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0xe701e47e7f517f11840529facb5cf22e01115bdbf115b79cb9ce00d7dd6e3477',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x25651d5df5f8e0769321236e3bd8e3998bad0b8ff3a374d746af8511622a14fc',
  ORDERBOOK_ID: '0x91bfb996b517cd60ba2f55c829ef42b46bf0a0f9d3c876a2e3a1bc6ed0c67618',
  
  // Market details
  MARKET_QUESTION: 'Which team is better? Barca or Madrid',
  OPTION_A: 'Barca',
  OPTION_B: 'Madrid',
};

export const MARKETS = [
  {
    id: '1',
    title: CONTRACTS.MARKET_QUESTION,
    optionA: CONTRACTS.OPTION_A,
    optionB: CONTRACTS.OPTION_B,
    tokenASymbol: CONTRACTS.OPTION_A,
    tokenBSymbol: CONTRACTS.OPTION_B,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30), // 30 days
  },
];