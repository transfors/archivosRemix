// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importa la interfaz estándar que define cómo se accede 
// a los oráculos de precios de Chainlink.
// Es una interfaz que define cómo se debe comunicar 
// el contrato con un oráculo de precios de Chainlink. 
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// ¿Qué podés hacer con esto?
// Mostrar el precio actualizado de ETH en tu frontend.
// Calcular cuánto USD representa una cantidad de ETH.
// Verificar que el precio cumpla alguna condición en un contrato 
// (por ejemplo, ejecutar algo si ETH > 2000 USD).

// Sirve para consultar el precio de ETH en USD usando Chainlink.
// Este contrato consulta un oráculo de Chainlink 
// (fuente externa de datos) que entrega el precio actual de ETH/USD
contract PriceConsumerV3 {

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Ethereum Mainnet
     * Aggregator: ETH/USD
     * Address: 0x... (Dirección del contrato de Chainlink para ETH/USD)
    */
    // Declara la variable priceFeed que usaremos para interactuar con el oráculo.
    // En el constructor, inicializamos priceFeed con la dirección 
    // del contrato de Chainlink ETH/USD 
    // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&search=eth%2Fusd&testnetSearch=eth%2Fusd
    // (por ejemplo, en Sepolia Testnet es: 0x694AA1769357215DE4FAC081bf1f309aDC325306).
    // Debes reemplazar 0x... con la dirección correcta según la red (Mainnet, Sepolia, etc.).
    constructor() {
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); // Direccion del oraculo de Chainlink para ETH/USD
    }

    // Retorna el precio más reciente de ETH/USD
    // Llama a latestRoundData() del oráculo, que retorna una tupla con varios datos:
    // roundID: número de ronda de actualización.
    // price: el precio actual de ETH/USD (con 8 decimales).
    // startedAt: timestamp de inicio de la ronda.
    // timeStamp: cuándo se respondió la ronda.
    // answeredInRound: ronda en la que se respondió efectivamente.
    // Esta función devuelve solo el precio, ignorando los demás datos.
    
    // al probarla me devuelve precio de un ETH 255721360410 = 2557.21360410 USD
    function getLatestPrice() public view returns (int) {
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return price; // El precio se devuelve con 8 decimales
    }
}