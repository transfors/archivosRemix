// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Este contrato gestiona una subasta 
// que se divide en tres etapas secuenciales:
// AcceptingBlindBids: acepta ofertas ocultas.
// RevealBids: revela las ofertas hechas.
// Finished: termina la subasta.
// Cada etapa dura 1 día, y el contrato avanza 
// automáticamente a la siguiente etapa cuando pasa el tiempo.
contract AuctionStateMachine {
    enum Stages {
        AcceptingBlindBids,
        RevealBids,
        Finished
    }

    // Variable para almacenar el estado actual del contrato
    // Guarda el estado actual del contrato, comenzando en AcceptingBlindBids
    Stages public stage = Stages.AcceptingBlindBids;

    // Variable para almacenar el tiempo en el que el contrato avanza al siguiente estado
    // Guarda el timestamp límite para avanzar al siguiente estado. 
    // Se inicializa con “ahora + 1 día”.
    uint public nextStageTime = block.timestamp + 1 days;

    // Modificador para controlar el acceso a funciones según el estado actual
    // Restringe el uso de funciones a una etapa específica.
    // Por ejemplo, evita que se puedan revelar pujas antes de tiempo.
    modifier atStage(Stages _stage) {
        require(stage == _stage, "Funcion no permitida en el estado actual.");
        _;
    }

    // Modificador para avanzar al siguiente estado basado en el tiempo
    // Verifica si ya pasó el tiempo de la etapa actual.
    // Si sí, llama a nextStage() automática/ antes de ejecutar la función principal.
    modifier transitionNext() {
        if (block.timestamp >= nextStageTime) {
            nextStage();
        }
        _;
    }

    // Función para avanzar al siguiente estado
    // Convierte el enum actual a número, le suma 1 
    // y lo vuelve a convertir a enum.
    // Establece un nuevo nextStageTime para el próximo día.
    function nextStage() internal {
        stage = Stages(uint(stage) + 1);
        nextStageTime = block.timestamp + 1 days;
    }

    // Ejemplo de función que puede ser llamada en un estado específico
    // Solo se puede ejecutar durante la fase de AcceptingBlindBids.
    // Antes de ejecutarse, verifica si ya debe avanzar al siguiente estado.
    function acceptBlindBid() public atStage(Stages.AcceptingBlindBids) transitionNext {
        // Lógica para aceptar una puja a ciegas
    }

    // Solo se puede llamar en la fase RevealBids.
    // También verifica si es hora de avanzar a la fase Finished.
    function revealBids() public atStage(Stages.RevealBids) transitionNext {
        // Lógica para revelar las pujas
    }

    // Lógica para finalizar la subasta, se puede implementar en el cambio a `Finished`
}