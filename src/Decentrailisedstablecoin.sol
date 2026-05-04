//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/**
 * @title Decentralised Stablecoin
 * @author Spider
 * @notice This is the implementation of a decentralised stablecoin. It is an ERC20 token that can be minted and burned by the owner of the contract.
 * The owner of the contract is the one who deploys it. The owner can also transfer the ownership to another address.
 * The stablecoin is pegged to the US dollar, meaning that 1 stablecoin is equal to 1 US dollar.
 * The stablecoin can be used for trading, lending, borrowing, and other DeFi applications.
 */

contract DecentrailisedStableCoin is ERC20Burnable, Ownable(msg.sender){

    error DCoin__MustBeAboveZero();
    error DCoin__ExceedsBalance();
    error DCoin__NoZeroAddress();

    constructor() ERC20("DecentralisedSPIDERCOIN", "DSP") {

    }

    function burn(uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(_amount <= 0){
            revert DCoin__MustBeAboveZero();
        }
        if(balance < _amount){
            revert DCoin__ExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DCoin__NoZeroAddress();
        }
        if(_amount <= 0){
            revert DCoin__MustBeAboveZero();
        }
        _mint(_to, _amount);
        return true;
    }
}