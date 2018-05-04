pragma solidity 0.4.23;
pragma experimental "v0.5.0";

import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { ClosePositionDelegator } from "../margin/interfaces/ClosePositionDelegator.sol";
import { PositionOwner } from "../margin/interfaces/PositionOwner.sol";
import { OnlyMargin } from "../margin/interfaces/OnlyMargin.sol";


contract TestPositionOwner is
    OnlyMargin,
    PositionOwner,
    ClosePositionDelegator
{
    using SafeMath for uint256;

    address public TO_RETURN;
    bool public TO_RETURN_ON_ADD;
    uint256 public TO_RETURN_ON_CLOSE;

    mapping(bytes32 => mapping(address => bool)) public hasReceived;
    mapping(bytes32 => mapping(address => uint256)) public valueAdded;

    constructor(
        address margin,
        address toReturn,
        bool toReturnOnAdd,
        uint256 toReturnOnCloseOnBehalfOf
    )
        public
        OnlyMargin(margin)
    {
        if (toReturn == address(1)) {
            TO_RETURN = address(this);
        } else {
            TO_RETURN = toReturn;
        }

        TO_RETURN_ON_ADD = toReturnOnAdd;
        TO_RETURN_ON_CLOSE = toReturnOnCloseOnBehalfOf;
    }

    function receivePositionOwnership(
        address from,
        bytes32 positionId
    )
        onlyMargin
        external
        returns (address)
    {
        hasReceived[positionId][from] = true;
        return TO_RETURN;
    }

    function marginPositionIncreased(
        address from,
        bytes32 positionId,
        uint256 amount
    )
        onlyMargin
        external
        returns (bool)
    {
        valueAdded[positionId][from] = valueAdded[positionId][from].add(amount);
        return TO_RETURN_ON_ADD;
    }

    function closeOnBehalfOf(
        address,
        address,
        bytes32,
        uint256 closeAmount
    )
        external
        onlyMargin
        returns (uint256)
    {
        if (TO_RETURN_ON_CLOSE == 1) {
            return closeAmount;
        }

        return TO_RETURN_ON_CLOSE;
    }
}
