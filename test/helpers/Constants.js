const BigNumber = require('bignumber.js');

module.exports = {
  addr1: '0xec37D2aFfb54cBFaE6f8e66E0161E1cfa4bBf471',
  addr2: '0xec37D2aFfb54cBFaE6f8e66E0161E1cfa4bBf472',
  zeroExFeeTokenConstant: '0x0000000000000000000000000000010',
  ADDRESSES: {
    ZERO: '0x0000000000000000000000000000000000000000',
    TEST: [
      '0x06012c8cf97bead5deae237070f9587f8e7a266d', // CryptoKittiesCore
      '0x06012c8cf97bead5deae237070f9587f8e7a2661', // 1
      '0x06012c8cf97bead5deae237070f9587f8e7a2662', // 2
      '0x06012c8cf97bead5deae237070f9587f8e7a2663', // 3
      '0x06012c8cf97bead5deae237070f9587f8e7a2664', // 4
      '0x06012c8cf97bead5deae237070f9587f8e7a2665', // 5
      '0x06012c8cf97bead5deae237070f9587f8e7a2666', // 6
      '0x06012c8cf97bead5deae237070f9587f8e7a2667', // 7
      '0x06012c8cf97bead5deae237070f9587f8e7a2668', // 8
      '0x06012c8cf97bead5deae237070f9587f8e7a2669', // 9
    ]
  },
  BIGNUMBERS: {
    ZERO: new BigNumber(0),
    ONE_DAY_IN_SECONDS: new BigNumber(60 * 60 * 24)
  }
};
