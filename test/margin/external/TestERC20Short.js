/*global artifacts, web3, contract, describe, it, before, beforeEach*/

const chai = require('chai');
const expect = chai.expect;
chai.use(require('chai-bignumber')());

const Margin = artifacts.require("Margin");
const ERC20Short = artifacts.require("ERC20Short");
const OwedToken = artifacts.require("TokenB");
const { ADDRESSES } = require('../../helpers/Constants');
const {
  callClosePosition,
  callClosePositionDirectly,
  doOpenPosition,
  getPosition,
  issueTokensAndSetAllowancesForClose,
  issueTokenToAccountInAmountAndApproveProxy,
  getMaxInterestFee
} = require('../../helpers/MarginHelper');
const {
  createSignedSellOrder
} = require('../../helpers/0xHelper');
const { transact } = require('../../helpers/ContractHelper');
const { expectThrow } = require('../../helpers/ExpectHelper');
const {
  getERC20ShortConstants,
  TOKENIZED_POSITION_STATE
} = require('./ERC20ShortHelper');
const { wait } = require('@digix/tempo')(web3);
const BigNumber = require('bignumber.js');

contract('ERC20Short', function(accounts) {
  let owedToken;

  let POSITIONS = {
    FULL: {
      TOKEN_CONTRACT: null,
      TX: null,
      ID: null,
      SELL_ORDER: null,
      NUM_TOKENS: 0,
      SALT: 0
    },
    PART: {
      TOKEN_CONTRACT: null,
      TX: null,
      ID: null,
      SELL_ORDER: null,
      NUM_TOKENS: 0,
      SALT: 0
    }
  };

  let CONTRACTS = {
    DYDX_MARGIN: null,
  }
  let pepper = 0;
  const INITIAL_TOKEN_HOLDER = accounts[9];

  before('Set up Proxy, Margin accounts', async () => {
    [
      CONTRACTS.DYDX_MARGIN,
      owedToken
    ] = await Promise.all([
      Margin.deployed(),
      OwedToken.deployed()
    ]);
  });

  async function setUpPositions() {
    pepper++;

    POSITIONS.FULL.SALT = 222 + pepper;
    POSITIONS.PART.SALT = 333 + pepper;

    POSITIONS.FULL.TX = await doOpenPosition(accounts.slice(1), POSITIONS.FULL.SALT);
    POSITIONS.PART.TX = await doOpenPosition(accounts.slice(2), POSITIONS.PART.SALT);

    expect(POSITIONS.FULL.TX.trader).to.be.not.equal(POSITIONS.PART.TX.trader);

    POSITIONS.FULL.ID = POSITIONS.FULL.TX.id;
    POSITIONS.PART.ID = POSITIONS.PART.TX.id;

    POSITIONS.PART.SELL_ORDER = await createSignedSellOrder(accounts, POSITIONS.PART.SALT);
    await issueTokensAndSetAllowancesForClose(POSITIONS.PART.TX, POSITIONS.PART.SELL_ORDER);
    await callClosePosition(
      CONTRACTS.DYDX_MARGIN,
      POSITIONS.PART.TX,
      POSITIONS.PART.SELL_ORDER,
      POSITIONS.PART.TX.principal.div(2));

    POSITIONS.FULL.NUM_TOKENS = POSITIONS.FULL.TX.principal;
    POSITIONS.PART.NUM_TOKENS = POSITIONS.PART.TX.principal.div(2);
  }

  async function setUpTokens() {
    POSITIONS.FULL.TRUSTED_RECIPIENTS = [ADDRESSES.TEST[1], ADDRESSES.TEST[2]];
    POSITIONS.PART.TRUSTED_RECIPIENTS = [ADDRESSES.TEST[3], ADDRESSES.TEST[4]];
    [
      POSITIONS.FULL.TOKEN_CONTRACT,
      POSITIONS.PART.TOKEN_CONTRACT
    ] = await Promise.all([
      ERC20Short.new(
        POSITIONS.FULL.ID,
        CONTRACTS.DYDX_MARGIN.address,
        INITIAL_TOKEN_HOLDER,
        POSITIONS.FULL.TRUSTED_RECIPIENTS),
      ERC20Short.new(
        POSITIONS.PART.ID,
        CONTRACTS.DYDX_MARGIN.address,
        INITIAL_TOKEN_HOLDER,
        POSITIONS.PART.TRUSTED_RECIPIENTS)
    ]);
  }

  async function transferPositionsToTokens() {
    await Promise.all([
      CONTRACTS.DYDX_MARGIN.transferPosition(
        POSITIONS.FULL.ID,
        POSITIONS.FULL.TOKEN_CONTRACT.address,
        { from: POSITIONS.FULL.TX.trader }
      ),
      CONTRACTS.DYDX_MARGIN.transferPosition(
        POSITIONS.PART.ID,
        POSITIONS.PART.TOKEN_CONTRACT.address,
        { from: POSITIONS.PART.TX.trader }
      ),
    ]);
  }

  async function returnTokenstoTrader() {
    await Promise.all([
      POSITIONS.FULL.TOKEN_CONTRACT.transfer(POSITIONS.FULL.TX.trader, POSITIONS.FULL.NUM_TOKENS,
        { from: INITIAL_TOKEN_HOLDER }),
      POSITIONS.PART.TOKEN_CONTRACT.transfer(POSITIONS.PART.TX.trader, POSITIONS.PART.NUM_TOKENS,
        { from: INITIAL_TOKEN_HOLDER })
    ]);
  }

  async function grantDirectCloseTokensToTrader(act = null) {
    const maxInterestFull = await getMaxInterestFee(POSITIONS.FULL.TX);
    const maxInterestPart = await getMaxInterestFee(POSITIONS.PART.TX);
    await issueTokenToAccountInAmountAndApproveProxy(
      owedToken,
      act ? act : POSITIONS.FULL.TX.trader,
      POSITIONS.FULL.NUM_TOKENS.plus(maxInterestFull));
    await issueTokenToAccountInAmountAndApproveProxy(
      owedToken,
      act ? act : POSITIONS.PART.TX.trader,
      POSITIONS.PART.NUM_TOKENS.plus(maxInterestPart));
  }

  async function marginCallPositions() {
    const requiredDeposit = new BigNumber(10);
    await Promise.all([
      CONTRACTS.DYDX_MARGIN.marginCall(
        POSITIONS.FULL.ID,
        requiredDeposit,
        { from : POSITIONS.FULL.TX.loanOffering.payer }
      ),
      CONTRACTS.DYDX_MARGIN.marginCall(
        POSITIONS.PART.ID,
        requiredDeposit,
        { from : POSITIONS.PART.TX.loanOffering.payer }
      ),
    ]);
  }

  describe('Constructor', () => {
    before('set up positions and tokens', async () => {
      await setUpPositions();
      await setUpTokens();
    });

    it('sets constants correctly', async () => {
      for (let type in POSITIONS) {
        const position = POSITIONS[type];
        const tsc = await getERC20ShortConstants(position.TOKEN_CONTRACT);
        expect(tsc.DYDX_MARGIN).to.equal(CONTRACTS.DYDX_MARGIN.address);
        expect(tsc.POSITION_ID).to.equal(position.ID);
        expect(tsc.state).to.be.bignumber.equal(TOKENIZED_POSITION_STATE.UNINITIALIZED);
        expect(tsc.INITIAL_TOKEN_HOLDER).to.equal(INITIAL_TOKEN_HOLDER);
        expect(tsc.heldToken).to.equal(ADDRESSES.ZERO);
        expect(tsc.symbol).to.equal("d/S");
        expect(tsc.name).to.equal("dYdX Short Token [UNINITIALIZED]");
        for (let i in position.TRUSTED_RECIPIENTS) {
          const recipient = position.TRUSTED_RECIPIENTS[i];
          const isIn = await position.TOKEN_CONTRACT.TRUSTED_RECIPIENTS.call(recipient);
          expect(isIn).to.be.true;
        }
        const hasZero = await position.TOKEN_CONTRACT.TRUSTED_RECIPIENTS.call(ADDRESSES.ZERO);
        expect(hasZero).to.be.false;
      }
    });
  });

  describe('#receivePositionOwnership', () => {
    beforeEach('set up new positions and tokens', async () => {
      // Create new positions since state is modified by transferring them
      await setUpPositions();
      await setUpTokens();
    });

    it('succeeds for FULL and PART positions', async () => {
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];

        const tsc1 = await getERC20ShortConstants(POSITION.TOKEN_CONTRACT);

        await CONTRACTS.DYDX_MARGIN.transferPosition(POSITION.ID, POSITION.TOKEN_CONTRACT.address,
          { from: POSITION.TX.trader });

        const [tsc2, position] = await Promise.all([
          getERC20ShortConstants(POSITION.TOKEN_CONTRACT),
          getPosition(CONTRACTS.DYDX_MARGIN, POSITION.ID)
        ]);

        // expect certain values
        expect(tsc2.DYDX_MARGIN).to.equal(CONTRACTS.DYDX_MARGIN.address);
        expect(tsc2.POSITION_ID).to.equal(POSITION.ID);
        expect(tsc2.state).to.be.bignumber.equal(TOKENIZED_POSITION_STATE.OPEN);
        expect(tsc2.INITIAL_TOKEN_HOLDER).to.equal(INITIAL_TOKEN_HOLDER);
        expect(tsc2.heldToken).to.equal(position.heldToken);

        // explicity make sure some things have changed
        expect(tsc2.state.equals(tsc1.state)).to.be.false;
        expect(tsc2.heldToken).to.not.equal(tsc1.heldToken);

        // explicity make sure some things have not changed
        expect(tsc2.POSITION_ID).to.equal(tsc1.POSITION_ID);
        expect(tsc2.DYDX_MARGIN).to.equal(tsc1.DYDX_MARGIN);
        expect(tsc2.INITIAL_TOKEN_HOLDER).to.equal(tsc1.INITIAL_TOKEN_HOLDER);
      }
    });

    it('fails for msg.sender != Margin', async () => {
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await expectThrow(
          POSITION.TOKEN_CONTRACT.receivePositionOwnership(
            INITIAL_TOKEN_HOLDER,
            POSITION.ID,
            { from: INITIAL_TOKEN_HOLDER }
          )
        );
      }
    });
  });

  describe('#closeOnBehalfOf', () => {
    it('fails if not authorized', async () => {
      await setUpPositions();
      await setUpTokens();
      await transferPositionsToTokens();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const trader = POSITION.TX.trader;
        const amount = POSITION.TX.principal;
        await expectThrow(
          POSITION.TOKEN_CONTRACT.closeOnBehalfOf(
            trader, trader, POSITION.ID, amount.div(2))
        );
      }
    });
  });

  describe('#closeOnBehalfOf via #closePositiondirectly', () => {
    beforeEach('set up positions and tokens', async () => {
      await setUpPositions();
      await setUpTokens();
    });

    it('fails if not transferred', async () => {
      // give owedTokens to token holder
      issueTokenToAccountInAmountAndApproveProxy(
        owedToken,
        INITIAL_TOKEN_HOLDER,
        POSITIONS.FULL.NUM_TOKENS + POSITIONS.PART.NUM_TOKENS);

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await expectThrow(
          callClosePositionDirectly(
            CONTRACTS.DYDX_MARGIN,
            POSITION.TX,
            POSITION.NUM_TOKENS,
            { from: INITIAL_TOKEN_HOLDER })
        );
      }
    });

    it('fails if user does not have the amount of owedToken required', async () => {
      await transferPositionsToTokens();
      await Promise.all([
        POSITIONS.FULL.TOKEN_CONTRACT.transfer(accounts[0], POSITIONS.FULL.NUM_TOKENS,
          { from: INITIAL_TOKEN_HOLDER }),
        POSITIONS.PART.TOKEN_CONTRACT.transfer(accounts[0], POSITIONS.PART.NUM_TOKENS,
          { from: INITIAL_TOKEN_HOLDER })
      ]);

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await expectThrow(
          callClosePositionDirectly(
            CONTRACTS.DYDX_MARGIN,
            POSITION.TX,
            POSITION.NUM_TOKENS,
            { from: POSITION.TX.trader }
          )
        );
      }
    });

    it('fails if value is zero', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await expectThrow(
          callClosePositionDirectly(
            CONTRACTS.DYDX_MARGIN,
            POSITION.TX,
            0,
            { from: POSITION.TX.trader }
          )
        );
      }
    });

    it('closes up to the remainingAmount if user tries to close more', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS + 1,
          { from: POSITION.TX.trader }
        );
      }
    });

    it('closes at most the number of tokens owned', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader();

      const rando = accounts[9];

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];

        // give away half of the tokens
        await POSITION.TOKEN_CONTRACT.transfer(rando, POSITION.NUM_TOKENS.div(2),
          { from: POSITION.TX.trader });

        // try to close with too-large amount, but it will get bounded by the number of tokens owned
        const tx = await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS.times(10)
        );
        expect(tx.result[0] /* amountClosed */).to.be.bignumber.equal(POSITION.NUM_TOKENS.div(2));
      }
    });

    it('fails if user does not own any of the tokenized position', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader(accounts[0]);

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await expectThrow(
          callClosePositionDirectly(
            CONTRACTS.DYDX_MARGIN,
            POSITION.TX,
            POSITION.NUM_TOKENS,
            { from: accounts[0] }
          )
        );
      }
    });

    it('fails if closed', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        // do it once to close it
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS,
          { from: POSITION.TX.trader }
        );

        // try again
        await expectThrow(
          callClosePositionDirectly(
            CONTRACTS.DYDX_MARGIN,
            POSITION.TX,
            POSITION.NUM_TOKENS,
            { from: POSITION.TX.trader }
          )
        );
      }
    });

    it('succeeds otherwise', async () => {
      await transferPositionsToTokens();
      await returnTokenstoTrader();
      await grantDirectCloseTokensToTrader();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS
        );
      }
    });
  });

  describe('#withdraw', () => {
    beforeEach('Set up all tokenized positions, then margin-call, waiting for calltimelimit',
      async () => {
        await setUpPositions();
        await setUpTokens();
        await transferPositionsToTokens();
        await returnTokenstoTrader();
        await marginCallPositions();
        await wait(POSITIONS.FULL.TX.loanOffering.callTimeLimit);
      }
    );

    it('returns 0 when caller never had any tokens', async () => {
      // close half, force recover, then some random person can't withdraw any funds
      await grantDirectCloseTokensToTrader();
      const rando = accounts[9];
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const lender = POSITION.TX.loanOffering.payer;
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS.div(2)
        );
        await CONTRACTS.DYDX_MARGIN.forceRecoverCollateral(POSITION.ID, lender, { from: lender });
        const tx = await transact(POSITION.TOKEN_CONTRACT.withdraw, rando, { from: rando });

        expect(tx.result).to.be.bignumber.eq(0);
      }
    });

    it('returns 0 when position is completely closed', async () => {
      // close the position completely and then try to withdraw
      await grantDirectCloseTokensToTrader();
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const trader = POSITION.TX.trader;
        const lender = POSITION.TX.loanOffering.payer;
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS
        );
        await expectThrow(
          CONTRACTS.DYDX_MARGIN.forceRecoverCollateral(POSITION.ID, lender, { from: lender })
        );
        const tx = await transact(POSITION.TOKEN_CONTRACT.withdraw, trader, { from: trader });

        expect(tx.result).to.be.bignumber.eq(0);
      }
    });

    it('fails when position is still open', async () => {
      // close position halfway and then try to withdraw
      await grantDirectCloseTokensToTrader();
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const trader = POSITION.TX.trader;
        await callClosePositionDirectly(
          CONTRACTS.DYDX_MARGIN,
          POSITION.TX,
          POSITION.NUM_TOKENS.div(2)
        );
        await expectThrow(POSITION.TOKEN_CONTRACT.withdraw(trader, { from: trader }));
      }
    });

    it('withdraws no tokens after forceRecoverCollateral', async () => {
      // close nothing, letting the lender forceRecoverCollateral
      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const trader = POSITION.TX.trader;
        const lender = POSITION.TX.loanOffering.payer;

        await CONTRACTS.DYDX_MARGIN.forceRecoverCollateral(POSITION.ID, lender, { from: lender });

        const tx = await transact(POSITION.TOKEN_CONTRACT.withdraw, trader, { from: trader });
        expect(tx.result).to.be.bignumber.equal(0);
      }
    });
  });

  describe('#decimals', () => {
    it('returns decimal value of owedToken', async () => {
      await setUpPositions();
      await setUpTokens();
      await transferPositionsToTokens();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const [decimal, expectedDecimal] = await Promise.all([
          POSITION.TOKEN_CONTRACT.decimals.call(),
          owedToken.decimals.call()
        ]);
        expect(decimal).to.be.bignumber.equal(expectedDecimal);
      }
    });

    it('returns decimal value of owedToken, even if not initialized', async () => {
      await setUpPositions();
      const tokenContract = await ERC20Short.new(
        POSITIONS.FULL.ID,
        CONTRACTS.DYDX_MARGIN.address,
        INITIAL_TOKEN_HOLDER,
        []);
      const [decimal, expectedDecimal] = await Promise.all([
        tokenContract.decimals.call(),
        owedToken.decimals.call()
      ]);
      expect(decimal).to.be.bignumber.equal(expectedDecimal);
    });
  });

  describe('#name', () => {
    it('successfully returns the positionId of the position', async () => {
      await setUpPositions();
      await setUpTokens();
      await transferPositionsToTokens();

      for (let type in POSITIONS) {
        const POSITION = POSITIONS[type];
        const [positionId, tokenName] = await Promise.all([
          POSITION.TOKEN_CONTRACT.POSITION_ID.call(),
          POSITION.TOKEN_CONTRACT.name.call()
        ]);
        expect(positionId).to.be.bignumber.equal(POSITION.ID);
        expect(tokenName).to.equal("dYdX Short Token " + POSITION.ID.toString());
      }
    });
  });
});
