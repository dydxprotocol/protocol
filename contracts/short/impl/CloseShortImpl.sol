pragma solidity 0.4.19;

import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { Math } from "zeppelin-solidity/contracts/math/Math.sol";
import { MathHelpers } from "../../lib/MathHelpers.sol";
import { ShortSellCommon } from "./ShortSellCommon.sol";
import { ShortSellState } from "./ShortSellState.sol";
import { Vault } from "../Vault.sol";
import { Proxy } from "../../shared/Proxy.sol";
import { ContractHelper } from "../../lib/ContractHelper.sol";
import { CloseShortDelegator } from "../interfaces/CloseShortDelegator.sol";
import { ExchangeWrapper } from "../interfaces/ExchangeWrapper.sol";
import { PayoutRecipient } from "../interfaces/PayoutRecipient.sol";


/**
 * @title CloseShortImpl
 * @author dYdX
 *
 * This library contains the implementation for the closeShort function of ShortSell
 */
library CloseShortImpl {
    using SafeMath for uint256;

    // ------------------------
    // -------- Events --------
    // ------------------------

    /**
     * A short sell was closed
     */
    event ShortClosed(
        bytes32 indexed id,
        uint256 closeAmount,
        uint256 interestFee,
        uint256 payoutBaseTokenAmount,
        uint256 buybackCost
    );

    /**
     * A short sell was partially closed
     */
    event ShortPartiallyClosed(
        bytes32 indexed id,
        uint256 closeAmount,
        uint256 remainingAmount,
        uint256 interestFee,
        uint256 payoutBaseTokenAmount,
        uint256 buybackCost
    );

    // -----------------------
    // ------- Structs -------
    // -----------------------

    struct Order {
        address exchangeWrapperAddress;
        bytes orderData;
    }

    // -------------------------------------------
    // ----- Public Implementation Functions -----
    // -------------------------------------------

    function closeShortImpl(
        ShortSellState.State storage state,
        bytes32 shortId,
        uint256 requestedCloseAmount,
        address payoutRecipient,
        address exchangeWrapperAddress,
        bytes orderData
    )
        public
        returns (
            uint256 _amountClosed,
            uint256 _baseTokenReceived,
            uint256 _interestFeeAmount
        )
    {
        Order memory order = Order({
            exchangeWrapperAddress: exchangeWrapperAddress,
            orderData: orderData
        });

        // Create CloseShortTx and validate closeAmount
        ShortSellCommon.CloseShortTx memory transaction = ShortSellCommon.parseCloseShortTx(
            state,
            shortId,
            requestedCloseAmount,
            payoutRecipient
        );
        validateCloseShortTx(transaction); // may modify transaction

        // State updates
        ShortSellCommon.updateClosedAmount(state, transaction);

        uint256 interestFee;
        uint256 buybackCost;
        uint256 payoutBaseTokenAmount;

        (
            interestFee,
            buybackCost,
            payoutBaseTokenAmount
        ) = sendTokens(
            state,
            transaction,
            order
        );

        // Delete the short if it is now completely closed
        if (transaction.closeAmount == transaction.currentShortAmount) {
            ShortSellCommon.cleanupShort(state, transaction.shortId);
        }

        logEventOnClose(
            transaction,
            interestFee,
            buybackCost,
            payoutBaseTokenAmount
        );

        return (
            transaction.closeAmount,
            payoutBaseTokenAmount,
            interestFee
        );
    }

    // --------- Helper Functions ---------

    /**
     * Validate the CloseShortTx object created for closing a short.
     * This function may throw, or it may simply modify parameters of the CloseShortTx object.
     * Will not throw if the resulting object is valid.
     * @param transaction  The transaction to validate
     */
    function validateCloseShortTx(
        ShortSellCommon.CloseShortTx transaction
    )
        internal
    {
        // If not the short seller, requires short seller to approve msg.sender
        if (transaction.short.seller != msg.sender) {
            uint256 allowedCloseAmount =
                CloseShortDelegator(transaction.short.seller).closeOnBehalfOf(
                    msg.sender,
                    transaction.payoutRecipient,
                    transaction.shortId,
                    transaction.closeAmount
                );

            // Because the verifier may do accounting based on the number that it returns, revert
            // if the returned amount is larger than the remaining amount of the short.
            require(transaction.closeAmount >= allowedCloseAmount);
            transaction.closeAmount = allowedCloseAmount;
        }

        require(transaction.closeAmount > 0);
        require(transaction.closeAmount <= transaction.currentShortAmount);
    }



    function sendTokens(
        ShortSellState.State storage state,
        ShortSellCommon.CloseShortTx transaction,
        Order order
    )
        internal
        returns (
            uint256 _interestFee,
            uint256 _buybackCost,
            uint256 _payoutBaseTokenAmount
        )
    {
        // Send underlying tokens to lender
        uint256 buybackCost = 0;
        uint256 interestFee = getInterestFee(transaction);
        uint256 underlyingTokenOwedToLender = transaction.closeAmount.add(interestFee);

        if (order.exchangeWrapperAddress == address(0)) {
            // no buy order; send underlying tokens directly from the closer to the lender
            Proxy(state.PROXY).transferTo(
                transaction.short.underlyingToken,
                msg.sender,
                transaction.short.lender,
                underlyingTokenOwedToLender
            );
        } else {
            // close short using buy order
            buybackCost = buyBackUnderlyingToken(
                state,
                transaction,
                order,
                underlyingTokenOwedToLender
            );
        }

        // Send base tokens to the correct parties
        uint256 payoutBaseTokenAmount = sendBaseTokensOnClose(
            state,
            transaction,
            buybackCost
        );

        // The ending base token balance of the vault should be the starting base token balance
        // minus the available base token amount
        assert(
            Vault(state.VAULT).balances(transaction.shortId, transaction.short.baseToken)
            == transaction.startingBaseToken.sub(transaction.availableBaseToken)
        );

        return (
            interestFee,
            buybackCost,
            payoutBaseTokenAmount
        );
    }

    function getInterestFee(
        ShortSellCommon.CloseShortTx transaction
    )
        internal
        view
        returns (uint256 _interestFee)
    {
        return ShortSellCommon.calculateInterestFee(
            transaction.short,
            transaction.closeAmount,
            block.timestamp
        );
    }

    function buyBackUnderlyingToken(
        ShortSellState.State storage state,
        ShortSellCommon.CloseShortTx transaction,
        Order order,
        uint256 underlyingTokenOwedToLender
    )
        internal
        returns (uint256 _buybackCost)
    {
        // Ask the exchange wrapper what the price in base token to buy back the close
        // amount of underlying token is
        uint256 baseTokenPrice = ExchangeWrapper(order.exchangeWrapperAddress).getTakerTokenPrice(
            transaction.short.underlyingToken,
            transaction.short.baseToken,
            underlyingTokenOwedToLender,
            order.orderData
        );

        // We need to have enough base token locked in the the close's vault to pay
        // for both the buyback and the interest fee
        require(baseTokenPrice <= transaction.availableBaseToken);

        // Send the requisite base token to do the buyback from vault to exchange wrapper
        if (baseTokenPrice > 0) {
            Vault(state.VAULT).transferFromVault(
                transaction.shortId,
                transaction.short.baseToken,
                order.exchangeWrapperAddress,
                baseTokenPrice
            );
        }

        // Trade the base token for the underlying token
        uint256 receivedUnderlyingToken = ExchangeWrapper(order.exchangeWrapperAddress).exchange(
            transaction.short.underlyingToken,
            transaction.short.baseToken,
            msg.sender,
            baseTokenPrice,
            order.orderData
        );

        assert(receivedUnderlyingToken == underlyingTokenOwedToLender);

        // Transfer underlying token from the exchange wrapper to the lender
        Proxy(state.PROXY).transferTo(
            transaction.short.underlyingToken,
            order.exchangeWrapperAddress,
            transaction.short.lender,
            underlyingTokenOwedToLender
        );

        return baseTokenPrice;
    }

    function sendBaseTokensOnClose(
        ShortSellState.State storage state,
        ShortSellCommon.CloseShortTx transaction,
        uint256 buybackCost
    )
        internal
        returns (uint256 _payoutBaseTokenAmount)
    {
        Vault vault = Vault(state.VAULT);

        // Send remaining base token to payoutRecipient
        uint256 payoutBaseTokenAmount = transaction.availableBaseToken.sub(buybackCost);

        vault.transferFromVault(
            transaction.shortId,
            transaction.short.baseToken,
            transaction.payoutRecipient,
            payoutBaseTokenAmount
        );

        if (ContractHelper.isContract(transaction.payoutRecipient)) {
            PayoutRecipient(transaction.payoutRecipient).receiveCloseShortPayout(
                transaction.shortId,
                transaction.closeAmount,
                msg.sender,
                transaction.short.seller,
                transaction.short.baseToken,
                payoutBaseTokenAmount,
                transaction.availableBaseToken
            );
        }

        return payoutBaseTokenAmount;
    }

    function logEventOnClose(
        ShortSellCommon.CloseShortTx transaction,
        uint256 interestFee,
        uint256 buybackCost,
        uint256 payoutBaseTokenAmount
    )
        internal
    {
        if (transaction.closeAmount == transaction.currentShortAmount) {
            ShortClosed(
                transaction.shortId,
                transaction.closeAmount,
                interestFee,
                payoutBaseTokenAmount,
                buybackCost
            );
        } else {
            ShortPartiallyClosed(
                transaction.shortId,
                transaction.closeAmount,
                transaction.currentShortAmount.sub(transaction.closeAmount),
                interestFee,
                payoutBaseTokenAmount,
                buybackCost
            );
        }
    }

}
