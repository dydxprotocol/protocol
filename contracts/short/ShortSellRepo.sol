pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/NoOwner.sol';
import '../lib/AccessControlled.sol';

contract ShortSellRepo is AccessControlled, NoOwner {
    // ---------------------------
    // ----- State Variables -----
    // ---------------------------

    struct Short {
        uint shortAmount;
        uint interestRate;
        address underlyingToken;
        address baseToken;
        address lender;
        address seller;
        uint32 startTimestamp;
        uint32 callTimestamp;
        uint32 callTimeLimit;
        uint32 lockoutTime;
    }

    mapping(bytes32 => Short) public shorts;

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function ShortSellRepo(
        uint _accessDelay,
        uint _gracePeriod
    ) AccessControlled(_accessDelay, _gracePeriod) public {}

    // -----------------------------------------
    // ---- Public State Changing Functions ----
    // -----------------------------------------

    function addShort(
        bytes32 id,
        address underlyingToken,
        address baseToken,
        uint shortAmount,
        uint interestRate,
        uint32 callTimeLimit,
        uint32 lockoutTime,
        uint32 startTimestamp,
        address lender,
        address seller
    ) requiresAuthorization public {
        require(!containsShort(id));

        shorts[id] = Short({
            underlyingToken: underlyingToken,
            baseToken: baseToken,
            shortAmount: shortAmount,
            interestRate: interestRate,
            callTimeLimit: callTimeLimit,
            lockoutTime: lockoutTime,
            startTimestamp: startTimestamp,
            callTimestamp: 0, // Not set until later
            lender: lender,
            seller: seller
        });
    }

    function setShortCallStart(
        bytes32 id,
        uint32 callStart
    ) requiresAuthorization public {
        require(containsShort(id));
        shorts[id].callTimestamp = callStart;
    }

    function setShortLender(
        bytes32 id,
        address who
    ) requiresAuthorization public {
        require(containsShort(id));
        shorts[id].lender = who;
    }

    function setShortSeller(
        bytes32 id,
        address who
    ) requiresAuthorization public {
        require(containsShort(id));
        shorts[id].seller = who;
    }

    function deleteShort(
        bytes32 id
    ) requiresAuthorization public {
        delete shorts[id];
    }

    // -------------------------------------
    // ----- Public Constant Functions -----
    // -------------------------------------

    function getShort(
        bytes32 id
    ) view public returns (
        address underlyingToken,
        address baseToken,
        uint shortAmount,
        uint interestRate,
        uint32 callTimeLimit,
        uint32 lockoutTime,
        uint32 startTimestamp,
        uint32 callTimestamp,
        address lender,
        address seller
    ) {
        Short storage short = shorts[id];

        return (
            short.underlyingToken,
            short.baseToken,
            short.shortAmount,
            short.interestRate,
            short.callTimeLimit,
            short.lockoutTime,
            short.startTimestamp,
            short.callTimestamp,
            short.lender,
            short.seller
        );
    }

    function containsShort(
        bytes32 id
    ) view public returns (
        bool exists
    ) {
        return shorts[id].startTimestamp != 0;
    }
}
