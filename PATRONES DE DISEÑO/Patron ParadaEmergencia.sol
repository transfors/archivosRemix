// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmergencyStopExample {
    address private owner;
    bool private paused;

    modifier onlyOwner() {
        require(msg.sender == owner, "No eres el propietario");
        _;
    }

    // Solo se puede ejecutar si el contrato está pausado.
    // Este modificador no cambia el estado, 
    // solo verifica si el contrato ya está pausado.
    // Si paused == true, la función continúa. El contrato está pausado.
    // Si paused == false, lanza un error y detiene la ejecución. El contrato no esta pausado
    modifier whenPaused() {
        require(paused, "El contrato no esta pausado");
        _;
    }
    
    event Paused();
    event Unpaused();
	event FundsWithdrawn(address owner, uint amount);
		
    constructor() {
        owner = msg.sender;
        paused = false;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // Solo puede ejecutarse cuando el contrato está pausado.
    // Obtiene el saldo total del contrato:
    // address(this).balance
    // Envía ese saldo al owner usando .call{value: ...}("").
    // Verifica que la transferencia haya sido exitosa.
    // Emite el evento para dejar registro en la blockchain.
    function emergencyWithdraw() public onlyOwner whenPaused {
        // Suponiendo que esta función retira todos los fondos del contrato 
        // a la dirección del propietario
        uint balance = address(this).balance;
        (bool sent, ) = owner.call{value: balance}("");
        require(sent, "Fallo al enviar Ether");
        emit FundsWithdrawn(owner, balance);
    }

    // Otras funciones del contrato deben también verificar el estado de `paused` usando el modificador `whenNotPaused`
}