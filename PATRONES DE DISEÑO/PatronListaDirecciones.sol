// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Importa Ownable desde OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";

// El contrato AddressList define un patrón común llamado
// "Lista de direcciones controlada",
// donde solo el dueño (owner) puede agregar o quitar direcciones.

// Esto define un nuevo contrato llamado AddressList,
// que hereda de Ownable. Gracias a esta herencia, el contrato puede usar:
// owner() – función para ver quién es el dueño
// onlyOwner – modificador que restringe funciones
// transferOwnership() – para cambiar de dueño
contract AddressList is Ownable {
    // Este mapping actúa como una lista de direcciones autorizadas, donde:
    // La clave es una dirección.
    // El valor true o false indica si está en la lista.
    // La palabra internal significa que solo este contrato
    // y los derivados pueden acceder directamente a map.
    mapping(address => bool) internal map;

    // Este constructor pasa el deployer como owner
    // Al momento del despliegue del contrato, esto:
    // Llama al constructor del padre Ownable.
    // Le pasa msg.sender, es decir, el que despliega el 
    // contrato se convierte en el dueño.
    constructor() Ownable(msg.sender) {}

    // Permite que solo el dueño (gracias a onlyOwner) 
    // agregue una dirección a la lista.
    function add(address _address) public onlyOwner {
        map[_address] = true;
    }

    // Permite que solo el dueño desactive (elimine lógicamente) 
    // una dirección de la lista.
    function remove(address _address) public onlyOwner {
        map[_address] = false;
    }

    // Cualquiera puede llamar esta función para saber si 
    // una dirección está en la lista (true) o no (false).
    function isExists(address _address) public view returns (bool) {
        return map[_address];
    }
}
