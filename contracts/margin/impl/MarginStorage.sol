pragma solidity 0.4.21;
pragma experimental "v0.5.0";

import { MarginState } from "./MarginState.sol";


/**
 * @title MarginStorage
 * @author dYdX
 *
 * This contract serves as the storage for the entire state of Margin
 */
contract MarginStorage {

    MarginState.State state;

}
