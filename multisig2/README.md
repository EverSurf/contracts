# Multisignature Wallet 2.0

**Status**: completed, release in progress

There are two versions of multisig wallet:

- [SafeMultisig](./build/SafeMultisig.tvc) - multisignature wallet without upgrade feature;

    code hash: `7a49d29d05c56b4ef41c77170dde1c31c70959bd5a7a682f8ae57065e8fbc161`

- [SetcodeMultisig](./build/SetcodeMultisig.tvc) - multisignature wallet with upgrade feature.

    code hash: `1c75ca12b493ff32a3c7eb5056db5f4b7e1438b1d503f4a9ffb64d89ac6705cf`

    NOTE: don't use SetcodeMultisig to update old mulsitig wallet.

- SurfMultisig - copy of setcode multisignature wallet but with ability to update old multisig.

**IMPORTANT: tvc image for SurfMultisig is not released yet. It will be available after solidity 0.65.0 release.**

## How to build SafeMultisig and SetcodeMultisig

### Build [sold 0.64.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.64.0/sold)

It's an utility with solidity compiler and linker in one binary. 

sold v0.64.0 includes

- [TON-Solidity Compiler 0.64.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.64.0)

- tvm_linker 0.15.70

### Build smart contract

```bash
    sold SafeMultisig.sol
    sold SetcodeMultisig.sol
```

NOTE: you can compile and link multisig wallet manually using required compiler & linker versions.

## How to build SurfMultisig 

Run bash script:

```bash
    ./create_surfmsig.sh
```

### Build [sold 0.65.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.65.0/sold)

It's an utility with solidity compiler and linker in one binary. 

sold v0.65.0 includes

- [TON-Solidity Compiler 0.65.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.65.0)

- tvm_linker 0.18.1

Run:

```bash
    sold SurfMultisig.sol
```