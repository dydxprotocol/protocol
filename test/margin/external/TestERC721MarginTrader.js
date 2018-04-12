/*global web3, artifacts, contract, describe, it, before, beforeEach,*/

const Web3 = require('web3');
const BigNumber = require('bignumber.js');
const web3Instance = new Web3(web3.currentProvider);
const chai = require('chai');
const expect = chai.expect;
chai.use(require('chai-bignumber')());

const ERC721MarginTrader = artifacts.require("ERC721MarginTrader");
const Margin = artifacts.require("Margin");
const ProxyContract = artifacts.require("Proxy");
const BaseToken = artifacts.require("TokenB");

const { BYTES32 } = require('../../helpers/Constants');
const { expectThrow } = require('../../helpers/ExpectHelper');
const {
  doOpenPosition,
  issueTokensAndSetAllowancesForClose,
  callClosePosition,
  getMaxInterestFee,
  callClosePositionDirectly
} = require('../../helpers/MarginHelper');
const {
  createSignedSellOrder
} = require('../../helpers/0xHelper');

function uint256(marginId) {
  return new BigNumber(web3Instance.utils.toBN(marginId));
}

contract('ERC721MarginTrader', function(accounts) {
  let marginContract, ERC721MarginTraderContract, baseToken;
  let salt = 1111;

  before('retrieve deployed contracts', async () => {
    [
      marginContract,
      ERC721MarginTraderContract,
      baseToken
    ] = await Promise.all([
      Margin.deployed(),
      ERC721MarginTrader.deployed(),
      BaseToken.deployed()
    ]);
  });

  describe('Constructor', () => {
    it('sets constants correctly', async () => {
      const contract = await ERC721MarginTrader.new(Margin.address);
      const marginContractAddress = await contract.MARGIN.call();
      expect(marginContractAddress).to.equal(Margin.address);
    });
  });

  describe('#receiveOwnershipAsTrader', () => {
    it('fails for arbitrary caller', async () => {
      await expectThrow(
        ERC721MarginTraderContract.receiveOwnershipAsTrader(accounts[0], BYTES32.BAD_ID));
    });

    it('succeeds for new position', async () => {
      const openTx = await doOpenPosition(accounts, salt++, ERC721MarginTrader.address);
      const owner = await ERC721MarginTraderContract.ownerOf.call(uint256(openTx.id));
      expect(owner).to.equal(accounts[0]);
    });

    it('succeeds for half-closed position', async () => {
      const openTx = await doOpenPosition(accounts, salt++);

      // close half the position
      const sellOrder = await createSignedSellOrder(accounts, salt++);
      await issueTokensAndSetAllowancesForClose(openTx, sellOrder);
      await callClosePosition(
        marginContract,
        openTx,
        sellOrder,
        openTx.amount.div(2));

      // transfer position to ERC20MarginTraderCreator
      await marginContract.transferAsTrader(openTx.id, ERC721MarginTraderContract.address);
      const owner = await ERC721MarginTraderContract.ownerOf.call(uint256(openTx.id));
      expect(owner).to.equal(accounts[0]);
    });
  });

  describe('#getPositionDeedHolder', () => {
    it('fails for bad marginId', async () => {
      await expectThrow(
        ERC721MarginTraderContract.getPositionDeedHolder(BYTES32.BAD_ID));
    });

    it('succeeds for owned position', async () => {
      const openTx = await doOpenPosition(accounts, salt++, ERC721MarginTrader.address);
      const deedHolder = await ERC721MarginTraderContract.getPositionDeedHolder.call(openTx.id);
      expect(deedHolder).to.equal(accounts[0]);
    });
  });

  describe('#approveCloser', () => {
    const sender = accounts[6];
    const helper = accounts[7];

    it('succeeds in approving', async () => {
      await ERC721MarginTraderContract.approveCloser(helper, true, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedClosers.call(sender, helper);
      expect(approved).to.be.true;
    });

    it('succeeds in revoking approval', async () => {
      await ERC721MarginTraderContract.approveCloser(helper, true, { from: sender });
      await ERC721MarginTraderContract.approveCloser(helper, false, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedClosers.call(sender, helper);
      expect(approved).to.be.false;
    });

    it('succeeds when true => true', async () => {
      await ERC721MarginTraderContract.approveCloser(helper, true, { from: sender });
      await ERC721MarginTraderContract.approveCloser(helper, true, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedClosers.call(sender, helper);
      expect(approved).to.be.true;
    });

    it('succeeds when false => false', async () => {
      await ERC721MarginTraderContract.approveCloser(helper, true, { from: sender });
      await ERC721MarginTraderContract.approveCloser(helper, false, { from: sender });
      await ERC721MarginTraderContract.approveCloser(helper, false, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedClosers.call(sender, helper);
      expect(approved).to.be.false;
    });

    it('throws when address approves itself', async () => {
      await expectThrow(
        ERC721MarginTraderContract.approveCloser(helper, true, { from: helper }));
    });
  });

  describe('#approveRecipient', () => {
    const sender = accounts[6];
    const recipient = accounts[7];

    it('succeeds in approving', async () => {
      await ERC721MarginTraderContract.approveRecipient(recipient, true, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedRecipients.call(sender, recipient);
      expect(approved).to.be.true;
    });

    it('succeeds in revoking approval', async () => {
      await ERC721MarginTraderContract.approveRecipient(recipient, true, { from: sender });
      await ERC721MarginTraderContract.approveRecipient(recipient, false, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedRecipients.call(sender, recipient);
      expect(approved).to.be.false;
    });

    it('succeeds when true => true', async () => {
      await ERC721MarginTraderContract.approveRecipient(recipient, true, { from: sender });
      await ERC721MarginTraderContract.approveRecipient(recipient, true, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedRecipients.call(sender, recipient);
      expect(approved).to.be.true;
    });

    it('succeeds when false => false', async () => {
      await ERC721MarginTraderContract.approveRecipient(recipient, true, { from: sender });
      await ERC721MarginTraderContract.approveRecipient(recipient, false, { from: sender });
      await ERC721MarginTraderContract.approveRecipient(recipient, false, { from: sender });
      const approved = await ERC721MarginTraderContract.approvedRecipients.call(sender, recipient);
      expect(approved).to.be.false;
    });
  });

  describe('#transferAsTrader', () => {
    const receiver = accounts[9];
    const trader = accounts[0];
    let openTx;

    beforeEach('sets up position', async () => {
      openTx = await doOpenPosition(accounts, salt++, ERC721MarginTrader.address);
      const owner = await ERC721MarginTraderContract.ownerOf.call(uint256(openTx.id));
      expect(owner).to.equal(trader);
    });

    it('succeeds when called by ownerOf', async () => {
      await ERC721MarginTraderContract.transferAsTrader(openTx.id, receiver, { from: trader });
      await expectThrow( ERC721MarginTraderContract.ownerOf.call(uint256(openTx.id)));
      const newOwner = await marginContract.getPositionTrader.call(openTx.id);
      expect(newOwner).to.equal(receiver);
    });

    it('fails for a non-owner', async () => {
      await expectThrow(
        ERC721MarginTraderContract.transferAsTrader(openTx.id, receiver, { from: accounts[2] }));
    });

    it('fails for a non-existent position', async () => {
      await expectThrow(
        ERC721MarginTraderContract.transferAsTrader(BYTES32.BAD_ID, receiver, { from: trader }));
    });
  });

  describe('#closePositionOnBehalfOf', () => {
    let openTx;
    const approvedCloser = accounts[6];
    const approvedRecipient = accounts[7];
    const unapprovedAcct = accounts[9];

    async function initBase(account) {
      const maxInterest = await getMaxInterestFee(openTx);
      const amount = openTx.amount.plus(maxInterest);
      await baseToken.issueTo(account, amount);
      await baseToken.approve(ProxyContract.address, amount, { from: account });
    }

    beforeEach('sets up position', async () => {
      openTx = await doOpenPosition(accounts, salt++, ERC721MarginTrader.address);
      await ERC721MarginTraderContract.approveCloser(
        approvedCloser,
        true,
        { from: openTx.trader }
      );
      await ERC721MarginTraderContract.approveRecipient(
        approvedRecipient,
        true,
        { from: openTx.trader }
      );
    });

    it('succeeds for owner', async () => {
      await initBase(openTx.trader);
      await callClosePositionDirectly(
        marginContract,
        openTx,
        openTx.amount,
        openTx.trader,
        unapprovedAcct
      );
    });

    it('succeeds for approved recipients', async () => {
      await initBase(unapprovedAcct);
      await callClosePositionDirectly(
        marginContract,
        openTx,
        openTx.amount,
        unapprovedAcct,
        approvedRecipient
      );
    });

    it('succeeds for approved closers', async () => {
      await initBase(approvedCloser);
      await callClosePositionDirectly(
        marginContract,
        openTx,
        openTx.amount,
        approvedCloser,
        unapprovedAcct
      );
    });

    it('fails for non-approved recipients/closers', async () => {
      await initBase(unapprovedAcct);
      await expectThrow( callClosePositionDirectly(
        marginContract,
        openTx,
        openTx.amount,
        unapprovedAcct,
        unapprovedAcct
      ));
    });
  });
});