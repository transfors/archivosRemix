// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Importa las interfaces necesarias para interactuar con tokens ERC-20 y SimpleSwap.
// Asumimos que IERC20 ya está disponible de OpenZeppelin.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Necesitamos una interfaz para tu contrato SimpleSwap para poder llamarlo.
// Esta es una versión simplificada de tu contrato para permitir las llamadas externas.
interface ISimpleSwap {
    // Declaraciones de funciones externas de SimpleSwap que usaremos
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getPrice(address tokenA, address tokenB)
        external
        view
        returns (uint256 price);
}

/**
 * @title SimpleSwapTester
 * @dev Un contrato de ejemplo para interactuar y "verificar" el contrato SimpleSwap.
 * Este contrato no tiene la intención de ser de producción, sino una herramienta de prueba/interacción.
 */
contract SimpleSwapTester {
    // La instancia del contrato SimpleSwap con el que interactuaremos.
    ISimpleSwap public simpleSwap;

    // Constructor que inicializa la dirección del contrato SimpleSwap.
    // Al desplegar este contrato Tester, debes proporcionar la dirección del SimpleSwap ya desplegado.
    constructor(address _simpleSwapAddress) {
        require(_simpleSwapAddress != address(0), "SimpleSwapTester: Direccion SimpleSwap invalida");
        simpleSwap = ISimpleSwap(_simpleSwapAddress);
    }

    /**
     * @dev Permite a este contrato Tester simular una aprobación de tokens para el contrato SimpleSwap.
     * En un escenario real, los usuarios tendrían que aprobar directamente a SimpleSwap.
     * Esta función es útil para pruebas donde este contrato Tester actúa en nombre de un usuario.
     * @param token La dirección del token ERC-20 a aprobar.
     * @param spender La dirección que se autoriza a gastar (será la dirección de SimpleSwap).
     * @param amount La cantidad máxima de tokens que el spender puede gastar.
     * @return bool Verdadero si la aprobación fue exitosa.
     */
    function approveTokenForSwap(address token, address spender, uint256 amount) external returns (bool) {
        // Asegúrate de que el token es un contrato ERC-20 válido.
        require(token != address(0), "SimpleSwapTester: Direccion de token invalida");
        // Llama a la función `approve` del token ERC-20.
        return IERC20(token).approve(spender, amount);
    }

    /**
     * @dev Llama a la función `addLiquidity` del contrato SimpleSwap.
     * Este contrato Tester actuará como el proveedor de liquidez.
     * Asegúrate de que este contrato (SimpleSwapTester) tenga los tokens aprobados
     * para que SimpleSwap pueda transferirlos.
     * @param tokenA La dirección del primer token a añadir.
     * @param tokenB La dirección del segundo token a añadir.
     * @param amountADesired La cantidad deseada de tokenA a depositar.
     * @param amountBDesired La cantidad deseada de tokenB a depositar.
     * @param amountAMin La cantidad mínima de tokenA que debe aceptarse (protección de deslizamiento).
     * @param amountBMin La cantidad mínima de tokenB que debe aceptarse (protección de deslizamiento).
     * @param deadline El timestamp límite para la transacción.
     * @return amountA_ Actual cantidad de tokenA transferida y usada.
     * @return amountB_ Actual cantidad de tokenB transferida y usada.
     * @return liquidity_ Cantidad de tokens de liquidez internos acuñados.
     */
    function testAddLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external returns (uint256 amountA_, uint256 amountB_, uint256 liquidity_) {
        // En un escenario real de usuario, 'msg.sender' sería la persona que llama a 'addLiquidity'.
        // Aquí, como 'SimpleSwapTester' es el que llama, 'to' será la dirección de este contrato.
        (amountA_, amountB_, liquidity_) = simpleSwap.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this), // La liquidez se asigna a este contrato Tester.
            deadline
        );
    }

    /**
     * @dev Llama a la función `swapExactTokensForTokens` del contrato SimpleSwap.
     * Este contrato Tester actuará como el swapper.
     * Asegúrate de que este contrato (SimpleSwapTester) tenga los tokens de entrada aprobados
     * para que SimpleSwap pueda transferirlos.
     * @param amountIn La cantidad exacta del token de entrada a intercambiar.
     * @param amountOutMin La cantidad mínima del token de salida que debe recibirse.
     * @param path Un array con las direcciones de los tokens en la ruta de intercambio ([tokenIn, tokenOut]).
     * @param deadline El timestamp límite para la transacción.
     * @return amounts_ Un array con la cantidad de entrada y la cantidad de salida.
     */
    function testSwapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256[] memory amounts_) {
        // En un escenario real de usuario, 'msg.sender' sería la persona que llama a 'swapExactTokensForTokens'.
        // Aquí, como 'SimpleSwapTester' es el que llama, 'to' será la dirección de este contrato.
        amounts_ = simpleSwap.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this), // Los tokens de salida se envían a este contrato Tester.
            deadline
        );
    }

    /**
     * @dev Llama a la función `getPrice` del contrato SimpleSwap.
     * @param tokenA La dirección del primer token.
     * @param tokenB La dirección del segundo token.
     * @return price_ El precio de tokenB en términos de tokenA (o viceversa), escalado por 1e18.
     */
    function testGetPrice(address tokenA, address tokenB)
        external
        view
        returns (uint256 price_)
    {
        price_ = simpleSwap.getPrice(tokenA, tokenB);
    }

    /**
     * @dev Función de fallback/receive para aceptar Ether (si fuera necesario).
     * Nota: Tu contrato SimpleSwap no maneja Ether directamente para liquidez o swaps,
     * pero un contrato de prueba podría necesitar aceptar Ether para simular interacciones.
     */
    receive() external payable {}
}
