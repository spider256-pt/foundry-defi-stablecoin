//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
/*
 * @title DSCEngine
 * @author Pratik Das
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSP system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSP.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSP, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

import {DecentrailisedStableCoin} from "./Decentrailisedstablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IOracleLib} from "../src/libraries/OracleLib.sol";

contract DSCEngine is ReentrancyGuard {

    using IOracleLib for AggregatorV3Interface;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentrailisedStableCoin private immutable i_dsc;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Chainlink price feeds have 8 decimals, we want to work with 18 decimals, so we need to multiply the price by 10^10
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedemed(address indexed From_user, address indexed To_user, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressANDPriceFeedAddressMustBeSameLength();
    error DSCEnfine_TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorTooLow(uint256 healthFactor);
    error DSCEngine__HealthFactorisOk();
    error DSCEngine__HealtFactoDoesNOTImprove();

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier morethanZero(uint256 amount){
        if (amount == 0 ){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token){
        if(s_priceFeeds[token] == address(0)){
            revert DSCEnfine_TokenNotAllowed(token);
        }
        _;
    }

    




    ///////////////////
    //   Functions   //
    ///////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeed, address DSPAddress){
        if(tokenAddresses.length != priceFeed.length){
            revert DSCEngine__TokenAddressANDPriceFeedAddressMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeed[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentrailisedStableCoin(DSPAddress);
    } 


    /*//////////////////////////////////////////////////////////////
                      PUBLIC & EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
        * @notice: This function allows users to deposit collateral and mint DSC in a single transaction. It is more efficient than calling the two functions separately, as it saves on gas costs.
        * @param: tokenCollateralAddress: The ERC20 token address of the collateral that is being deposited.
        * @param: collateralAmount: The amount of collateral that is being deposited.
        * @param: dscAmount: The amount of DSC to mint.
     */
    function depositCollateralAndMintDsc(address tokenCollateraladdress, uint256 collateralAmonut, uint256 dscAmount) external {
        depositCollateral(tokenCollateraladdress,collateralAmonut);  
        mintDsc(dscAmount); 
    }

    /*
        * @notice: This function allows users to deposit collateral and mint DSC in a single transaction. It is more efficient than calling the two functions separately, as it saves on gas costs.
        * @param: tokenCollateralAddress: The ERC20 token address of the collateral that is being deposited.
        * @param: collateralAmount: The amount of collateral that is being deposited.
    */
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmount) public morethanZero(collateralAmount) isAllowedToken(tokenCollateralAddress) nonReentrant{
        s_collateralDeposited[msg.sender][tokenCollateralAddress]+=collateralAmount;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
        * @notice: This function is a way to get the CollateralBack by burning th DSC without affecting the HealthFactor.
        @ param: CollateralTokenAddress: The ERC20 token Address of the collateral that is being withdrawed.
        @ param: collateralAmount: The amount of collateral that is being withdrawed.
        @ param: DSCAmountToBurn: The amount of DSC to burn to get the collateral back.
    */
    function redeemCollateralForDsc(address collateraltokenAddress, uint256 collateralAmount, uint256 dSCAmountToBurn) external {
        burnDsc(dSCAmountToBurn);
        redeemCollateral(collateraltokenAddress, collateralAmount);
    }

    /*
        * @notice: This Function is a way to redeem Collateral From the Contract. Without Affecting the HealthFactor.
        * @param: CollateralTokenAddress: The ERC20 token Address of the collateral that is being withdrawed.
        * @param: collateralAmount: The amount of collateral that is being withdrawed.
     */
    function redeemCollateral(address collateraltokenAddress, uint256 collateralAmount) public morethanZero(collateralAmount) nonReentrant{
        _redeemCollateral(collateraltokenAddress, collateralAmount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    } 

    /*
        * @param amountDscToMint: The amount of DSC to mint
        Only allows minting if the user has enough collateral deposited.
    */
    
    function mintDsc(uint256 amountDscToMint) public morethanZero(amountDscToMint) nonReentrant {
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        (bool minted) = i_dsc.mint(msg.sender, amountDscToMint);

        if(!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /*
        @notice: This function allow user to step back from the protocol, but first need to burn the withdrawed DSC to get their collateral back.
        @param: DSCAmount: The amount of DSC to burn.
     */
    function burnDsc(uint256 dSCAmount) public morethanZero(dSCAmount){
        _burnDSC(dSCAmount, msg.sender, msg.sender);
         _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
        * @notice: This function is used to liquidate a user's account if their health factor is too low.   
        * @param: collateral: The ERC20 token address of the collateral that is being liquidated.
        * @param: user: The address of the user whose account is being liquidated.
        * @param: debtTOcover: The amount of DSC that the liquidator wants to burn to cover the user's debt.
        * @notice: The liquidator will receive a portion of the user's collateral in exchange for burning their DSC. 
           The amount of collateral that the liquidator receives is determined by the liquidation threshold and the amount of DSC that they burn.

        * @notice: You can partially liquidate a user.
        * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
        * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
        * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     */
    function liquidate(address collateral, address user, uint256 debtTOcover) external morethanZero(debtTOcover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor > MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorisOk();
        }

        uint256 tokenAmountFromDebtcovered = getTokenAmountFromUsdValue(collateral, debtTOcover);
        uint256 bonusCollateral = (tokenAmountFromDebtcovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralReedemed = tokenAmountFromDebtcovered + bonusCollateral;

        _redeemCollateral(collateral, totalCollateralReedemed, user, msg.sender);
        _burnDSC(debtTOcover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealtFactoDoesNOTImprove();
        }
        _revertIfHealthFactorIsBroken(user);

    } //remaining

   


    /*
        * @notice: This function is used to get the total collateral value of a user's account in USD.
        * @param: user: The address of the user for whom to get the collateral value.`
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i< s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    } 

    function getTokenAmountFromUsdValue(address token, uint256 usdAmount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /*
        * @notice: This function is used to get the USD value of the collateral that is being deposited.
        * @param: token: The ERC20 token address of the collateral that is being deposited.
        * @param: amount: The amount of collateral that is being deposited.
     */



    /*//////////////////////////////////////////////////////////////
                    PRIVATE & INTERNAL VIEW FUNCTION
    //////////////////////////////////////////////////////////////*/

     function _getUsdValue(address token, uint256 amount) private view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount / PRECISION);
    }

    function _revertIfHealthFactorIsBroken(address user) private {
        uint256 healthFactor = _healthFactor(user);
        if(healthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorTooLow(healthFactor);
        }
    }


    /*
        * @param user: The user for whom to calculate the health factor
        * @return: The health factor for the user
        * if Health Factor < 1, the user can be liquidated.
     */
    function _healthFactor(address user) private view returns(uint256) {
        (uint256 totalDscMinted,uint256 totalCollateralValue) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, totalCollateralValue);
        
    }

     function _calculateHealthFactor(uint256 totalDSCMinted, uint256 collateralValueInUsd) internal pure returns(uint256){
        if (totalDSCMinted == 0){
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThresHold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThresHold * PRECISION / totalDSCMinted);
    }

    /*
        * @param user: The user to whom to get the account information for
        * @return totalDscMinted: The total amount of DSC that the user has
        * @return totalCollateralValue: The total value of the collateral that the user has deposited
    */
    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 totalCollateralValue){
        totalDscMinted = s_DscMinted[user];
        totalCollateralValue = getAccountCollateralValue(user);   
    }

    function _redeemCollateral(address collateralToken, uint256 collateralAmount, address from, address to) private {
        s_collateralDeposited[from][collateralToken] -= collateralAmount;
        emit CollateralReedemed(from, to, collateralToken, collateralAmount);

        (bool success) = IERC20(collateralToken).transfer(to, collateralAmount);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDSC(uint256 AmountOfDscoBurn, address OnBehalfOf, address dscFrom) private{
        s_DscMinted[OnBehalfOf] -= AmountOfDscoBurn;
        (bool success) = i_dsc.transferFrom(dscFrom, address(this), AmountOfDscoBurn);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(AmountOfDscoBurn);
    }


    /*//////////////////////////////////////////////////////////////
                       EXTERNAL & PURE, VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCollateralBalanceOfUser(address user, address collateral) external view returns(uint256){
        return s_collateralDeposited[user][collateral];
    }

    function getDSCMinted(address user) external returns(uint256){
        return s_DscMinted[user];
    }


    function get_Precision() external pure returns(uint256){
        return PRECISION;
    }   

    function getUsdValue (address token, uint256 amount) external view returns(uint256){
        return _getUsdValue(token, amount);
    }

    function get_AdditionalFeedPrecision() external pure returns(uint256){
        return ADDITIONAL_FEED_PRECISION;
    }

    function get_LiquidationBonus() external pure returns(uint256){
        return LIQUIDATION_BONUS;
    }

    function get_LiquidationThreshold() external pure returns(uint256){
        return LIQUIDATION_THRESHOLD;
    }

    function get_LiquidationPrecision() external pure returns(uint256){
        return LIQUIDATION_PRECISION;
    }

    function get_minimumHealthFactor() external pure returns(uint256){
        return MIN_HEALTH_FACTOR;
    }


    function get_CollateralTokens() external view returns(address[] memory){
        return s_collateralTokens;
    }

   
    function getDsc() external view returns(address){
        return address(i_dsc);
    }

    function get_tokenPriceFeed(address token) external view returns(address){
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns(uint256){
        return _healthFactor(user);
    }
    
    function getAccountInformation(address user) external view returns(uint256 totalDscMinted, uint256 totalCollateralValue){
        return _getAccountInformation(user);
    }

    function getCollateralPriceFeed(address token) public view returns(address){
        return s_priceFeeds[token];
    }
}