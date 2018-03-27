pragma solidity 0.4.19;

import { Fraction256 } from "./Fraction256.sol";
import { FractionMath } from "./FractionMath.sol";
import { SafeMath } from "zeppelin-solidity/contracts/math/SafeMath.sol";


library Exponent {
    using SafeMath for uint256;
    using FractionMath for Fraction256.Fraction;

    // -------------------------
    // ------ Constants --------
    // -------------------------

    // 2**128 - 1
    uint256 constant public MAX_NUMERATOR = 340282366920938463463374607431768211455;

    // Number such that e is approximated by (MAX_NUMERATOR / E_DENOMINATOR)
    uint256 constant public E_DENOMINATOR = 125182886983370532117250726298150828301;

    // Number of precomputed integers, X, for E^((1/2)^X)
    uint256 constant public MAX_PRECOMPUTE_PRECISION = 32;

    // Number of precomputed integers, X, for E^X
    uint256 constant public NUM_PRECOMPUTED_INTEGERS = 32;

    // -----------------------------------------
    // ---- Public Implementation Functions ----
    // -----------------------------------------

    /**
     * Returns e^X for any fraction X
     *
     * @param  X                    The exponent
     * @param  precomputePrecision  Accuracy of precomputed terms
     * @param  maclaurinPrecision   Accuracy of Maclaurin terms
     * @return                      e^X
     */
    function exp(
        Fraction256.Fraction memory X,
        uint256 precomputePrecision,
        uint256 maclaurinPrecision
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        require(precomputePrecision <= MAX_PRECOMPUTE_PRECISION);

        Fraction256.Fraction memory Xcopy = X.copy().bound();
        if (Xcopy.num == 0) { // e^0 = 1
            return ONE();
        }

        // get the integer value of the fraction (example: 9/4 is 2.25 so has integerValue of 2)
        uint256 integerX = Xcopy.num.div(Xcopy.den);

        // if X is less than 1, then just calculate X
        if (integerX == 0) {
            return expHybrid(Xcopy, precomputePrecision, maclaurinPrecision);
        }

        // get e^integerX
        Fraction256.Fraction memory expOfInt =
            getPrecomputedEToThe(integerX % NUM_PRECOMPUTED_INTEGERS);
        while (integerX > NUM_PRECOMPUTED_INTEGERS) {
            expOfInt = expOfInt.mul(getPrecomputedEToThe(NUM_PRECOMPUTED_INTEGERS));
            integerX -= NUM_PRECOMPUTED_INTEGERS;
        }

        // multiply e^integerX by e^decimalX
        Fraction256.Fraction memory decimalX = Fraction256.Fraction({
            num: Xcopy.num % Xcopy.den,
            den: Xcopy.den
        });
        return expHybrid(decimalX, precomputePrecision, maclaurinPrecision).mul(expOfInt);
    }

    /**
     * Returns e^X for any X < 1. Multiplies precomputed values to get close to the real value, then
     * Maclaurin Series approximation to reduce error.
     *
     * @param  X                    Exponent
     * @param  precomputePrecision  Accuracy of precomputed terms
     * @param  maclaurinPrecision   Accuracy of Maclaurin terms
     * @return                      e^X
     */
    function expHybrid(
        Fraction256.Fraction memory X,
        uint256 precomputePrecision,
        uint256 maclaurinPrecision
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        require(precomputePrecision <= MAX_PRECOMPUTE_PRECISION);
        assert(X.num < X.den);
        // will also throw if precomputePrecision is larger than the array length in getDenominator

        Fraction256.Fraction memory Xtemp = X.copy().bound();
        if (Xtemp.num == 0) { // e^0 = 1
            return ONE();
        }

        Fraction256.Fraction memory result = ONE();

        uint256 d = 1; // 2^i
        for (uint256 i = 1; i <= precomputePrecision; i++) {
            d *= 2;

            // if Fraction > 1/d, subtract 1/d and multiply result by precomputed e^(1/d)
            if (d.mul(Xtemp.num) >= Xtemp.den) {
                Xtemp.num = Xtemp.num.sub(Xtemp.den.div(d));
                result = result.mul(getPrecomputedEToTheHalfToThe(i));
            }
        }
        return result.mul(expMaclaurin(Xtemp, maclaurinPrecision));
    }

    /**
     * Returns e^X for any X, using Maclaurin Series approximation
     *
     * e^X = SUM(X^n / n!) for n >= 0
     * e^X = 1 + X/1! + X^2/2! + X^3/3! ...
     *
     * @param  X           Exponent
     * @param  precision   Accuracy of Maclaurin terms
     * @return             e^X
     */
    function expMaclaurin(
        Fraction256.Fraction memory X,
        uint256 precision
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        Fraction256.Fraction memory Xcopy = X.copy().bound();
        if (Xcopy.num == 0) { // e^0 = 1
            return ONE();
        }

        Fraction256.Fraction memory result = ONE();
        Fraction256.Fraction memory Xtemp = ONE();
        for (uint256 i = 1; i <= precision; i++) {
            Xtemp = Xtemp.mul(Xcopy.div(i));
            result = result.add(Xtemp);
        }
        return result;
    }

    // ------------------------------
    // ------ Helper Functions ------
    // ------------------------------

    function ONE(
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        return Fraction256.Fraction({ num: 1, den: 1 });
    }

    /**
     * Returns a fraction roughly equaling E^((1/2)^x) for integer x
     */
    function getPrecomputedEToTheHalfToThe(
        uint256 x
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        uint256 denominator = [
            125182886983370532117250726298150828301,
            206391688497133195273760705512282642279,
            265012173823417992016237332255925138361,
            300298134811882980317033350418940119802,
            319665700530617779809390163992561606014,
            329812979126047300897653247035862915816,
            335006777809430963166468914297166288162,
            337634268532609249517744113622081347950,
            338955731696479810470146282672867036734,
            339618401537809365075354109784799900812,
            339950222128463181389559457827561204959,
            340116253979683015278260491021941090650,
            340199300311581465057079429423749235412,
            340240831081268226777032180141478221816,
            340261598367316729254995498374473399540,
            340271982485676106947851156443492415142,
            340277174663693808406010255284800906112,
            340279770782412691177936847400746725466,
            340281068849199706686796915841848278311,
            340281717884450116236033378667952410919,
            340282042402539547492367191008339680733,
            340282204661700319870089970029119685699,
            340282285791309720262481214385569134454,
            340282326356121674011576912006427792656,
            340282346638529464274601981200276914173,
            340282356779733812753265346086924801364,
            340282361850336100329388676752133324799,
            340282364385637272451648746721404212564,
            340282365653287865596328444437856608255,
            340282366287113163939555716675618384724,
            340282366604025813553891209601455838559,
            340282366762482138471739420386372790954,
            340282366841710300958333641874363209044
        ][x];
        return Fraction256.Fraction({
            num: MAX_NUMERATOR,
            den: denominator
        });
    }



    /**
     * Returns a fraction roughly equaling E^(x) for integer x
     */
    function getPrecomputedEToThe(
        uint256 x
    )
        internal
        pure
        returns (Fraction256.Fraction memory)
    {
        uint256 denominator = [
            340282366920938463463374607431768211455,
            125182886983370532117250726298150828301,
            46052210507670172419625860892627118820,
            16941661466271327126146327822211253888,
            6232488952727653950957829210887653621,
            2292804553036637136093891217529878878,
            843475657686456657683449904934172134,
            310297353591408453462393329342695980,
            114152017036184782947077973323212575,
            41994180235864621538772677139808695,
            15448795557622704876497742989562086,
            5683294276510101335127414470015662,
            2090767122455392675095471286328463,
            769150240628514374138961856925097,
            282954560699298259527814398449860,
            104093165666968799599694528310221,
            38293735615330848145349245349513,
            14087478058534870382224480725096,
            5182493555688763339001418388912,
            1906532833141383353974257736699,
            701374233231058797338605168652,
            258021160973090761055471434334,
            94920680509187392077350434438,
            34919366901332874995585576427,
            12846117181722897538509298435,
            4725822410035083116489797150,
            1738532907279185132707372378,
            639570514388029575350057932,
            235284843422800231081973821,
            86556456714490055457751527,
            31842340925906738090071268,
            11714142585413118080082437,
            4309392228124372433711936
        ][x];
        return Fraction256.Fraction({
            num: MAX_NUMERATOR,
            den: denominator
        });
    }
}
