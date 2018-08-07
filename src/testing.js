import promisify from "es6-promisify";
import BigNumber from 'bignumber.js';
import * as TestPositionsJson from '../build/test-positions.json';

export function reset(web3Instance) {
  // Needed for different versions of web3
  const func = web3Instance.currentProvider.sendAsync || web3Instance.currentProvider.send;
  return promisify(func)({
    jsonrpc: "2.0",
    method: "evm_revert",
    id: 12345,
    params: ['0x1'],
  });
}
// (() => {
//   const TestPositionsArray = [TestPositionsJson["0"],TestPositionsJson["1"],TestPositionsJson["2"]];
//   console.log(TestPositionsArray)
// })();
export const TEST_POSITIONS = [TestPositionsJson["0"],TestPositionsJson["1"],TestPositionsJson["2"]]
  .map(mapPositionFromJson);
console.log(TEST_POSITIONS);
function mapPositionFromJson(jsonPosition) {
  return {
    ...jsonPosition,
    position: new BigNumber(jsonPosition.principal),
    interestRate: new BigNumber(jsonPosition.interestRate),
    requiredDeposit: new BigNumber(jsonPosition.requiredDeposit),
    callTimeLimit: new BigNumber(jsonPosition.callTimeLimit),
    callTimestamp: new BigNumber(jsonPosition.callTimestamp),
    startTimestamp: new BigNumber(jsonPosition.startTimestamp),
    maxDuration: new BigNumber(jsonPosition.maxDuration),
    interestPeriod: new BigNumber(jsonPosition.interestPeriod),
  }
}
