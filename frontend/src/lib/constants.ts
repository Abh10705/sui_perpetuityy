export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x735ef90260d63f0a310eb0e6df51e142a836f7bad48fbb56777748e6bae6c43e',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x6f8decd62e1f02c938200117d9bb2af94b1e752d709741f73abf6ada4dc1e4b3',
  ORDERBOOK_ID: '0xd7ca753fb8d80ce073d8ad4c2038b6d0ba9b0691925e7495abe125a41c8c9073',
  
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