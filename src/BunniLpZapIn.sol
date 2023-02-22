// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "bunni/interfaces/IBunniHub.sol";

import {ILiquidityGauge} from "gauge-foundry/interfaces/ILiquidityGauge.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Multicall} from "./lib/Multicall.sol";
import {SelfPermit} from "./lib/SelfPermit.sol";

contract BunniLpZapIn is ReentrancyGuard, Multicall, SelfPermit {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error BunniLpZapIn__SameToken();
    error BunniLpZapIn__PastDeadline();
    error BunniLpZapIn__ZeroExSwapFailed();
    error BunniLpZapIn__InsufficientOutput();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The 0x proxy contract used for 0x swaps
    address public immutable zeroExProxy;

    /// @notice The Wrapped Ethereum contract
    WETH public immutable weth;

    /// @notice BunniHub for managing Uniswap v3 liquidity
    IBunniHub public immutable bunniHub;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address zeroExProxy_, WETH weth_, IBunniHub bunniHub_) {
        zeroExProxy = zeroExProxy_;
        weth = weth_;
        bunniHub = bunniHub_;
    }

    /// -----------------------------------------------------------------------
    /// Zaps
    /// -----------------------------------------------------------------------

    /// @notice Deposits tokens into a Bunni LP position and then stakes it in a gauge.
    /// @dev depositParams.recipient is always overridden to address(this) so can just make it 0,
    /// depositParams.amount0Desired and depositParams.amount1Desired are overridden to the balances
    /// of address(this) if the corresponding useContractBalance flag is set to true.
    /// @param depositParams The deposit params passed to BunniHub
    /// @param gauge The gauge contract to stake the LP tokens into. Make sure it isn't malicious!
    /// @param token0 The token0 of the Uniswap pair to LP into
    /// @param token1 The token1 of the Uniswap pair to LP into
    /// @param recipient The recipient of the staked gauge position
    /// @param sharesMin The minimum acceptable amount of shares received. Used for controlling slippage.
    /// @param useContractBalance0 Set to true to use the token0 balance of address(this) instead of msg.sender
    /// @param useContractBalance1 Set to true to use the token1 balance of address(this) instead of msg.sender
    /// @param compound Set to true to compound the Bunni pool before depositing
    /// @return shares The new share tokens minted to the sender
    /// @return addedLiquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function zapIn(
        IBunniHub.DepositParams memory depositParams,
        ILiquidityGauge gauge,
        ERC20 token0,
        ERC20 token1,
        address recipient,
        uint256 sharesMin,
        bool useContractBalance0,
        bool useContractBalance1,
        bool compound
    )
        external
        virtual
        nonReentrant
        returns (uint256 shares, uint128 addedLiquidity, uint256 amount0, uint256 amount1)
    {
        // transfer tokens in and modify deposit params
        if (!useContractBalance0) {
            token0.safeTransferFrom(msg.sender, address(this), depositParams.amount0Desired);
        } else {
            depositParams.amount0Desired = token0.balanceOf(address(this));
        }
        if (!useContractBalance1) {
            token1.safeTransferFrom(msg.sender, address(this), depositParams.amount1Desired);
        } else {
            depositParams.amount1Desired = token1.balanceOf(address(this));
        }
        depositParams.recipient = address(this);

        // compound if requested
        if (compound) {
            bunniHub.compound(depositParams.key);
        }

        // approve tokens to Bunni
        token0.safeApprove(address(bunniHub), depositParams.amount0Desired);
        token1.safeApprove(address(bunniHub), depositParams.amount1Desired);

        // deposit tokens into Bunni
        (shares, addedLiquidity, amount0, amount1) = bunniHub.deposit(depositParams);
        if (shares < sharesMin) {
            revert BunniLpZapIn__InsufficientOutput();
        }

        // stake Bunni shares into gauge
        bunniHub.getBunniToken(depositParams.key).approve(address(gauge), shares);
        gauge.deposit(shares, recipient);

        // refund tokens
        uint256 balance = token0.balanceOf(address(this));
        if (balance != 0) {
            token0.safeTransfer(recipient, balance);
        }
        balance = token1.balanceOf(address(this));
        if (balance != 0) {
            token1.safeTransfer(recipient, balance);
        }
    }

    /// -----------------------------------------------------------------------
    /// WETH support
    /// -----------------------------------------------------------------------

    /// @notice Wraps the user's ETH input into WETH
    /// @dev Should be used as part of a multicall to convert the user's ETH input into WETH
    /// so that it can be swapped into other tokens.
    function wrapEthInput() external payable {
        weth.deposit{value: msg.value}();
    }

    /// -----------------------------------------------------------------------
    /// 0x support
    /// -----------------------------------------------------------------------

    /// @notice Swaps between two regular tokens using 0x.
    /// @dev Used in conjuction with the 0x API https://www.0x.org/docs/api
    /// @param tokenIn The input token
    /// @param tokenAmountIn The amount of token input
    /// @param tokenOut The output token
    /// @param minAmountOut The minimum acceptable token output amount, used for slippage checking.
    /// @param recipient The recipient of the token output
    /// @param refundRecipient The recipient of refunded input tokens
    /// @param useContractBalance Set to true to use the Contract's token balance as token input
    /// @param deadline The Unix timestamp (in seconds) after which the call will be reverted
    /// @param swapData The call data to zeroExProxy to execute the swap, obtained from
    /// the https://api.0x.org/swap/v1/quote endpoint
    /// @return tokenAmountOut The amount of token output
    function doZeroExSwap(
        ERC20 tokenIn,
        uint256 tokenAmountIn,
        ERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        address refundRecipient,
        bool useContractBalance,
        uint256 deadline,
        bytes calldata swapData
    ) external payable virtual nonReentrant returns (uint256 tokenAmountOut) {
        // check if input token equals output
        if (tokenIn == tokenOut) {
            revert BunniLpZapIn__SameToken();
        }

        // check deadline
        if (block.timestamp > deadline) {
            revert BunniLpZapIn__PastDeadline();
        }

        // transfer in input tokens
        if (!useContractBalance) {
            tokenIn.safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        }

        // approve zeroExProxy
        tokenIn.safeApprove(zeroExProxy, tokenAmountIn);

        // do swap via zeroExProxy
        (bool success,) = zeroExProxy.call(swapData);
        if (!success) {
            revert BunniLpZapIn__ZeroExSwapFailed();
        }

        // check slippage
        tokenAmountOut = tokenOut.balanceOf(address(this));
        if (tokenAmountOut < minAmountOut) {
            revert BunniLpZapIn__InsufficientOutput();
        }

        // transfer output tokens to recipient
        if (recipient != address(this)) {
            tokenOut.safeTransfer(recipient, tokenAmountOut);
        }

        // refund input tokens
        uint256 balance = tokenIn.balanceOf(address(this));
        if (balance != 0) {
            tokenIn.safeTransfer(refundRecipient, balance);
        }
    }
}
