// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleSwap is ReentrancyGuard {
    event LiquidityAdded(
        address indexed provider, // cuenta que agrego liquidez: owner u otro usuario
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA, // unidades de Token agregadas al pool por el proveedor
        uint256 amountB,
        uint256 liquidityMinted, // cantidad de tokens de liquidez (LP) que se emitieron al proveedor
        uint256 timestamp // el momento exacto (en segundos desde 1970) en que ocurrio la accion
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );

    event TokensSwapped(
        address indexed swapper, // direccion de quien realiza el intercambio
        address indexed tokenIn, // direccion del token que se entrega (envia) al contrato
        address indexed tokenOut, // direccion del token que se recibe del contrato
        uint256 amountIn, // cantidad del token que se entrega
        uint256 amountOut, // cantidad del token que se recibe
        uint256 timestamp
    );

    struct Pool {
        uint256 reserveA; // cantidad actual del Token A en el pool
        uint256 reserveB;
        uint256 totalLiquidity; // total de tokens de liquidez emitidos para este pool (suma de LP tokens)
        mapping(address => uint256) liquidityProvided; // mapeo que guarda cuanto LP tokens ha aportado cada proveedor (dirección => cantidad)
    }

    mapping(bytes32 => Pool) internal pools;

    function _getPairHash(address tokenA, address tokenB)
        internal
        pure
        returns (bytes32)
    {
        return
            tokenA < tokenB
                ? keccak256(abi.encodePacked(tokenA, tokenB))
                : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        require(tokenA != tokenB, "Must be different");
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _getOrderedReserves(
        address tokenA,
        address token0, // direccion del primer token del par ordenado (obtenida de _sortTokens()
        Pool storage pool // struct Pool donde estan las reservas reserveA y reserveB
    ) internal view returns (uint256 currentReserve0, uint256 currentReserve1) {
        if (tokenA == token0) {
            currentReserve0 = pool.reserveA;
            currentReserve1 = pool.reserveB;
        } else {
            currentReserve0 = pool.reserveB;
            currentReserve1 = pool.reserveA;
        }
    }

    function _calculateAddLiquidityAmountsAndLiquidity(
        address tokenA,
        address token0,
        uint256 amountADesired, // cuantos tokenA quiere aportar el usuario
        uint256 amountBDesired,
        uint256 amountAMin, // minimo aceptable de tokenA (proteccion contra slippage)
        uint256 amountBMin,
        Pool storage pool
    )
        internal
        view
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity // cantidad de tokens LP que se van a emitir
        )
    {
        (
            uint256 currentReserve0,
            uint256 currentReserve1
        ) = _getOrderedReserves(tokenA, token0, pool);

        if (pool.totalLiquidity == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
            require(amountA > 0 && amountB > 0, "Amounts must be > 0");
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            uint256 amountBOptimal = (amountADesired * currentReserve1) /
                currentReserve0;

            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "TokenB slippage error");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * currentReserve0) /
                    currentReserve1;
                require(amountAOptimal >= amountAMin, "TokenA slippage error");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }

            liquidity = Math.min(
                (amountA * pool.totalLiquidity) / currentReserve0,
                (amountB * pool.totalLiquidity) / currentReserve1
            );
        }
        require(liquidity > 0, "Liquidity must be > 0");
    }

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
            pool.reserveA += amountB;
            pool.reserveB += amountA;
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired, // cantidades max de tokens A y B que el usuario quiere añadir
        uint256 amountBDesired,
        uint256 amountAMin, // cantidades minimas aceptables para evitar slippage
        uint256 amountBMin,
        address to, // direccion que recibira los tokens LP emitidos
        uint256 deadline
    )
        external
        nonReentrant
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        require(block.timestamp <= deadline, "Transaction expired");
        require(to != address(0), "Invalid 'to' address");

        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash];

        (
            amountA,
            amountB,
            liquidity
        ) = _calculateAddLiquidityAmountsAndLiquidity(
            tokenA,
            token0,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            pool
        );

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        _updateAddLiquidityPoolReserves(tokenA, token0, pool, amountA, amountB);

        pool.totalLiquidity += liquidity;
        pool.liquidityProvided[to] += liquidity;

        emit LiquidityAdded(
            msg.sender,
            tokenA,
            tokenB,
            amountA,
            amountB,
            liquidity,
            block.timestamp
        );

        return (amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(to != address(0), "Invalid 'to' address");
        require(liquidity > 0, "Liquidity must be > 0");

        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash];

        require(
            pool.liquidityProvided[msg.sender] >= liquidity,
            "Insufficient liquidity"
        );
        require(pool.totalLiquidity > 0, "Empty liquidity pool");

        uint256 currentReserve0 = tokenA == token0
            ? pool.reserveA
            : pool.reserveB;
        uint256 currentReserve1 = tokenA == token0
            ? pool.reserveB
            : pool.reserveA;

        amountA = (liquidity * currentReserve0) / pool.totalLiquidity;
        amountB = (liquidity * currentReserve1) / pool.totalLiquidity;

        require(amountA >= amountAMin, "TokenA slippage error");
        require(amountB >= amountBMin, "TokenB slippage error");

        pool.totalLiquidity -= liquidity;
        pool.liquidityProvided[msg.sender] -= liquidity;

        if (tokenA == token0) {
            pool.reserveA -= amountA;
            pool.reserveB -= amountB;
        } else {
            pool.reserveA -= amountB;
            pool.reserveB -= amountA;
        }

        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);

        return (amountA, amountB);
    }

    function _getReservesForSwap(
        address tokenIn,
        address tokenOut,
        Pool storage pool
    ) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        (address token0, ) = _sortTokens(tokenIn, tokenOut);
        if (tokenIn == token0) {
            reserveIn = pool.reserveA;
            reserveOut = pool.reserveB;
        } else {
            reserveIn = pool.reserveB;
            reserveOut = pool.reserveA;
        }
    }

    function _updatePoolReserves(
        address tokenIn,
        address tokenOut,
        Pool storage pool,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        (address token0, ) = _sortTokens(tokenIn, tokenOut);
        if (tokenIn == token0) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(path.length == 2, "Only 1 hop allowed");
        require(to != address(0), "Invalid 'to' address");
        require(amountIn > 0, "Input must be > 0");

        bytes32 pairHash = _getPairHash(path[0], path[1]);
        Pool storage pool = pools[pairHash];

        (uint256 reserveIn, uint256 reserveOut) = _getReservesForSwap(
            path[0],
            path[1],
            pool
        );

        require(reserveIn > 0 && reserveOut > 0, "Empty pool");

        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Excessive slippage");        

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).transfer(to, amountOut);

        _updatePoolReserves(path[0], path[1], pool, amountIn, amountOut);

        emit TokensSwapped(
            msg.sender,
            path[0],
            path[1],
            amountIn,
            amountOut,
            block.timestamp
        );

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    function getPrice(address tokenA, address tokenB)
        external
        view
        returns (uint256 price)
    {
        require(tokenA != address(0) && tokenB != address(0), "Invalid tokens");

        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash];

        require(pool.reserveA > 0 && pool.reserveB > 0, "No liquidity in pool");

        if (tokenA < tokenB) {
            return (pool.reserveB * 1e18) / pool.reserveA;
        } else {
            return (pool.reserveA * 1e18) / pool.reserveB;
        }
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "Invalid output data"
        );

        uint256 amountInWithFee = amountIn * 997; // Fee 0.3%
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
