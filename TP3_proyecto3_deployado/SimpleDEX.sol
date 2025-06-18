// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

// Importing ERC20 and Ownable contracts from OpenZeppelin
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Simple decentralized exchange contract
contract SimpleDEX {
    address public tokenA; // Address of the first token (TokenA)
    address public tokenB; // Address of the second token (TokenB)
    
    // Mappings to store the reserves of TokenA and TokenB for each address
    mapping(address => uint256) public reservesA;
    mapping(address => uint256) public reservesB;

    // Events to log actions like liquidity addition and token swaps
    event LiquidityAdded(uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, uint256 amountA, uint256 amountB);

    // Constructor to initialize the contract with TokenA and TokenB addresses
    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    // Function to add liquidity (both TokenA and TokenB) to the DEX
    function addLiquidity(uint256 amountA, uint256 amountB) public {
        // Ensure the amounts are greater than 0
        require(amountA > 0 && amountB > 0, "Amount must be greater than 0");

        // Store the current reserves of TokenA and TokenB
        uint256 totalA = reservesA[tokenA];
        uint256 totalB = reservesB[tokenB];

        // Transfer tokens from the user to the contract
        ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Update the reserves after liquidity is added
        reservesA[tokenA] = totalA + amountA;
        reservesB[tokenB] = totalB + amountB;

        // Emit event to log the liquidity addition
        emit LiquidityAdded(amountA, amountB);
    }

    // Function to swap TokenA for TokenB
    function swapAforB(uint256 amountAIn) public {
        // Calculate how much TokenB will be received for the given amount of TokenA
        uint256 amountBOut = calculateSwap(tokenA, tokenB, amountAIn);

        // Ensure there is enough liquidity of TokenA
        require(reservesA[tokenA] >= amountAIn, "Not enough TokenA liquidity");

        // Transfer TokenA from the user to the contract
        ERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        
        // Transfer the calculated amount of TokenB to the user
        ERC20(tokenB).transfer(msg.sender, amountBOut);

        // Update the reserves after the swap
        reservesA[tokenA] -= amountAIn;
        reservesB[tokenB] += amountBOut;

        // Emit event to log the token swap
        emit TokensSwapped(msg.sender, amountAIn, amountBOut);
    }

    // Function to swap TokenB for TokenA
    function swapBforA(uint256 amountBIn) public {
        // Calculate how much TokenA will be received for the given amount of TokenB
        uint256 amountAOut = calculateSwap(tokenB, tokenA, amountBIn);

        // Ensure there is enough liquidity of TokenB
        require(reservesB[tokenB] >= amountBIn, "Not enough TokenB liquidity");

        // Transfer TokenB from the user to the contract
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        
        // Transfer the calculated amount of TokenA to the user
        ERC20(tokenA).transfer(msg.sender, amountAOut);

        // Update the reserves after the swap
        reservesA[tokenA] += amountAOut;
        reservesB[tokenB] -= amountBIn;

        // Emit event to log the token swap
        emit TokensSwapped(msg.sender, amountAOut, amountBIn);
    }

    // Internal function to calculate the output amount for a swap based on the reserves
    function calculateSwap(address fromToken, address toToken, uint256 amount) internal view returns(uint256) {
        // Formula to calculate swap amount (using a constant product market maker model)
        return (reservesB[toToken] * amount * 997) / (reservesA[fromToken] * 1000 + amount * 997);
    }

    // Function to remove liquidity from the DEX
    function removeLiquidity(uint256 amountA, uint256 amountB) public {
        // Ensure there is enough liquidity to remove
        require(reservesA[tokenA] >= amountA && reservesB[tokenB] >= amountB, "Not enough liquidity to remove");

        // Transfer the specified amount of TokenA and TokenB back to the user
        ERC20(tokenA).transfer(msg.sender, amountA);
        ERC20(tokenB).transfer(msg.sender, amountB);

        // Update the reserves after liquidity is removed
        reservesA[tokenA] -= amountA;
        reservesB[tokenB] -= amountB;
    }

    // Function to get the current price of a token in terms of the other token
    function getPrice(address _token) public view returns (uint256) {
        // Calculate price based on the reserves of the two tokens
        if (_token == tokenA) {
            return (reservesB[tokenB] * 1000) / reservesA[tokenA];
        } else if (_token == tokenB) {
            return (reservesA[tokenA] * 1000) / reservesB[tokenB];
        }
        
        // If an invalid token address is provided, revert the transaction
        revert("Invalid token");
    }
}
