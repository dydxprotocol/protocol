pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../shared/Exchange.sol";
import "../shared/Proxy.sol";
import "../lib/SafeMath.sol";

/**
 * @title CoveredOption
 * @author Antonio Juliano
 *
 * CoveredOption represents a specific type of covered option corresponding to
 * a unique combination of:
 *
 *    - underlyingToken
 *    - baseToken
 *    - expirationTimestamp
 *    - underlyingTokenStrikeRate
 *    - baseTokenStrikeRate
 *
 * This contract facilitates issuance and exercise of its type of options
 * Each option adheres to the ERC20 token standard to allow transfer and trading
 * of options after issuance
 */
contract CoveredOption is SafeMath {
    // ----------------------------
    // ---- Constant Variables ----
    // ----------------------------

    // Address of the underlying token. This is the token underlying the option.
    // Must implement the ERC20 token standard
    address public underlyingToken;

    // Address of the base token. This token will be used to pay premiums as well as to pay the
    // strike price upon option exercise. Must implement the ERC20 token standard
    address public baseToken;

    // Timestamp indicating the expiration date of this option
    // TODO make sure in millis
    uint256 public expirationTimestamp;

    // The strike price is made up of an exchange rate between underlying and base token
    uint public underlyingTokenStrikeRate;
    uint public baseTokenStrikeRate;

    // ---------------------------
    // ----- State Variables -----
    // ---------------------------

    // Address of the 0x Exchange Contract
    // TODO how to change
    address public exchange;

    // Address of the dYdX Proxy Contract
    address public proxy;

    // Mapping containing the numbers of options owned by each address
    mapping(address => uint256) public balances;

    // Mapping containing the numbers of options written by each address
    mapping(address => uint256) public writers;

    // Total number of options outstanding
    uint256 public totalOptions;

    // Total amount of baseToken collected on option exercise and held by this contract
    uint256 public totalBaseToken;

    // Total number of options written
    uint256 public totalWritten;

    // Total number of options withdrawn after expiration
    uint256 public totalWithdrawn;

    // Total number of options exercised
    uint256 public totalExercised;

    // ------------------------
    // -------- Events --------
    // ------------------------

    /**
     * Buy event indicating new options were issued
     */
    event Buy(
        address indexed writer,
        address indexed buyer,
        uint options,
        uint premium,
        uint256 timestamp
    );

    /**
     * Exercise event indicating an options holder exercised some or all of their options
     */
    event Exercise(
        address indexed exerciser,
        uint amount,
        uint256 timestamp
    );

    /**
     * Withdrawal event indicating a writer withdrew their share of base and underlying token
     * after the option expired
     */
    event Withdrawal(
        address indexed withdrawer,
        uint balance,
        uint underlyingTokenAmount,
        uint baseTokenAmount
    );

    /**
     * Recovery event indicating an address which both wrote and held options traded in
     * options in exchange for the underlying token
     */
    event Recovery(
        address indexed recoverer,
        uint amount,
        uint256 timestamp
    );

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function CoveredOption(
        address _underlyingToken,
        address _baseToken,
        uint256 _expirationTimestamp,
        uint256 _underlyingTokenStrikeRate,
        uint256 _baseTokenStrikeRate,
        address _exchange,
        address _proxy
    ) public {
        underlyingToken = _underlyingToken;
        baseToken = _baseToken;
        expirationTimestamp = _expirationTimestamp;
        underlyingTokenStrikeRate = _underlyingTokenStrikeRate;
        baseTokenStrikeRate = _baseTokenStrikeRate;
        exchange = _exchange;
        proxy = _proxy;
    }

    // -----------------------------------------
    // ---- Public State Changing Functions ----
    // -----------------------------------------

    /**
     * Issue new options from a given writer offer. Options can be issued anytime before the
     * expiration time of the option
     *
     * 1 - baseToken premium is transfered from buyer to this CoveredOption
     * 2 - 0x Exchange Contract is called to exchange baseToken premium for underlyingToken.
     *     underlyingToken is kept by CoveredOption as colateral
     * 3 - balances balance of buyer is increased by number of options purchased
     * 4 - writers balance for the writer is increased by number of options written
     * 5 - If there is excess baseToken not used by the 0x trade, transfer it back to the buyer
     * 6 - totalOptions is incremented by the number of options written
     *     totalWritten is incremented by the number of options written
     * 7 - Buy event is recorded
     *
     * @param  orderAddresses Array of addresses corresponding to:
     *
     *  [0] = writer
     *  [1] = feeRecipient
     *  [2] = makerFeeToken
     *  [3] = takerFeeToken
     *
     * @param  orderValues    array containing:
     *
     * [0] = underlyingTokenAmount
     * [1] = baseTokenAmount
     * [2] = writerFee
     * [3] = buyerFee
     * [4] = expirationTimestampInSec
     * [5] = salt
     *
     * @param  maximumPremium Maximum amount of premium in baseToken the the buyer wishes to pay
     *                        new options will be issued on a 1:1 basis with number of
     *                        underlyingToken transfered in by the writer as per the
     *                        exchange rate offered in the trade
     * @param  v              ECDSA signature parameter v
     * @param  r              CDSA signature parameters r
     * @param  s              CDSA signature parameters s
     * @return _optionsIssued number of options issued to the buyer
     */
    function buy(
        address[4] orderAddresses,
        uint[6] orderValues,
        uint maximumPremium,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (
        uint _optionsIssued
    ) {
        require(maximumPremium > 0);
        require(block.timestamp < expirationTimestamp);

        // Transfer the maximum baseToken premium from the sender to CoveredOption
        Proxy(proxy).transfer(baseToken, msg.sender, maximumPremium);

        address writer = orderAddresses[0];

        // Transfer taker fee
        uint takerFee = getPartialAmount(
            maximumPremium,
            orderValues[1],
            orderValues[3]
        );
        Proxy(proxy).transfer(orderAddresses[3], msg.sender, takerFee);

        // Call the the Exchange Contract to exchange the baseToken premium for the underlyingToken
        uint premium = Exchange(exchange).fillOrder(
            [
                writer,
                address(this),
                underlyingToken,
                baseToken,
                orderAddresses[1],
                orderAddresses[2],
                orderAddresses[3]
            ],
            orderValues,
            maximumPremium,
            true,
            v,
            r,
            s
        );

        uint optionsIssued = getPartialAmount(
            orderValues[0],
            orderValues[1],
            premium
        );

        require(premium > 0);
        require(optionsIssued > 0);

        // Increment balances
        balances[msg.sender] = add(balances[msg.sender], optionsIssued);
        writers[writer] = add(writers[writer], optionsIssued);

        // Send back any excess baseToken premium taken from sender
        // TODO make sure state of token has updated from first call
        if (premium < maximumPremium) {
            ERC20(baseToken).transfer(
                msg.sender,
                sub(maximumPremium, premium)
            );

            // Send back extra taker fee
            uint extraTakerTokenAmount = sub(
                takerFee,
                getPartialAmount(
                    premium,
                    orderValues[1],
                    orderValues[3]
                )
            );
            ERC20(orderAddresses[3]).transfer(
                msg.sender,
                extraTakerTokenAmount
            );
        }

        // Increment totals
        totalOptions = add(totalOptions, optionsIssued);
        totalWritten = add(totalWritten, optionsIssued);

        Buy(writer, msg.sender, optionsIssued, premium, block.timestamp);

        return optionsIssued;
    }

    /**
     * Exercise an amount of options. Exercising costs amount * (strike price) of baseToken. Holders
     * can exercise any amount of options less than or equal to the number they own at any time
     * before the option expiration date
     *
     * 1 - price in baseToken is calculated based on the number of options being exercised
     *     and strike price
     * 2 - amount of options being exercised are deducted from holder's balance
     * 3 - total price in baseToken is transfered to CoveredOption from the sender
     * 4 - amount of underlyingToken is transfered to the sender
     * 5 - totalExercised is incremented by amount exercised
     *     totalOptions is decremented by amount exercised
     *     totalBaseToken is incremented by the amount of baseToken paid to CoveredOption
     * 6 - Exercise event is recorded
     *
     * @param  amount                number of options to exercise
     * @return _totalBaseTokenPrice  total price in baseToken paid for exercise
     */
    function exercise(
        uint amount
    ) external returns (
        uint _totalBaseTokenPrice
    ) {
        require(amount > 0);

        uint256 balance = balances[msg.sender];
        require(balance >= amount);
        require(block.timestamp < expirationTimestamp);

        // Calculate total exercise price in baseToken
        // TODO make sure there is no rounding error weirdness
        uint totalBaseTokenPrice = getPartialAmount(
            baseTokenStrikeRate,
            underlyingTokenStrikeRate,
            amount
        );

        require(totalBaseTokenPrice > 0);

        // TODO make sure no reentrancy attack here

        // Deduct balance
        balances[msg.sender] = sub(balance, amount);

        // Transfer total base token price from sender
        Proxy(proxy).transfer(baseToken, msg.sender, totalBaseTokenPrice);

        // Transfer underlyingToken to sender
        require(ERC20(underlyingToken).transfer(msg.sender, amount));

        // Update totals
        // TODO is it ok to set these at the end?
        totalExercised = add(totalExercised, amount);
        totalOptions = sub(totalOptions, amount);
        totalBaseToken = add(totalBaseToken, totalBaseTokenPrice);

        Exercise(msg.sender, amount, block.timestamp);

        return(totalBaseTokenPrice);
    }

    /**
     * Withdraw a writer's portion of baseToken and underlyingToken.
     * Can only be done after expiration of the option
     *
     * Note: this function can be called by any address. There is no reason for a writer not to
     *       withdraw, so anyone can trigger this
     *
     * 1 - Set the writer's balance to 0
     * 2 - Calculate the writer's amount of baseToken and underlyingToken that can be withdrawn
     *     based on the total amount of each token held by CoveredOption and the proportion of
     *     options written by the writer
     * 3 - Transfer the writer their amount of both baseToken and underlyingToken
     * 4 - Increment totalWithdrawn by the writer's original balance
     * 5 - Record a Withdrawal event
     *
     * @return _underlyingTokenAmount amount of underlyingToken withdrawn
     * @return _baseTokenAmount       amount of baseToken withdrawn
     */
    function withdraw(
        address writer
    ) external returns (
        uint _underlyingTokenAmount,
        uint _baseTokenAmount
    ) {
        // Validations
        uint256 balance = writers[writer];
        require(block.timestamp > expirationTimestamp);
        require(balance > 0);

        // Zero the writer's written balance
        writers[writer] = 0;

        // Calculate amount of each token the writer can withdraw
        // TODO understand rounding errors
        // TODO make sure this is right
        uint underlyingTokenAmount = getPartialAmount(
            balance,
            totalWritten,
            totalOptions
        );
        uint baseTokenAmount = getPartialAmount(
            balance,
            totalWritten,
            totalBaseToken
        );

        // Transfer each token to the writer
        // TODO make sure no reentrancy attack
        if (underlyingTokenAmount > 0) {
            require(ERC20(underlyingToken).transfer(writer, underlyingTokenAmount));
        }
        if (baseTokenAmount > 0) {
            require(ERC20(baseToken).transfer(writer, baseTokenAmount));
        }

        // Update totals
        totalWithdrawn = add(totalWithdrawn, balance);

        Withdrawal(writer, balance, underlyingTokenAmount, baseTokenAmount);

        return (underlyingTokenAmount, baseTokenAmount);
    }

    /**
     * Recover the underlyingToken deposited by a writer. The writer must own options greater than
     * or equal to the recovery amount, and must have also written at least as many options.
     * Recovery can only be performed before the expiration of the option
     *
     * 1 - Sender's written balance is decremented by the amount
     * 2 - Sender's holder balance is decremented by the amount
     * 3 - amount of underlyingToken is transfered to the sender
     * 4 - Recovery event is recorded
     *
     * @param  amount amount of underlyingToken to recover
     */
    function recover(
        uint amount
    ) external {
        // Validations
        require(amount > 0);
        require(block.timestamp < expirationTimestamp);

        uint256 written = writers[msg.sender];
        uint256 balance = balances[msg.sender];

        require(written >= amount);
        require(balance >= amount);

        // Deduct from writer balance and balances
        writers[msg.sender] = sub(written, amount);
        balances[msg.sender] = sub(balance, amount);

        // Transfer underlyingToken to sender
        require(ERC20(underlyingToken).transfer(msg.sender, amount));

        // Update totals
        totalOptions = sub(totalOptions, amount);
        totalWritten = sub(totalWritten, amount);

        Recovery(msg.sender, amount, block.timestamp);
    }

    // ---------------------
    // ------- ERC20 -------
    // ---------------------

    mapping (address => mapping (address => uint256)) allowed;

    function transfer(
        address to,
        uint value
    ) public returns (
        bool ok
    ) {
        if (balances[msg.sender] >= value) {
            balances[msg.sender] = sub(balances[msg.sender], value);
            balances[to] = add(balances[to], value);
            Transfer(msg.sender, to, value);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(
        address from,
        address to,
        uint value
    ) public returns (
        bool ok
    ) {
        if (balances[from] >= value && allowed[from][msg.sender] >= value) {
            balances[to] = add(balances[to], value);
            balances[from] = sub(balances[from], value);
            allowed[from][msg.sender] = sub(allowed[from][msg.sender], value);
            Transfer(from, to, value);
            return true;
        } else {
            return false;
        }
    }

    function approve(
        address spender,
        uint value
    ) public returns (
        bool ok
    ) {
      allowed[msg.sender][spender] = value;
      Approval(msg.sender, spender, value);
      return true;
    }

    function totalSupply() view public returns (
        uint supply
    ) {
        return totalOptions;
    }

    function balanceOf(
        address who
    ) view public returns (
        uint value
    ) {
        return balances[who];
    }

    function allowance(
        address owner,
        address spender
    ) view public returns (
        uint _allowance
    ) {
        return allowed[owner][spender];
    }

    // TODO make this deterministic based on option parameters
    function name() pure public returns (
        string _name
    ) {
        return "dYdX Covered Option";
    }

    // TODO make this deterministic based on option parameters
    function symbol() pure public returns (
        string _symbol
    ) {
        return "dYdX";
    }

    // Decimals for the option will always match decimals for the underlying token
    // since options are issued on a 1:1 basis with underlyingToken
    function decimals() pure public returns (
        uint8 _decimals
    ) {
        return 18; // TODO ERC20(underlyingToken).decimals();
    }

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
