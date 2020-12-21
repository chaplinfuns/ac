// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ACFuns is ERC20, Ownable {
    
    uint public constant MAX_SUPPLY = 100000000 ether;

    constructor (address owner) public ERC20(
        "ACFuns",
        "ACF"
    )  Ownable() {
        transferOwnership(owner);
    }
    
    function mint(address to, uint amount) onlyOwner public {
        _mint(to, amount);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (address(from) == address(0)) {
            require(amount.add(totalSupply()) <= MAX_SUPPLY, "exceeds max supply");
        }
    }
    
}
