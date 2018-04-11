pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { ReentrancyGuard } from "zeppelin-solidity/contracts/ReentrancyGuard.sol";
import { NoOwner } from "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import { SharedLoan } from "./SharedLoan.sol";
import { LoanOwner } from "../interfaces/LoanOwner.sol";


/**
 * @title SharedLoanCreator
 * @author dYdX
 *
 * This contract is used to deploy new SharedLoan contracts. A new SharedLoan is automatically
 * deployed whenever a loan is transferred to this contract. That loan is then transferred to the
 * new SharedLoan, with the initial allocation going to the address that transferred the
 * loan originally to the SharedLoanCreator.
 */
/* solium-disable-next-line */
contract SharedLoanCreator is
    NoOwner,
    LoanOwner,
    ReentrancyGuard
{
    // -------------------
    // ------ Events -----
    // -------------------

    event SharedLoanCreated(
        bytes32 shortId,
        address sharedLoanAddress
    );

    // ----------------------------
    // ------ State Variables -----
    // ----------------------------

    // Addresses of recipients that will fairly verify and redistribute funds from closing the short
    address[] public TRUSTED_LOAN_CALLERS;

    // ------------------------
    // ------ Constructor -----
    // ------------------------

    function SharedLoanCreator(
        address shortSell,
        address[] trustedLoanCallers
    )
        public
        LoanOwner(shortSell)
    {
        for (uint256 i = 0; i < trustedLoanCallers.length; i++) {
            TRUSTED_LOAN_CALLERS.push(trustedLoanCallers[i]);
        }
    }

    // -----------------------------------
    // ---- ShortSell Only Functions -----
    // -----------------------------------

    /**
     * Implementation of LoanOwner functionality. Creates a new SharedLoan and assigns loan
     * ownership to the SharedLoan. Called by ShortSell when a loan is transferred to this
     * contract.
     *
     * @param  from  Address of the previous owner of the loan
     * @return       Address of the new SharedLoan contract
     */
    function receiveLoanOwnership(
        address from,
        bytes32 shortId
    )
        onlyShortSell
        nonReentrant
        external
        returns (address)
    {
        address sharedLoanAddress = new SharedLoan(
            shortId,
            SHORT_SELL,
            from,
            TRUSTED_LOAN_CALLERS
        );

        emit SharedLoanCreated(shortId, sharedLoanAddress);

        return sharedLoanAddress;
    }

    function additionalLoanValueAdded(
        address,
        bytes32,
        uint256
    )
        onlyShortSell
        nonReentrant
        external
        returns (bool)
    {
        return false;
    }
}
