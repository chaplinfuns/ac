// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract TestToken is ERC20, Ownable {
    
    
    constructor (string memory _name, string memory _symbol, uint8 decimals, address owner) public ERC20(
        _name,
        _symbol
    )  Ownable() {
        _setupDecimals(decimals);
        transferOwnership(owner);
    }
    
    function mint(address to, uint amount) onlyOwner public {
        _mint(to, amount);
    }
    
    
}
