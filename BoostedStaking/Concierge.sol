/*
    Boosted Staking System
    Copyright (C) 2022 Ever Surf

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
pragma ton-solidity >= 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "DeBotInterfaces.sol";
import "../common/Upgradable.sol";
import "../common/Modifiers.sol";
import "../common/IMultisig.sol";
import "../common/Debug.sol";
import "./interfaces/IExtraService.sol";
import "./interfaces/IConcierge.sol";
import "../libraries/FormatLib.sol";

interface IExtraAccount {
    function withdraw() external;
}

contract Concierge is Debot, Debug, IConcierge, Upgradable, Modifiers {
    bytes m_icon;
    optional(uint64) m_walletBalance;
    uint32 m_sigingBoxHandle;
    address m_depool;
    // Address of Staking Service smc
    address m_service;
    mapping(uint256 => TvmCell) public m_accountImages;
    mapping(uint32 => ExtraLib.PeriodInfo) m_periods;
    uint32[] m_periodsMenu;
    uint32 m_seconds;
    uint64 m_stake;
    bytes m_signature;
    uint256 m_clientKey;
    address m_invoker;
    address m_extraAccount;
    ExtraStake[] m_stakes;
    bool m_testMode;
    uint256 m_nextImageHash;
    optional(ExtraLib.Statistics) m_stats;
    //
    // DeBot mandatory functions
    //

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Boosted Staking";
        version = "1.0.0";
        publisher = "Ever Surf";
        caption = "Up to 20 % APY";
        author = "Ever Surf";
        support = address(0x606545c3b681489f2c217782e2da2399b0aed8640ccbcf9884f75648304dbc77);
        hello = " ";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, UserInfo.ID, Menu.ID, Sdk.ID ];
    }
   
   function start() public override {}

    //
    // Invoke API functions.
    //

    function invokeDialog() external override {
        m_invoker = msg.sender;
        m_stake = 0;
        m_seconds = 0;
        UserInfo.getAccount(tvm.functionId(setUserAccount));
        _getStats(tvm.functionId(setStats));
        this.enterStake();
    }

    function invokeStake(uint64 stake, uint32 secs, bytes signature, uint256 clientKey) external override {
        m_invoker = msg.sender;
        m_stake = stake;
        m_signature = signature;
        m_clientKey = clientKey;
        m_seconds = secs;
        _getStats(tvm.functionId(setStats));
        if (m_periods.empty()) {
            _getPeriods(tvm.functionId(setPeriods));
        }
        this.validateParameters();
    }

    function invokeWithdraw(address extraAccount) external override {
        m_invoker = msg.sender;
        m_extraAccount = extraAccount;
        UserInfo.getSigningBox(tvm.functionId(setSigningBox));
        UserInfo.getAccount(tvm.functionId(setUserAccount));
        this.withdraw();
    }

    function invokeGetStakes() external override {
        m_invoker = msg.sender;
        m_nextImageHash = 0;
        delete m_stakes;
        if (m_periods.empty()) {
            _getPeriods(tvm.functionId(setPeriods));
        }
        UserInfo.getAccount(tvm.functionId(queryAccounts));
    }

    // -----------------------------------------------------------------

    function menuEnterStake(uint32 index) public {
        index;
        enterStake();
    }

    function enterStake() public {
        if (!m_walletBalance.hasValue()) {
            this.enterStake();
            return;
        }
        if (!ExtraLib.checkBonusCapacity(m_stats.get(), 1 ton)) {
            return onDialogAnswer();
        }
        AmountInput.get(
            tvm.functionId(setAmount),
            "What will be your stake?", 9, 
            ExtraLib.MIN_STAKE, 
            math.min(m_walletBalance.get(), 10000000 ton)
        );
    }

    function validateParameters() public {
        if (!m_periods.exists(m_seconds)) {
            onStakeAnswer(StakeStatus.InvalidPeriod);
            return;
        }
        UserInfo.getSigningBox(tvm.functionId(setSigningBox));
        UserInfo.getAccount(tvm.functionId(setUserAccount));
        this.stake();
    }

    function queryAccounts(address value) public returns (bool) {
        m_wallet = value;
        TvmBuilder b; b.store(m_service, value);
        optional(uint256, TvmCell) opt = m_accountImages.next(m_nextImageHash);
        if (opt.hasValue()) {
            (uint256 hash, TvmCell image) = opt.get();
            m_nextImageHash = hash;
            TvmCell code = tvm.setCodeSalt(image.toSlice().loadRef(), b.toCell());
            Sdk.getAccountsDataByHash(tvm.functionId(setAccounts), tvm.hash(code), address(0));
            return true;
        }
        return false;
    }

    function setAccounts(AccData[] accounts) public {
        for (AccData acc: accounts) {
            (, , , uint32 unlockedAt, mapping(address => uint64) parts, 
                uint64 reward, bool requested, uint64 annualYield, ExtraLib.Period period) = 
                acc.data.toSlice().decode(
                    uint256, uint64, bool, uint32, mapping(address => uint64), 
                    uint64, bool, uint64, ExtraLib.Period
                );
            uint64 totalAmount = 0;
            for ((, uint64 amount): parts) {
                totalAmount += amount;
            }
            string periodStr = m_periods[ExtraLib.periodToSeconds(period)].title;
            ExtraStake es = ExtraStake({
                totalAmount: totalAmount, 
                unlockedAt: unlockedAt, 
                extraAccount: acc.id,
                reward: reward, 
                requested: requested, 
                annualYield: annualYield, 
                period: ExtraLib.PeriodInfo(period, periodStr)
            });
            es.parts = parts;
            m_stakes.push(es);
        }

        if (queryAccounts(m_wallet)) {
            return;
        }

        IOnGetStakes(m_invoker).onGetStakes(m_stakes);
    }

    function setAmount(uint128 value) public {
        m_stake = uint64(value);
        if (m_periods.empty()) {
            _getPeriods(tvm.functionId(setPeriods));
        }
        this.enterPeriod();
    }

    function enterPeriod() public {
        uint32 id = tvm.functionId(menuPeriod);

        string rangeStr = "";
        if (m_stake < 1000 ton) {
            rangeStr = "100 to 999";
        } else if (m_stake < 10000 ton) {
            rangeStr = "1000 to 9999";
        } else if (m_stake < 100000 ton) {
            rangeStr = "10000 to 99999";
        } else {
            rangeStr = "100000";
        }

        (uint64 yield, uint64 bonus) = ExtraLib.calcExtraBonus(m_stake, ExtraLib.Period.m24);
        Terminal.print(0, 
            format("Nice! When you stake from {} tokens, you can earn boosted rewards up to {} %", 
            rangeStr, _yieldToStr(yield)));
        MenuItem[] items;
        for ((uint32 secs, ExtraLib.PeriodInfo p): m_periods) {
            (yield, bonus) = ExtraLib.calcExtraBonus(m_stake, p.value);
            items.push(MenuItem(format("For {} at +{} %", p.title, _yieldToStr(yield)), "", id));
        }
        items.push(MenuItem("Change stake amount", "", tvm.functionId(menuEnterStake)));

        Menu.select("For how long you will delegate evers?", "", items);
    }

    function menuPeriod(uint32 index) public {
        m_seconds = m_periodsMenu[index];
        (uint64 yield, uint64 bonus) = ExtraLib.calcExtraBonus(m_stake, m_periods[m_seconds].value);
        string summary = "";
        summary.append("Stake summary —\n"); 
        summary.append(format("Your stake: {} EVER\n", FormatLib.evers(m_stake)));
        summary.append(format("Staking term: {}\n", m_periods[m_seconds].title));
        summary.append(format("Approximate interest: {}\u2009%\n", _yieldToStr(yield)));
        summary.append(format("Processing fee: {} EVER\n", FormatLib.evers(ExtraLib.STAKE_FEE)));
        summary.append("\nWithout partial or full withdrawal before the term expires.");
        Terminal.print(0, summary);
        onDialogAnswer();
    }

    function onDialogAnswer() public {
        IOnDialog(m_invoker).onDialog(m_stake, m_seconds);
    }

    function onStakeAnswer(StakeStatus status) public view {
        IOnStake(m_invoker).onStake(status);
    }

    function onWithdrawAnswer(WithdrawStatus status) public view {
        IOnWithdraw(m_invoker).onWithdraw(status);
    }

    function setPeriods(mapping(uint32 => ExtraLib.PeriodInfo) periods) public {
        delete m_periods;
        delete m_periodsMenu;
        for ((uint32 secs, ExtraLib.PeriodInfo info): periods) {
            if (secs > 2 days) {
                m_periods[secs] = info;
                m_periodsMenu.push(secs);
            }
        }
    }

    function setSigningBox(uint32 handle) public {
        m_sigingBoxHandle = handle;
    }

    function setUserAccount(address value) public {
        m_wallet = value;
        Sdk.getBalance(tvm.functionId(setWalletBalance), m_wallet);
    }

    function setWalletBalance(uint128 nanotokens) public {
        m_walletBalance = uint64(nanotokens);
    }

    function stake() public {
        if (!m_walletBalance.hasValue()) {
            // come back later
            this.stake();
            return;
        }

        (, uint64 bonus) = ExtraLib.calcExtraBonus(m_stake, m_periods[m_seconds].value);
        if (!ExtraLib.checkBonusCapacity(m_stats.get(), bonus)) {
            return onStakeAnswer(StakeStatus.NotEnougthExtra);
        }

        if (m_testMode) {
            // RESTRICTION FOR TESTING MODE ONLY.
            if (m_seconds > 2 days) {
                Terminal.print(0, "Sorry, selected period in not supported in test mode.");
                onStakeAnswer(StakeStatus.InvalidPeriod);
                return;
            }
        }
        if (m_walletBalance.get() < m_stake + ExtraLib.STAKE_FEE + 0.1 ton) {
            dbgprint(format("balance {:t}, fee {:t}", m_walletBalance.get(), m_stake + ExtraLib.STAKE_FEE + 0.1 ton));
            onStakeAnswer(StakeStatus.LowBalance);
            return;
        }
        optional(uint256) key = 0;
        ExtraLib.Period period = m_periods[m_seconds].value;
        mapping(address => uint64) depools;
        depools[m_depool] = m_stake + bonus;
        TvmCell body = tvm.encodeBody(IExtraService.stake, depools, period, m_signature, m_clientKey);
        IMultisig(m_wallet).sendTransaction{
            abiVer: 2, extMsg: true, sign: true,
            time: 0, expire: 0, pubkey: key, signBoxHandle: m_sigingBoxHandle,
            callbackId: tvm.functionId(onStake),
            onErrorId: tvm.functionId(onStakeError)
        }(m_service, ExtraLib.STAKE_FEE + m_stake, true, 3, body);
    }

    function onStake() public {
        onStakeAnswer(StakeStatus.Success);
    }

    function onStakeError(uint32 sdkError, uint32 exitCode) public {
        dbgprint(format("sdkerror={};exitcode={}", sdkError, exitCode));
        StakeStatus status;
        if (sdkError == 812 || sdkError == 810) {
            status = StakeStatus.Canceled;
        } else {
            status = StakeStatus.ServiceFailed;
        }
        onStakeAnswer(status);
    }

    function withdraw() public {
        if (!m_walletBalance.hasValue()) {
            this.withdraw();
            return;
        }
        bool found = false;
        uint64 count = 0;
        bool requested = false;
        for(ExtraStake s: m_stakes) {
            if (s.extraAccount == m_extraAccount) {
                found = true;
                requested = s.requested;
                for((, uint64 v): s.parts) { count++; }
                break;
            }
        }
        if (!found) {
            onWithdrawAnswer(WithdrawStatus.StakeNotFound);
            return;
        }
        if (count == 0) {
            onWithdrawAnswer(WithdrawStatus.AlreadyReturned);
            return;
        }
        if (requested) {
            onWithdrawAnswer(WithdrawStatus.AlreadyRequested);
            return;
        }

        if (m_walletBalance.get() < ExtraLib.calcWithdrawGasFees(count) + 0.1 ton) {
            onWithdrawAnswer(WithdrawStatus.LowBalance);
            return;
        }

        optional(uint256) key = 0;
        TvmCell body = tvm.encodeBody(IExtraAccount.withdraw);
        IMultisig(m_wallet).sendTransaction{
            abiVer: 2, extMsg: true, sign: true,
            time: 0, expire: 0, pubkey: key, signBoxHandle: m_sigingBoxHandle,
            callbackId: tvm.functionId(onWithdraw),
            onErrorId: tvm.functionId(onWithdrawError)
        }(m_extraAccount, ExtraLib.calcWithdrawGasFees(count), true, 3, body);
    }

    function onWithdraw() public {
        onWithdrawAnswer(WithdrawStatus.Success);
    }

    function onWithdrawError(uint32 sdkError, uint32 exitCode) public {
        dbgprint(format("sdkerror={};exitcode={}", sdkError, exitCode));
        WithdrawStatus status;
        if (sdkError == 812 || sdkError == 810) {
            status = WithdrawStatus.Canceled;
        } else {
            status = WithdrawStatus.ExtraAccountFailed;
        }
        onWithdrawAnswer(status);
    }

    function setStats(ExtraLib.Statistics stats) public {
        m_stats = stats;
    }

    //
    // Get-methods
    //

    function _getPeriods(uint32 answerId) internal view {
        IExtraService(m_service).getPeriods{
            abiVer: 2, extMsg: true, sign: false,
            time: uint64(now), expire: 0,
            callbackId: answerId, onErrorId: 0
        }();
    }

    function _getStats(uint32 answerId) internal view {
        if (!m_stats.hasValue()) {
            IExtraService(m_service).getStats {
                abiVer: 2, extMsg: true, sign: false,
                time: uint64(now), expire: 0,
                callbackId: answerId, onErrorId: 0
            }();
        }
    }

    //
    // Helpers
    //

    function _yieldToStr(uint64 yield) private returns (string) {
        ufixed64x6 percent = ufixed64x6(yield) / ufixed64x6(1000000);
        string str = format("{}", percent);
        uint i = str.byteLength() - 1;
        while (bytes(str)[i] == '0') {
            i--;
        }
        if (bytes(str)[i] == '.') i--;

        return str.substr(0, i + 1);
    }

    // -----------------------------------------------------------------
    //
    // Onchain functions
    // 

    function setIcon(bytes icon) public onlyOwner accept {
        m_icon = icon;
    }

    function setService(address addr) public onlyOwner accept {
        m_service = addr;
    }

    function setDePool(address addr) public onlyOwner accept {
        m_depool = addr;
    }

    function setAccountImage(TvmCell image) public onlyOwner accept {
        m_accountImages[tvm.hash(image)] = image;
    }

    //
    // Upgradable
    //

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
}