# Multisignature Wallet 2.0

**Status**: completed, release in progress

There are two versions of multisig wallet:

- [SafeMultisig](./build/SafeMultisig.tvc) - multisignature wallet without upgrade feature;

    code hash: `1974b06efa89ba22d1962d06efaef6d00751b7cdc3156c151bb0cc1c504e7e8c`

- SetcodeMultisig - multisignature wallet with upgrade feature.

**IMPORTANT: tvc image for SetcodeMultisig is not production ready. Dont use it in production environment.**

## How to build SafeMultisig 

### Build [sold 0.64.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.64.0/sold)

It's an utility with solidity compiler and linker in one binary. 

sold v0.64.0 includes

- [TON-Solidity Compiler 0.64.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.64.0)

- tvm_linker 0.15.70

### Build smart contract

```bash
    sold SafeMultisig.sol
```

NOTE: you can compile and link multisig wallet manually using required compiler & linker versions.

## How to build SetcodeMultisig 

TODO