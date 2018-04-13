pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { LoanOwner } from "./LoanOwner.sol";


/**
 * @title MarginCallDelegator
 * @author dYdX
 *
 * Interface that smart contracts must implement in order to let other addresses call-in a loan
 * owned by the smart contract.
 */
contract MarginCallDelegator is LoanOwner {

    // ============ Constructor ============

    function MarginCallDelegator(
        address margin
    )
        public
        LoanOwner(margin)
    {
    }

    // ============ Public Interface functions ============

    /**
     * Function a contract must implement in order to let other addresses call marginCall() for
     * the loan-side of a margin position.
     *
     * NOTE: If returning true, this contract must assume that Margin will either revert the
     * entire transaction or that the loan was successfully called-in
     *
     * @param who            Address of the caller of the marginCall function
     * @param marginId       Unique ID of the margin position
     * @param depositAmount  Amount of quoteToken deposit that will be required to cancel the call
     * @return               True if the user is allowed to margin call the position
     */
    function marginCallOnBehalfOf(
        address who,
        bytes32 marginId,
        uint256 depositAmount
    )
        onlyMargin
        external
        returns (bool);

    /**
     * Function a contract must implement in order to let other addresses call cancelMarginCall()
     * for the loan-side of a margin position.
     *
     * NOTE: If returning true, this contract must assume that Margin will either revert the
     * entire transaction or that the loan call was successfully canceled
     *
     * @param who            Address of the caller of the cancelMarginCall function
     * @param marginId       Unique ID of the margin position
     * @return               True if the user is allowed to cancel the position's margin call
     */
    function cancelMarginCallOnBehalfOf(
        address who,
        bytes32 marginId
    )
        onlyMargin
        external
        returns (bool);
}
