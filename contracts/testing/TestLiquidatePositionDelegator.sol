pragma solidity 0.4.23;
pragma experimental "v0.5.0";

import { LiquidatePositionDelegator } from "../margin/interfaces/LiquidatePositionDelegator.sol";
import { OnlyMargin } from "../margin/interfaces/OnlyMargin.sol";


contract TestLiquidatePositionDelegator is OnlyMargin, LiquidatePositionDelegator {

    address public CLOSER;

    constructor(
        address margin,
        address closer
    )
        public
        OnlyMargin(margin)
    {
        CLOSER = closer;
    }

    function receiveLoanOwnership(
        address,
        bytes32
    )
        onlyMargin
        external
        returns (address)
    {
        return address(this);
    }

    function liquidateOnBehalfOf(
        address who,
        address,
        bytes32,
        uint256 requestedAmount
    )
        onlyMargin
        external
        returns (uint256)
    {
        return who == CLOSER ? requestedAmount : 0;
    }

    function marginLoanIncreased(
        address,
        bytes32,
        uint256
    )
        onlyMargin
        external
        returns (bool)
    {
        return false;
    }
}
