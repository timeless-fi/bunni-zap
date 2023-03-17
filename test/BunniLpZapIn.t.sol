// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

import "../src/BunniLpZapIn.sol";

contract BunniLpZapInTest is Test {
    BunniLpZapIn zap;
    ERC20 constant token0 = ERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e); // FRAX
    ERC20 constant token1 = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
    IUniswapV3Pool constant uniswapPool = IUniswapV3Pool(0x9A834b70C07C81a9fcD6F22E842BF002fBfFbe4D);
    ILiquidityGauge constant gauge = ILiquidityGauge(0x471A34823DDd9506fe8dFD6BC5c2890e4114Fafe);
    Gate constant gate = Gate(0x36b49ebF089BE8860d7fC60f2553461E9Cc8e9e2); // Yearn gate
    address constant yvusdc = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    IxPYT constant yvusdcXPYT = IxPYT(0x48DB0DE4FeD4b978C1AeA882bc8D9bf94b15a3B7);

    function setUp() public {
        zap = new BunniLpZapIn({
            zeroExProxy_: 0xDef1C0ded9bec7F1a1670819833240f027b25EfF,
            weth_: WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)),
            bunniHub_: IBunniHub(0xb5087F95643A9a4069471A28d32C569D9bd57fE4)
        });

        // approve tokens
        token0.approve(address(zap), type(uint256).max);
        token1.approve(address(zap), type(uint256).max);
    }

    function test_basicAdd() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        (uint256 shares,,,) = zap.zapIn(
            IBunniHub.DepositParams({
                key: BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327}),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            gauge,
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            false
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(gauge.balanceOf(address(this)), shares, "didn't receive gauge shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_basicAddUsingContractBalance() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(zap), amount0Desired);
        deal(address(token1), address(zap), amount1Desired);

        (uint256 shares,,,) = zap.zapIn(
            IBunniHub.DepositParams({
                key: BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327}),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            gauge,
            token0,
            token1,
            address(this),
            0,
            true,
            true,
            false
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(gauge.balanceOf(address(this)), shares, "didn't receive gauge shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_basicAddWithCompound() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        (uint256 shares,,,) = zap.zapIn(
            IBunniHub.DepositParams({
                key: BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327}),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            gauge,
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            true
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(gauge.balanceOf(address(this)), shares, "didn't receive gauge shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_basicAdd_noStake() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        BunniKey memory key = BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327});
        (uint256 shares,,,) = zap.zapInNoStake(
            IBunniHub.DepositParams({
                key: key,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            }),
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            false
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(zap.bunniHub().getBunniToken(key).balanceOf(address(this)), shares, "didn't receive LP shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_basicAdd_noStake_usingContractBalance() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(zap), amount0Desired);
        deal(address(token1), address(zap), amount1Desired);

        BunniKey memory key = BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327});
        (uint256 shares,,,) = zap.zapInNoStake(
            IBunniHub.DepositParams({
                key: key,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            }),
            token0,
            token1,
            address(this),
            0,
            true,
            true,
            false
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(zap.bunniHub().getBunniToken(key).balanceOf(address(this)), shares, "didn't receive LP shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_basicAdd_noStake_withCompound() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        BunniKey memory key = BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327});
        (uint256 shares,,,) = zap.zapInNoStake(
            IBunniHub.DepositParams({
                key: key,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            }),
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            true
        );

        assertGt(shares, 0, "shares is zero");
        assertEq(zap.bunniHub().getBunniToken(key).balanceOf(address(this)), shares, "didn't receive LP shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_multicall_wrapEthAndZap() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        // make multicall
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(BunniLpZapIn.wrapEthInput.selector);
        calls[1] = abi.encodeWithSelector(
            BunniLpZapIn.zapIn.selector,
            IBunniHub.DepositParams({
                key: BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327}),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            gauge,
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            false
        );
        bytes[] memory results = zap.multicall{value: 1 ether}(calls);
        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));

        assertGt(shares, 0, "shares is zero");
        assertEq(gauge.balanceOf(address(this)), shares, "didn't receive gauge shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_multicall_wrapEthAndZapAndReadUniswapState() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        // make multicall
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(BunniLpZapIn.wrapEthInput.selector);
        calls[1] = abi.encodeWithSelector(
            BunniLpZapIn.zapIn.selector,
            IBunniHub.DepositParams({
                key: BunniKey({pool: uniswapPool, tickLower: -276331, tickUpper: -276327}),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            gauge,
            token0,
            token1,
            address(this),
            0,
            false,
            false,
            false
        );
        calls[2] = abi.encodeWithSelector(BunniLpZapIn.uniswapV3PoolState.selector, uniswapPool);
        bytes[] memory results = zap.multicall{value: 1 ether}(calls);
        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));

        assertGt(shares, 0, "shares is zero");
        assertEq(gauge.balanceOf(address(this)), shares, "didn't receive gauge shares");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test_enterWithUnderlying() external {
        uint256 amount = 1e6;

        // mint USDC
        ERC20 usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        deal(address(usdc), address(this), amount);

        // mint yield tokens
        usdc.approve(address(zap), type(uint256).max);
        uint256 mintAmount =
            zap.enterWithUnderlying(gate, address(this), address(this), yvusdc, IxPYT(address(0)), amount, false);

        assertEqDecimal(
            gate.getPerpetualYieldTokenForVault(yvusdc).balanceOf(address(this)), mintAmount, 18, "didn't get PYT"
        );
        assertEqDecimal(
            gate.getNegativeYieldTokenForVault(yvusdc).balanceOf(address(this)), mintAmount, 18, "didn't get NYT"
        );
    }

    function test_enterWithVaultShares() external {
        uint256 amount = 1e6;

        // mint vault shares
        deal(yvusdc, address(this), amount);

        // mint yield tokens
        ERC20(yvusdc).approve(address(zap), type(uint256).max);
        uint256 mintAmount =
            zap.enterWithVaultShares(gate, address(this), address(this), yvusdc, IxPYT(address(0)), amount, false);

        assertEqDecimal(
            gate.getPerpetualYieldTokenForVault(yvusdc).balanceOf(address(this)), mintAmount, 18, "didn't get PYT"
        );
        assertEqDecimal(
            gate.getNegativeYieldTokenForVault(yvusdc).balanceOf(address(this)), mintAmount, 18, "didn't get NYT"
        );
    }

    function test_enterWithUnderlyingAndZapIn() external {
        uint256 amount = 1e6;

        // mint USDC
        ERC20 usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        deal(address(usdc), address(this), amount);

        // mint yield tokens to zap contract
        usdc.approve(address(zap), type(uint256).max);
        zap.enterWithUnderlying(gate, address(zap), address(zap), yvusdc, yvusdcXPYT, amount, false);

        // zap in
        address nyt = address(gate.getNegativeYieldTokenForVault(yvusdc));
        ERC20 token0_ = ERC20(address(yvusdcXPYT) > nyt ? nyt : address(yvusdcXPYT));
        ERC20 token1_ = ERC20(address(yvusdcXPYT) <= nyt ? nyt : address(yvusdcXPYT));
        uint256 amount0Desired = token0_.balanceOf(address(this));
        uint256 amount1Desired = token1_.balanceOf(address(this));
        (uint256 shares,,,) = zap.zapIn(
            IBunniHub.DepositParams({
                key: BunniKey({
                    pool: IUniswapV3Pool(0x742b20bC4E98E457A6E827ce89F50636a938200D),
                    tickLower: 0,
                    tickUpper: 21960
                }),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(0)
            }),
            ILiquidityGauge(0x4A0f5be682622c659c4A3C5996071d8E55695D4c),
            token0_,
            token1_,
            address(this),
            0,
            true,
            true,
            false
        );

        assertGtDecimal(shares, 0, 18, "didn't mint shares");
        assertEq(token0_.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1_.balanceOf(address(zap)), 0, "zap has token1 balance");
    }
}
