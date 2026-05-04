// //SPDX-License-Identifier: MIT

// pragma solidity ^0.8.18;

// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DecentrailisedStableCoin} from "../../src/Decentrailisedstablecoin.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DeployScript} from "../../script/DeployScript.s.sol";
// import {Handler} from "./Handler.t.sol";

// contract InvariantTest is StdInvariant, Test {
    
//     DSCEngine dsce;
//     DecentrailisedStableCoin dsc;
//     HelperConfig helperConfig;
//     DeployScript deployer;
//     address weth;
//     address wbtc;
//     Handler handler;

//     function setUp() external {
//         deployer = new DeployScript();
//         (dsc, dsce, helperConfig) = deployer.run();
//         (,weth,,wbtc,)= helperConfig.activeNetworkConfig();
//         handler = new Handler(dsce, dsc);
//         targetContract(address(handler));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalsupply = dsc.totalSupply();
//         uint256 wethDeposited = IERC20(weth).balanceOf(address(dsce));
//         uint256 wbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

//         uint256 wethValue = dsce.getUsdValue(weth, wethDeposited);
//         uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

//         console.log("Weth Value: ", wethValue);
//         console.log("Wbtc Value: ", wbtcValue);
//         console.log("Total Supply: ", totalsupply);

//         assert(wethValue + wbtcValue >= totalsupply);
  
//     }
    
// }