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

Note: Concierge debot address - `0:c99a2ea5049c98c5c96273bbd2df5a75893724f187cb2a5df900c19499a21ccc`


## How to use Boosted Staking from other smart contract

- Call IExtraService.stake function ([IExtraService interface](./interfaces/IExtraService.sol)).

```bash
    /// @notice Allows to make boosted stake. 
    /// Should be called by other smart contract.
    /// @param depools Set of pairs [depool -> amount]. User stake will be split 
    /// between this depools according to defined amounts. Every stake part should
    /// include bonus funds according to period and stake category.
    /// Remark: all depools MUST be in Depooler rating table.
    /// Note: number of stake parts MUST be <= ExtraLib.MAX_STAKE_PARTS.
    /// @param period One of the predefined lock periods of Boosted Program.
    /// @param signature Not used in Boosted Staking Program 1.0.
    /// Remark: It's a part of authorization feature - allow to make boosted stakes
    /// to whitelisted clients only. in ver 1.0 Everyone can make a boosted stake.
    /// @param clientKey Not used in Boosted Staking Program 1.0.
    /// Remark: Client public key used to check @signature argument.
    function stake(
        mapping(address => uint64) depools,
        ExtraLib.Period period,
        bytes signature,
        uint256 clientKey
    )
```

Note: Extra Service address - `0:36443296ce4c9a6f174cc20f9644e6a7f1f5f1dd0542d58e82ee544b3252b1b2`