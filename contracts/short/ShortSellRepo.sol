pragma solidity 0.4.19;

import { NoOwner } from "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import { StaticAccessControlled } from "../lib/StaticAccessControlled.sol";
import { ShortSellCommon } from "./impl/ShortSellCommon.sol";


/**
 * @title ShortSellRepo
 * @author dYdX
 *
 * This contract is used to store state for short sells
 */
contract ShortSellRepo is StaticAccessControlled, NoOwner {
    // ---------------------------
    // ----- State Variables -----
    // ---------------------------

    // Mapping that contains all short sells. Mapped by: shortId -> Short
    mapping(bytes32 => ShortSellCommon.Short) public shorts;
    mapping(bytes32 => bool) public closedShorts;

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function ShortSellRepo(
        uint _gracePeriod
    )
        public
        StaticAccessControlled(_gracePeriod)
    {}

    // --------------------------------------------------
    // ---- Authorized Only State Changing Functions ----
    // --------------------------------------------------

    function addShort(
        bytes32 id,
        address underlyingToken,
        address baseToken,
        uint shortAmount,
        uint interestRate,
        uint32 callTimeLimit,
        uint32 lockoutTime,
        uint32 startTimestamp,
        uint32 maxDuration,
        address lender,
        address seller
    )
        requiresAuthorization
        external
    {
        require(!containsShort(id));
        require(startTimestamp != 0);

        shorts[id] = ShortSellCommon.Short({
            underlyingToken: underlyingToken,
            baseToken: baseToken,
            shortAmount: shortAmount,
            closedAmount: 0,
            interestRate: interestRate,
            callTimeLimit: callTimeLimit,
            lockoutTime: lockoutTime,
            startTimestamp: startTimestamp,
            callTimestamp: 0,
            maxDuration: maxDuration,
            lender: lender,
            seller: seller
        });
    }

    function setShortCallStart(
        bytes32 id,
        uint32 callStart
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].callTimestamp = callStart;
    }

    function setShortLender(
        bytes32 id,
        address who
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].lender = who;
    }

    function setShortSeller(
        bytes32 id,
        address who
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].seller = who;
    }

    function setShortClosedAmount(
        bytes32 id,
        uint closedAmount
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].closedAmount = closedAmount;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function setShortAmount(
        bytes32 id,
        uint amount
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].shortAmount = amount;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function setShortInterestRate(
        bytes32 id,
        uint rate
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].interestRate = rate;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function setShortCallTimeLimit(
        bytes32 id,
        uint32 limit
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].callTimeLimit = limit;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function setShortLockoutTime(
        bytes32 id,
        uint32 time
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].lockoutTime = time;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function setShortMaxDuration(
        bytes32 id,
        uint32 maxDuration
    )
        requiresAuthorization
        external
    {
        require(containsShort(id));
        shorts[id].maxDuration = maxDuration;
    }

    function deleteShort(
        bytes32 id
    )
        requiresAuthorization
        external
    {
        delete shorts[id];
    }

    function markShortClosed(
        bytes32 id
    )
        requiresAuthorization
        external
    {
        closedShorts[id] = true;
    }

    /**
     * NOTE: Currently unused, added as a utility for later versions of ShortSell
     */
    function unmarkShortClosed(
        bytes32 id
    )
        requiresAuthorization
        external
    {
        closedShorts[id] = false;
    }

    // -------------------------------------
    // ----- Public Constant Functions -----
    // -------------------------------------

    /**
     * Get a Short by id. This does not validate the short exists. If the short does not exist
     * all 0's will be returned.
     */
    function getShort(
        bytes32 id
    )
        view
        external
        returns (
            address underlyingToken,
            address baseToken,
            uint shortAmount,
            uint closedAmount,
            uint interestRate,
            uint32 callTimeLimit,
            uint32 lockoutTime,
            uint32 startTimestamp,
            uint32 callTimestamp,
            uint32 maxDuration,
            address lender,
            address seller
        )
    {
        ShortSellCommon.Short storage short = shorts[id];

        return (
            short.underlyingToken,
            short.baseToken,
            short.shortAmount,
            short.closedAmount,
            short.interestRate,
            short.callTimeLimit,
            short.lockoutTime,
            short.startTimestamp,
            short.callTimestamp,
            short.maxDuration,
            short.lender,
            short.seller
        );
    }

    function getShortLender(
        bytes32 id
    )
        view
        external
        returns (address _lender)
    {
        return shorts[id].lender;
    }

    function getShortSeller(
        bytes32 id
    )
        view
        external
        returns (address _seller)
    {
        return shorts[id].seller;
    }

    function getShortBaseToken(
        bytes32 id
    )
        view
        external
        returns (address _baseToken)
    {
        return shorts[id].baseToken;
    }

    function getShortUnderlyingToken(
        bytes32 id
    )
        view
        external
        returns (address _underlyingToken)
    {
        return shorts[id].underlyingToken;
    }

    function getShortAmount(
        bytes32 id
    )
        view
        external
        returns (uint _shortAmount)
    {
        return shorts[id].shortAmount;
    }

    function getShortClosedAmount(
        bytes32 id
    )
        view
        external
        returns (uint _closedAmount)
    {
        return shorts[id].closedAmount;
    }

    function getShortInterestRate(
        bytes32 id
    )
        view
        external
        returns (uint _interestRate)
    {
        return shorts[id].interestRate;
    }

    function getShortStartTimestamp(
        bytes32 id
    )
        view
        external
        returns (uint32 _startTimestamp)
    {
        return shorts[id].startTimestamp;
    }

    function getShortCallTimestamp(
        bytes32 id
    )
        view
        external
        returns (uint32 _callTimestamp)
    {
        return shorts[id].callTimestamp;
    }

    function getShortCallTimeLimit(
        bytes32 id
    )
        view
        external
        returns (uint32 _callTimeLimit)
    {
        return shorts[id].callTimeLimit;
    }

    function getShortLockoutTime(
        bytes32 id
    )
        view
        external
        returns (uint32 _lockoutTime)
    {
        return shorts[id].lockoutTime;
    }

    function getShortMaxDuration(
        bytes32 id
    )
        view
        external
        returns (uint32 _maxDuration)
    {
        return shorts[id].maxDuration;
    }

    function containsShort(
        bytes32 id
    )
        view
        public // Used by other ShortSellRepo functions
        returns (bool exists)
    {
        return shorts[id].startTimestamp != 0;
    }
}
