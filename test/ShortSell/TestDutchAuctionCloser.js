/*global web3, artifacts, contract, describe, it, before, beforeEach,*/

const BigNumber = require('bignumber.js');
const chai = require('chai');
const expect = chai.expect;
chai.use(require('chai-bignumber')());

const DutchAuctionCloser = artifacts.require("DutchAuctionCloser");
const ERC721Short = artifacts.require("ERC721Short");
const QuoteToken = artifacts.require("TokenA");
const BaseToken = artifacts.require("TokenB");
const ShortSell = artifacts.require("ShortSell");
const ProxyContract = artifacts.require("Proxy");
const Vault = artifacts.require("Vault");

const { getOwedAmount } = require('../helpers/CloseShortHelper');
const { getMaxInterestFee, callCloseShortDirectly } = require('../helpers/ShortSellHelper');
const { expectThrow } = require('../helpers/ExpectHelper');
const {
  doShort
} = require('../helpers/ShortSellHelper');
const { wait } = require('@digix/tempo')(web3);

const ONE = new BigNumber(1);
const TWO = new BigNumber(2);

contract('DutchAuctionCloser', function(accounts) {
  let shortSellContract, VaultContract, ERC721ShortContract;
  let BaseTokenContract, QuoteTokenContract;
  let shortTx;
  const dutchBidder = accounts[9];

  before('retrieve deployed contracts', async () => {
    [
      shortSellContract,
      VaultContract,
      ERC721ShortContract,
      BaseTokenContract,
      QuoteTokenContract,
    ] = await Promise.all([
      ShortSell.deployed(),
      Vault.deployed(),
      ERC721Short.deployed(),
      BaseToken.deployed(),
      QuoteToken.deployed(),
    ]);
  });

  describe('Constructor', () => {
    it('sets constants correctly', async () => {
      const contract = await DutchAuctionCloser.new(ShortSell.address, ONE, TWO);
      const [ssAddress, num, den] = await Promise.all([
        contract.SHORT_SELL.call(),
        contract.CALL_TIMELIMIT_NUMERATOR.call(),
        contract.CALL_TIMELIMIT_DENOMINATOR.call(),
      ]);
      expect(ssAddress).to.equal(ShortSell.address);
      expect(num).to.be.bignumber.equal(ONE);
      expect(den).to.be.bignumber.equal(TWO);
    });
  });

  describe('#closeShortDirectly', () => {
    let salt = 1111;
    let callTimeLimit;

    beforeEach('approve DutchAuctionCloser for token transfers from bidder', async () => {
      shortTx = await doShort(accounts, salt++, ERC721Short.address);
      await ERC721ShortContract.approveRecipient(DutchAuctionCloser.address, true);
      await shortSellContract.callInLoan(
        shortTx.id,
        0, /*requiredDeposit*/
        { from: shortTx.loanOffering.payer }
      );
      callTimeLimit = shortTx.loanOffering.callTimeLimit;

      // grant tokens and set permissions for bidder
      const numTokens = await BaseTokenContract.balanceOf(dutchBidder);
      const maxInterest = await getMaxInterestFee(shortTx);
      const targetTokens = shortTx.shortAmount.plus(maxInterest);

      if (numTokens < targetTokens) {
        await BaseTokenContract.issueTo(dutchBidder, targetTokens.minus(numTokens));
        await BaseTokenContract.approve(
          ProxyContract.address,
          targetTokens,
          { from: dutchBidder });
      }
    });

    it('fails for unapproved short', async () => {
      // dont approve dutch auction closer
      await ERC721ShortContract.approveRecipient(DutchAuctionCloser.address, false);

      await wait(callTimeLimit * 3 / 4);

      await expectThrow( callCloseShortDirectly(
        shortSellContract,
        shortTx,
        shortTx.shortAmount.div(2),
        dutchBidder,
        DutchAuctionCloser.address
      ));
    });

    it('fails if bid too early', async () => {
      await wait(callTimeLimit / 4);

      await expectThrow( callCloseShortDirectly(
        shortSellContract,
        shortTx,
        shortTx.shortAmount.div(2),
        dutchBidder,
        DutchAuctionCloser.address
      ));
    });

    it('fails if bid too late', async () => {
      await wait(callTimeLimit + 1);

      await expectThrow( callCloseShortDirectly(
        shortSellContract,
        shortTx,
        shortTx.shortAmount.div(2),
        dutchBidder,
        DutchAuctionCloser.address
      ));
    });

    it('succeeds for full short', async () => {
      await wait(callTimeLimit * 3 / 4);

      const startingBidderBaseToken = await BaseTokenContract.balanceOf(dutchBidder);
      const quoteVault = await VaultContract.balances.call(shortTx.id, QuoteToken.address);
      const closeAmount = shortTx.shortAmount.div(2);

      // closing half is fine
      const closeTx1 = await callCloseShortDirectly(
        shortSellContract,
        shortTx,
        closeAmount,
        dutchBidder,
        DutchAuctionCloser.address
      );
      const owedAmount1 = await getOwedAmount(shortTx, closeTx1, closeAmount);

      // closing the other half is fine
      const closeTx2 = await callCloseShortDirectly(
        shortSellContract,
        shortTx,
        closeAmount,
        dutchBidder,
        DutchAuctionCloser.address
      );
      const owedAmount2 = await getOwedAmount(shortTx, closeTx2, closeAmount);

      // cannot close half a third time
      await expectThrow( callCloseShortDirectly(
        shortSellContract,
        shortTx,
        closeAmount,
        dutchBidder,
        DutchAuctionCloser.address
      ));

      const [
        baseBidder,
        quoteSeller,
        quoteBidder
      ] = await Promise.all([
        BaseTokenContract.balanceOf.call(dutchBidder),
        QuoteTokenContract.balanceOf.call(shortTx.seller),
        QuoteTokenContract.balanceOf.call(dutchBidder),
      ]);

      // check amounts
      expect(baseBidder).to.be.bignumber.equal(
        startingBidderBaseToken
          .minus(owedAmount1)
          .minus(owedAmount2)
      );
      expect(quoteSeller.plus(quoteBidder)).to.be.bignumber.equal(quoteVault);
    });
  });
});
