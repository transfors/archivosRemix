// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract WithdrawalContract {

    // Declara una estructura que guarda cuánto Ether tiene cada dirección.
    // Ejemplo: balances[0x123...] = 1 ether;
    // public: Solidity genera un getter automático 
    // llamado balances(dirección) para consultar saldos.
    mapping(address => uint) public balances;

    // Cualquiera que tenga fondos en el contrato puede 
    // llamar a esta función para retirar su dinero.
    function withdraw() public {
        // Toma el saldo almacenado de quien está llamando la función (msg.sender).
        // Guarda ese valor en la variable local amount.
        uint amount = balances[msg.sender];
        // Verifica que el usuario tenga un saldo mayor a 0.
        require(amount > 0);

        // Se pone el saldo en 0 antes de enviar Ether, 
        // para evitar ataques de reentrancy 
        // Este orden (Chequeo → Efecto → Interacción) 
        // es un patrón de seguridad en Solidity
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}