# Bunni Zap

Zap contracts for making multiple Bunni interactions in a single transaction.

## `BunniLpZapIn`

This contract is used for adding liquidity to a Bunni pool and then staking it in a gauge. It supports using 0x to perform arbitrary swaps, as well as wrapping ETH to WETH. It uses Multicall to enable performing multiple actions in one transaction.

### Example scenarios

- Basic LP & stake
- Swap once, LP & stake
  - User has only one of the tokens for LPing
  - Swap one for the other via 0x, then pair together to LP
- Swap twice, LP & stake
  - User has an asset other than the tokens for LPing
  - Swap asset for both tokens via 0x, then pair together to LP
- Wrap ETH & XXX
  - All the above scenarios can be combined with wrapping ETH to WETH

## Installation

To install with [DappTools](https://github.com/dapphub/dapptools):

```
dapp install timeless-fi/bunni-zap
```

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install timeless-fi/bunni-zap
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test -f mainnet
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```