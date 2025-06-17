// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// StringComparison está diseñado para comparar dos strings en Solidity, 
// un lenguaje donde las comparaciones de strings no se pueden hacer 
// directamente con == como en otros lenguajes. 

//  ¿Qué hace?
// Recibe dos cadenas de texto (string1 y string2).
// Codifica cada string en bytes con abi.encodePacked(...).
// Calcula el hash de cada uno con keccak256(...) (función hash criptográfica).
// Compara ambos hashes.
// Devuelve true si los hashes son iguales (es decir, los strings son idénticos), false si no.
// ¿Por qué no usamos string1 == string2?
// Porque Solidity no permite comparar strings con == directamente. 
// Hay que comparar sus hashes como solución práctica.
//  ¿Qué es keccak256?
// Es una función de hashing (similar a SHA3) que transforma datos en un hash único de 32 bytes. 
// Si dos strings son idénticos, sus hashes también lo serán.
contract StringComparison {
    // Función para comparar dos strings
    // abi.encodePacked(...): Esta función toma cualquier número de argumentos 
    // de cualquier tipo y los codifica en un único bytes continuo. 
    // Se usa aquí para convertir los strings en bytes.
    // keccak256(...): Calcula el hash KECCAK-256 de los datos. 
    // En este contexto, se usa para obtener el hash del bytes resultante de cada string.
    // ==: Compara los hashes de los dos strings. Si los strings son iguales, 
    // sus hashes también lo serán, resultando en true. De lo contrario, el resultado será false.
    function compareStrings(string memory string1, string memory string2) public pure returns (bool) {
        return keccak256(abi.encodePacked(string1)) == keccak256(abi.encodePacked(string2));
    }
}