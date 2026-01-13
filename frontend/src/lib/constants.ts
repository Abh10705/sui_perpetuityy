export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0xdd6790e97dfbd73feee49aad98200ad9536b9f35e61b48b0009a64e81682e14e',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0xa29bb16790c3941e2226be811152359527530a75193b4b4506d584e090bface0',
  ORDERBOOK_ID: '0xb7d6d9519082d096d2cea1eb7f8f56935dac15f5073e6ee1011846f8ec5afeef',
  
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