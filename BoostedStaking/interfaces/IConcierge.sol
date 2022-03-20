pragma ton-solidity >= 0.47.0;
import "../libraries/ExtraLib.sol";

enum StakeStatus {
    Success,
    LowBalance,
    ServiceFailed,
    InvalidPeriod,
    CapacityOverrun,
    Canceled,
    NotEnougthExtra
}

enum WithdrawStatus {
    Success,
    LowBalance,
    ExtraAccountFailed,
    StakeNotFound,
    AlreadyReturned,
    AlreadyRequested,
    Canceled
}

struct ExtraStake {
    mapping(address => uint64) parts;
    uint64 totalAmount;
    uint64 reward;
    uint32 unlockedAt;
    address extraAccount;
    bool requested;
    uint64 annualYield;
    ExtraLib.PeriodInfo period;
}

interface IConcierge {
    function invokeDialog() external;
    function invokeStake(uint64 stake, uint32 secs, bytes signature, uint256 clientKey) external;
    function invokeGetStakes() external;
    function invokeWithdraw(address extraAccount) external;
}

interface IOnDialog {
    function onDialog(uint64 stake, uint32 secs) external;
}

interface IOnStake {
    function onStake(StakeStatus status) external;
}

interface IOnGetStakes {
    function onGetStakes(ExtraStake[] stakes) external;
}

interface IOnWithdraw {
    function onWithdraw(WithdrawStatus status) external;
}


contract Test is IOnGetStakes, IOnWithdraw, IOnStake {
    function onStake(StakeStatus status) external override {}
    function onGetStakes(ExtraStake[] stakes) external override {}
    function onWithdraw(WithdrawStatus status) external override {}
}