export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0xa0d96944ae558975549e82d64f50b42ff8d850f99da7c24d5b5200d72f3a2377',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x9b82bd948ad3fb578099ba06f46d0bb41f577efe03489012f43f2b3d253e8a67',
  ORDERBOOK_ID: '0xc874e583710c292caa5fd5f83cb3b34f1815db9f85be6f8f0c018b555be0a38e',
  
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