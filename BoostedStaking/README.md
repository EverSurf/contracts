# Boosted Staking

## Prerequisites

- make

- [tondev](https://github.com/tonlabs/tondev) 0.8.1 (ton-solidity 0.47.0)


## How to build

```bash
make
```

## How to use Boosted Staking from DeBot

- Create client debot.

- Invoke IConcierge.invokeDialog to gather stake parameters from the user.

- Invoke IConcierge.invokeStake to make a boosted stake.

- Invoke IConcierge.invokeGetStakes to query a list of user boosted stakes.

- Invoke IConcierge.invokeWithdraw to withdaw user stake after the end of lock period.

Note: see [IConcierge interface](./interfaces/IConcierge.sol) for a detailed description.

Note: see [ExtraClient debot](./ExtraClient.sol) for an example of a client debot.