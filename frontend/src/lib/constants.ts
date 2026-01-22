export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0xaf04060398bad888fbfff03abf0cb0b13fbd1ed9746c1571a1eabe2bfbcbe6f6',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x22637140022c4ba6de579a415cef91dc239f56178d0bbce9e51a41086d17a751',
  ORDERBOOK_ID: '0x7890185cdb77b49de1387a56c4ef261dfbda360d1c7fe823ec87bc4abed45c25',
  
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