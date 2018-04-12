pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { ReentrancyGuard } from "zeppelin-solidity/contracts/ReentrancyGuard.sol";
import { NoOwner } from "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import { SharedLoan } from "./SharedLoan.sol";
import { LenderOwner } from "../interfaces/LenderOwner.sol";


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
    LenderOwner,
    ReentrancyGuard
{
    // ============ Events ============

    event SharedLoanCreated(
        bytes32 marginId,
        address sharedLoanAddress
    );

    // ============ State Variables ============

    // Addresses that are trusted to margin call the position
    address[] public TRUSTED_MARGIN_CALLERS;

    // ============ Constructor ============

    function SharedLoanCreator(
        address margin,
        address[] trustedLoanCallers
    )
        public
        LenderOwner(margin)
    {
        for (uint256 i = 0; i < trustedLoanCallers.length; i++) {
            TRUSTED_MARGIN_CALLERS.push(trustedLoanCallers[i]);
        }
    }

    // ============ Margin-Only Functions ============

    /**
     * Implementation of LenderOwner functionality. Creates a new SharedLoan and assigns loan
     * ownership to the SharedLoan. Called by Margin when a loan is transferred to this
     * contract.
     *
     * @param  from  Address of the previous owner of the loan
     * @return       Address of the new SharedLoan contract
     */
    function receiveOwnershipAsLender(
        address from,
        bytes32 marginId
    )
        onlyMargin
        nonReentrant
        external
        returns (address)
    {
        address sharedLoanAddress = new SharedLoan(
            marginId,
            MARGIN,
            from,
            TRUSTED_MARGIN_CALLERS
        );

        emit SharedLoanCreated(marginId, sharedLoanAddress);

        return sharedLoanAddress;
    }

    function loanIncreased(
        address,
        bytes32,
        uint256
    )
        onlyMargin
        nonReentrant
        external
        returns (bool)
    {
        return false;
    }
}