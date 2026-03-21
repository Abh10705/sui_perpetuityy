export const CONTRACTS = {
  // Deployed contract
  PACKAGE_ID: '0x4e501083c053689ba5b59acf2d92caaeaaf9a494b3890c670a75de90916c8fca',
  
  // Market (Barca vs Madrid)
  MARKET_ID: '0x6b10a21933e466c100ea4034fb52f094a97384fa96bc25ca0500aee7198faf94',
  ORDERBOOK_ID: '0xec2339c4fce40d74806f1acee291a8b989b03b82ef4e72509bc27a485d48433e',
  
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
