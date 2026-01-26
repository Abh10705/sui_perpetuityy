export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x47b198aaaaca365f027b7e80b3f94fc35f482d4fc20026f8dacaa72d000663fc',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x6441136612b7284cdc0dea507132680bc4d1e5f40dac18fa8f3d6194a6ddc4da',
  ORDERBOOK_ID: '0x46ee5fcf2529579c2e3f6ce2d289b7e85fb2447e946e9b4fcab7445fe0704a6f',
  
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