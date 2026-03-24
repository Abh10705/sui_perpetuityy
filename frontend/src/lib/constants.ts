export const CONTRACTS = {
  // Deployed contract
  PACKAGE_ID: '0x433f546dbc38a3ef2c3f38c168acbcb7b80fcbf2298549c8d71467455727a10a',
  
  // Market (Barca vs Madrid)
  MARKET_ID: '0xf4c5f65bbc640eda35716382186fffeaa4eac1cd72b1c697938f39c29fd2ab52',
  ORDERBOOK_ID: '0xe7208d4697ccdbca18fcb8841863f323237f10d9eda570ee775df317151bbf57',
  
  // Market details
  MARKET_QUESTION: 'Which team is better? Barca or Madrid',
  OPTION_A_LABEL: 'Barca',
  OPTION_B_LABEL: 'Madrid',
};

export const MARKETS = [
  {
    id: '1',
    title: CONTRACTS.MARKET_QUESTION,
    optionALabel: CONTRACTS.OPTION_A_LABEL,
    optionBLabel: CONTRACTS.OPTION_B_LABEL,
    tokenASymbol: CONTRACTS.OPTION_A_LABEL,
    tokenBSymbol: CONTRACTS.OPTION_B_LABEL,
    endTime: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30000000), // never
  },
];
