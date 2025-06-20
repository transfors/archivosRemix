// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Import OpenZeppelin contracts for secure functionalities
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Standard interface for ERC-20 tokens
import "@openzeppelin/contracts/utils/math/Math.sol"; // Mathematical utilities (e.g., Math.sqrt, Math.min)
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Protection against reentrancy attacks

/**
 * @title SimpleSwap
 * @dev A basic decentralized exchange contract (similar to Uniswap V2)
 * that allows users to add/remove liquidity, swap ERC-20 tokens,
 * get prices, and calculate amounts to receive.
 * It does not directly depend on the Uniswap protocol; it implements its own pool logic.
 */
contract SimpleSwap is ReentrancyGuard {
    // --- Events ---

    /**
     * @dev Emitted when liquidity is successfully added to a pool.
     * @param provider The address of the liquidity provider.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountA The actual amount of tokenA transferred to the pool.
     * @param amountB The actual amount of tokenB transferred to the pool.
     * @param liquidityMinted The amount of internal liquidity tokens minted for the provider.
     * @param timestamp The timestamp when the liquidity was added.
     */
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityMinted,
        uint256 timestamp
    );

    /**
     * @dev Emitted when liquidity is successfully removed from a pool.
     * @param provider The address of the liquidity provider who removed liquidity.
     * @param amountA The amount of tokenA withdrawn from the pool.
     * @param amountB The amount of tokenB withdrawn from the pool.
     */
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);

    /**
     * @dev Emitted when tokens are successfully swapped in a pool.
     * @param swapper The address of the user who performed the swap.
     * @param tokenIn The address of the token that was sent into the pool.
     * @param tokenOut The address of the token that was received from the pool.
     * @param amountIn The amount of `tokenIn` that was swapped.
     * @param amountOut The amount of `tokenOut` that was received.
     * @param timestamp The timestamp when the swap occurred.
     */
    event TokensSwapped(
        address indexed swapper,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    // --- Structs ---

    /**
     * @dev Structure to represent a liquidity pool between two tokens.
     * @param reserveA The amount of the first token (token0) in the pool.
     * @param reserveB The amount of the second token (token1) in the pool.
     * @param totalLiquidity The total amount of internal liquidity tokens issued for this pool.
     * @param liquidityProvided A mapping from user address to the amount of liquidity tokens they hold.
     */
    struct Pool {
        uint256 reserveA; // Amount of the first token (token0) in the pool
        uint256 reserveB; // Amount of the second token (token1) in the pool
        uint256 totalLiquidity; // Total amount of liquidity tokens issued for this pool
        mapping(address => uint256) liquidityProvided; // Amount of liquidity provided by each user
    }

    // --- State Variables ---

    /**
     * @dev Mapping from a unique pair hash (bytes32) to its corresponding Pool struct.
     * The pair hash ensures that each token pair has a single unique pool,
     * regardless of the order in which tokens are provided (TokenA, TokenB or TokenB, TokenA).
     */
    mapping(bytes32 => Pool) internal pools;

    // --- Internal Helper Functions ---

    /**
     * @dev Calculates a unique hash for a pair of tokens, ensuring a canonical order.
     * Always sorts the token addresses before hashing so that
     * (tokenA, tokenB) and (tokenB, tokenA) result in the same hash.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return bytes32 The keccak256 hash of the sorted token addresses.
     */
    function _getPairHash(address tokenA, address tokenB)
        internal
        pure
        returns (bytes32)
    {
        // Ensure that tokenA is always the smaller address for consistent ordering
        return
            tokenA < tokenB
                ? keccak256(abi.encodePacked(tokenA, tokenB))
                : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @dev Sorts two token addresses to establish a canonical order (token0, token1).
     * `token0` will be the address with the lower hexadecimal value.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return address The address of the token with the lower value (token0).
     * @return address The address of the token with the higher value (token1).
     */
    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        // Revert if token addresses are identical, as a pool requires two distinct tokens.
        require(tokenA != tokenB, "SimpleSwap: Tokens must be different");
        // Return tokens in ascending order of their addresses.
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @dev Internal helper to get the pool reserves in the correct order
     * (currentReserve0, currentReserve1) based on `tokenA` and `token0`.
     * This function ensures that the reserves are retrieved consistently, regardless
     * of how `tokenA` and `tokenB` were originally passed.
     * @param tokenA The address of the first token provided by the user.
     * @param token0 The address of token0 (the lower value address) of the pair.
     * @param pool The storage reference to the Pool struct.
     * @return currentReserve0 The reserve of the token that corresponds to token0.
     * @return currentReserve1 The reserve of the token that corresponds to token1.
     */
    function _getOrderedReserves(
        address tokenA,
        address token0,
        Pool storage pool
    ) internal view returns (uint256 currentReserve0, uint256 currentReserve1) {
        // If the user's tokenA is the canonically smaller token (token0),
        // then pool.reserveA corresponds to token0's reserve and pool.reserveB to token1's.
        if (tokenA == token0) {
            currentReserve0 = pool.reserveA;
            currentReserve1 = pool.reserveB;
        } else {
            // Otherwise, pool.reserveB corresponds to token0's reserve and pool.reserveA to token1's.
            currentReserve0 = pool.reserveB;
            currentReserve1 = pool.reserveA;
        }
    }

    /**
     * @dev Internal helper to calculate the optimal amounts of tokens to add
     * and the amount of liquidity to mint.
     * This function handles both initial liquidity provision and adding to existing pools,
     * ensuring the correct ratio is maintained for existing pools.
     * @param tokenA The address of token A.
     * @param token0 The address of token 0 (the canonically smaller token).
     * @param amountADesired The desired amount of tokenA to deposit.
     * @param amountBDesired The desired amount of tokenB to deposit.
     * @param amountAMin The minimum amount of tokenA that must be accepted (slippage protection).
     * @param amountBMin The minimum amount of tokenB that must be accepted (slippage protection).
     * @param pool The storage reference to the Pool struct.
     * @return amountA The actual amount of tokenA to be used.
     * @return amountB The actual amount of tokenB to be used.
     * @return liquidity The amount of liquidity tokens to be minted.
     */
    function _calculateAddLiquidityAmountsAndLiquidity(
        address tokenA,
        address token0,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        Pool storage pool
    )
        internal
        view
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        // Retrieve current reserves, ordered canonically based on token0.
        (
            uint256 currentReserve0,
            uint256 currentReserve1
        ) = _getOrderedReserves(tokenA, token0, pool);

        // Check if this is the first liquidity addition to the pool.
        if (pool.totalLiquidity == 0) {
            // For the first liquidity, use the desired amounts directly.
            amountA = amountADesired;
            amountB = amountBDesired;
            // Both initial amounts must be positive to create a valid pool.
            require(
                amountA > 0 && amountB > 0,
                "SimpleSwap: Initial amounts must be > 0"
            );
            // Initial liquidity is calculated as the geometric mean of the deposited amounts.
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            // For additional liquidity, calculate optimal amounts to maintain the existing ratio.
            // Calculate the optimal amount of tokenB required for the desired amount of tokenA,
            // based on the current pool ratio (reserve1 / reserve0).
            uint256 amountBOptimal = (amountADesired * currentReserve1) /
                currentReserve0;

            // If the calculated optimal amount of tokenB is less than or equal to the desired tokenB,
            // it means we can provide the full desired amount of tokenA.
            if (amountBOptimal <= amountBDesired) {
                // Check against minimum acceptable amountB (slippage protection).
                require(
                    amountBOptimal >= amountBMin,
                    "SimpleSwap: Excessive slippage on Token B"
                );
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                // If the desired tokenB is limiting, calculate the optimal amount of tokenA for it.
                // Calculate the optimal amount of tokenA required for the desired amount of tokenB,
                // based on the current pool ratio (reserve0 / reserve1).
                uint256 amountAOptimal = (amountBDesired * currentReserve0) /
                    currentReserve1;
                // Check against minimum acceptable amountA (slippage protection).
                require(
                    amountAOptimal >= amountAMin,
                    "SimpleSwap: Excessive slippage on Token A"
                );
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }

            // Calculate the amount of liquidity tokens to mint.
            // This is proportional to the smallest ratio of (added token / current reserve)
            // multiplied by the total existing liquidity. This ensures the provider
            // gets a share of the pool proportionate to their contribution.
            liquidity = Math.min(
                (amountA * pool.totalLiquidity) / currentReserve0,
                (amountB * pool.totalLiquidity) / currentReserve1
            );
        }
        // Ensure that a non-zero amount of liquidity is minted.
        require(liquidity > 0, "SimpleSwap: Liquidity minted must be > 0");
    }

    /**
     * @dev Internal helper to update the pool reserves after adding liquidity.
     * This function ensures that `reserveA` and `reserveB` are updated correctly
     * based on the canonical order of `token0` and `token1`.
     * @param tokenA The address of token A as provided by the user.
     * @param token0 The address of token 0 (the canonically smaller token).
     * @param pool The storage reference to the Pool struct.
     * @param amountA The effective amount of tokenA added.
     * @param amountB The effective amount of tokenB added.
     */
    function _updateAddLiquidityPoolReserves(
        address tokenA,
        address token0,
        Pool storage pool,
        uint256 amountA,
        uint256 amountB
    ) internal {
        // If the user's tokenA is the canonically smaller token (token0),
        // then add amountA to pool.reserveA and amountB to pool.reserveB.
        if (tokenA == token0) {
            pool.reserveA += amountA;
            pool.reserveB += amountB;
        } else {
            // Otherwise, amountA corresponds to token1 and amountB to token0.
            // So, add amountB to pool.reserveA (which holds token0's reserve)
            // and amountA to pool.reserveB (which holds token1's reserve).
            pool.reserveA += amountB;
            pool.reserveB += amountA;
        }
    }

    // --- 1. ADD LIQUIDITY ---
    /**
     * @dev Allows users to add liquidity to an ERC-20 token pair pool.
     * If it's the first liquidity provision, the pool is initialized. Otherwise,
     * optimal amounts are calculated to maintain the existing ratio.
     * @param tokenA The address of the first token to add.
     * @param tokenB The address of the second token to add.
     * @param amountADesired The desired amount of tokenA to deposit.
     * @param amountBDesired The desired amount of tokenB to deposit.
     * @param amountAMin The minimum amount of tokenA that must be accepted (slippage protection).
     * @param amountBMin The minimum amount of tokenB that must be accepted (slippage protection).
     * @param to The address to which the minted liquidity tokens will be assigned.
     * @param deadline The timestamp by which the transaction must be mined.
     * @return amountA The actual amount of tokenA transferred and used.
     * @return amountB The actual amount of tokenB transferred and used.
     * @return liquidity The amount of internal liquidity tokens minted for the user.
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
        nonReentrant // Prevents reentrancy attacks, ensuring state changes are atomic
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        // Validate that the transaction has not expired.
        // This prevents delayed transactions from executing after market conditions change.
        require(
            block.timestamp <= deadline,
            "SimpleSwap: Transaction expired"
        );
        // Validate that the 'to' address is not null to prevent funds from being sent to address(0).
        require(to != address(0), "SimpleSwap: Invalid 'to' address");

        // Get the canonical order of tokens and the pair hash.
        // Tokens are sorted to maintain a canonical order (token0 < token1).
        // A unique pairHash is generated to identify the pool.
        // The corresponding pool in the 'pools' mapping is accessed.
        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        // Get a storage reference to the pool for direct modification.
        Pool storage pool = pools[pairHash];

        // Calculate optimal contribution amounts and liquidity to mint.
        // Optimal amounts are calculated to maintain the pool's ratio,
        // and the amount of liquidity to be assigned to the user is determined.
        // This helper also handles the case where the pool is empty (first deposit).
        (amountA, amountB, liquidity) = _calculateAddLiquidityAmountsAndLiquidity(
            tokenA,
            token0,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            pool
        );

        // Transfer tokens from the sender to the SimpleSwap contract.
        // `transferFrom` is used, meaning the user must have previously approved
        // this contract to spend the specified amounts on their behalf.
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Update pool reserves.
        // Reserves are updated using a helper function to ensure they reflect new deposits,
        // respecting the canonical token0/token1 order.
        _updateAddLiquidityPoolReserves(tokenA, token0, pool, amountA, amountB);

        // Record the user's liquidity in the internal accounting system.
        // `totalLiquidity` of the pool is updated.
        // The `liquidityProvided` by the user (`to` address) is registered,
        // representing their share of the pool.
        pool.totalLiquidity += liquidity;
        pool.liquidityProvided[to] += liquidity;

        // Emit an event to log the successful addition of liquidity.
        emit LiquidityAdded(
            msg.sender,
            tokenA,
            tokenB,
            amountA,
            amountB,
            liquidity,
            block.timestamp
        );

        // Return the actual amounts of tokens deposited and the liquidity minted.
        return (amountA, amountB, liquidity);
    }

    // --- 2. REMOVE LIQUIDITY ---
    /**
     * @dev Allows users to withdraw liquidity from a token pool by burning their liquidity tokens (LP tokens).
     * Users receive a proportional amount of the underlying tokens (tokenA and tokenB) based on their burned liquidity.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidity The amount of liquidity tokens (LP tokens) to burn.
     * @param amountAMin The minimum amount of tokenA that must be received (slippage protection).
     * @param amountBMin The minimum amount of tokenB that must be received (slippage protection).
     * @param to The address to which the withdrawn tokenA and tokenB will be sent.
     * @param deadline The timestamp by which the transaction must be mined.
     * @return amountA The actual amount of tokenA withdrawn.
     * @return amountB The actual amount of tokenB withdrawn.
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
        // Validate that the transaction has not expired.
        require(
            block.timestamp <= deadline,
            "SimpleSwap: Transaction expired"
        );
        // Validate that the 'to' address is not null.
        require(to != address(0), "SimpleSwap: Invalid 'to' address");
        // Ensure that a positive amount of liquidity is being removed.
        require(liquidity > 0, "SimpleSwap: Liquidity to remove must be > 0");

        // Get the canonical order of tokens and the pair hash to identify the pool.
        (address token0, ) = _sortTokens(tokenA, tokenB);
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        // Get a storage reference to the pool.
        Pool storage pool = pools[pairHash];

        // Check if the sender has sufficient liquidity to remove.
        require(
            pool.liquidityProvided[msg.sender] >= liquidity,
            "SimpleSwap: Insufficient user liquidity"
        );
        // Ensure the pool is not empty before attempting to remove liquidity.
        require(pool.totalLiquidity > 0, "SimpleSwap: Liquidity pool is empty");

        // Get the current reserves of the pool, ensuring they are ordered correctly
        // based on the canonical token0/token1 addresses.
        uint256 currentReserve0 = tokenA == token0
            ? pool.reserveA
            : pool.reserveB;
        uint256 currentReserve1 = tokenA == token0
            ? pool.reserveB
            : pool.reserveA;

        // Calculate the amounts of tokenA and tokenB to withdraw proportionally
        // to the amount of liquidity being burned.
        // amountA = (liquidity to burn * current reserve of token0) / total pool liquidity
        // amountB = (liquidity to burn * current reserve of token1) / total pool liquidity
        amountA = (liquidity * currentReserve0) / pool.totalLiquidity;
        amountB = (liquidity * currentReserve1) / pool.totalLiquidity;

        // Apply slippage protection: ensure the calculated amounts are at least the minimum specified.
        require(
            amountA >= amountAMin,
            "SimpleSwap: Excessive slippage on Token A when removing"
        );
        require(
            amountB >= amountBMin,
            "SimpleSwap: Excessive slippage on Token B when removing"
        );

        // Update the total liquidity of the pool and the liquidity provided by the user.
        pool.totalLiquidity -= liquidity;
        pool.liquidityProvided[msg.sender] -= liquidity;

        // Update the pool reserves based on the canonical order.
        // If tokenA was token0, subtract `amountA` from `reserveA` and `amountB` from `reserveB`.
        // Otherwise, subtract `amountB` from `reserveA` (which holds token0) and `amountA` from `reserveB` (which holds token1).
        if (tokenA == token0) {
            pool.reserveA -= amountA;
            pool.reserveB -= amountB;
        } else {
            pool.reserveA -= amountB; // This is the amount for token0 (pool.reserveA)
            pool.reserveB -= amountA; // This is the amount for token1 (pool.reserveB)
        }

        // Transfer the withdrawn tokens to the recipient.
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);

        // Emit an event to log the successful removal of liquidity.
        emit LiquidityRemoved(msg.sender, amountA, amountB);

        // Return the actual amounts of tokens withdrawn.
        return (amountA, amountB);
    }

    /**
     * @dev Internal helper to get the input and output reserves for a swap,
     * considering the canonical order of tokens in the pool.
     * This ensures that `reserveIn` always refers to the reserve of `_tokenIn`
     * and `reserveOut` to `_tokenOut`, regardless of their canonical position.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _pool The storage reference to the Pool struct.
     * @return reserveIn The reserve of the input token in the pool.
     * @return reserveOut The reserve of the output token in the pool.
     */
    function _getReservesForSwap(
        address _tokenIn,
        address _tokenOut,
        Pool storage _pool
    ) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        // Determine the canonical token0 and token1 of the pair to correctly access pool reserves.
        address token0;
        address token1;
        if (_tokenIn < _tokenOut) {
            token0 = _tokenIn;
            token1 = _tokenOut;
        } else {
            token0 = _tokenOut;
            token1 = _tokenIn;
        }

        // Assign reserveIn and reserveOut based on whether _tokenIn is token0 or token1 of the pair.
        if (_tokenIn == token0) {
            reserveIn = _pool.reserveA; // If _tokenIn is token0, its reserve is pool.reserveA
            reserveOut = _pool.reserveB; // And _tokenOut's reserve is pool.reserveB
        } else {
            reserveIn = _pool.reserveB; // If _tokenIn is token1, its reserve is pool.reserveB
            reserveOut = _pool.reserveA; // And _tokenOut's reserve is pool.reserveA
        }
    }

    /**
     * @dev Internal helper to update the pool reserves after a swap.
     * This function adjusts `reserveA` and `reserveB` based on the amounts swapped,
     * respecting the canonical ordering of tokens within the pool.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _pool The storage reference to the Pool struct.
     * @param _amountIn The amount of the input token that entered the pool.
     * @param _amountOut The amount of the output token that left the pool.
     */
    function _updatePoolReserves(
        address _tokenIn,
        address _tokenOut,
        Pool storage _pool,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal {
        // Determine the canonical token0 and token1 of the pair to correctly update pool reserves.
        address token0;
        address token1;
        if (_tokenIn < _tokenOut) {
            token0 = _tokenIn;
            token1 = _tokenOut;
        } else {
            token0 = _tokenOut;
            token1 = _tokenIn;
        }

        // Update reserveA and reserveB of the pool.
        // If _tokenIn is token0, add _amountIn to reserveA (token0's reserve)
        // and subtract _amountOut from reserveB (token1's reserve).
        if (_tokenIn == token0) {
            _pool.reserveA += _amountIn;
            _pool.reserveB -= _amountOut;
        } else {
            // If _tokenIn is token1, add _amountIn to reserveB (token1's reserve)
            // and subtract _amountOut from reserveA (token0's reserve).
            _pool.reserveB += _amountIn;
            _pool.reserveA -= _amountOut;
        }
    }

    // --- 3. SWAP EXACT TOKENS FOR TOKENS ---
    /**
     * @dev Allows users to swap an exact amount of an input token (`amountIn`)
     * for another token, with a single-hop path.
     * The `path` array must contain exactly two token addresses: [inputToken, outputToken].
     * @param amountIn The exact amount of the input token to swap.
     * @param amountOutMin The minimum amount of the output token that must be received (slippage protection).
     * @param path An array containing the addresses of the tokens in the swap path (e.g., [tokenA, tokenB]).
     * @param to The address to which the output token will be sent.
     * @param deadline The timestamp by which the transaction must be mined.
     * @return amounts An array containing the input amount (amounts[0]) and the output amount (amounts[1]).
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        // Validate that the transaction has not expired.
        require(
            block.timestamp <= deadline,
            "SimpleSwap: Transaction expired"
        );
        // Ensure the path consists of exactly two tokens (a single-hop swap).
        require(
            path.length == 2,
            "SimpleSwap: Only 1 hop (2-token path) is allowed"
        );
        // Validate that the 'to' address is not null.
        require(to != address(0), "SimpleSwap: Invalid 'to' address");
        // Ensure the input amount is positive.
        require(amountIn > 0, "SimpleSwap: Input amount must be > 0");

        // Get the pair hash for the two tokens in the path.
        bytes32 pairHash = _getPairHash(path[0], path[1]);
        // Get a storage reference to the pool for the specified pair.
        Pool storage pool = pools[pairHash];

        // Retrieve the correct reserves for the swap, mapping path[0] to reserveIn
        // and path[1] to reserveOut based on the pool's canonical token order.
        (uint256 reserveIn, uint256 reserveOut) = _getReservesForSwap(
            path[0], // The input token for the swap
            path[1], // The output token for the swap
            pool
        );

        // Ensure both reserves are positive, indicating an existing and liquid pool.
        require(
            reserveIn > 0 && reserveOut > 0,
            "SimpleSwap: Pool empty or no liquidity"
        );

        // Calculate the amount of output token to be received.
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        // Apply slippage protection: ensure the calculated output amount meets the minimum.
        require(amountOut >= amountOutMin, "SimpleSwap: Excessive slippage");

        // Transfer the input token from the user to the swap contract.
        // User must have pre-approved the contract to spend `amountIn`.
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        // Transfer the calculated output token from the swap contract to the recipient.
        IERC20(path[1]).transfer(to, amountOut);

        // Update the pool reserves after the swap to reflect the new balances.
        _updatePoolReserves(path[0], path[1], pool, amountIn, amountOut);

        // Emit an event to log the successful token swap.
        emit TokensSwapped(
            msg.sender,
            path[0], // tokenIn
            path[1], // tokenOut
            amountIn,
            amountOut,
            block.timestamp
        );

        // Prepare the return array with the input and output amounts.
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    // --- 4. GET PRICE ---
    /**
     * @dev Returns the current price of one token in terms of another.
     * The price is scaled by 1e18 for better precision (e.g., if TokenB's price in TokenA is 0.5, it returns 0.5 * 1e18).
     * The price is calculated as (reserve of tokenB / reserve of tokenA) if A is token0 (the lower address).
     * If B is token0, then it's (reserve of tokenA / reserve of tokenB).
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return price The price of tokenB in terms of tokenA (or vice versa if tokenA > tokenB), scaled by 1e18.
     */
    function getPrice(address tokenA, address tokenB)
        external
        view
        returns (uint256 price)
    {
        // Ensure both token addresses are valid and not null.
        require(
            tokenA != address(0) && tokenB != address(0),
            "SimpleSwap: Invalid token addresses"
        );

        // Get the unique pair hash and access the corresponding pool.
        bytes32 pairHash = _getPairHash(tokenA, tokenB);
        Pool storage pool = pools[pairHash];

        // Ensure both reserves are positive, indicating an active and liquid pool.
        require(
            pool.reserveA > 0 && pool.reserveB > 0,
            "SimpleSwap: Pool empty or no liquidity"
        );

        // Calculate the price. The canonical order (token0 < token1) affects
        // which reserve (reserveA or reserveB) corresponds to which token.
        if (tokenA < tokenB) {
            // If tokenA is token0 (the lower address) and tokenB is token1,
            // the price of TokenB in terms of TokenA is (reserveB / reserveA).
            // Multiply by 1e18 first to maintain precision before division.
            return (pool.reserveB * 1e18) / pool.reserveA;
        } else {
            // If tokenB is token0 (the lower address) and tokenA is token1,
            // the price of TokenA in terms of TokenB is (reserveA / reserveB).
            // Multiply by 1e18 first to maintain precision before division.
            return (pool.reserveA * 1e18) / pool.reserveB;
        }
    }

    // --- 5. CALCULATE AMOUNT TO RECEIVE ---
    /**
     * @dev Calculates how many output tokens will be received for a given amount of input tokens,
     * based on the current pool reserves. It uses the constant product formula (x * y = k)
     * without applying any swap fees.
     * The formula used is: `amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)`.
     * @param amountIn The amount of the input token.
     * @param reserveIn The reserve of the input token in the pool.
     * @param reserveOut The reserve of the output token in the pool.
     * @return amountOut The expected amount of output tokens.
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        // Ensure all input parameters are positive to avoid division by zero or nonsensical calculations.
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "SimpleSwap: Invalid data for output amount calculation"
        );

        // Simplified swap formula (without fees), derived from x * y = k.
        // If we add deltaX to x, the new x' is x + deltaX.
        // To maintain k, the new y' must be k / x' = (x * y) / (x + deltaX).
        // The amount out (deltaY) is y - y' = y - (x * y) / (x + deltaX) = (y * (x + deltaX) - x * y) / (x + deltaX)
        // = (x * y + deltaX * y - x * y) / (x + deltaX) = (deltaX * y) / (x + deltaX).
        // Where x = reserveIn, y = reserveOut, deltaX = amountIn.
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}