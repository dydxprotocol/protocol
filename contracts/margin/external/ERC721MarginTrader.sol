pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { ReentrancyGuard } from "zeppelin-solidity/contracts/ReentrancyGuard.sol";
import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";
import { ERC721Token } from "zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import { Margin } from "../Margin.sol";
import { ClosePositionDelegator } from "../interfaces/ClosePositionDelegator.sol";
import { TraderCustodian } from "./interfaces/TraderCustodian.sol";


/**
 * @title ERC721MarginTrader
 * @author dYdX
 *
 * Contract used to tokenize margin positions as ERC721-compliant non-fungible tokens. Holding the
 * token allows the holder to close the margin position. Functionality is added to let users approve
 * other addresses to close their positions for them.
 */
 /* solium-disable-next-line */
contract ERC721MarginTrader is
    ERC721Token,
    ClosePositionDelegator,
    TraderCustodian,
    ReentrancyGuard {
    using SafeMath for uint256;

    // ============ Events ============

    event CloserApproval(
        address indexed owner,
        address indexed approved,
        bool isApproved
    );

    event RecipientApproval(
        address indexed owner,
        address indexed approved,
        bool isApproved
    );

    // ============ State Variables ============

    // Mapping from an address to other addresses that are approved to be position closers
    mapping (address => mapping (address => bool)) public approvedClosers;

    // Mapping from an address to other addresses that are approved to be payoutRecipients
    mapping (address => mapping (address => bool)) public approvedRecipients;

    // ============ Constructor ============

    function ERC721MarginTrader(
        address margin
    )
        ERC721Token("dYdX Margin Positions", "dYdX")
        public
        ClosePositionDelegator(margin)
    {
    }

    // ============ Token-Holder functions ============

    /**
     * Approve any close with the specified closer as the msg.sender of the close.
     *
     * @param  closer      Address of the closer
     * @param  isApproved  True if approving the closer, false if revoking approval
     */
    function approveCloser(
        address closer,
        bool isApproved
    )
        nonReentrant
        external
    {
        // cannot approve self since any address can already close its own margin positions
        require(closer != msg.sender);

        if (approvedClosers[msg.sender][closer] != isApproved) {
            approvedClosers[msg.sender][closer] = isApproved;
            emit CloserApproval(msg.sender, closer, isApproved);
        }
    }

    /**
     * Approve any close with the specified recipient as the payoutRecipient of the close.
     *
     * NOTE: An account approving itself as a recipient is often a very bad idea. A smart contract
     * that approves itself should implement the PayoutRecipient interface for dYdX to verify that
     * it is given a fair payout for an external account closing the position.
     *
     * @param  recipient   Address of the recipient
     * @param  isApproved  True if approving the recipient, false if revoking approval
     */
    function approveRecipient(
        address recipient,
        bool isApproved
    )
        nonReentrant
        external
    {
        if (approvedRecipients[msg.sender][recipient] != isApproved) {
            approvedRecipients[msg.sender][recipient] = isApproved;
            emit RecipientApproval(msg.sender, recipient, isApproved);
        }
    }

    /**
     * Transfer ownership of the margin position to an arbitrary address, thereby burning the token
     *
     * @param  marginId  Unique ID of the margin position
     * @param  to        Address to transfer position ownership to
     */
    function transferAsTrader(
        bytes32 marginId,
        address to
    )
        nonReentrant
        external
    {
        uint256 tokenId = uint256(marginId);
        require(msg.sender == ownerOf(tokenId));
        _burn(msg.sender, tokenId); // requires msg.sender to be owner
        Margin(MARGIN).transferAsTrader(marginId, to);
    }

    /**
     * Burn an invalid token. Callable by anyone. Used to burn unecessary tokens for clarity and to
     * free up storage. Throws if the position is not yet closed.
     *
     * @param  marginId  Unique ID of the margin position
     */
    function burnTokenSafe(
        bytes32 marginId
    )
        nonReentrant
        external
    {
        require(!Margin(MARGIN).containsPosition(marginId));
        _burn(ownerOf(uint256(marginId)), uint256(marginId));
    }

    // ============ Margin-Only Functions ============

    /**
     * Called by the Margin contract when anyone transfers ownership of a position to this contract.
     * This function mints a new ERC721 Token and returns this address to
     * indicate to Margin that it is willing to take ownership of the margin position.
     *
     * @param  from      Address of previous position owner
     * @param  marginId  Unique ID of the margin position
     * @return           This address on success, throw otherwise
     */
    function receiveOwnershipAsTrader(
        address from,
        bytes32 marginId
    )
        onlyMargin
        nonReentrant
        external
        returns (address)
    {
        _mint(from, uint256(marginId));
        return address(this); // returning own address retains ownership of position
    }

    function marginPositionIncreased(
        address from,
        bytes32 marginId,
        uint256 /* amountAdded */
    )
        onlyMargin
        external
        returns (bool)
    {
        require(ownerOf(uint256(marginId)) != from);
        return true;
    }

    /**
     * Called by Margin when an owner of this token is attempting to close some of the margin
     * position. Implementation is required per TraderOwner contract in order to be used by
     * Margin to approve closing parts of a margin position. If true is returned, this contract
     * must assume that Margin will either revert the entire transaction or that the specified
     * amount of the margin position was successfully closed.
     *
     * @param closer           Address of the caller of the close function
     * @param payoutRecipient  Address of the recipient of any quote tokens paid out
     * @param marginId         Unique ID of the margin position
     * @param requestedAmount  Amount of the margin position being closed
     * @return                 The amount the user is allowed to close for the specified position
     */
    function closePositionOnBehalfOf(
        address closer,
        address payoutRecipient,
        bytes32 marginId,
        uint256 requestedAmount
    )
        onlyMargin
        nonReentrant
        external
        returns (uint256)
    {
        // Cannot burn the token since the position hasn't been closed yet and getPositionDeedHolder
        // must return the owner of the margin position after it has been closed within the current
        // transaction.

        address owner = ownerOf(uint256(marginId));
        if (
            (closer == owner)
            || approvedClosers[owner][closer]
            || approvedRecipients[owner][payoutRecipient]
        ) {
            return requestedAmount;
        }

        return 0;
    }

    // ============ TraderCustodian Functions ============

    function getPositionDeedHolder(
        bytes32 marginId
    )
        external
        view
        returns (address)
    {
        return ownerOf(uint256(marginId));
    }
}