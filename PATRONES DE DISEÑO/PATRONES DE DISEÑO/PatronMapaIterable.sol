// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Simula un mapa iterable (un mapping al que se le puede iterar) 
// en Solidity, algo que no es posible directamente en los mapping nativos.

// Este contrato permite almacenar datos (uint) 
// asociados a direcciones (address) y poder:
// Agregar/modificar elementos.
// Eliminar elementos.
// Iterar sobre todas las claves agregadas.
// Consultar existencia y valor.
contract IterableMapping {
    // Estructura para almacenar los datos junto con un flag para marcar si el elemento está en el array
    
    // Cada dirección almacenada en el mapping tiene un valor (value) 
    // y un indicador (exists) que nos dice si la clave existe actualmente. 
    // Esto es clave porque en Solidity un mapping no se puede iterar 
    // ni detectar si una clave fue "eliminada", salvo que agregues este tipo de flag.
    struct MapData {
        uint value;
        bool exists;
    }

    // Mapa para almacenar los datos asociados a una clave
    // dataMap: Guarda el valor y el flag exists para cada dirección.
    mapping(address => MapData) public dataMap;

    // Array para mantener el orden de las claves
    // keys: Array auxiliar que guarda todas las claves agregadas. 
    // Esto permite recorrerlas una por una.
    address[] public keys;

    // Función para añadir o actualizar un valor
    // Si la clave no existía, la agrega al array keys 
    // y guarda el valor en el mapping.
    // Si ya existía, actualiza el valor sin tocar el array.
    function set(address key, uint value) public {
       // Si es la primera vez que se añade, también se agrega la clave al array
        if (!dataMap[key].exists) {
            keys.push(key);
            dataMap[key] = MapData(value, true);
        } else {
            // Si ya existía, solo actualizamos el valor
            dataMap[key].value = value;
        }
    }

    // Función para obtener un valor
    // Consulta segura: si la clave no existe, lanza un error.
    function get(address key) public view returns (uint) {
        require(dataMap[key].exists, "La clave no existe");
        return dataMap[key].value;
    }

    // Función para eliminar un elemento
    // Elimina la entrada del mapping.
    // Elimina la dirección del array keys:
    // Busca la dirección.
    // la reemplaza por la última del array (para no dejar huecos).
    // Elimina el último elemento (pop()).
    // Esto rompe el orden original, pero es más eficiente.
    function remove(address key) public {
        require(dataMap[key].exists, "La clave no existe");

        // Eliminar la clave del mapa
        delete dataMap[key];

        // Encontrar el índice de la clave en el array y eliminarlo
        for (uint i = 0; i < keys.length; i++) {
            if (keys[i] == key) {
                // Mover el último elemento al lugar del elemento eliminado y luego eliminar el último elemento
                keys[i] = keys[keys.length - 1];
                keys.pop();
                break;
            }
        }
    }

    // Función para obtener el tamaño del mapa
    // Retorna cuántas claves activas hay en keys.
    function size() public view returns (uint) {
        return keys.length;
    }

    // Función para comprobar si una clave existe en el mapa
    // Devuelve true si la clave aún está registrada.
    function exists(address key) public view returns (bool) {
        return dataMap[key].exists;
    }

    // Función para obtener una clave en un índice específico
    // Permite iterar externamente sobre el array de claves 
    // (por ejemplo, en una interfaz frontend).
    function getKeyAtIndex(uint index) public view returns (address) {
        require(index < keys.length, "Indice fuera de rango");
        return keys[index];
    }
}