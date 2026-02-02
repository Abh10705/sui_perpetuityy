export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x5c91319eba13f26ef17a708cd5bae1276c283795ba3e843962c6a1bfe0660210',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x6f26f71dc26a4dbfa86a07f8207846d243576034be9507eb692e6ebb8f9ae242',
  ORDERBOOK_ID: '0x99ddf978c01db02a56a4ade6192a91540c44f7b98ac67097658730b6ad7d2e34',
  
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