pragma ton-solidity >= 0.57.0;

struct TokenRoot {
    string symbol;
    string name;
    uint8 decimals;
    address addr;
    string logoURI;
    int8 version;
}

struct TokenWallet {
    TokenRoot root;
    address addr;
    uint128 balance;
}

struct Rate {
    uint128 expected;
    string expectedStr;
    uint128 rate;
    string rateStr;
    uint128 fee;
    string feeStr;
}

struct Pair {
    TokenWallet left;
    TokenWallet right;
}

struct ReceiverTip3 {
    address ownerAddress;
    optional(address) tokenWalletAddress;
}

struct TransactionTip3 {
    string amount;
    uint64 blockTime;
    string kind;
    ReceiverTip3 receiver;
    address rootAddress;
    ReceiverTip3 sender;
    string standard;
    string token;
    string transactionHash;
}

struct TokenTransactions {
    uint64 limit;
    uint64 offset;
    uint64 totalCount;
    TransactionTip3[] transactions;
}

enum Status {
    Success,
    InvalidAmount,
    InvalidPair,
    NotEnoughTokens,
    NotEnoughEvers,
    UnsupportedRightToken,
    SwapFailed,
    SwapCanceled,
    RecipientUnexist,
    SwapImpossible
}

library Fees {
    uint128 constant P100 = 10000;
    // Percent with 2 decimals
    uint128 constant DEFAULT_COMMISSION = 50; // 0.10%
}

library Consts {
    uint256 constant EVER_ROOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint8 constant ACTION_TIP3_TIP3 = 0;
    uint8 constant ACTION_TIP3_EVER = 1;
    uint8 constant ACTION_RECEIVE_TIP3 = 2;
    uint8 constant ACTION_EVER_TIP3 = 3;

    uint128 constant MIN_TVL = 50000;
}