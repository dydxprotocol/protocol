pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { Math } from "zeppelin-solidity/contracts/math/Math.sol";
import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { InterestImpl } from "./InterestImpl.sol";
import { MarginState } from "./MarginState.sol";
import { MathHelpers } from "../../lib/MathHelpers.sol";


/**
 * @title MarginCommon
 * @author dYdX
 *
 * This library contains common functions for implementations of public facing Margin functions
 */
library MarginCommon {
    using SafeMath for uint256;

    // ============ Structs ============

    struct Position {
        address baseToken;       // Immutable
        address quoteToken;      // Immutable
        address lender;
        address owner;
        uint256 principal;
        uint256 requiredDeposit;
        uint32  callTimeLimit;   // Immutable
        uint32  startTimestamp;  // Immutable, cannot be 0
        uint32  callTimestamp;
        uint32  maxDuration;     // Immutable
        uint32  interestRate;    // Immutable
        uint32  interestPeriod;  // Immutable
    }

    struct LoanOffering {
        address   payer;
        address   signer;
        address   owner;
        address   taker;
        address   feeRecipient;
        address   lenderFeeToken;
        address   takerFeeToken;
        LoanRates rates;
        uint256   expirationTimestamp;
        uint32    callTimeLimit;
        uint32    maxDuration;
        uint256   salt;
        bytes32   loanHash;
        Signature signature;
    }

    struct LoanRates {
        uint256 maxAmount;
        uint256 minAmount;
        uint256 minQuoteToken;
        uint256 lenderFee;
        uint256 takerFee;
        uint32  interestRate;
        uint32  interestPeriod;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // ============ Internal Implementation Functions ============

    function getUnavailableLoanOfferingAmountImpl(
        MarginState.State storage state,
        bytes32 loanHash
    )
        internal
        view
        returns (uint256)
    {
        return state.loanFills[loanHash].add(state.loanCancels[loanHash]);
    }

    function cleanupPosition(
        MarginState.State storage state,
        bytes32 positionId
    )
        internal
    {
        delete state.positions[positionId];
        state.closedPositions[positionId] = true;
    }

    function calculateOwedAmount(
        Position memory position,
        uint256 closeAmount,
        uint256 endTimestamp
    )
        internal
        pure
        returns (uint256)
    {
        uint256 timeElapsed = calculateEffectiveTimeElapsed(position, endTimestamp);

        return InterestImpl.getCompoundedInterest(
            closeAmount,
            position.interestRate,
            timeElapsed
        );
    }

    /**
     * Calculates time elapsed rounded up to the nearest interestPeriod
     */
    function calculateEffectiveTimeElapsed(
        Position memory position,
        uint256 timestamp
    )
        internal
        pure
        returns (uint256)
    {
        uint256 elapsed = timestamp.sub(position.startTimestamp);

        // round up to interestPeriod
        uint256 period = position.interestPeriod;
        if (period > 1) {
            elapsed = MathHelpers.divisionRoundedUp(elapsed, period).mul(period);
        }

        // bound by maxDuration
        return Math.min256(
            elapsed,
            position.maxDuration
        );
    }

    function calculateLenderAmountForAddValue(
        Position memory position,
        uint256 addAmount,
        uint256 endTimestamp
    )
        internal
        pure
        returns (uint256)
    {
        uint256 timeElapsed = calculateEffectiveTimeElapsedForNewLender(position, endTimestamp);

        return InterestImpl.getCompoundedInterest(
            addAmount,
            position.interestRate,
            timeElapsed
        );
    }

    /**
     * Calculates time elapsed rounded down to the nearest interestPeriod
     */
    function calculateEffectiveTimeElapsedForNewLender(
        Position memory position,
        uint256 timestamp
    )
        internal
        pure
        returns (uint256)
    {
        uint256 elapsed = timestamp.sub(position.startTimestamp);

        // round down to interestPeriod
        uint256 period = position.interestPeriod;
        if (period > 1) {
            elapsed = elapsed.div(period).mul(period);
        }

        // bound by maxDuration
        return Math.min256(
            elapsed,
            position.maxDuration
        );
    }

    function getLoanOfferingHash(
        LoanOffering loanOffering,
        address quoteToken,
        address baseToken
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            address(this),
            baseToken,
            quoteToken,
            loanOffering.payer,
            loanOffering.signer,
            loanOffering.owner,
            loanOffering.taker,
            loanOffering.feeRecipient,
            loanOffering.lenderFeeToken,
            loanOffering.takerFeeToken,
            getValuesHash(loanOffering)
        );
    }

    function getValuesHash(
        LoanOffering loanOffering
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            loanOffering.rates.maxAmount,
            loanOffering.rates.minAmount,
            loanOffering.rates.minQuoteToken,
            loanOffering.rates.lenderFee,
            loanOffering.rates.takerFee,
            loanOffering.expirationTimestamp,
            loanOffering.salt,
            loanOffering.callTimeLimit,
            loanOffering.maxDuration,
            loanOffering.rates.interestRate,
            loanOffering.rates.interestPeriod
        );
    }

    function containsPositionImpl(
        MarginState.State storage state,
        bytes32 positionId
    )
        internal
        view
        returns (bool)
    {
        return state.positions[positionId].startTimestamp != 0;
    }

    function getPositionObject(
        MarginState.State storage state,
        bytes32 positionId
    )
        internal
        view
        returns (Position storage)
    {
        Position storage position = state.positions[positionId];

        // This checks that the position exists
        require(position.startTimestamp != 0);

        return position;
    }
}
