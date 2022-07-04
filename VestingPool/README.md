# Vesting Pool

**Status**: work in progress

## Prerequisites

- TON-Solidity Compiler 0.61.0

- tvm_linker 0.15.42

# How to create Vesting Pool 

Vesting Service address:

    DEVNET 0:e812f1f1fc2ca1caadacc4460c1265e43089f762f861950ca280c4179f2aa4d1

## via TONOS-CLI

### 1. Install tonos-cli using [everdev](https://github.com/tonlabs/everdev) or build from [source](https://github.com/tonlabs/tonos-cli)

### 2. Download [VestingService.abi.json](https://raw.githubusercontent.com/EverSurf/contracts/main/VestingPool/build/VestingService.abi.json) and place in your working directory

### 3. Create payload:

```bash
tonos-cli -j body createPool '{"amount":<amount_nanoevers>,"cliffMonths":<number>,"vestingMonths":<number>,"recipient":"<everscale address>","claimers":[<pubkey>, ...]}' --abi VestingService.abi.json
```
where:

*amount* - total vesting funds in nanoevers;

*cliffMonths* - cliff period, in months; can be 0 - in that case the first part of the vesting funds will be unlocked after the first month;

*vestingMonths* - total vesting period, in months; each month Vestng Pool will unlock funds equal to `amount/vestingMonths`; can be 0 - in that case all vesting funds will be available right after cliff period;

*recipient* - everscale address of account, which will receive vesting funds;

*claimers* - array of public keys; external inbound message signed by one of these keys can trigger vesting transfer to the recipient address; cannot be empty;

Example:

Create 1M EVER pool with 3 month cliff and 1 year vesting, with 1 claimer:

```bash
tonos-cli -j -u net.ton.dev body createPool '{"amount":1000000000000000,"cliffMonths":3,"vestingMonths":12,"recipient":"0:66e01d6df5a8d7677d9ab2daf7f258f1e2a7fe73da5320300395f99e01dc3b5f","claimers":["0x816747e3c1e0c3be11797a76ffd5f823a1c933586cac2f170bc1395f1f25e15b"]}' --abi VestingService.abi.json 

{
  "Message": "te6ccgEBAgEAYwABdxfCVWkAAAAAAAAAAAADjX6kxoAAAwyADNwDrb61Guzvs1ZbXv5LHjxU/857SmQGAHK/M8A7h2vgAAAAOAEAQ9BAs6Px4PBh3wi8vTt/6vwR0OSZrDZWF4uF4Jyvj5LwrcA="
}
```

### 4. Calculate execution fee:

```bash
tonos-cli -j -u <network> run <vesting_service_address> getCreateFee '{"vestingMonths":<months>}' --abi VestingService.abi.json
```

*network* - `net.ton.dev` for devnet and `main.ton.dev` for mainnet;

*vesting_service_address* - Vesting Service smart contract address;

Example for devnet:

```bash
tonos-cli -j -u net.ton.dev run 0:e812f1f1fc2ca1caadacc4460c1265e43089f762f861950ca280c4179f2aa4d1 getCreateFee '{"vestingMonths":12}' --abi VestingService.abi.json

{
  "fee": "1400000000"
}
```

The command returns execution fee in nanoevers.

### 5. Create pool

Transfer funds + execution fee ([step 4](#4-calculate-execution-fee)) and attach payload ([step 3](#3-create-payload)).

Command example for multisig wallet:

```bash
tonos-cli -j -u <network> call <multisig_address> submitTransaction '{"dest":<vesting_service_address>,"value":<amount_+_fee>,"bounce":true,"allBalance":false,"payload":"<payload>"}' --abi SafeMultisigWallet.abi.json --sign <seed_phrase>
```

where:

*network* - `net.ton.dev` for devnet and `main.ton.dev` for mainnet;

*multisig_address* - address of multisig wallet;

*dest* - address of Vesting Service contract;

*value* - amount of vesting funds and execution fee (gas) for operation;

*payload* - message body created in `tonos-cli body createPool` command.

> **Note**: Do not forget to download the ABI file for the multisig you're working with (e.g. [SafeMultisigWallet.abi.json](https://raw.githubusercontent.com/tonlabs/ton-labs-contracts/master/solidity/safemultisig/SafeMultisigWallet.abi.json)) and place it in your working directory.

Example:

```bash
tonos-cli -j -u net.ton.dev call 0:66e01d6df5a8d7677d9ab2daf7f258f1e2a7fe73da5320300395f99e01dc3b5f submitTransaction '{"dest":"0:e812f1f1fc2ca1caadacc4460c1265e43089f762f861950ca280c4179f2aa4d1","value":1000001400000000,"bounce":true,"allBalance":false,"payload":"te6ccgEBAgEAYwABdxfCVWkAAAAAAAAAAAADjX6kxoAAAwyADNwDrb61Guzvs1ZbXv5LHjxU/857SmQGAHK/M8A7h2vgAAAAOAEAQ9BAs6Px4PBh3wi8vTt/6vwR0OSZrDZWF4uF4Jyvj5LwrcA="}' --abi SafeMultisigWallet.abi.json --sign wallet.keys.json

Result: {
  "transId": "0"
}
```

### 6. Vesting Pool is ready

Go to [vesting.surf](https://vesting.surf) to see your pools.

### Remark for multisig wallet with several custodians

Only one custodian should follow the instruction above and generate `transId`. Other custodians should confirm this `transId` through [`confirmTransaction`](https://github.com/tonlabs/ton-labs-contracts/tree/master/solidity/safemultisig#47-create-transaction-confirmation-online) function.
