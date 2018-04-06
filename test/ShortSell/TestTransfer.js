/*global artifacts, contract, describe, before, it*/

const expect = require('chai').expect;

const TokenA = artifacts.require("TokenA");
const ShortSell = artifacts.require("ShortSell");
const TestCloseShortDelegator = artifacts.require("TestCloseShortDelegator");
const TestShortOwner = artifacts.require("TestShortOwner");
const TestCallLoanDelegator = artifacts.require("TestCallLoanDelegator");
const TestLoanOwner = artifacts.require("TestLoanOwner");
const {
  doShort,
  getShort
} = require('../helpers/ShortSellHelper');
const { expectThrow } = require('../helpers/ExpectHelper');
const { ADDRESSES, BYTES32 } = require('../helpers/Constants');

describe('#transferShort', () => {
  contract('ShortSell', function(accounts) {
    const toAddress = accounts[6];
    let shortSell, shortTx;

    before('set up a short', async () => {
      shortSell = await ShortSell.deployed();
      shortTx = await doShort(accounts);
      expect(shortTx.seller).to.not.equal(toAddress);
    });

    it('only allows short seller to transfer', async () => {
      await expectThrow( () => shortSell.transferShort(
        shortTx.id,
        toAddress,
        { from: toAddress }
      ));
      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(shortTx.seller.toLowerCase());
    });

    it('fails if transferring to self', async () => {
      await expectThrow(() => shortSell.transferShort(
        shortTx.id,
        shortTx.seller,
        { from: shortTx.seller }
      ));
    });

    it('transfers ownership of a short', async () => {
      const tx = await shortSell.transferShort(
        shortTx.id,
        toAddress,
        { from: shortTx.seller }
      );
      console.log('\tShortSell.transferShort gas used: ' + tx.receipt.gasUsed);

      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(toAddress.toLowerCase());
    });

    it('fails if already transferred', async () => {
      await expectThrow( () => shortSell.transferShort(
        shortTx.id,
        toAddress,
        { from: shortTx.seller }
      ));
    });

    it('fails for invalid id', async () => {
      await expectThrow( () => shortSell.transferShort(
        BYTES32.BAD_ID,
        toAddress,
        { from: shortTx.seller }
      ));
      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(toAddress.toLowerCase());
    });
  });

  contract('ShortSell', function(accounts) {
    it('successfully transfers to a contract with the correct interface', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testCloseShortDelegator = await TestCloseShortDelegator.new(
        shortSell.address,
        ADDRESSES.ZERO,
        false);

      const tx = await shortSell.transferShort(shortTx.id,
        testCloseShortDelegator.address,
        { from: shortTx.seller });
      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(testCloseShortDelegator.address.toLowerCase());
      console.log('\tShortSell.transferShort gas used (to contract): ' + tx.receipt.gasUsed);
    });
  });

  contract('ShortSell', function(accounts) {
    it('successfully transfers to a contract that chains to another contract', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testCloseShortDelegator = await TestCloseShortDelegator.new(
        shortSell.address,
        ADDRESSES.ZERO,
        false);
      const testShortOwner = await TestShortOwner.new(
        ShortSell.address,
        testCloseShortDelegator.address);

      const tx = await shortSell.transferShort(shortTx.id,
        testShortOwner.address,
        { from: shortTx.seller });
      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(testCloseShortDelegator.address.toLowerCase());
      console.log('\tShortSell.transferShort gas used (chains thru): ' + tx.receipt.gasUsed);
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to a contract that transfers to 0x0', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testShortOwner = await TestShortOwner.new(
        ShortSell.address,
        ADDRESSES.ZERO);

      await expectThrow(() =>
        shortSell.transferShort(shortTx.id,
          testShortOwner.address,
          { from: shortTx.seller })
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to a contract that transfers back to original owner', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testShortOwner = await TestShortOwner.new(
        ShortSell.address,
        shortTx.seller);

      await expectThrow(() =>
        shortSell.transferShort(shortTx.id,
          testShortOwner.address,
          { from: shortTx.seller })
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to an arbitrary contract', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      await expectThrow(() =>
        shortSell.transferShort(shortTx.id, TokenA.address, { from: shortTx.seller }));
      const { seller } = await getShort(shortSell, shortTx.id);
      expect(seller.toLowerCase()).to.eq(shortTx.seller.toLowerCase());
    });
  });
});

describe('#transferLoan', () => {
  contract('ShortSell', function(accounts) {
    const toAddress = accounts[6];
    let shortSell, shortTx;

    before('set up a short', async () => {
      shortSell = await ShortSell.deployed();
      shortTx = await doShort(accounts);
      expect(shortTx.loanOffering.lender).to.not.equal(toAddress);
    });

    it('only allows short lender to transfer', async () => {
      await expectThrow( () => shortSell.transferLoan(
        shortTx.id,
        toAddress,
        { from: toAddress }
      ));

      const { lender } = await getShort(shortSell, shortTx.id);

      expect(lender.toLowerCase()).to.eq(shortTx.loanOffering.lender.toLowerCase());
    });

    it('fails if transferring to self', async () => {
      await expectThrow( () => shortSell.transferLoan(
        shortTx.id,
        shortTx.loanOffering.lender,
        { from: shortTx.loanOffering.lender }
      ));
    });

    it('transfers ownership of a loan', async () => {
      const tx = await shortSell.transferLoan(
        shortTx.id,
        toAddress,
        { from: shortTx.loanOffering.lender }
      );
      console.log('\tShortSell.transferLoan gas used: ' + tx.receipt.gasUsed);

      const { lender } = await getShort(shortSell, shortTx.id);
      expect(lender.toLowerCase()).to.eq(toAddress.toLowerCase());
    });

    it('fails if already transferred', async () => {
      await expectThrow( () => shortSell.transferLoan(
        shortTx.id,
        toAddress,
        { from: shortTx.loanOffering.lender }
      ));
    });

    it('fails for invalid id', async () => {
      await expectThrow( () => shortSell.transferLoan(
        BYTES32.BAD_ID,
        toAddress,
        { from: shortTx.loanOffering.lender }
      ));

      const { lender } = await getShort(shortSell, shortTx.id);
      expect(lender.toLowerCase()).to.eq(toAddress.toLowerCase());
    });
  });

  contract('ShortSell', function(accounts) {
    it('successfully transfers to a contract with the correct interface', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testCallLoanDelegator = await TestCallLoanDelegator.new(
        shortSell.address,
        ADDRESSES.ZERO,
        ADDRESSES.ZERO);

      const tx = await shortSell.transferLoan(shortTx.id,
        testCallLoanDelegator.address,
        { from: shortTx.loanOffering.lender });
      const { lender } = await getShort(shortSell, shortTx.id);
      expect(lender.toLowerCase()).to.eq(testCallLoanDelegator.address.toLowerCase());
      console.log('\tShortSell.transferLoan gas used (to contract): ' + tx.receipt.gasUsed);
    });
  });

  contract('ShortSell', function(accounts) {
    it('successfully transfers to a contract that chains to another contract', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testCallLoanDelegator = await TestCallLoanDelegator.new(
        shortSell.address,
        ADDRESSES.ZERO,
        ADDRESSES.ZERO);
      const testLoanOwner = await TestLoanOwner.new(
        shortSell.address,
        testCallLoanDelegator.address);

      const tx = await shortSell.transferLoan(shortTx.id,
        testLoanOwner.address,
        { from: shortTx.loanOffering.lender });
      const { lender } = await getShort(shortSell, shortTx.id);
      expect(lender.toLowerCase()).to.eq(testCallLoanDelegator.address.toLowerCase());
      console.log('\tShortSell.transferLoan gas used (chain thru): ' + tx.receipt.gasUsed);
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to a contract that transfers to 0x0', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testLoanOwner = await TestLoanOwner.new(
        shortSell.address,
        ADDRESSES.ZERO);

      await expectThrow(() =>
        shortSell.transferLoan(shortTx.id,
          testLoanOwner.address,
          { from: shortTx.loanOffering.lender })
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to a contract that transfers back to original owner', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      const testLoanOwner = await TestLoanOwner.new(
        shortSell.address,
        shortTx.loanOffering.lender);

      await expectThrow(() =>
        shortSell.transferLoan(shortTx.id,
          testLoanOwner.address,
          { from: shortTx.loanOffering.lender })
      );
    });
  });

  contract('ShortSell', function(accounts) {
    it('fails to transfer to an arbitrary contract', async () => {
      const shortSell = await ShortSell.deployed();
      const shortTx = await doShort(accounts);
      await expectThrow(() =>
        shortSell.transferLoan(shortTx.id, TokenA.address, { from: shortTx.loanOffering.lender }));
      const { lender } = await getShort(shortSell, shortTx.id);
      expect(lender.toLowerCase()).to.eq(shortTx.loanOffering.lender.toLowerCase());
    });
  });
});
