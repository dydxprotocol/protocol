pragma solidity 0.4.19;

import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { ShortSellState } from "./ShortSellState.sol";
import { Vault } from "../Vault.sol";
import { ShortSellRepo } from "../ShortSellRepo.sol";
import { ShortSellAuctionRepo } from "../ShortSellAuctionRepo.sol";
import { TermsContract } from "../interfaces/TermsContract.sol";
import { MathHelpers } from "../../lib/MathHelpers.sol";


/**
 * @title ShortSellCommon
 * @author Antonio Juliano
 *
 * This library contains common functions for implementations of public facing ShortSell functions
 */
library ShortSellCommon {
    using SafeMath for uint;

    // -----------------------
    // ------- Structs -------
    // -----------------------

    struct Short {
        address underlyingToken; // Immutable
        address baseToken;       // Immutable
        uint shortAmount;
        uint closedAmount;
        uint termsParameters;
        uint32 callTimeLimit;
        uint32 lockoutTime;
        uint32 startTimestamp;   // Immutable, cannot be 0
        uint32 callTimestamp;
        uint32 maxDuration;
        address lender;
        address seller;
        address termsContract;
    }

    struct LoanOffering {
        address lender;
        address signer;
        address taker;
        address feeRecipient;
        address lenderFeeToken;
        address takerFeeToken;
        address termsContract;
        LoanRates rates;
        uint expirationTimestamp;
        uint32 lockoutTime;
        uint32 callTimeLimit;
        uint32 maxDuration;
        uint salt;
        uint termsParameters;
        bytes32 loanHash;
        Signature signature;
    }

    struct LoanRates {
        uint minimumDeposit;
        uint minimumSellAmount;
        uint maxAmount;
        uint minAmount;
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
        return state.loanFills[loanHash].add(state.loanCancels[loanHash]);
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
        uint currentShortAmount = short.shortAmount.sub(short.closedAmount);

        // The maximum amount of base token that can be used by this close
        uint baseTokenShare = MathHelpers.getPartialAmount(
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
            loanOffering.signer,
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

        return uint(short.startTimestamp).add(uint(short.maxDuration));
    }

    // -------- Parsing Functions -------

    function getShortObject(
        address repo,
        bytes32 shortId
    )
        internal
        view
        returns (Short _short)
    {
        var (
            addresses,
            values256,
            values32
        ) =  ShortSellRepo(repo).getShort(shortId);

        // This checks that the short exists
        require(values32[2] != 0); // startTimestamp is not zero

        return Short({
            underlyingToken: addresses[0],
            baseToken:       addresses[1],
            lender:          addresses[2],
            seller:          addresses[3],
            termsContract:   addresses[4],
            shortAmount:     values256[0],
            closedAmount:    values256[1],
            termsParameters: values256[2],
            callTimeLimit:   values32[0],
            lockoutTime:     values32[1],
            startTimestamp:  values32[2],
            callTimestamp:   values32[3],
            maxDuration:     values32[4]
        });
    }
}
