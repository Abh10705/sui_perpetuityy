// lib/constants.ts
// Sui Devnet Perpetuity Market Constants

export const CONTRACTS = {
  // Your deployed contract
  PACKAGE_ID: '0x1b0987f005504b1ee96aba09471757c4207fd3accb2eeb34b602150d6b52be91',
  
  // Your market (Barca vs Madrid)
  MARKET_ID: '0x18a85c26495bf60dfcca9b09a4fe07a85a365ad2ec4784cf864b69c5aad010d7',
  ORDERBOOK_ID: '0x356be0dbfea0e7fb41855a4841529d5b6b3f9cddfeb2bf3e814d6a461b00e8ad',
  
  // Market details
  MARKET_QUESTION: 'Who wins? Barca vs Madrid',
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