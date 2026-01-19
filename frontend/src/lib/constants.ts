export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x24c72e6b20cd86f627941dadaab9c9f0b95a1e56c22ac8544d5a57661b823657',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0xe0b04185f89e28880cbefce0361b40a416bab291aa76caef3c68a354154eae17',
  ORDERBOOK_ID: '0x60abb9aec5999e98f8f132123d258475852c94c5e547a5f3fb695125f6cc129a',
  
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