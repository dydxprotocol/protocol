/*

    Copyright 2018 dYdX Trading Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity 0.4.23;
pragma experimental "v0.5.0";

import { MarginCallDelegator } from "../margin/interfaces/MarginCallDelegator.sol";
import { OnlyMargin } from "../margin/interfaces/OnlyMargin.sol";


contract TestMarginCallDelegator is OnlyMargin, MarginCallDelegator {

    address public CALLER;
    address public CANCELLER;

    constructor(
        address margin,
        address caller,
        address canceller
    )
        public
        OnlyMargin(margin)
    {
        CALLER = caller;
        CANCELLER = canceller;
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

    function marginCallOnBehalfOf(
        address who,
        bytes32,
        uint256
    )
        onlyMargin
        external
        returns (bool)
    {
        return who == CALLER;
    }

    function cancelMarginCallOnBehalfOf(
        address who,
        bytes32
    )
        onlyMargin
        external
        returns (bool)
    {
        return who == CANCELLER;
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
