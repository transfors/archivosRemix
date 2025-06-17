// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/ERC20.sol)

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TransforToken is ERC20 {
    constructor() ERC20("Transfor Token", "TFT") {
        // Crea 1 millón de tokens con 18 decimales (1_000_000 * 10^18)
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}