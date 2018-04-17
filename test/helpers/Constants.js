/*global web3*/

const Web3 = require('web3');
const web3Instance = new Web3(web3.currentProvider);
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
    ONE_DAY_IN_SECONDS: new BigNumber(60 * 60 * 24),
    ONE_YEAR_IN_SECONDS: new BigNumber(60 * 60 * 24 * 365),
    BASE_AMOUNT: new BigNumber('1e18')
  },
  BYTES32: {
    ZERO: '0x0000000000000000000000000000000000000000000000000000000000000000'.valueOf(),
    BAD_ID: web3Instance.utils.utf8ToHex("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"),
    TEST: [
      web3Instance.utils.utf8ToHex("12345670123456701234567012345670"),
      web3Instance.utils.utf8ToHex("12345671123456711234567112345671"),
      web3Instance.utils.utf8ToHex("12345672123456721234567212345672"),
      web3Instance.utils.utf8ToHex("12345673123456731234567312345673"),
      web3Instance.utils.utf8ToHex("12345674123456741234567412345674"),
      web3Instance.utils.utf8ToHex("12345675123456751234567512345675"),
      web3Instance.utils.utf8ToHex("12345676123456761234567612345676"),
      web3Instance.utils.utf8ToHex("12345677123456771234567712345677"),
      web3Instance.utils.utf8ToHex("12345678123456781234567812345678"),
      web3Instance.utils.utf8ToHex("12345679123456791234567912345679"),
    ]
  },
  DEFAULT_SALT: 425
};
