//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentrailisedStableCoin} from "../../src/Decentrailisedstablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

contract Handler is Test{

    DecentrailisedStableCoin dsc;
    DSCEngine dsce;
    MockV3Aggregator public ethUsdPriceFeed;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    address[] public userWithCollateralDeposited;

    uint256 public timeMintisCalled;
    uint256 public timeDepositCollateralCalled;

    constructor(DSCEngine _engine,DecentrailisedStableCoin _dsc){
        dsce = _engine;
        dsc = _dsc;


        address[] memory collateralToken = dsce.get_CollateralTokens();
        weth = ERC20Mock(collateralToken[0]);
        wbtc = ERC20Mock(collateralToken[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralPriceFeed(address(weth)));
    }

  

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        //mint and approve
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);

        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        userWithCollateralDeposited.push(msg.sender);
        timeDepositCollateralCalled++;
    }


    function redeemCollateral(uint256 collateralseed, uint256 amountCollateral) public {
        
        ERC20Mock collateral = _getCollateralFromSeed(collateralseed);
        uint256 maxCollateralTokenToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);

        amountCollateral = bound(amountCollateral, 0, maxCollateralTokenToRedeem);

        if(amountCollateral == 0){
            return;
        }
        
        dsce.redeemCollateral(address(collateral), amountCollateral);
    
    }

    function mintDsc(uint256 dscamount, uint256 addressSeed) public {

        if(userWithCollateralDeposited.length == 0){
            return;
        }
        
        address sender = userWithCollateralDeposited[addressSeed % userWithCollateralDeposited.length];

        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dsce.getAccountInformation(sender);

        uint256 maxDscTomint = (totalCollateralValueInUsd/2) - totalDscMinted;

        if(maxDscTomint == 0){
            return;
        }

        dscamount = bound(dscamount,0,maxDscTomint);
        if(dscamount == 0){
            return;
        }

        
       
        vm.startPrank(sender);
        dsce.mintDsc(dscamount);
        vm.stopPrank();

        timeMintisCalled++;
    }


    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }




    //Helper Function:

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed % 2 == 0 ){
            return weth;
        }else {
            return wbtc;
        }
    }



}