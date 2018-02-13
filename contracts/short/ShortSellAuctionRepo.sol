pragma solidity 0.4.19;

import { NoOwner } from "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import { StaticAccessControlled } from "../lib/StaticAccessControlled.sol";


/**
 * @title ShortSellAuctionRepo
 * @author dYdX
 *
 * This contract is used to store state for short sell auctions
 */
contract ShortSellAuctionRepo is StaticAccessControlled, NoOwner {
    // -----------------------
    // ------- Structs -------
    // -----------------------

    struct AuctionOffer {
        uint offer;
        address bidder;
        bool exists;
    }

    // ---------------------------
    // ----- State Variables -----
    // ---------------------------

    // Mapping that contains all short sells. Mapped by: shortId -> Short
    mapping(bytes32 => AuctionOffer) public auctionOffers;

    // -------------------------
    // ------ Constructor ------
    // -------------------------

    function ShortSellAuctionRepo(
        uint _gracePeriod
    )
        public
        StaticAccessControlled(_gracePeriod)
    {}

    // --------------------------------------------------
    // ---- Authorized Only State Changing Functions ----
    // --------------------------------------------------

    function setAuctionOffer(
        bytes32 shortId,
        uint offer,
        address bidder
    )
        requiresAuthorization
        external
    {
        auctionOffers[shortId] = AuctionOffer({
            offer: offer,
            bidder: bidder,
            exists: true
        });
    }

    function deleteAuctionOffer(
        bytes32 shortId
    )
        requiresAuthorization
        external
    {
        delete auctionOffers[shortId];
    }

    // -------------------------------------
    // ----- Public Constant Functions -----
    // -------------------------------------

    function getAuction(
        bytes32 shortId
    )
        view
        public
        returns (
            uint _offer,
            address _bidder,
            bool _exists
        )
    {
        AuctionOffer memory auctionOffer = auctionOffers[shortId];

        return (
            auctionOffer.offer,
            auctionOffer.bidder,
            auctionOffer.exists
        );
    }

    function containsAuction(
        bytes32 shortId
    )
        view
        public
        returns (bool exists)
    {
        return auctionOffers[shortId].exists;
    }
}
