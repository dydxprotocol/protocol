pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { LenderOwner } from "./LenderOwner.sol";


/**
 * @title LiquidatePositionDelegator
 * @author dYdX
 *
 * Interface that smart contracts must implement in order to let other addresses liquidate a loan
 * owned by the smart contract.
 */
contract LiquidatePositionDelegator is LenderOwner {

    // ============ Constructor ============

    function LiquidatePositionDelegator(
        address margin
    )
        public
        LenderOwner(margin)
    {
    }

    // ============ Public Interface functions ============

    /**
     * Function a contract must implement in order to let other addresses call liquidate() for the
     * lender position. This allows lenders to use more complex logic to control their lending
     * positions.
     *
     * NOTE: If returning non-zero, this contract must assume that Margin will either revert the
     * entire transaction or that the specified amount of the margin position was successfully
     * closed. Returning 0 will indicate an error and cause Margin to throw.
     *
     * @param liquidator       Address of the caller of the close function
     * @param payoutRecipient  Address of the recipient of quote tokens paid out
     * @param marginId         Unique ID of the margin position
     * @param requestedAmount  Amount of the loan being closed
     * @return                 The amount the user is allowed to close for the specified loan
     */
    function liquidatePositionOnBehalfOf(
        address liquidator,
        address payoutRecipient,
        bytes32 marginId,
        uint256 requestedAmount
    )
        onlyMargin
        external
        returns (uint256);
}
