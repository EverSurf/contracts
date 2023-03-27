# Multisignature Wallet 2.0

**WARMING**: multisig source code and build artifacts were cloned to a separate repository:

[Multisig 2.0 repository](https://github.com/EverSurf/multisig2)


**Status**: Released

There are 3 versions of multisig wallet:

- [SafeMultisig](./build/SafeMultisig.tvc) - multisignature wallet without upgrade feature;

    code hash: `4f70388d532a34cf68e6a495e4600d6c9000e37e44041c72f1e3f6e979d4544d`

- [SetcodeMultisig](./build/SetcodeMultisig.tvc) - multisignature wallet with upgrade feature.

    code hash: `aa3c3fad9ea9fc652e60f659c58702f64f02e18a81ec9972f05339d06cb1aed2`

    **IMPORTANT**: don't use SetcodeMultisig to update old mulsitig wallet.

- [UpdateMultisig](./build/UpdateMultisig.tvc) - copy of setcode multisignature wallet but with ability to update old [setcode](https://github.com/tonlabs/ton-labs-contracts/tree/master/solidity/setcodemultisig)/[surf](https://github.com/EverSurf/contracts/tree/main/surfmultisig) multisig.

    code hash: `835b577231faf863755455517145ff5bf03c63aaff6e03d12ea5beef2385b20d`

    NOTE: run `create_updmsig.sh` to generate UpdateMultisig.sol from SetcodeMultisig.sol.

## How to build SafeMultisig and SetcodeMultisig

### Build [sold 0.66.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.66.0/sold)

`sold` is an utility with solidity compiler and linker in one binary. 

sold v0.66.0 includes

- [TON-Solidity Compiler 0.66.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.66.0)

- [tvm_linker 0.18.4](https://github.com/tonlabs/TVM-linker/releases/tag/0.18.4)

### Build smart contract

```bash
    sold SafeMultisig.sol
    sold SetcodeMultisig.sol
```

NOTE: you can compile and link multisig wallet manually using required compiler & linker versions.

## How to build UpdateMultisig 

#### Run bash script

```bash
    ./create_updmsig.sh
```

#### Build [sold 0.66.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/0.66.0/sold)

#### Compile with sold

```bash
    sold UpdateMultisig.sol
```