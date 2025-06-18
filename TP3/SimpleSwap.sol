// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importar contratos de OpenZeppelin para funcionalidades seguras
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Interfaz estándar para tokens ERC-20
import "@openzeppelin/contracts/utils/math/Math.sol"; // Utilidades matemáticas (e.g., Math.sqrt, Math.min)
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Protección contra ataques de reentrada

/**
 * @title SimpleSwap
 * @dev Contrato de intercambio descentralizado básico (similar a Uniswap V2)
 * que permite a los usuarios agregar/remover liquidez e intercambiar tokens ERC-20.
 * No depende directamente del protocolo Uniswap; implementa su propia lógica de pool.
 */
contract SimpleSwap is ReentrancyGuard {
    // Estructura para representar un pool de liquidez entre dos tokens
    struct Pool {
        uint256 reserveA; // Cantidad del primer token (token0) en el pool
        uint256 reserveB; // Cantidad del segundo token (token1) en el pool
        uint256 totalLiquidity; // Cantidad total de tokens de liquidez emitidos para este pool
        mapping(address => uint256) liquidityProvided; // Cantidad de liquidez proporcionada por cada usuario
    }

    // Mapeo de un hash de par de tokens a su Pool correspondiente
    // El hash de par asegura que cada par de tokens tenga un único pool,
    // independientemente del orden en que se proporcionen (TokenA, TokenB o TokenB, TokenA).
    mapping(bytes32 => Pool) public pools;

    /**
     * @dev Calcula un hash único para un par de tokens, asegurando un orden canónico.
     * Siempre ordena las direcciones de los tokens antes de hashear para que
     * (tokenA, tokenB) y (tokenB, tokenA) resulten en el mismo hash.
     * @param tokenA La dirección del primer token.
     * @param tokenB La dirección del segundo token.
     * @return bytes32 El hash keccak256 de las direcciones de los tokens ordenadas.
     */
    function _getPairHash(address tokenA, address tokenB)
        internal
        pure
        returns (bytes32)
    {
        // Asegurarse de que tokenA sea siempre el de menor dirección para un orden consistente
        return
            tokenA < tokenB
                ? keccak256(abi.encodePacked(tokenA, tokenB))
                : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @dev Ordena dos direcciones de tokens para establecer un orden canónico (token0, token1).
     * `token0` será la dirección con el valor hexadecimal más bajo.
     * @param tokenA La dirección del primer token.
     * @param tokenB La dirección del segundo token.
     * @return address La dirección del token con el valor más bajo (token0).
     * @return address La dirección del token con el valor más alto (token1).
     */
    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        require(tokenA != tokenB, "SimpleSwap: Tokens deben ser diferentes");
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @dev Helper interno para obtener las reservas del pool en el orden correcto
     * (currentReserve0, currentReserve1) basado en el tokenA y token0.
     * @param tokenA La dirección del token A proporcionado por el usuario.
     * @param token0 La dirección del token 0 (el de menor valor) del par.
     * @param pool La referencia al storage del Pool.
     * @return currentReserve0 La reserva del token que corresponde a token0.
     * @return currentReserve1 La reserva del token que corresponde a token1.
     */
    function _getOrderedReserves(address tokenA, address token0, Pool storage pool)
        internal
        view
        returns (uint256 currentReserve0, uint256 currentReserve1)
    {
        if (tokenA == token0) {
            currentReserve0 = pool.reserveA;
            currentReserve1 = pool.reserveB;
        } else {
            currentReserve0 = pool.reserveB;
            currentReserve1 = pool.reserveA;
        }
    }

    /**
     * @dev Helper interno para calcular las cantidades óptimas de tokens a agregar
     * y la cantidad de liquidez a emitir.
     * Nota: Ahora toma `tokenA`, `token0` y el `pool` directamente para reducir
     * la profundidad de la pila en la función `addLiquidity`.
     * @param tokenA La dirección del token A.
     * @param token0 La dirección del token 0.
     * @param amountADesired Cantidad deseada de tokenA.
     * @param amountBDesired Cantidad deseada de tokenB.
     * @param amountAMin Cantidad mínima de tokenA.
     * @param amountBMin Cantidad mínima de tokenB.
     * @param pool La referencia al storage del Pool.
     * @return amountA La cantidad real de tokenA a usar.
     * @return amountB La cantidad real de tokenB a usar.
     * @return liquidity La cantidad de liquidez a emitir.
     */
    function _calculateAddLiquidityAmountsAndLiquidity(
        address tokenA, // Nueva variable: pasa tokenA directamente
        address token0, // Nueva variable: pasa token0 directamente
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        Pool storage pool // Pasa la referencia al storage del pool
    ) internal view returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Obtener las reservas actuales dentro de esta función helper
        (uint256 currentReserve0, uint256 currentReserve1) = _getOrderedReserves(tokenA, token0, pool);

        if (pool.totalLiquidity == 0) { // Accede a pool.totalLiquidity directamente
            // Primera liquidez
            amountA = amountADesired;
            amountB = amountBDesired;
            require(amountA > 0 && amountB > 0, "SimpleSwap: Cantidades iniciales deben ser > 0");
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            // Liquidez adicional
            uint256 amountBOptimal = (amountADesired * currentReserve1) / currentReserve0;

            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "SimpleSwap: Slippage excesivo en Token B");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * currentReserve0) / currentReserve1;
                require(amountAOptimal >= amountAMin, "SimpleSwap: Slippage excesivo en Token A");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }

            liquidity = Math.min(
                (amountA * pool.totalLiquidity) / currentReserve0, // Accede a pool.totalLiquidity directamente
                (amountB * pool.totalLiquidity) / currentReserve1
            );
        }
        require(liquidity > 0, "SimpleSwap: Liquidez emitida debe ser > 0");
    }

    /**
     * @dev Helper interno para actualizar las reservas del pool después de agregar liquidez.
     * @param tokenA La dirección del token A.
     * @param token0 La dirección del token 0.
     * @param pool La referencia al storage del Pool.
     * @param amountA La cantidad efectiva de tokenA agregada.
     * @param amountB La cantidad efectiva de tokenB agregada.
     */
    function _updateAddLiquidityPoolReserves(
        address tokenA,
        address token0,
        Pool storage pool,
        uint256 amountA,
        uint256 amountB
    ) internal {
        if (tokenA == token0) {
            pool.reserveA += amountA;
            pool.reserveB += amountB;
        } else {
            pool.reserveA += amountB; // amountB de TokenA (token1)
            pool.reserveB += amountA; // amountA de TokenB (token0)
        }
    }

    // --- 1. AGREGAR LIQUIDEZ ---
    /**
     * @dev Permite a los usuarios agregar liquidez a un pool de tokens ERC-20.
     * Si es la primera liquidez, se inicializa el pool. De lo contrario,
     * se calculan las cantidades óptimas para mantener la proporción existente.
     * @param tokenA La dirección del primer token a agregar.
     * @param tokenB La dirección del segundo token a agregar.
     * @param amountADesired La cantidad deseada de tokenA a depositar.
     * @param amountBDesired La cantidad deseada de tokenB a depositar.
     * @param amountAMin La cantidad mínima de tokenA que debe aceptarse (protección contra slippage).
     * @param amountBMin La cantidad mínima de tokenB que debe aceptarse (protección contra slippage).
     * @param to La dirección a la que se enviarán los tokens de liquidez (LP tokens).
     * @param deadline El tiempo límite para que la transacción sea minada.
     * @return amountA La cantidad real de tokenA transferida y utilizada.
     * @return amountB La cantidad real de tokenB transferida y utilizada.
     * @return liquidity La cantidad de tokens de liquidez (LP tokens) emitidos.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant // Previene ataques de reentrada
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        require(block.timestamp <= deadline, "SimpleSwap: Transaccion expirada");
        require(to != address(0), "SimpleSwap: Direccion 'to' invalida");

        // Obtener el orden canónico de los tokens y el hash del par
        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash]; // Referencia al storage del pool

        // Ahora, _calculateAddLiquidityAmountsAndLiquidity se encargará de obtener las reservas
        // y calcular la liquidez, reduciendo variables locales en esta función.
        (amountA, amountB, liquidity) = _calculateAddLiquidityAmountsAndLiquidity(
            tokenA, // Pasa tokenA
            token0, // Pasa token0
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            pool // Pasa la referencia al pool
        );

        // Transferir los tokens del remitente al contrato del swap
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Actualizar las reservas del pool según el orden canónico usando una función helper
        _updateAddLiquidityPoolReserves(tokenA, token0, pool, amountA, amountB);

        // Actualizar la liquidez total y la liquidez provista por el usuario
        pool.totalLiquidity += liquidity;
        pool.liquidityProvided[to] += liquidity; // Asignar la liquidez al 'to' address

        return (amountA, amountB, liquidity);
    }

    // --- 2. REMOVER LIQUIDEZ ---
    /**
     * @dev Permite a los usuarios retirar liquidez de un pool quemando sus tokens de liquidez (LP tokens).
     * Los usuarios reciben una cantidad proporcional de los tokens subyacentes (tokenA y tokenB).
     * @param tokenA La dirección del primer token en el par.
     * @param tokenB La dirección del segundo token en el par.
     * @param liquidity La cantidad de tokens de liquidez (LP tokens) a quemar.
     * @param amountAMin La cantidad mínima de tokenA que debe recibirse (protección contra slippage).
     * @param amountBMin La cantidad mínima de tokenB que debe recibirse (protección contra slippage).
     * @param to La dirección a la que se enviarán los tokens A y B retirados.
     * @param deadline El tiempo límite para que la transacción sea minada.
     * @return amountA La cantidad real de tokenA retirada.
     * @return amountB La cantidad real de tokenB retirada.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "SimpleSwap: Transaccion expirada");
        require(to != address(0), "SimpleSwap: Direccion 'to' invalida");
        require(liquidity > 0, "SimpleSwap: Liquidez a remover debe ser > 0");

        // Obtener el orden canónico de los tokens y el hash del par
        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash]; // Referencia al storage del pool

        require(
            pool.liquidityProvided[msg.sender] >= liquidity,
            "SimpleSwap: Liquidez insuficiente del usuario"
        );
        require(pool.totalLiquidity > 0, "SimpleSwap: Pool de liquidez vacio");

        // Obtener las reservas actuales del pool, asegurando el orden correcto
        uint256 currentReserve0 = tokenA == token0 ? pool.reserveA : pool.reserveB;
        uint256 currentReserve1 = tokenA == token0 ? pool.reserveB : pool.reserveA;

        // Calcular la cantidad de tokens A y B a retirar proporcionalmente a la liquidez quemada
        amountA = (liquidity * currentReserve0) / pool.totalLiquidity;
        amountB = (liquidity * currentReserve1) / pool.totalLiquidity;

        require(amountA >= amountAMin, "SimpleSwap: Slippage excesivo en Token A al remover");
        require(amountB >= amountBMin, "SimpleSwap: Slippage excesivo en Token B al remover");

        // Actualizar la liquidez total y la liquidez provista por el usuario
        pool.totalLiquidity -= liquidity;
        pool.liquidityProvided[msg.sender] -= liquidity;

        // Actualizar las reservas del pool según el orden canónico
        if (tokenA == token0) {
            pool.reserveA -= amountA;
            pool.reserveB -= amountB;
        } else {
            pool.reserveA -= amountB; // amountB de TokenA (token1)
            pool.reserveB -= amountA; // amountA de TokenB (token0)
        }

        // Transferir los tokens retirados al destinatario
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);

        return (amountA, amountB);
    }

    /**
     * @dev Helper interno para obtener las reservas de entrada y salida para un swap,
     * considerando el orden canónico de los tokens en el pool.
     * @param _tokenIn La dirección del token de entrada.
     * @param _tokenOut La dirección del token de salida.
     * @param _pool La referencia al storage del Pool.
     * @return reserveIn La reserva del token de entrada en el pool.
     * @return reserveOut La reserva del token de salida en el pool.
     */
    function _getReservesForSwap(
        address _tokenIn,
        address _tokenOut,
        Pool storage _pool
    ) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        // Determinamos el token0 y token1 del par para acceder correctamente a las reservas del pool
        address token0;
        address token1;
        if (_tokenIn < _tokenOut) {
            token0 = _tokenIn;
            token1 = _tokenOut;
        } else {
            token0 = _tokenOut;
            token1 = _tokenIn;
        }

        // Asignamos reserveIn y reserveOut según si el tokenIn es token0 o token1 del par
        if (_tokenIn == token0) {
            reserveIn = _pool.reserveA;
            reserveOut = _pool.reserveB;
        } else {
            reserveIn = _pool.reserveB;
            reserveOut = _pool.reserveA;
        }
    }

    /**
     * @dev Helper interno para actualizar las reservas del pool después de un swap.
     * @param _tokenIn La dirección del token de entrada.
     * @param _tokenOut La dirección del token de salida.
     * @param _pool La referencia al storage del Pool.
     * @param _amountIn La cantidad de token que entró al pool.
     * @param _amountOut La cantidad de token que salió del pool.
     */
    function _updatePoolReserves(
        address _tokenIn,
        address _tokenOut,
        Pool storage _pool,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal {
        // Determinamos el token0 y token1 del par para actualizar correctamente las reservas del pool
        address token0;
        address token1;
        if (_tokenIn < _tokenOut) {
            token0 = _tokenIn;
            token1 = _tokenOut;
        } else {
            token0 = _tokenOut;
            token1 = _tokenIn;
        }

        // Actualizamos reserveA y reserveB del pool.
        // Si _tokenIn es token0, sumamos a reserveA y restamos de reserveB.
        // Si _tokenIn es token1, sumamos a reserveB y restamos de reserveA.
        if (_tokenIn == token0) {
            _pool.reserveA += _amountIn;
            _pool.reserveB -= _amountOut;
        } else {
            _pool.reserveB += _amountIn;
            _pool.reserveA -= _amountOut;
        }
    }

    // --- 3. INTERCAMBIAR TOKENS (SWAP EXACT) ---
    /**
     * @dev Permite a los usuarios intercambiar una cantidad exacta de un token
     * (amountIn) por otro token, con una ruta de un solo salto.
     * El `path` debe contener exactamente dos direcciones: [tokenEntrada, tokenSalida].
     * @param amountIn La cantidad exacta del token de entrada a intercambiar.
     * @param amountOutMin La cantidad mínima del token de salida que debe recibirse (protección contra slippage).
     * @param path Un array con las direcciones de los tokens en la ruta de intercambio (ej: [tokenA, tokenB]).
     * @param to La dirección a la que se enviará el token de salida.
     * @param deadline El tiempo límite para que la transacción sea minada.
     * @return amounts Un array con la cantidad de entrada (amounts[0]) y la cantidad de salida (amounts[1]).
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "SimpleSwap: Transaccion expirada");
        require(path.length == 2, "SimpleSwap: Solo se permite 1 hop (ruta de 2 tokens)");
        require(to != address(0), "SimpleSwap: Direccion 'to' invalida");
        require(amountIn > 0, "SimpleSwap: Cantidad de entrada debe ser > 0");

        // Acceder directamente a path[0] y path[1] en lugar de variables locales
        bytes32 pairHash = _getPairHash(path[0], path[1]);
        Pool storage pool = pools[pairHash];

        // Obtener las reservas correctas para el cálculo del swap
        (uint256 reserveIn, uint256 reserveOut) = _getReservesForSwap(
            path[0], // Directamente path[0] para tokenIn
            path[1], // Directamente path[1] para tokenOut
            pool
        );

        require(reserveIn > 0 && reserveOut > 0, "SimpleSwap: Pool vacio o sin liquidez");

        // Calcular la cantidad de token de salida
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "SimpleSwap: Slippage excesivo");

        // Transferir el token de entrada del usuario al contrato del swap
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        // Transferir el token de salida del contrato del swap al destinatario
        IERC20(path[1]).transfer(to, amountOut);

        // Actualizar las reservas del pool después del swap
        _updatePoolReserves(path[0], path[1], pool, amountIn, amountOut);

        // Preparar el array de retorno con las cantidades de entrada y salida
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    // --- 4. OBTENER EL PRECIO ---
    /**
     * @dev Devuelve el precio actual de un token en términos de otro.
     * El precio se escala por 1e18 para una mejor precisión.
     * Por ejemplo, si el precio de TokenB en TokenA es 0.5, se retornará 0.5 * 1e18.
     * @param tokenA La dirección del primer token.
     * @param tokenB La dirección del segundo token.
     * @return price El precio de tokenB en términos de tokenA (o viceversa si tokenA > tokenB), escalado por 1e18.
     */
    function getPrice(address tokenA, address tokenB)
        external
        view
        returns (uint256 price)
    {
        require(tokenA != address(0) && tokenB != address(0), "SimpleSwap: Direcciones de token invalidas");

        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash];

        require(pool.reserveA > 0 && pool.reserveB > 0, "SimpleSwap: Pool vacio o sin liquidez");

        // El precio se calcula como (reserva del token B / reserva del token A) si A es el token0.
        // Si B es el token0, entonces es (reserva del token A / reserva del token B).
        if (tokenA < tokenB) {
            // tokenA es token0, tokenB es token1
            // Price = (reserveB / reserveA)
            return (pool.reserveB * 1e18) / pool.reserveA;
        } else {
            // tokenB es token0, tokenA es token1
            // Price = (reserveA * 1e18) / pool.reserveB;
            // Corregido: La división se debe hacer después de la multiplicación por 1e18 para evitar pérdida de precisión.
            return (pool.reserveA * 1e18) / pool.reserveB;
        }
    }

    // --- 5. CALCULAR CANTIDAD A RECIBIR ---
    /**
     * @dev Calcula cuántos tokens de salida se recibirán para una cantidad dada de tokens de entrada,
     * basado en las reservas actuales del pool. Utiliza la fórmula de producto constante
     * (x * y = k) sin aplicar comisiones de swap.
     * amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
     * @param amountIn La cantidad del token de entrada.
     * @param reserveIn La reserva del token de entrada en el pool.
     * @param reserveOut La reserva del token de salida en el pool.
     * @return amountOut La cantidad de tokens de salida esperada.
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "SimpleSwap: Datos invalidos para calculo de cantidad de salida"
        );

        // Fórmula de intercambio simplificada (sin comisiones)
        // (x * y = k) => deltaY = y * deltaX / (x + deltaX)
        // Donde x = reserveIn, y = reserveOut, deltaX = amountIn
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}
