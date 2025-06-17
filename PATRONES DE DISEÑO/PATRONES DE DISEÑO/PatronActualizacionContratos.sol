// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Cualquier llamada que no sea upgrade ni receive llega a fallback.
// fallback redirige la llamada a otro contrato (la implementación) 
// usando delegatecall.
// El Proxy actúa como una fachada, que redirige toda la lógica 
// a otro contrato pero mantiene el estado.
// Así podés actualizar la lógica cambiando solo la dirección implementation.

// Proxy delega todas las llamadas al LogicContractV1. 
// Si queremos actualizar la lógica, desplegaríamos un 
// nuevo contrato de implementación (LogicContractV2, por ejemplo) 
// y luego llamaríamos a upgrade en el Proxy para cambiar 
// la dirección de la implementación.

// ¿Qué hace?
// Es el contrato de lógica o implementación.
// Tiene una variable counter que almacena un número.
// Tiene una función increment() que suma 1 a counter.
// No es el contrato con el que interactúa directamente el usuario 
// (al menos no siempre).
// Este contrato contiene la lógica de negocio que queremos que se ejecute.

// Contrato de Implementación
contract LogicContractV1 {
    uint public counter;

    function increment() public {
        counter += 1;
    }
}

// ¿Qué hace?
// Es un contrato intermediario o "fachada" 
// que recibe todas las llamadas del usuario.
// Almacena la dirección del contrato implementation 
// que contiene la lógica actual.
// Cuando llega una llamada que no es explícita en Proxy 
// (ejemplo: no es upgrade), la reenvía usando delegatecall a implementation.
// Permite actualizar la lógica al cambiar la dirección del contrato con upgrade().
// También puede recibir ETH (función receive).

// Contrato Proxy
contract Proxy {

    // Guarda la dirección del contrato de lógica (implementación) 
    // al que el proxy delegará todas las llamadas.
    address public implementation;

    // Inicializa el proxy indicando cuál contrato 
    // será la implementación a delegar.
    constructor(address _logic) {
        implementation = _logic;
    }

    // Permite cambiar la dirección del contrato de implementación, 
    // para hacer actualizaciones.
    function upgrade(address _newImplementation) external {
        implementation = _newImplementation;
    }

    // Función vacía para aceptar ETH cuando se envía al proxy 
    // sin datos (msg.data vacío).
    // Es necesaria para evitar warnings y permitir que el contrato reciba ETH.
    receive() external payable {} // agregada al código de ETHKIPU


    fallback() external payable {
        address _impl = implementation;
        require(_impl != address(0));
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}