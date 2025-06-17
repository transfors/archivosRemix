// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Este contrato hereda todo el comportamiento 
// del contrato ERC20 de OpenZeppelin.
// Solo necesita el constructor para personalizarlo 
// (nombre, símbolo y cantidad inicial).
// cantidad inicial = 1000000 * (10 ** uint256(decimals()))
contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}

// otra forma:
contract GLDToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Gold", "GLD") {
        // Minting: _mint es una función que se utiliza para crear 
        // la cantidad inicial de tokens. Estos tokens se asignan a
        // la dirección que despliega el contrato (generalmente tu dirección).
        _mint(msg.sender, initialSupply);
    }
}


