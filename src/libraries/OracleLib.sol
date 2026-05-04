//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title OracleLib
 * @author Pratik Das
 * @notice The library is used to check the ChainLink Oracle for Stale Data.
 * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design
 * We want the DSCEngine to freeze if prices become state
 */

library IOracleLib {

    error OracleLib__StalePrice();
    uint256 private constant TIMEOUT = 3 hours;


    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundid, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answerinRound) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if(secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundid, answer, startedAt, updatedAt, answerinRound);
    }
}