pragma solidity 0.4.19;

import { LoanOwner } from "./LoanOwner.sol";


/**
 * @title ForceRecoverLoanDelegator
 * @author dYdX
 *
 * Interface that smart contracts must implement in order to let other addresses forceRecoverLoan()
 * a loan owned by the smart contract.
 */
contract ForceRecoverLoanDelegator is LoanOwner {

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function ForceRecoverLoanDelegator(
        address _shortSell
    )
        public
        LoanOwner(_shortSell)
    {
    }

    // ----------------------------------------
    // ------ Public Interface functions ------
    // ----------------------------------------

    /**
     * Function a contract must implement in order to let other addresses call forceRecoverLoan()
     * for the loan-side of a short position.
     *
     * NOTE: If returning true, this contract must assume that ShortSell will either revert the
     * entire transaction or that the loan call was successfully cancelled
     *
     * @param _who            Address of the caller of the cancelLoanCall function
     * @param _shortId        Id of the short being call-canceled
     * @return _allowed       true if the user is allowed to cancel the short call, false otherwise
     */
    function forceRecoverLoanOnBehalfOf(
        address _who,
        bytes32 _shortId
    )
        onlyShortSell
        external
        returns (bool _allowed);
}
