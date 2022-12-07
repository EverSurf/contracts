pragma ton-solidity >= 0.57.0;
import "../libraries/Structs.sol";

struct GlobalParams {
    address wtonVault;
    address everToTip3;
    address tip3ToEver;
    TokenRoot[] whitelist;
}

struct TokenPrice {
    string name;
    string usdPrice;
    string everPrice;
}

struct SwapPair {
    address addr;
    TokenRoot left;
    TokenRoot right;
    uint128 leftBalance;
    uint128 rightBalance;
    uint128 denominator;
    uint128 nominator;
    uint128 tvl;
}

struct SwapRouteStep {
    uint128 amount;
    uint128 expectedAmount;
    uint128 minExpectedAmount;
    uint128 fee;
    string from;
    string to;
    address receiveAddress;
    address spentAddress;
    SwapPair pair;
}

struct SwapRoute {
    uint128 expectedAmount;
    uint128 expectedMinAmount;
    uint128 leftAmount;
    uint128 rightAmount;
    uint128 priceLeftToRight;
    uint128 priceRightToLeft;
    uint128 slippage;
    SwapRouteStep[] steps;
}

struct WalletStatus {
    address addr;
    bool activated;
}

struct DexPrice {
    uint price;
    uint32 decimals;
    string priceStr;
}

interface ITokenAPI {
    function invokeGetPrices() external;
    function invokeGetDexTokenPrice(string symbol) external;
    function invokeGetGlobalParams() external view responsible returns (GlobalParams params);
    function invokeGetPairTokens(mapping(int32 => TokenWallet) wallets, TokenWallet left) external;
    function invokeGetUserTokens() external;
    function invokeGetCrossPairRoute(address leftRoot, address rightRoot, uint128 amount) external;
    function invokeGetDexPairInfo(address pair) external;
    function invokeGetPairAddress(address leftRoot, address rightRoot) external responsible view returns (address pairAddr);
}

interface ITokenAPI2 {
    function invokeGetRootWallet(
        address root,
        address owner
    ) external responsible functionID(0x12111111) returns (address walletAddr);

    function invokeCheckWalletsByOwner(
        address[] roots,
        address owner
    ) external responsible functionID(0x12111112) 
        returns (mapping(address => WalletStatus) wallets);

    function invokeGetTokenPriceSync(
        string name
    ) external responsible functionID(0x12111113) 
        returns (optional(DexPrice) price);
}

interface IOnGetPrices {
    function onGetPrices(mapping(address => TokenPrice) prices) external;
}

interface IOnGetPairTokens {
    function onGetPairTokens(TokenWallet[] tokens) external;
}

interface IOnGetUserTokens {
    function onGetUserTokens(mapping(int32 => TokenWallet) wallets) external;
}

interface IOnGetCrossPairRoute {
    function onGetCrossPairRoute(optional(SwapRoute) route) external;
}

interface IOnGetDexPairInfo {
    function onGetDexPairInfo(optional(SwapPair) pairInfo) external;
}

interface IOnGetDexTokenPrice {
    function onGetDexTokenPrice(optional(DexPrice) price) external;
}

interface IOnGetTokenTransactions {
    function onGetTokenTransactions(optional(TokenTransactions) txns) external;
}

contract ABI1 is IOnGetPrices, 
                IOnGetPairTokens,
                IOnGetUserTokens,
                IOnGetCrossPairRoute,
                IOnGetDexPairInfo,
                IOnGetDexTokenPrice,
                IOnGetTokenTransactions
{
    function onGetPrices(mapping(address => TokenPrice) prices) external override {}
    function onGetPairTokens(TokenWallet[] tokens) external override {}
    function onGetUserTokens(mapping(int32 => TokenWallet) wallets) external override {}
    function onGetCrossPairRoute(optional(SwapRoute) route) external override {}
    function onGetDexPairInfo(optional(SwapPair) pairInfo) external override {}
    function onGetDexTokenPrice(optional(DexPrice) price) external override {}
    function onGetTokenTransactions(optional(TokenTransactions) txns) external override {}
}