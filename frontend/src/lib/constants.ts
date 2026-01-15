export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x793eb38194aaaa3164c2c69264a3f0052dab7f7eec43c04ba61f7035173cfe0f',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x0cd640f72cbd83b6479b0d6f7f003b164a6861f90817b22518cc8fb8846f8046',
  ORDERBOOK_ID: '0xc694639d0697dba3f6ec7de01ec3a02500fd675f10554d3b4e26aab8a9be5a4b',
  
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