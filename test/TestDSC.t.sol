//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentrailisedStableCoin} from "../src/Decentrailisedstablecoin.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol"; 
import {DSCEngine} from "../src/DSCEngine.sol";
import {DeployScript} from "../script/DeployScript.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";


contract TestDSC is Test {

    DSCEngine dsce;
    DecentrailisedStableCoin dsc;
    DeployScript deployer;
    HelperConfig config;
    address weth;
    address wethUsdPriceFeed;


    // address addweth = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;


    address[] public token;
    address[] public priceFeedAddress;


    address public USER = makeAddr("user");
    address public spider = makeAddr("spider"); //LIQUIDATOR
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_BALANACE = 10 ether;
    uint256 public constant DSC_AMOUNT = 100 ether;

    function setUp() external {
        deployer = new DeployScript();
        (dsc, dsce, config) = deployer.run();
        (wethUsdPriceFeed, weth,,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANACE);
    }


    modifier depositedCollateral(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(weth, COLLATERAL_AMOUNT);
        _;
    }

    modifier depositCollateralAndMintDSC(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PRICE TEST
    //////////////////////////////////////////////////////////////*/

    function testGetUsdPrice() public{
        //15e18 * 2000ETH = 30,000e18
        uint256 ethPrice = 15e18;
        uint256 expectedPrice = 30000e18;
        uint256 actualPrice = dsce.getUsdValue(weth, ethPrice);
        assertEq(expectedPrice, actualPrice); 
    }

    function testRevertIfCollateralZero() public{
         vm.startPrank(USER);
         ERC20Mock(weth).approve(address(dsce), COLLATERAL_AMOUNT);

         vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
         dsce.depositCollateral(weth, 0);
         vm.stopPrank();
    }
    

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TEST
    //////////////////////////////////////////////////////////////*/


    function testRevertifTokenAddressAndPriceFeedAddressIsNotSameLength() public {
        token.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        priceFeedAddress.push(wethUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressANDPriceFeedAddressMustBeSameLength.selector);
        new DSCEngine(token, priceFeedAddress, address(dsc));
    }


    /*//////////////////////////////////////////////////////////////
                          GETTER FUNCTIONS TEST
    //////////////////////////////////////////////////////////////*/

    function testCollateralbalance() public depositedCollateral{
        uint256 expectedCollateralBalance = COLLATERAL_AMOUNT;
        uint256 actualCollateralBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(expectedCollateralBalance, actualCollateralBalance);
    }

    function testgetDSCMinted() public depositCollateralAndMintDSC{
        uint256 expectedDSCAmount = DSC_AMOUNT;
        uint256 actualDSCMinted = dsce.getDSCMinted(USER);
        assertEq(expectedDSCAmount, actualDSCMinted);
    }

    function testgetPrecision() public {
        uint256 valueOfPRECISION = 1e18;
        uint256 actualValueOfPRECISION = dsce.get_Precision();
        assertEq(valueOfPRECISION, actualValueOfPRECISION);
    }

    function testgetAddtionalFeedPrecision() public{
        uint256 valueofAdditional_precision = 1e10;
        uint256 actualValueOfAdditional_precision  = dsce.get_AdditionalFeedPrecision();
        assertEq(valueofAdditional_precision, actualValueOfAdditional_precision);
    }

    function testgetLiquidationbonus() public {
        uint256 valueOfLiquidationBonus = 10;
        uint256 actualValueOfLiquidationBonus = dsce.get_LiquidationBonus();
        assertEq(valueOfLiquidationBonus, actualValueOfLiquidationBonus);
    }

    function testgetLiquidationThreshold() public {
        uint256 valueOfLiquidationThreshold = 50;
        uint256 actualValueOfLiquidationThreshold = dsce.get_LiquidationThreshold();
        assertEq(valueOfLiquidationThreshold, actualValueOfLiquidationThreshold);
    }

    function testgetLiquidationPrecision() public {
        uint256 valueOfLiquidationPrecision = 100;
        uint256 actualValueOfLiquidationPrecision = dsce.get_LiquidationPrecision();
        assertEq(valueOfLiquidationPrecision, actualValueOfLiquidationPrecision);
    }

    function testgetMinHealthFactor() public {
        uint256 valueOfMinHealthFactor = 1e18;
        uint256 actualValueOfMinHealthFactor = dsce.get_minimumHealthFactor();
        assertEq(valueOfMinHealthFactor, actualValueOfMinHealthFactor);
    }

    function testlengthOfCollateralTokens() public {
        uint256 expectedLengthOfCollateralTokens = 2;
        uint256 actualLengthOfCollateralTokens = dsce.get_CollateralTokens().length;
        assertEq(expectedLengthOfCollateralTokens, actualLengthOfCollateralTokens);
    }

    function testgetDSC() public {
        address token1 = dsce.getDsc();
        console.log(token1);
    }

    /*//////////////////////////////////////////////////////////////
                           FUNDAMENTAL TESTS
    //////////////////////////////////////////////////////////////*/


    function testCanDepositCollateralWithoutMinting() public {
        //Arrange
        vm.startPrank(USER);
        uint256 amountToken = 2;
        ERC20Mock(weth).approve(address(dsce), amountToken);
        //Act
        dsce.depositCollateral(weth, amountToken);
        uint256 usercollateralDeposited = dsce.getCollateralBalanceOfUser(USER, weth);
        //Assert
        assertEq(amountToken, 2);
        
    }

    function testCanMintDSC() public {
        //Arrange
        vm.startPrank(USER);
        uint256 collateralAmount = 2 ether;
        ERC20Mock(weth).approve(address(dsce), collateralAmount);
        uint256 mintDSCAmount = 25 ether ;
        //Act 

        dsce.depositCollateral(weth, collateralAmount);
        console.log("Deposited");
        dsce.mintDsc(mintDSCAmount);
        
        //Assert
        uint256 userdscBalance = dsc.balanceOf(USER);
        assertEq(userdscBalance, mintDSCAmount);

        uint256 totalDSC = dsc.totalSupply();
        assertEq(totalDSC, mintDSCAmount);
        vm.stopPrank();

    }

    function testdepositCollateralAndMintDsc() public {
        //Arrange
        uint256 collateralAmount = 2 ether;
        uint256 dscAmount = 25 ether;

        vm.startPrank(USER);
        
        ERC20Mock(weth).approve(address(dsce), collateralAmount);
        //Act 
       
         dsce.depositCollateralAndMintDsc(weth, collateralAmount, dscAmount);
         console.log("Deposited and Minted !");

        //Assert
        uint256  userdsceBalance = dsc.balanceOf(USER);
        assertEq(userdsceBalance, dscAmount);
        console.log("The value of dscAmount: ", dscAmount);
        uint256 amount = dsce.getCollateralBalanceOfUser(USER,weth);
        console.log(amount);
        assertEq(collateralAmount, amount);
        vm.stopPrank();
    }

    function testBurnDsc() public depositCollateralAndMintDSC {
        //Arrange 
        /* Done by the depositCollatealAndMintDSC */
        uint256 burnDscAmount = 10 ether;
        //Act 
        dsc.approve(address(dsce), burnDscAmount);
        dsce.burnDsc(burnDscAmount);
        //Assert
        uint256 userDSCbalance = dsc.balanceOf(USER);
        assertEq(DSC_AMOUNT - burnDscAmount, userDSCbalance);
    }

    function testredeemCollateral() public depositedCollateral {
        //Arrange 
        /*
            *The collateral has been deposited by the Modifier:
         */
        uint256 updatedBalance;
        uint256 collateralAmountTobeReedemed = 7 ether;
        //Act 
        console.log("Deposited", dsce.getCollateralBalanceOfUser(USER, weth));
        
        dsce.redeemCollateral(weth, collateralAmountTobeReedemed);
        updatedBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        console.log("Redeemed!!!",updatedBalance);
        //Assert 

        assertEq(updatedBalance, COLLATERAL_AMOUNT - collateralAmountTobeReedemed);
    }

    function testredeemCollateralForDsc() public depositCollateralAndMintDSC {
        //Arrange 
        uint256 initialCollateral = dsce.getCollateralBalanceOfUser(USER, weth);
        uint256 dSCMinted = dsce.getDSCMinted(USER);
        uint256 dscToBurn = 10 ether;
        uint256 amountOfCollateralToRedeem = 6 ether;
        uint256 finalCollateral;
        //Act 
        console.log("The Amount of DSCMinted", dSCMinted);
        console.log("This is the InitialBalance of the USER:", initialCollateral);
        console.log("The amount of DSC burned: ", dscToBurn);
        dsc.approve(address(dsce), dscToBurn);
        dsce.redeemCollateralForDsc(weth, amountOfCollateralToRedeem, dscToBurn);
        finalCollateral = dsce.getCollateralBalanceOfUser(USER, weth);
        uint256 finalDSCBalance = dsce.getDSCMinted(USER);
        //Assert
        assertEq(finalDSCBalance, DSC_AMOUNT - dscToBurn);
    }

    function testLiquidation() public{
        uint256 amountToCover = 20 ether;

        vm.startPrank(USER);
        console.log("Before The Price Drop");
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
        console.log("The balance of the USER: ", dsce.getDSCMinted(USER));
        vm.stopPrank();

        int256 crashPrice = 18e8;
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(crashPrice);
        ERC20Mock(weth).mint(spider, amountToCover);

        vm.startPrank(spider);
        ERC20Mock(weth).approve(address(dsce), amountToCover);
        dsce.depositCollateralAndMintDsc(weth, amountToCover, DSC_AMOUNT);
        dsc.approve(address(dsce), DSC_AMOUNT);
        dsce.liquidate(weth, USER, DSC_AMOUNT);
        vm.stopPrank();


    }

    function testRevertliquidateIfHealthFactorisOk() public {
        //Arrange

        uint256 liquidator_collateralAmount = 10 ether;
        uint256 liquidator_debtToMint = 2000 ether;
        uint256 debtTocover = 1500 ether;
        uint256 healthFactor_before;
        uint256 collateralinUSD = dsce.getUsdValue(weth, COLLATERAL_AMOUNT);
        console.log("Value of Collateral in USD: ", collateralinUSD);
        
        
        vm.startPrank(spider); //Liquidator
        ERC20Mock(weth).mint(spider, liquidator_collateralAmount);
        ERC20Mock(weth).approve(address(dsce), liquidator_collateralAmount);
        dsce.depositCollateralAndMintDsc(weth, liquidator_collateralAmount, liquidator_debtToMint);
        console.log("The minted Token for spider: ", dsce.getDSCMinted(spider));
        vm.stopPrank();
        
        vm.startPrank(USER);
        console.log("Before The Price Drop");
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
        console.log("The balance of the USER: ", dsce.getDSCMinted(USER));
        vm.stopPrank();

        //Is Liquidation possible before PriceDrop: 

        //Act
        vm.startPrank(spider);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorisOk.selector);
        dsce.liquidate(weth, USER, debtTocover);
        healthFactor_before = dsce.getHealthFactor(USER);
        console.log("Health Factor of User: ", healthFactor_before);

        //Assert 
        assertGt(healthFactor_before, 1e18);

        vm.stopPrank();
 
    }



}