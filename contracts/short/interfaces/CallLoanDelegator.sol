pragma solidity 0.4.19;

import { LoanOwner } from "./LoanOwner.sol";


/**
 * @title CallLoanDelegator
 * @author dYdX
 *
 * Interface that smart contracts must implement in order to let other addresses call-in a loan
 * owned by the smart contract.
 */
contract CallLoanDelegator is LoanOwner {

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function CallLoanDelegator(
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
     * Function a contract must implement in order to let other addresses call callInLoan() for
     * the loan-side of a short position.
     *
     * NOTE: If returning true, this contract must assume that ShortSell will either revert the
     * entire transaction or that the loan was successfully called-in
     *
     * @param _who            Address of the caller of the callInLoan function
     * @param _shortId        Id of the short being called
     * @param _depositAmount  Amount of baseToken deposit that will be required to cancel the call
     * @return _allowed       true if the user is allowed to call-in the short, false otherwise
     */
    function callOnBehalfOf(
        address _who,
        bytes32 _shortId,
        uint256 _depositAmount
    )
        onlyShortSell
        external
        returns (bool _allowed);

    /**
     * Function a contract must implement in order to let other addresses call cancelLoanCall() for
     * the loan-side of a short position.
     *
     * NOTE: If returning true, this contract must assume that ShortSell will either revert the
     * entire transaction or that the loan call was successfully cancelled
     *
     * @param _who            Address of the caller of the cancelLoanCall function
     * @param _shortId        Id of the short being call-canceled
     * @return _allowed       true if the user is allowed to cancel the short call, false otherwise
     */
    function cancelLoanCallOnBehalfOf(
        address _who,
        bytes32 _shortId
    )
        onlyShortSell
        external
        returns (bool _allowed);
}
