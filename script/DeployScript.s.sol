//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentrailisedStableCoin} from "../src/Decentrailisedstablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployScript is Script {

    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function run() external returns(DecentrailisedStableCoin, DSCEngine, HelperConfig){
        HelperConfig config = new HelperConfig();
        (address wethPriceFeed, address weth, address wbtPriceFeed, address wbtc, uint256 deployKey) = config.activeNetworkConfig();


        tokenAddress = [weth, wbtc];
        priceFeedAddress = [wethPriceFeed, wbtPriceFeed];

        vm.startBroadcast();
        DecentrailisedStableCoin dsc = new DecentrailisedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokenAddress, priceFeedAddress, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return(dsc, dscEngine, config);
    }
    

}

