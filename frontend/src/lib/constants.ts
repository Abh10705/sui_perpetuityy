export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0xa3d0fcb9b5923434d046e68dcfc8303eff6e33d5e0a9dfc3af168396ce413ed9',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x6cdd8d356d1e9184d9c86a6de66f0f9ec4b25ed59273d544bce0cb6a674d44a5',
  ORDERBOOK_ID: '0xeb834abfa4186d8fd5dbe2752417bcda239d592819c981ce0a38ecbf34d88d4f',
  
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
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30000000), // never
  },
];