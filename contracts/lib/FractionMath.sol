pragma solidity 0.4.19;

import { Fraction256 } from "./Fraction256.sol";
import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";


library FractionMath {
    using SafeMath for uint256;

    function add(
        Fraction256.Fraction memory a,
        Fraction256.Fraction memory b
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        return bound(
            Fraction256.Fraction({
                num: (a.num.mul(b.den)).add(b.num.mul(a.den)),
                den: a.den.mul(b.den)
            })
        );
    }

    function sub(
        Fraction256.Fraction memory a,
        Fraction256.Fraction memory b
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        return bound(
            Fraction256.Fraction({
                num: (a.num.mul(b.den)).sub(b.num.mul(a.den)),
                den: a.den.mul(b.den)
            })
        );
    }

    function div(
        Fraction256.Fraction memory a,
        uint256 d
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        return bound(
            Fraction256.Fraction({
                num: a.num,
                den: a.den.mul(d)
            })
        );
    }

    function mul(
        Fraction256.Fraction memory a,
        Fraction256.Fraction memory b
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        return bound(
            Fraction256.Fraction({
                num: a.num.mul(b.num),
                den: a.den.mul(b.den)
            })
        );
    }

    function mul(
        Fraction256.Fraction memory a,
        uint256 m
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        return bound(
            Fraction256.Fraction({
                num: a.num.mul(m),
                den: a.den
            })
        );
    }

    /**
     * If necessary, reduces the numerator and denominator to be less than 2**127, attempting to
     * keep the Fraction256.Fraction as accurate as possible
     */
    function bound(
        Fraction256.Fraction memory a
    )
        pure
        internal
        returns (Fraction256.Fraction memory)
    {
        uint256 max = a.num > a.den ? a.num : a.den;
        uint256 diff = (max >> 127) + 1;
        if (diff > 1) {
            a.num = a.num.div(diff);
            a.den = a.den.div(diff);
        }
        validate(a);
        return a;
    }

    function validate(
        Fraction256.Fraction memory a
    )
        pure
        internal
    {
        assert(a.num < 2**127 && a.den < 2**127 && a.den > 0);
    }
}
