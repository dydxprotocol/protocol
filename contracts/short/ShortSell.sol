pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { ReentrancyGuard } from "zeppelin-solidity/contracts/ReentrancyGuard.sol";
import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { NoOwner } from "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import { Ownable } from "zeppelin-solidity/contracts/ownership/Ownable.sol";
import { Vault } from "./Vault.sol";
import { AddValueToShortImpl } from "./impl/AddValueToShortImpl.sol";
import { CloseShortImpl } from "./impl/CloseShortImpl.sol";
import { DepositImpl } from "./impl/DepositImpl.sol";
import { ForceRecoverLoanImpl } from "./impl/ForceRecoverLoanImpl.sol";
import { LiquidateImpl } from "./impl/LiquidateImpl.sol";
import { LoanGetters } from "./impl/LoanGetters.sol";
import { LoanImpl } from "./impl/LoanImpl.sol";
import { ShortGetters } from "./impl/ShortGetters.sol";
import { ShortImpl } from "./impl/ShortImpl.sol";
import { ShortSellAdmin } from "./impl/ShortSellAdmin.sol";
import { ShortSellEvents } from "./impl/ShortSellEvents.sol";
import { ShortSellState } from "./impl/ShortSellState.sol";
import { ShortSellStorage } from "./impl/ShortSellStorage.sol";
import { TransferImpl } from "./impl/TransferImpl.sol";


/**
 * @title ShortSell
 * @author dYdX
 *
 * This contract is used to facilitate short selling as per the dYdX short sell protocol
 */
 /* solium-disable-next-line */
contract ShortSell is
    Ownable,
    NoOwner,
    ReentrancyGuard,
    ShortSellStorage,
    ShortSellEvents,
    ShortSellAdmin,
    LoanGetters,
    ShortGetters {

    using SafeMath for uint256;

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function ShortSell(
        address vault,
        address proxy
    )
        Ownable()
        ShortSellAdmin()
        public
    {
        state = ShortSellState.State({
            VAULT: vault,
            PROXY: proxy
        });
    }

    // -----------------------------------------
    // ---- Public State Changing Functions ----
    // -----------------------------------------

    /**
     * Initiate a short sell. Called by the short seller. Short seller must provide both a
     * signed loan offering as well as a signed buy order for the base token to be shorted.
     *
     * @param  addresses  Addresses corresponding to:
     *
     *  [0]  = short owner
     *  [1]  = base token
     *  [2]  = quote token
     *  [3]  = loan payer
     *  [4]  = loan signer
     *  [5]  = loan owner
     *  [6]  = loan taker
     *  [7]  = loan fee recipient
     *  [8]  = loan lender fee token
     *  [9]  = loan taker fee token
     *  [10]  = exchange wrapper address
     *
     * @param  values256  Values corresponding to:
     *
     *  [0]  = loan maximum amount
     *  [1]  = loan minimum amount
     *  [2]  = loan minimum quote token
     *  [3]  = loan lender fee
     *  [4]  = loan taker fee
     *  [5]  = loan expiration timestamp (in seconds)
     *  [6]  = loan salt
     *  [7]  = short amount
     *  [8]  = deposit amount
     *
     * @param  values32  Values corresponding to:
     *
     *  [0] = loan call time limit (in seconds)
     *  [1] = loan maxDuration (in seconds)
     *  [2] = loan interest rate (annual nominal percentage times 10**6)
     *  [3] = loan interest update period (in seconds)
     *
     * @param  sigV       ECDSA v parameter for loan offering
     * @param  sigRS      ECDSA r and s parameters for loan offering
     * @param  depositInQuoteToken  true if the short seller wishes to pay the margin deposit in
     *                              quote token. If false, margin deposit will be pulled in base
     *                              token, and then sold along with the base token borrowed from
     *                              the lender
     * @param  order      Order object to be passed to the exchange wrapper
     * @return            Unique ID for the new short
     */
    function short(
        address[11] addresses,
        uint256[9]  values256,
        uint32[4]   values32,
        uint8       sigV,
        bytes32[2]  sigRS,
        bool        depositInQuoteToken,
        bytes       order
    )
        external
        onlyWhileOperational
        nonReentrant
        returns (bytes32)
    {
        return ShortImpl.shortImpl(
            state,
            addresses,
            values256,
            values32,
            sigV,
            sigRS,
            depositInQuoteToken,
            order
        );
    }

    /**
     * Add value to a short sell. Funds will be borrowed from the loan payer and sold as per short.
     * The value added to the short will be equal to the effective amount lent, and will incorporate
     * interest already earned by the position so far.
     *
     * @param  addresses  Addresses corresponding to:
     *
     *  [0]  = loan payer
     *  [1]  = loan signer
     *  [2]  = loan taker
     *  [3]  = loan fee recipient
     *  [4]  = loan lender fee token
     *  [5]  = loan taker fee token
     *  [6]  = exchange wrapper address
     *
     * @param  values256  Values corresponding to:
     *
     *  [0]  = loan maximum amount
     *  [1]  = loan minimum amount
     *  [2]  = loan minimum quote token
     *  [3]  = loan lender fee
     *  [4]  = loan taker fee
     *  [5]  = loan expiration timestamp (in seconds)
     *  [6]  = loan salt
     *  [7]  = amount to add to the position (NOTE: the amount pulled from the lender will be
     *                                              >= this amount)
     *
     * @param  values32  Values corresponding to:
     *
     *  [0] = loan call time limit (in seconds)
     *  [1] = loan maxDuration (in seconds)
     *
     * @param  sigV       ECDSA v parameter for loan offering
     * @param  sigRS      ECDSA r and s parameters for loan offering
     * @param  depositInQuoteToken  true if the short seller wishes to pay the margin deposit in
     *                              quote token. If false, margin deposit will be pulled in base
     *                              token, and then sold along with the base token borrowed from
     *                              the lender
     * @param  order      Order object to be passed to the exchange wrapper
     * @return            Amount of base tokens pulled from the lender
     */
    function addValueToShort(
        bytes32     shortId,
        address[7]  addresses,
        uint256[8]  values256,
        uint32[2]   values32,
        uint8       sigV,
        bytes32[2]  sigRS,
        bool        depositInQuoteToken,
        bytes       order
    )
        external
        onlyWhileOperational
        nonReentrant
        returns (uint256)
    {
        return AddValueToShortImpl.addValueToShortImpl(
            state,
            shortId,
            addresses,
            values256,
            values32,
            sigV,
            sigRS,
            depositInQuoteToken,
            order
        );
    }

    /**
     * Add value to a short sell by directly putting up quote token. The adder will serve as both
     * the lender and seller.
     *
     * @param shortId   Unique ID of the short sell
     * @param amount    Amount (in base token) to add to the short
     * @return          Amount of quote token pulled from the adder
     */
    function addValueToShortDirectly(
        bytes32 shortId,
        uint256 amount
    )
        external
        onlyWhileOperational
        nonReentrant
        returns (uint256)
    {
        return AddValueToShortImpl.addValueToShortDirectlyImpl(
            state,
            shortId,
            amount
        );
    }

    /**
    * Close a short sell. May be called by the short seller or with the approval of the short
    * seller. May provide an order and exchangeWrapperAddress to facilitate the closing of the
    * short position. The short seller is sent quote token stored in the contract.
     *
     * @param  shortId                  Unique ID for the short sell
     * @param  requestedCloseAmount     Amount of the short position to close. The amount closed
     *                                  will be: min(requestedCloseAmount, currentShortAmount)
     * @param  payoutRecipient          Address to send remaining quoteToken to after closing
     * @param  exchangeWrapperAddress   Address of the exchange wrapper
     * @param  order                    Order object to be passed to the exchange wrapper
     * @return                          Values corresponding to:
     *                                  1) Amount of short closed
     *                                  2) Amount of quote token recieved by the payoutRecipient
     *                                  3) Amount of base token paid as interest fee to the lender
     */
    function closeShort(
        bytes32 shortId,
        uint256 requestedCloseAmount,
        address payoutRecipient,
        address exchangeWrapperAddress,
        bytes   order
    )
        external
        closeShortStateControl
        nonReentrant
        returns (uint256, uint256, uint256)
    {
        return CloseShortImpl.closeShortImpl(
            state,
            shortId,
            requestedCloseAmount,
            payoutRecipient,
            exchangeWrapperAddress,
            order
        );
    }

    /**
     * Helper to close a short sell by paying base token directly from the short seller
     *
     * @param  shortId                  Unique ID for the short sell
     * @param  requestedCloseAmount     Amount of the short position to close. The amount closed
     *                                  will be: min(requestedCloseAmount, currentShortAmount)
     * @param  payoutRecipient          Address to send remaining quoteToken to after closing
     * @return                          Values corresponding to:
     *                                  1) Amount of short closed
     *                                  2) Amount of quote token received by the payoutRecipient
     *                                  3) Amount of base token paid as interest fee to the lender
     */
    function closeShortDirectly(
        bytes32 shortId,
        uint256 requestedCloseAmount,
        address payoutRecipient
    )
        external
        closeShortDirectlyStateControl
        nonReentrant
        returns (uint256, uint256, uint256)
    {
        return CloseShortImpl.closeShortImpl(
            state,
            shortId,
            requestedCloseAmount,
            payoutRecipient,
            address(0),
            new bytes(0)
        );
    }

    /**
     * Liquidate loan position and withdraw quote tokens from the vault.
     * Must be approved by the short seller (e.g., by requiring the lender to own part of the
     * short position, and burning in order to liquidate part of the loan).
     *
     * @param  shortId                     Unique ID for the short sell
     * @param  requestedLiquidationAmount  Amount of the loan to close. The amount closed
     *                                     will be: min(requestedCloseAmount, currentShortAmount)
     * @return                             Values corresponding to:
     *                                     1) Amount of short closed
     *                                     2) Amount of quote token recieved by the msg.sender
     */
    function liquidate(
        bytes32 shortId,
        uint256 requestedLiquidationAmount,
        address payoutRecipient
    )
        external
        closeShortStateControl
        nonReentrant
        returns (uint256, uint256)
    {
        return LiquidateImpl.liquidateImpl(
            state,
            shortId,
            requestedLiquidationAmount,
            payoutRecipient
        );
    }

    /**
     * Call in a short sell loan.
     * Only callable by the lender for a short sell. After loan is called in, the short seller
     * will have time equal to the call time limit specified on the original short sell to
     * close the short and repay the loan. If the short seller does not close the short, the
     * lender can use forceRecoverLoan to recover his funds.
     *
     * @param  shortId          Unique ID for the short sell
     * @param  requiredDeposit  Amount of deposit the short seller must put up to cancel the call
     */
    function callInLoan(
        bytes32 shortId,
        uint256 requiredDeposit
    )
        external
        nonReentrant
    {
        LoanImpl.callInLoanImpl(
            state,
            shortId,
            requiredDeposit
        );
    }

    /**
     * Cancel a loan call. Only callable by the short sell's lender
     *
     * @param  shortId  Unique ID for the short sell
     */
    function cancelLoanCall(
        bytes32 shortId
    )
        external
        onlyWhileOperational
        nonReentrant
    {
        LoanImpl.cancelLoanCallImpl(state, shortId);
    }

    /**
     * Function callable by the lender after the loan has been called-in for the call time limit but
     * remains unclosed. Used to recover the quote tokens held as collateral.
     *
     * @param  shortId  Unique ID for the short sell
     */
    function forceRecoverLoan(
        bytes32 shortId
    )
        external
        nonReentrant
        returns (uint256)
    {
        return ForceRecoverLoanImpl.forceRecoverLoanImpl(state, shortId);
    }

    /**
     * Deposit additional quote token as colateral for a short sell loan. Cancels loan call if:
     * 0 < short.requiredDeposit < depositAmount
     *
     * @param  shortId          Unique ID for the short sell
     * @param  depositAmount    Additional amount in quote token to deposit
     */
    function deposit(
        bytes32 shortId,
        uint256 depositAmount
    )
        external
        onlyWhileOperational
        nonReentrant
    {
        DepositImpl.depositImpl(
            state,
            shortId,
            depositAmount
        );
    }

    /**
     * Cancel an amount of a loan offering. Only callable by the offering's lender.
     *
     * @param  addresses  Array of addresses:
     *
     *  [0] = base token
     *  [1] = quote token
     *  [2] = loan payer
     *  [3] = loan signer
     *  [4] = loan owner
     *  [5] = loan taker
     *  [6] = loan fee recipient
     *  [7] = loan lender fee token
     *  [8] = loan taker fee token
     *
     * @param  values256  Values corresponding to:
     *
     *  [0] = loan maximum amount
     *  [1] = loan minimum amount
     *  [2] = loan minimum quote token
     *  [3] = loan lender fee
     *  [4] = loan taker fee
     *  [5] = loan expiration timestamp (in seconds)
     *  [6] = loan salt
     *
     * @param  values32  Values corresponding to:
     *
     *  [0] = loan call time limit (in seconds)
     *  [1] = loan maxDuration (in seconds)
     *  [2] = loan interest rate (annual nominal percentage times 10**6)
     *  [3] = loan interest update period (in seconds)
     *
     * @param  cancelAmount     Amount to cancel
     * @return                  Amount that was canceled
     */
    function cancelLoanOffering(
        address[9] addresses,
        uint256[7] values256,
        uint32[4]  values32,
        uint256    cancelAmount
    )
        external
        cancelLoanOfferingStateControl
        nonReentrant
        returns (uint256)
    {
        return LoanImpl.cancelLoanOfferingImpl(
            state,
            addresses,
            values256,
            values32,
            cancelAmount
        );
    }

    /**
     * On-chain approve a loan offering. Meant for smart contracts to approve loans with a
     * transaction rather than a signature.
     *
     * @param  addresses  Array of addresses:
     *
     *  [0] = base token
     *  [1] = quote token
     *  [2] = loan payer
     *  [3] = loan signer
     *  [4] = loan owner
     *  [5] = loan taker
     *  [6] = loan fee recipient
     *  [7] = loan lender fee token
     *  [8] = loan taker fee token
     *
     * @param  values256  Values corresponding to:
     *
     *  [0] = loan maximum amount
     *  [1] = loan minimum amount
     *  [2] = loan minimum quote token
     *  [3] = loan lender fee
     *  [4] = loan taker fee
     *  [5] = loan expiration timestamp (in seconds)
     *  [6] = loan salt
     *
     * @param  values32  Values corresponding to:
     *
     *  [0] = loan call time limit (in seconds)
     *  [1] = loan maxDuration (in seconds)
     *  [2] = loan interest rate (annual nominal percentage times 10**18)
     *  [3] = loan interest update period (in seconds)
     */
    function approveLoanOffering(
        address[9] addresses,
        uint256[7] values256,
        uint32[4]  values32
    )
        external
        onlyWhileOperational
        nonReentrant
    {
        LoanImpl.approveLoanOfferingImpl(
            state,
            addresses,
            values256,
            values32
        );
    }

    /**
     * Transfer ownership of a loan to a new address. This new address will be entitled
     * to all payouts for this loan. Only callable by the lender for a short. If the "who"
     * param is a contract, it must implement the LoanOwner interface.
     *
     * @param  shortId  Unique ID for the short sell
     * @param  who      New owner of the loan
     */
    function transferLoan(
        bytes32 shortId,
        address who
    )
        external
        nonReentrant
    {
        TransferImpl.transferLoanImpl(
            state,
            shortId,
            who);
    }

    /**
     * Transfer ownership of a short to a new address. This new address will be entitled
     * to all payouts for this short. Only callable by the short seller for a short. If the "who"
     * param is a contract, it must implement the ShortOwner interface.
     *
     * @param  shortId  Unique ID for the short sell
     * @param  who      New owner of the short
     */
    function transferShort(
        bytes32 shortId,
        address who
    )
        external
        nonReentrant
    {
        TransferImpl.transferShortImpl(
            state,
            shortId,
            who);
    }

    // -------------------------------------
    // ----- Public Constant Functions -----
    // -------------------------------------

    function getVaultAddress()
        view
        external
        returns (address)
    {
        return state.VAULT;
    }

    function getProxyAddress()
        view
        external
        returns (address)
    {
        return state.PROXY;
    }
}
