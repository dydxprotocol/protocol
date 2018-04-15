pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { OnlyMargin } from "./OnlyMargin.sol";


/**
 * @title PositionOwner
 * @author dYdX
 *
 * Interface that smart contracts must implement in order to own position on behalf of other
 * accounts
 */
contract PositionOwner is OnlyMargin {

    // ============ Constructor ============

    function PositionOwner(
        address margin
    )
        public
        OnlyMargin(margin)
    {
    }

    // ============ Public Interface functions ============

    /**
     * Function a contract must implement in order to receive ownership of a position via the
     * transferPosition function or the atomic-assign to the "owner" field when opening a position.
     *
     * @param  from        Address of the previous owner
     * @param  positionId  Unique ID of the position
     * @return             The address to pass position ownership to. This address to keep
     *                     ownership, 0x0 to reject loan ownership completely.
     */
    function receivePositionOwnership(
        address from,
        bytes32 positionId
    )
        external
        onlyMargin
        returns (address);

    /**
     * Function a contract must implement in order to allow additional value to be added onto
     * an owned position. Margin will call this on the owner of a position
     * during Margin#increasePosition. If true is returned, the implementing contract can assume
     * the additional value was added.
     *
     * @param  from            Address initiating the addition of funds to the position
     * @param  positionId      Unique ID of the position
     * @param  principalAdded  Amount of principal to be added to the position
     * @return                 True if the contract consents to additional value being added,
     *                         false otherwise
     */
    function marginPositionIncreased(
        address from,
        bytes32 positionId,
        uint256 principalAdded
    )
        external
        onlyMargin
        returns (bool);
}
