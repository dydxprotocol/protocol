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
  callCloseEntireShort,
  getPartialAmount,
  callCloseShort
} = require('../helpers/ShortSellHelper');
const ProxyContract = artifacts.require("Proxy");

describe('#closeEntireShort', () => {
  contract('ShortSell', function(accounts) {
    it('successfully closes a short', async () => {
      const shortTx = await doShort(accounts);
      const [sellOrder, shortSell] = await Promise.all([
        createSigned0xSellOrder(accounts),
        ShortSell.deployed()
      ]);
      await issueTokensAndSetAllowancesForClose(shortTx, sellOrder);

      const tx = await callCloseEntireShort(shortSell, shortTx, sellOrder);

      console.log('\tShortSell.closeShort gas used: ' + tx.receipt.gasUsed);

      const exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      // Simulate time between open and close so interest fee needs to be paid
      await wait(10000);

      const shortTimestamp = shortTx.response.logs.find(
        l => l.event === 'ShortInitiated'
      ).args.timestamp;
      const shortClosedTimestamp = tx.logs.find(
        l => l.event === 'ShortClosed'
      ).args.timestamp;
      const shortLifetime = shortClosedTimestamp.minus(shortTimestamp);

      const ONE_DAY_IN_SECONDS = new BigNumber(60 * 60 * 24);

      const balance = await shortSell.getShortBalance.call(shortTx.id);

      const baseTokenFromSell = getPartialAmount(
        shortTx.buyOrder.makerTokenAmount,
        shortTx.buyOrder.takerTokenAmount,
        shortTx.shortAmount
      );
      const interestFee = getPartialAmount(
        shortTx.loanOffering.rates.interestRate,
        ONE_DAY_IN_SECONDS,
        shortLifetime
      );
      const baseTokenBuybackCost = getPartialAmount(
        sellOrder.takerTokenAmount,
        sellOrder.makerTokenAmount,
        shortTx.shortAmount
      );

      expect(balance.equals(new BigNumber(0))).to.be.true;

      const [
        underlyingToken,
        baseToken,
        feeToken
      ] = await Promise.all([
        UnderlyingToken.deployed(),
        BaseToken.deployed(),
        FeeToken.deployed(),
      ]);

      const [
        sellerBaseToken,
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
        traderUnderlyingToken
      ] = await Promise.all([
        baseToken.balanceOf.call(shortTx.seller),
        baseToken.balanceOf.call(shortTx.loanOffering.lender),
        underlyingToken.balanceOf.call(shortTx.loanOffering.lender),
        baseToken.balanceOf.call(sellOrder.maker),
        underlyingToken.balanceOf.call(sellOrder.maker),
        feeToken.balanceOf.call(shortTx.seller),
        feeToken.balanceOf.call(sellOrder.maker),
        feeToken.balanceOf.call(sellOrder.feeRecipient),
        feeToken.balanceOf.call(Vault.address),
        baseToken.balanceOf.call(Vault.address),
        underlyingToken.balanceOf.call(Vault.address),
        feeToken.balanceOf.call(Trader.address),
        baseToken.balanceOf.call(Trader.address),
        underlyingToken.balanceOf.call(Trader.address)
      ]);

      expect(
        sellerBaseToken.equals(
          shortTx.depositAmount
            .plus(baseTokenFromSell)
            .minus(baseTokenBuybackCost)
            .minus(interestFee)
        )
      ).to.be.true;
      expect(lenderBaseToken.equals(interestFee)).to.be.true;
      expect(lenderUnderlyingToken.equals(shortTx.loanOffering.rates.maxAmount)).to.be.true;
      expect(externalSellerBaseToken.equals(baseTokenBuybackCost)).to.be.true;
      expect(
        externalSellerUnderlyingToken.equals(
          sellOrder.makerTokenAmount.minus(shortTx.shortAmount)
        )
      ).to.be.true;
      expect(vaultFeeToken.equals(new BigNumber(0))).to.be.true;
      expect(vaultBaseToken.equals(new BigNumber(0))).to.be.true;
      expect(vaultUnderlyingToken.equals(new BigNumber(0))).to.be.true;
      expect(traderFeeToken.equals(new BigNumber(0))).to.be.true;
      expect(traderBaseToken.equals(new BigNumber(0))).to.be.true;
      expect(traderUnderlyingToken.equals(new BigNumber(0))).to.be.true;
      expect(feeRecipientFeeToken.equals(
        getPartialAmount(
          shortTx.shortAmount,
          sellOrder.makerTokenAmount,
          sellOrder.takerFee
        ).plus(
          getPartialAmount(
            shortTx.shortAmount,
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
              shortTx.shortAmount,
              sellOrder.makerTokenAmount,
              sellOrder.takerFee
            )
          )
      )).to.be.true;
      expect(externalSellerFeeToken.equals(
        sellOrder.makerFee
          .minus(
            getPartialAmount(
              shortTx.shortAmount,
              sellOrder.makerTokenAmount,
              sellOrder.makerFee
            )
          )
      )).to.be.true;
    });
  });
});

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

      await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);

      let exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.true;

      const [
        ,
        ,
        ,
        closedAmount,
        ,
        ,
        ,
        ,
        ,
        ,
        ,
      ] = await shortSell.getShort.call(shortTx.id);

      expect(closedAmount.equals(closeAmount)).to.be.true;

      // Simulate time between open and close so interest fee needs to be paid
      await wait(10000);

      // Close the rest of the short
      await callCloseShort(shortSell, shortTx, sellOrder, closeAmount);
      exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      // TODO check balances, rest of stuff
    });
  });
});

describe('#closeEntireShortDirectly', () => {
  contract('ShortSell', function(accounts) {
    it('Successfully closes a short', async () => {
      const shortTx = await doShort(accounts);
      const underlyingToken = await UnderlyingToken.deployed();

      // Give the short seller enough underlying token to close
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

      const shortSell = await ShortSell.deployed();
      await shortSell.closeEntireShortDirectly(shortTx.id);

      const exists = await shortSell.containsShort.call(shortTx.id);
      expect(exists).to.be.false;

      // TODO check balances, rest of stuff
    });
  });
});
