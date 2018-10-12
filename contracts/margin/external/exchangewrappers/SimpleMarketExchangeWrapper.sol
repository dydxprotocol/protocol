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

pragma solidity 0.4.24;
pragma experimental "v0.5.0";

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { ISimpleMarket } from "../../../external/Maker/ISimpleMarket.sol";
import { MathHelpers } from "../../../lib/MathHelpers.sol";
import { TokenInteract } from "../../../lib/TokenInteract.sol";
import { ExchangeReader } from "../../interfaces/ExchangeReader.sol";
import { ExchangeWrapper } from "../../interfaces/ExchangeWrapper.sol";


/**
 * @title SimpleMarketExchangeWrapper
 * @author dYdX
 *
 * dYdX ExchangeWrapper to interface with Maker's (Oasis exchange) SimpleMarket or MatchingMarket
 * contracts to trade using a specific offer. Since any MatchingMarket is also a SimpleMarket, this
 * ExchangeWrapper can also be used for any MatchingMarket.
 */
contract SimpleMarketExchangeWrapper is
    ExchangeWrapper,
    ExchangeReader
{
    using SafeMath for uint256;
    using TokenInteract for address;

    // ============ Structs ============

    struct Offer {
        uint256 makerAmount;
        address makerToken;
        uint256 takerAmount;
        address takerToken;
    }

    // ============ State Variables ============

    address public SIMPLE_MARKET;

    // ============ Constructor ============

    constructor(
        address simpleMarket
    )
        public
    {
        SIMPLE_MARKET = simpleMarket;
    }

    // ============ Public Functions ============

    function exchange(
        address /*tradeOriginator*/,
        address receiver,
        address makerToken,
        address takerToken,
        uint256 requestedFillAmount,
        bytes orderData
    )
        external
        returns (uint256)
    {
        ISimpleMarket market = ISimpleMarket(SIMPLE_MARKET);
        uint256 offerId = bytesToOfferId(orderData);

        Offer memory offer = getOffer(market, offerId);
        verifyOffer(offer, makerToken, takerToken);

        // calculate maximum amount of makerToken to receive given requestedFillAmount
        uint256 makerAmount = MathHelpers.getPartialAmount(
            requestedFillAmount,
            offer.takerAmount,
            offer.makerAmount
        );

        // complete the exchange
        takerToken.approve(address(market), requestedFillAmount);
        require(
            market.buy(offerId, makerAmount),
            "SimpleMarketExchangeWrapper#exchange: Buy failed"
        );
        assert(makerToken.balanceOf(address(this)) >= makerAmount);

        ensureAllowance(
            makerToken,
            receiver,
            makerAmount
        );

        return makerAmount;
    }

    function getExchangeCost(
        address makerToken,
        address takerToken,
        uint256 desiredMakerToken,
        bytes orderData
    )
        external
        view
        returns (uint256)
    {
        ISimpleMarket market = ISimpleMarket(SIMPLE_MARKET);
        Offer memory offer = getOffer(market, bytesToOfferId(orderData));
        verifyOffer(offer, makerToken, takerToken);

        require(
            desiredMakerToken <= offer.makerAmount,
            "SimpleMarketExchangeWrapper#getExchangeCost: Offer is not large enough"
        );

        // return takerToken cost of desiredMakerToken
        return MathHelpers.getPartialAmount(
            desiredMakerToken,
            offer.makerAmount,
            offer.takerAmount
        );
    }

    function getMaxMakerAmount(
        address makerToken,
        address takerToken,
        bytes orderData
    )
        external
        view
        returns (uint256)
    {
        ISimpleMarket market = ISimpleMarket(SIMPLE_MARKET);
        Offer memory offer = getOffer(market, bytesToOfferId(orderData));
        verifyOffer(offer, makerToken, takerToken);

        return offer.makerAmount;
    }

    // ============ Private Functions ============

    function ensureAllowance(
        address token,
        address spender,
        uint256 requiredAmount
    )
        private
    {
        if (token.allowance(address(this), spender) < requiredAmount) {
            token.approve(spender, MathHelpers.maxUint256());
        }
    }

    function getOffer(
        ISimpleMarket market,
        uint256 offerId
    )
        private
        view
        returns (Offer memory)
    {
        (
            uint256 offerMakerAmount,
            address offerMakerToken,
            uint256 offerTakerAmount,
            address offerTakerToken
        ) = market.getOffer(offerId);

        return Offer({
            makerAmount: offerMakerAmount,
            makerToken: offerMakerToken,
            takerAmount: offerTakerAmount,
            takerToken: offerTakerToken
        });
    }

    function verifyOffer(
        Offer memory offer,
        address makerToken,
        address takerToken
    )
        private
        pure
    {
        require(
            makerToken == offer.makerToken,
            "SimpleMarketExchangeWrapper#verifyOffer: offer makerToken does not match"
        );
        require(
            takerToken == offer.takerToken,
            "SimpleMarketExchangeWrapper#verifyOffer: offer takerToken does not match"
        );
    }

    function bytesToOfferId(
        bytes orderData
    )
        private
        pure
        returns (uint256)
    {
        require(
            orderData.length == 32,
            "SimpleMarketExchangeWrapper:#bytesToOfferId: orderData is not the right length"
        );

        uint256 offerId;

        /* solium-disable-next-line security/no-inline-assembly */
        assembly {
            offerId := mload(add(orderData, 32))
        }

        return offerId;
    }
}
