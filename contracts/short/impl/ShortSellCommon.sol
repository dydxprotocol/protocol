pragma solidity 0.4.19;

import { ShortSellState } from "./ShortSellState.sol";
import { Vault } from "../Vault.sol";
import { ShortSellRepo } from "../ShortSellRepo.sol";
import { ShortSellAuctionRepo } from "../ShortSellAuctionRepo.sol";
import { SafeMathLib } from "../../lib/SafeMathLib.sol";


/**
 * @title ShortSellCommon
 * @author Antonio Juliano
 *
 * This library contains common functions for implementations of public facing ShortSell functions
 */
library ShortSellCommon {

    // -----------------------
    // ------- Structs -------
    // -----------------------

    struct Short {
        address underlyingToken;
        address baseToken;
        uint shortAmount;
        uint closedAmount;
        uint interestRate;
        uint32 callTimeLimit;
        uint32 lockoutTime;
        uint32 startTimestamp;
        uint32 callTimestamp;
        uint32 maxDuration;
        address lender;
        address seller;
    }

    struct LoanOffering {
        address lender;
        address taker;
        address feeRecipient;
        address lenderFeeToken;
        address takerFeeToken;
        LoanRates rates;
        uint expirationTimestamp;
        uint32 lockoutTime;
        uint32 callTimeLimit;
        uint32 maxDuration;
        uint salt;
        bytes32 loanHash;
        Signature signature;
    }

    struct LoanRates {
        uint minimumDeposit;
        uint minimumSellAmount;
        uint maxAmount;
        uint minAmount;
        uint interestRate;
        uint lenderFee;
        uint takerFee;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // -------------------------------------------
    // ---- Internal Implementation Functions ----
    // -------------------------------------------

    function getUnavailableLoanOfferingAmountImpl(
        ShortSellState.State storage state,
        bytes32 loanHash
    )
        view
        internal
        returns (uint _unavailableAmount)
    {
        return SafeMathLib.add(state.loanFills[loanHash], state.loanCancels[loanHash]);
    }

    function transferToCloseVault(
        ShortSellState.State storage state,
        Short short,
        bytes32 shortId,
        uint closeAmount
    )
        internal
        returns (bytes32 _closeId)
    {
        uint currentShortAmount = SafeMathLib.sub(short.shortAmount, short.closedAmount);

        // The maximum amount of base token that can be used by this close
        uint baseTokenShare = SafeMathLib.getPartialAmount(
            closeAmount,
            currentShortAmount,
            Vault(state.VAULT).balances(shortId, short.baseToken)
        );

        bytes32 closeId = keccak256(shortId, "CLOSE");
        Vault(state.VAULT).transferBetweenVaults(
            shortId,
            closeId,
            short.baseToken,
            baseTokenShare
        );

        return closeId;
    }

    function cleanupShort(
        ShortSellState.State storage state,
        bytes32 shortId
    )
        internal
    {
        ShortSellRepo repo = ShortSellRepo(state.REPO);
        repo.deleteShort(shortId);
        repo.markShortClosed(shortId);
    }

    function payBackAuctionBidderIfExists(
        ShortSellState.State storage state,
        bytes32 shortId,
        Short short
    )
        internal
    {
        ShortSellAuctionRepo repo = ShortSellAuctionRepo(state.AUCTION_REPO);
        Vault vault = Vault(state.VAULT);

        var (, currentBidder, hasCurrentOffer) = repo.getAuction(shortId);

        if (!hasCurrentOffer) {
            return;
        }

        repo.deleteAuctionOffer(shortId);

        bytes32 auctionVaultId = getAuctionVaultId(shortId);

        vault.sendFromVault(
            auctionVaultId,
            short.underlyingToken,
            currentBidder,
            vault.balances(auctionVaultId, short.underlyingToken)
        );
    }

    function getAuctionVaultId(
        bytes32 shortId
    )
        internal
        pure
        returns (bytes32 _auctionVaultId)
    {
        return keccak256(shortId, "AUCTION_VAULT");
    }

    function calculateInterestFee(
        Short short,
        uint closeAmount,
        uint endTimestamp
    )
        internal
        pure
        returns (uint _interestFee)
    {
        // The interest rate for the proportion of the position being closed
        uint interestRate = SafeMathLib.getPartialAmount(
            closeAmount,
            short.shortAmount,
            short.interestRate
        );

        uint timeElapsed = SafeMathLib.sub(endTimestamp, short.startTimestamp);
        // TODO implement more complex interest rates
        return SafeMathLib.getPartialAmount(timeElapsed, 1 days, interestRate);
    }

    function getLoanOfferingHash(
        LoanOffering loanOffering,
        address baseToken,
        address underlyingToken
    )
        internal
        view
        returns (bytes32 _hash)
    {
        return keccak256(
            address(this),
            underlyingToken,
            baseToken,
            loanOffering.lender,
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
        returns (bytes32 _hash)
    {
        return keccak256(
            loanOffering.rates.minimumDeposit,
            loanOffering.rates.maxAmount,
            loanOffering.rates.minAmount,
            loanOffering.rates.minimumSellAmount,
            loanOffering.rates.interestRate,
            loanOffering.rates.lenderFee,
            loanOffering.rates.takerFee,
            loanOffering.expirationTimestamp,
            loanOffering.lockoutTime,
            loanOffering.callTimeLimit,
            loanOffering.maxDuration,
            loanOffering.salt
        );
    }

    function getShortEndTimestamp(
        Short short
    )
        internal
        pure
        returns (uint _endTimestamp)
    {
        // If the maxDuration is 0, then this short should never expire so return maximum int
        if (short.maxDuration == 0) {
            return 2 ** 255;
        }

        return SafeMathLib.add(uint(short.startTimestamp), uint(short.maxDuration));
    }

    // -------- Parsing Functions -------

    function getShortObject(
        ShortSellState.State storage state,
        bytes32 shortId
    )
        internal
        view
        returns (Short _short)
    {
        var (
            underlyingToken,
            baseToken,
            shortAmount,
            closedAmount,
            interestRate,
            callTimeLimit,
            lockoutTime,
            startTimestamp,
            callTimestamp,
            maxDuration,
            lender,
            seller
        ) =  ShortSellRepo(state.REPO).getShort(shortId);

        // This checks that the short exists
        require(startTimestamp != 0);

        return Short({
            underlyingToken: underlyingToken,
            baseToken: baseToken,
            shortAmount: shortAmount,
            closedAmount: closedAmount,
            interestRate: interestRate,
            callTimeLimit: callTimeLimit,
            lockoutTime: lockoutTime,
            startTimestamp: startTimestamp,
            callTimestamp: callTimestamp,
            maxDuration: maxDuration,
            lender: lender,
            seller: seller
        });
    }
}
