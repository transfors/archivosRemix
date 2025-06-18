// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importamos la interfaz ERC20 y el ReentrancyGuard de OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleDEX is ReentrancyGuard {
    // Declaramos los contratos de TokenA y TokenB
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Reservas de liquidez en el pool
    uint256 public reserveA; // Tokens A en el pool
    uint256 public reserveB; // Tokens B en el pool

    // Dirección del owner
    address public owner;

    // Eventos para añadir y retirar liquidez, e intercambios de tokens
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);
    event TokenSwapped(
        address indexed swapper,
        address indexed fromToken,
        address indexed toToken,
        uint256 amountIn,
        uint256 amountOut
    );

    // Modificador para permitir solo al owner ejecutar ciertas funciones
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // Constructor que inicializa los tokens y asigna al deployer como owner
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }

    // Función para añadir liquidez al pool
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Invalid token amounts");

        // Transferir tokens del proveedor al contrato
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Actualizar reservas
        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    // Función para intercambiar TokenA por TokenB con una comisión del 0.3%
    function swapAforB(uint256 amountAIn) external nonReentrant {
        require(amountAIn > 0, "Amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        // Aplicar la comisión (fee) del 0.3%
        uint256 amountInWithFee = (amountAIn * 997) / 1000;
        uint256 amountBOut = (reserveB * amountInWithFee) / (reserveA + amountInWithFee);

        // Asegurarse de que hay suficiente TokenB en el pool
        require(amountBOut > 0 && amountBOut <= reserveB, "Insufficient liquidity for this trade");

        // Transferir TokenA del usuario al contrato
        tokenA.transferFrom(msg.sender, address(this), amountAIn);

        // Transferir TokenB del contrato al usuario
        tokenB.transfer(msg.sender, amountBOut);

        // Actualizar las reservas
        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit TokenSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }

    // Función para intercambiar TokenB por TokenA con una comisión del 0.3%
    function swapBforA(uint256 amountBIn) external nonReentrant {
        require(amountBIn > 0, "Amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        // Aplicar la comisión (fee) del 0.3%
        uint256 amountInWithFee = (amountBIn * 997) / 1000;
        uint256 amountAOut = (reserveA * amountInWithFee) / (reserveB + amountInWithFee);

        // Asegurarse de que hay suficiente TokenA en el pool
        require(amountAOut > 0 && amountAOut <= reserveA, "Insufficient liquidity for this trade");

        // Transferir TokenB del usuario al contrato
        tokenB.transferFrom(msg.sender, address(this), amountBIn);

        // Transferir TokenA del contrato al usuario
        tokenA.transfer(msg.sender, amountAOut);

        // Actualizar las reservas
        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit TokenSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }

    // Función para que el owner retire liquidez del pool
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner nonReentrant {
        require(amountA <= reserveA && amountB <= reserveB, "Not enough liquidity");

        // Transferir tokens del contrato al owner
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        // Actualizar reservas
        reserveA -= amountA;
        reserveB -= amountB;

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // Obtener el precio actual de un token en función del otro
    function getPrice(address _token) external view returns (uint256) {
        if (_token == address(tokenA)) {
            require(reserveA > 0, "No liquidity for TokenA");
            return (reserveB * 1e18) / reserveA; // Precio de TokenA en términos de TokenB
        } else if (_token == address(tokenB)) {
            require(reserveB > 0, "No liquidity for TokenB");
            return (reserveA * 1e18) / reserveB; // Precio de TokenB en términos de TokenA
        } else {
            revert("Invalid token address");
        }
    }

    // Obtener las reservas actuales del pool
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }
}