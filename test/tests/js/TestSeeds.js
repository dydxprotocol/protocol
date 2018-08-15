const { seeds, reset, snapshot } = require('../../../src/index');
const { getPosition } = require('../../helpers/MarginHelper');
const chai = require('chai');
const expect = chai.expect;
chai.use(require('chai-bignumber')());
const { ZeroEx } = require('0x.js');

const Margin = artifacts.require('Margin');
const TestToken = artifacts.require('TestToken');
const ZeroExProxy = artifacts.require('ZeroExProxy');

contract('Margin', () => {
  after(async () => {
    await reset(web3.currentProvider);
    // Snapshot a final time to fool truffle into reverting to this in the contract block
    await snapshot(web3.currentProvider);
  });

  describe('seeds', () => {
    context('positions', () => {
      it('sets up seed positions correctly', async () => {
        await checkSeedPositions();
      });

      it('seed positions still exist after reset', async () => {
        await checkSeedPositions();

        await reset(web3.currentProvider);

        await checkSeedPositions();
      });
    });

    context('orders', () => {
      it('sets up seed orders correctly', async () => {
        await checkSeedOrders();
      });

      it('seed orders still exist after reset', async () => {
        await checkSeedOrders();

        await reset(web3.currentProvider);

        await checkSeedOrders();
      });
    });
  });
});

async function checkSeedPositions() {
  const promises = seeds.positions.map(async seedPosition => {
    const margin = await Margin.deployed();

    const position = await getPosition(margin, seedPosition.id);

    expect(seedPosition.owedToken).to.be.eq(position.owedToken);
    expect(seedPosition.heldToken).to.be.eq(position.heldToken);
    expect(seedPosition.lender).to.be.eq(position.lender);
    expect(seedPosition.owner).to.be.eq(position.owner);
    expect(seedPosition.interestRate).to.be.bignumber.eq(position.interestRate);
    expect(seedPosition.requiredDeposit).to.be.bignumber.eq(position.requiredDeposit);
    expect(seedPosition.callTimeLimit).to.be.bignumber.eq(position.callTimeLimit);
    expect(seedPosition.startTimestamp).to.be.bignumber.eq(position.startTimestamp);
    expect(seedPosition.callTimestamp).to.be.bignumber.eq(position.callTimestamp);
    expect(seedPosition.maxDuration).to.be.bignumber.eq(position.maxDuration);
    expect(seedPosition.interestPeriod).to.be.bignumber.eq(position.interestPeriod);
  });

  await Promise.all(promises);
}

async function checkSeedOrders() {
  const promises = seeds.orders.map(async seedOrder => {
    expect(ZeroEx.isValidSignature(
      ZeroEx.getOrderHashHex(seedOrder),
      seedOrder.ecSignature,
      seedOrder.maker
    )).to.be.true;

    const makerToken = await TestToken.at(seedOrder.makerTokenAddress);

    const [makerBalance, makerAllowance] = await Promise.all([
      makerToken.balanceOf.call(seedOrder.maker),
      makerToken.allowance.call(seedOrder.maker, ZeroExProxy.address),
    ]);

    expect(makerBalance).to.be.bignumber.gte(seedOrder.makerTokenAmount);
    expect(makerAllowance).to.be.bignumber.gte(seedOrder.makerTokenAmount);
  });

  await Promise.all(promises);
}
