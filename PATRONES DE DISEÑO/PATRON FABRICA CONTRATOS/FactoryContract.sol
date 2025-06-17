// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// CONTRATO FABRICA 
// actuará como la fábrica que crea instancias de ChildContract

// Referencia al contrato hijo
import "./ChildContract.sol";

contract FactoryContract {
    // Array para almacenar las direcciones de los contratos hijos creados
    // Guarda las instancias creadas por la fábrica.
    ChildContract[] public children;

    // Emite un evento cada vez que se crea un contrato hijo.
    event ChildCreated(uint number, address childAddress);

    // Función para crear un nuevo contrato hijo
    // Crea un nuevo ChildContract pasándole el número _number.
    // Guarda la instancia en el array children.
    // Emite un evento con el número y la dirección del contrato hijo creado.
    function createChild(uint _number) public {
        ChildContract child = new ChildContract(_number);
        children.push(child);
        emit ChildCreated(_number, address(child));
    }

    // Función para obtener la dirección de un contrato hijo en el array
    // Devuelve la instancia (referencia) de un contrato hijo según el índice.
    function getChild(uint _index) public view returns (ChildContract) {
        require(_index < children.length, "Indice fuera de limites");
        return children[_index];
    }
}