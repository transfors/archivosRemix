// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// Importamos ERC20.sol de OpenZeppelin, que contiene la implementación estándar de un token ERC-20
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// Extiende ERC20 de OpenZeppelin. 
contract TokenA is ERC20 {
    // El constructor requiere un suministro inicial initialSupply y llama a ERC20, 
    // el constructor de OpenZeppelin, 
    // para establecer el nombre (”TokenA”) y el símbolo del token (”TKA”).
    constructor(uint256 initialSupply) ERC20("TokenA", "TKA") {
        // _mint es una función que se utiliza para crear la cantidad inicial de tokens. 
        // Estos tokens se asignan a la dirección que despliega el contrato (generalmente tu dirección).
        _mint(msg.sender, initialSupply);
    }
}



