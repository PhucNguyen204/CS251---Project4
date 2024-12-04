// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
 
// Your token contract
contract Token is Ownable, ERC20 {
    string private constant _symbol = 'PUC';                 // TODO: Give your token a symbol (all caps!)
    string private constant _name = 'Puckuncute';                   // TODO: Give your token a nam
    bool private minting_enabled = true;

    constructor() ERC20(_name, _symbol) {}

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    // Function _mint: Create more of your tokens.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function mint(uint amount) public onlyOwner {
        require(minting_enabled, "Minting is disabled");
        _mint(msg.sender, amount);
    }


    // Function _disable_mint: Disable future minting of your token.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function disable_mint() public onlyOwner {
        minting_enabled = false;
    }
}