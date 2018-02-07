/*global artifacts, web3, contract, describe, it*/

const expect = require('chai').expect;
const BigNumber = require('bignumber.js');

const ShortSell = artifacts.require("ShortSell");
const Vault = artifacts.require("Vault");
const Trader = artifacts.require("Trader");
const BaseToken = artifacts.require("TokenA");
const UnderlyingToken = artifacts.require("TokenB");
const FeeToken = artifacts.require("TokenC");
const { wait } = require('@digix/tempo')(web3);
const {
  createSigned0xSellOrder,
  issueTokensAndSetAllowancesForClose,
  doShort,
  getPartialAmount,
  callCloseShort,
  getShort,
  doShortAndCall,
  placeAuctionBid
} = require('../helpers/ShortSellHelper');
const { BIGNUMBERS } = require('../helpers/Constants');
const ProxyContract = artifacts.require("Proxy");
const { getBlockTimestamp } = require('../helpers/NodeHelper');
const { expectThrow } = require('../helpers/ExpectHelper');

describe('#closeShort', () => {
  contract('ShortSell', function(accounts) {
    it('Successfully closes a short in increments', async () => {
      const shortTx = await doShort(accounts);
      const [sellOrder, shortSell] = await Promise.all([
        createSigned0xSellOrder(accounts),
        ShortSell.deployed()
      ]);
      await issueTokensAndSetAllowancesForClose(shortTx, sellOrder);

      // Close half the short at a time
      const closeAmount = shortTx.shortAmount.div(new BigNumber(2));

      // Simulate time between open and close so interest fee needs to be paid
      await wait(10000);

      let closeTx = await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);

      let exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.true;

      await checkSuccess(shortSell, shortTx, closeTx, sellOrder, closeAmount);

      const { closedAmount } = await getShort(shortSell, shortTx.id);

      expect(closedAmount.equals(closeAmount)).to.be.true;

      // Simulate time between open and close so interest fee needs to be paid
      await wait(10000);

      // Close the rest of the short
      await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);
      exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;
    });
  });

  contract('ShortSell', function(accounts) {
    it('only allows the short seller to close', async () => {
      const shortTx = await doShort(accounts);
      const [sellOrder, shortSell] = await Promise.all([
        createSigned0xSellOrder(accounts),
        ShortSell.deployed()
      ]);
      await issueTokensAndSetAllowancesForClose(shortTx, sellOrder);
      const closeAmount = shortTx.shortAmount.div(new BigNumber(2));

      await expectThrow(
        () => callCloseShort(
          shortSell,
          shortTx,
          sellOrder,
          closeAmount,
          accounts[6]
        )
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('sends tokens back to auction bidder if there is one', async () => {
      const { shortSell, underlyingToken, shortTx } = await doShortAndCall(accounts);
      const sellOrder = await createSigned0xSellOrder(accounts);
      await issueTokensAndSetAllowancesForClose(shortTx, sellOrder);
      const bidder = accounts[6];
      const bid = new BigNumber(200);
      await placeAuctionBid(shortSell, underlyingToken, shortTx, bidder, bid);
      const closeAmount = shortTx.shortAmount.div(new BigNumber(2));

      await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);

      let bidderUnderlyingTokenBalance = await underlyingToken.balanceOf.call(bidder);
      expect(bidderUnderlyingTokenBalance.equals(new BigNumber(0))).to.be.true;

      await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);

      bidderUnderlyingTokenBalance = await underlyingToken.balanceOf.call(bidder);
      expect(bidderUnderlyingTokenBalance.equals(shortTx.shortAmount)).to.be.true;
    });
  });

  contract('ShortSell', function(accounts) {
    it('Only closes up to the current short amount', async () => {
      const shortTx = await doShort(accounts);
      const [sellOrder, shortSell] = await Promise.all([
        createSigned0xSellOrder(accounts),
        ShortSell.deployed()
      ]);
      await issueTokensAndSetAllowancesForClose(shortTx, sellOrder);

      // Try to close twice the short amount
      const closeAmount = shortTx.shortAmount.times(new BigNumber(2));

      // Simulate time between open and close so interest fee needs to be paid
      await wait(10000);

      let closeTx = await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);

      let exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      await checkSuccess(shortSell, shortTx, closeTx, sellOrder, shortTx.shortAmount);
    });
  });
});

describe('#closeShortDirectly', () => {
  contract('ShortSell', function(accounts) {
    it('Successfully closes a short in increments', async () => {
      const shortTx = await doShort(accounts);

      // Give the short seller enough underlying token to close
      await issueForDirectClose(shortTx);

      const shortSell = await ShortSell.deployed();
      const closeAmount = shortTx.shortAmount.div(new BigNumber(2));

      const closeTx = await shortSell.closeShortDirectly(
        shortTx.id,
        closeAmount,
        { from: shortTx.seller }
      );

      const exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.true;

      const interestFee = await getInterestFee(shortTx, closeTx, closeAmount);
      const balances = await getBalances(shortSell, shortTx);
      const baseTokenFromSell = getPartialAmount(
        shortTx.buyOrder.makerTokenAmount,
        shortTx.buyOrder.takerTokenAmount,
        closeAmount
      );
      checkSmartContractBalances(balances, shortTx, closeAmount);
      checkLenderBalances(balances, interestFee, shortTx, closeAmount);

      expect(balances.sellerUnderlyingToken.equals(
        shortTx.shortAmount.minus(closeAmount)
      )).to.be.true;
      expect(balances.sellerBaseToken.equals(
        getPartialAmount(
          closeAmount,
          shortTx.shortAmount,
          shortTx.depositAmount
        ).plus(baseTokenFromSell)
          .minus(interestFee)
      )).to.be.true;
    });
  });

  contract('ShortSell', function(accounts) {
    it('only allows the short seller to close', async () => {
      const shortTx = await doShort(accounts);
      const shortSell = await ShortSell.deployed();
      await issueForDirectClose(shortTx);
      const closeAmount = shortTx.shortAmount.div(new BigNumber(2));

      await expectThrow(
        () => shortSell.closeShortDirectly(
          shortTx.id,
          closeAmount,
          { from: accounts[6] }
        )
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('sends tokens back to auction bidder if there is one', async () => {
      const { shortSell, underlyingToken, shortTx } = await doShortAndCall(accounts);
      await issueForDirectClose(shortTx);
      const bidder = accounts[6];
      const bid = new BigNumber(200);
      await placeAuctionBid(shortSell, underlyingToken, shortTx, bidder, bid);

      const closeTx = await shortSell.closeShortDirectly(
        shortTx.id,
        shortTx.shortAmount,
        { from: shortTx.seller }
      );

      const exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      const closeAmount = shortTx.shortAmount;

      const interestFee = await getInterestFee(shortTx, closeTx, closeAmount);
      const balances = await getBalances(shortSell, shortTx);
      const baseTokenFromSell = getPartialAmount(
        shortTx.buyOrder.makerTokenAmount,
        shortTx.buyOrder.takerTokenAmount,
        closeAmount
      );
      checkSmartContractBalances(balances, shortTx, closeAmount);
      checkLenderBalances(balances, interestFee, shortTx, closeAmount);

      expect(balances.sellerUnderlyingToken.equals(new BigNumber(0))).to.be.true;
      expect(balances.sellerBaseToken.equals(
        shortTx.depositAmount
          .plus(baseTokenFromSell)
          .minus(interestFee)
      )).to.be.true;

      const bidderUnderlyingTokenBalance = await underlyingToken.balanceOf.call(bidder);
      expect(bidderUnderlyingTokenBalance.equals(shortTx.shortAmount)).to.be.true;
    });
  });

  contract('ShortSell', function(accounts) {
    it('Only closes up to the current short amount', async () => {
      const shortTx = await doShort(accounts);

      // Give the short seller enough underlying token to close
      await issueForDirectClose(shortTx);

      const shortSell = await ShortSell.deployed();
      const requestedCloseAmount = shortTx.shortAmount.times(new BigNumber(2));

      const closeTx = await shortSell.closeShortDirectly(
        shortTx.id,
        requestedCloseAmount,
        { from: shortTx.seller }
      );

      const exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      const closeAmount = shortTx.shortAmount;

      const interestFee = await getInterestFee(shortTx, closeTx, closeAmount);
      const balances = await getBalances(shortSell, shortTx);
      const baseTokenFromSell = getPartialAmount(
        shortTx.buyOrder.makerTokenAmount,
        shortTx.buyOrder.takerTokenAmount,
        closeAmount
      );
      checkSmartContractBalances(balances, shortTx, closeAmount);
      checkLenderBalances(balances, interestFee, shortTx, closeAmount);

      expect(balances.sellerUnderlyingToken.equals(
        shortTx.shortAmount.minus(closeAmount)
      )).to.be.true;
      expect(balances.sellerBaseToken.equals(
        getPartialAmount(
          closeAmount,
          shortTx.shortAmount,
          shortTx.depositAmount
        ).plus(baseTokenFromSell)
          .minus(interestFee)
      )).to.be.true;
    });
  });
});

async function issueForDirectClose(shortTx) {
  const underlyingToken = await UnderlyingToken.deployed();
  await Promise.all([
    underlyingToken.issueTo(
      shortTx.seller,
      shortTx.shortAmount
    ),
    underlyingToken.approve(
      ProxyContract.address,
      shortTx.shortAmount,
      { from: shortTx.seller }
    )
  ]);
}

async function checkSuccess(shortSell, shortTx, closeTx, sellOrder, closeAmount) {
  const baseTokenFromSell = getPartialAmount(
    shortTx.buyOrder.makerTokenAmount,
    shortTx.buyOrder.takerTokenAmount,
    closeAmount
  );
  const interestFee = await getInterestFee(shortTx, closeTx, closeAmount);
  const baseTokenBuybackCost = getPartialAmount(
    sellOrder.takerTokenAmount,
    sellOrder.makerTokenAmount,
    closeAmount
  );

  const balances = await getBalances(shortSell, shortTx, sellOrder);
  const {
    sellerBaseToken,
    externalSellerBaseToken,
    externalSellerUnderlyingToken,
    sellerFeeToken,
    externalSellerFeeToken,
    feeRecipientFeeToken
  } = balances;

  checkSmartContractBalances(balances, shortTx, closeAmount);
  checkLenderBalances(balances, interestFee, shortTx, closeAmount);

  expect(
    sellerBaseToken.equals(
      getPartialAmount(
        closeAmount,
        shortTx.shortAmount,
        shortTx.depositAmount
      ).plus(baseTokenFromSell)
        .minus(baseTokenBuybackCost)
        .minus(interestFee)
    )
  ).to.be.true;
  expect(externalSellerBaseToken.equals(baseTokenBuybackCost)).to.be.true;
  expect(
    externalSellerUnderlyingToken.equals(
      sellOrder.makerTokenAmount.minus(closeAmount)
    )
  ).to.be.true;
  expect(feeRecipientFeeToken.equals(
    getPartialAmount(
      closeAmount,
      sellOrder.makerTokenAmount,
      sellOrder.takerFee
    ).plus(
      getPartialAmount(
        closeAmount,
        sellOrder.makerTokenAmount,
        sellOrder.makerFee
      )
    )
  )).to.be.true;
  expect(sellerFeeToken.equals(
    shortTx.buyOrder.takerFee
      .plus(shortTx.loanOffering.rates.takerFee)
      .plus(sellOrder.takerFee)
      .minus(
        getPartialAmount(
          shortTx.shortAmount,
          shortTx.loanOffering.rates.maxAmount,
          shortTx.loanOffering.rates.takerFee
        )
      )
      .minus(
        getPartialAmount(
          shortTx.shortAmount,
          shortTx.buyOrder.takerTokenAmount,
          shortTx.buyOrder.takerFee
        )
      )
      .minus(
        getPartialAmount(
          closeAmount,
          sellOrder.makerTokenAmount,
          sellOrder.takerFee
        )
      )
  )).to.be.true;
  expect(externalSellerFeeToken.equals(
    sellOrder.makerFee
      .minus(
        getPartialAmount(
          closeAmount,
          sellOrder.makerTokenAmount,
          sellOrder.makerFee
        )
      )
  )).to.be.true;
}

function checkSmartContractBalances(balances, shortTx, closeAmount) {
  const startingShortBaseTokenAmount = getPartialAmount(
    shortTx.buyOrder.makerTokenAmount,
    shortTx.buyOrder.takerTokenAmount,
    shortTx.shortAmount
  ).plus(shortTx.depositAmount);
  const expectedShortBalance = getPartialAmount(
    shortTx.shortAmount.minus(closeAmount),
    shortTx.shortAmount,
    startingShortBaseTokenAmount
  );

  const {
    vaultFeeToken,
    vaultBaseToken,
    vaultUnderlyingToken,
    traderFeeToken,
    traderBaseToken,
    traderUnderlyingToken,
    shortBalance
  } = balances;

  expect(vaultFeeToken.equals(new BigNumber(0))).to.be.true;
  expect(vaultBaseToken.equals(expectedShortBalance)).to.be.true;
  expect(vaultUnderlyingToken.equals(new BigNumber(0))).to.be.true;
  expect(traderFeeToken.equals(new BigNumber(0))).to.be.true;
  expect(traderBaseToken.equals(new BigNumber(0))).to.be.true;
  expect(traderUnderlyingToken.equals(new BigNumber(0))).to.be.true;
  expect(shortBalance.equals(expectedShortBalance)).to.be.true;
}

function checkLenderBalances(balances, interestFee, shortTx, closeAmount) {
  const {
    lenderBaseToken,
    lenderUnderlyingToken
  } = balances;
  expect(lenderBaseToken.equals(interestFee)).to.be.true;
  expect(lenderUnderlyingToken.equals(
    shortTx.loanOffering.rates.maxAmount
      .minus(shortTx.shortAmount)
      .plus(closeAmount)
  )).to.be.true;
}

async function getInterestFee(shortTx, closeTx, closeAmount) {
  const shortLifetime = await getShortLifetime(shortTx, closeTx);

  return getPartialAmount(
    closeAmount,
    shortTx.shortAmount,
    getPartialAmount(
      shortTx.loanOffering.rates.interestRate,
      BIGNUMBERS.ONE_DAY_IN_SECONDS,
      shortLifetime
    )
  );
}

async function getBalances(shortSell, shortTx, sellOrder) {
  const [
    underlyingToken,
    baseToken,
    feeToken
  ] = await Promise.all([
    UnderlyingToken.deployed(),
    BaseToken.deployed(),
    FeeToken.deployed(),
  ]);

  let externalSellerBaseToken,
    externalSellerUnderlyingToken,
    externalSellerFeeToken,
    feeRecipientFeeToken;

  if (sellOrder) {
    [
      externalSellerBaseToken,
      externalSellerUnderlyingToken,
      externalSellerFeeToken,
      feeRecipientFeeToken,
    ] = await Promise.all([
      baseToken.balanceOf.call(sellOrder.maker),
      underlyingToken.balanceOf.call(sellOrder.maker),
      feeToken.balanceOf.call(sellOrder.maker),
      feeToken.balanceOf.call(sellOrder.feeRecipient),
    ]);
  }

  const [
    sellerBaseToken,
    sellerUnderlyingToken,
    lenderBaseToken,
    lenderUnderlyingToken,
    sellerFeeToken,
    vaultFeeToken,
    vaultBaseToken,
    vaultUnderlyingToken,
    traderFeeToken,
    traderBaseToken,
    traderUnderlyingToken,
    shortBalance
  ] = await Promise.all([
    baseToken.balanceOf.call(shortTx.seller),
    underlyingToken.balanceOf.call(shortTx.seller),
    baseToken.balanceOf.call(shortTx.loanOffering.lender),
    underlyingToken.balanceOf.call(shortTx.loanOffering.lender),
    feeToken.balanceOf.call(shortTx.seller),
    feeToken.balanceOf.call(Vault.address),
    baseToken.balanceOf.call(Vault.address),
    underlyingToken.balanceOf.call(Vault.address),
    feeToken.balanceOf.call(Trader.address),
    baseToken.balanceOf.call(Trader.address),
    underlyingToken.balanceOf.call(Trader.address),
    shortSell.getShortBalance.call(shortTx.id)
  ]);

  return {
    sellerBaseToken,
    sellerUnderlyingToken,
    lenderBaseToken,
    lenderUnderlyingToken,
    externalSellerBaseToken,
    externalSellerUnderlyingToken,
    sellerFeeToken,
    externalSellerFeeToken,
    feeRecipientFeeToken,
    vaultFeeToken,
    vaultBaseToken,
    vaultUnderlyingToken,
    traderFeeToken,
    traderBaseToken,
    traderUnderlyingToken,
    shortBalance
  };
}

async function getShortLifetime(shortTx, closeTx) {
  const [shortTimestamp, shortClosedTimestamp] = await Promise.all([
    getBlockTimestamp(shortTx.response.receipt.blockNumber),
    getBlockTimestamp(closeTx.receipt.blockNumber)
  ]);

  return shortClosedTimestamp - shortTimestamp;
}
