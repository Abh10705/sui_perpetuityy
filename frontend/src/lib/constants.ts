// lib/constants.ts
// Sui Devnet Perpetuity Market Constants

export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x85e477bdc976e6303dc3e08067a7dd06a8c6a20012247d265336949244d5eb83',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0xf012156021c3ed3ff66264c2ce70fa153a6ed4a0125bcff258124df7407dfd33',
  ORDERBOOK_ID: '0x23b79bbd20157c1621796d1eeeb3560b919b66a72f2e7509656ac77f0016af20',
  
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