pragma ton-solidity >= 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "DeBotInterfaces.sol";
import "../common/Debug.sol";
import "../common/Upgradable.sol";
import "../common/Modifiers.sol";
import "./interfaces/IConcierge.sol";
import "../libraries/FormatLib.sol";

contract ExtraClient is Debot, Debug, Upgradable, Modifiers, IOnDialog, IOnStake, IOnGetStakes {
    
    bytes m_icon;
    uint128 m_walletBalance;
    uint32 m_sigingBoxHandle;
    address m_concierge;
    bytes m_signature;
    uint256 m_clientKey;
    mapping(uint32 => ExtraStake) m_lockedStakes;
    ExtraStake[] m_unlockedStakes;
    uint64 m_chosenStake; // in nanotokens
    uint32 m_chosenPeriod; // in seconds
    uint m_withdrawIndex;

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
        caption = "Up to 20\u2009% APY";
        author = "Ever Surf";
        support = address(0x606545c3b681489f2c217782e2da2399b0aed8640ccbcf9884f75648304dbc77);
        hello = "Long term staking and advanced bonuses are here — time to boost the Everscale Reward by 3–15\u2009%";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, UserInfo.ID, Menu.ID, Sdk.ID ];
    }
   
   function start() public override {
        UserInfo.getAccount(tvm.functionId(setWalletAccount));
        this.substart();
    }

    function setWalletAccount(address value) public {
        m_wallet = value;
    }

    function substart() public view {
        IConcierge(m_concierge).invokeGetStakes();
    }

    function onGetStakes(ExtraStake[] stakes) external override {
        uint64 totalStake = 0;
        uint64 unlockedStake = 0;
        uint64 requestedStake = 0;
        delete m_unlockedStakes;
        delete m_lockedStakes;
        for(ExtraStake s: stakes) {
            uint64 rawAmount = ExtraLib.calcRawStake(s.totalAmount, s.annualYield, s.period.value);
            totalStake += rawAmount;
            if (uint32(now) >= s.unlockedAt) {
                if (s.requested) {
                    requestedStake += rawAmount;
                    totalStake -= rawAmount;
                } else {
                    m_unlockedStakes.push(s);
                    unlockedStake += rawAmount;
                }
            } else {
                m_lockedStakes[s.unlockedAt] = s;
            }
        }
        showMenu(totalStake, unlockedStake, requestedStake);
    }

    function showMenu(uint64 totalStake, uint64 unlockedStake, uint64 requestedStake) public {
        string infoStr = "";
        string prefix = "OK. Let’s see...";
        if (totalStake == 0) {
            infoStr = format("{} There are no stakes around.", prefix);
        } else {
            if (unlockedStake == 0) {
                infoStr = format("{} You’ve deposited {} for staking.", prefix, FormatLib.evers(totalStake));
            } else {
                infoStr = format("{} You’ve deposited {} and can withdraw {} of them.", prefix, FormatLib.evers(totalStake), FormatLib.evers(unlockedStake));
            }
        }
        if (requestedStake != 0) {
            infoStr.append(format(" {} is withdrawn.", FormatLib.evers(requestedStake)));
        }
        Terminal.print(0, infoStr);
        MenuItem[] items;
        items.push( MenuItem("Deposit", "", tvm.functionId(menuStake)) );
        
        if (m_unlockedStakes.length > 0) {
            items.push( MenuItem("Withdraw", "", tvm.functionId(menuWithdraw)) );
        }
        if (totalStake != 0) {
            items.push( MenuItem("Show stakes", "", tvm.functionId(menuShow)) );
        }
        items.push( MenuItem("Learn more", "", tvm.functionId(menuLearnMore)) );
        Menu.select("What’s your plan?", "", items);
    }

    function menuLearnMore(uint32 index) public {
        index;
        Terminal.print(0, "So, you wonder how all this works?");
        Terminal.print(0, "You can deposit any amount from 100 evers and get up to 20\u2009% APY on it.");
        Terminal.print(0, "The larger amount you deposit and the longer staking term you choose, the higher the extra reward you receive:");
        Menu.select("6 months, +3–9 %\nOne year, +5–11 %\nYear and a half, +7–13 %\nTwo years, +9–15 %", "", [ 
            MenuItem("Deposit", "", tvm.functionId(menuStake)),
            MenuItem("I’ll think it over", "", tvm.functionId(onBack))
        ]);
    }

    function onBack(uint32 index) public view {
        index;
        substart();
    }

    function menuStake(uint32 index) public {
        index;
        Sdk.getBalance(tvm.functionId(invokeStakeDialog), m_wallet);
    }

    function invokeStakeDialog(uint128 nanotokens) public {
        m_walletBalance = nanotokens;
        if (m_walletBalance < ExtraLib.MIN_STAKE + ExtraLib.STAKE_FEE) {
            Terminal.print(
                tvm.functionId(substart), 
                format("Sorry, your account does not have {} EVER to process this stake. Top up your balance.", 
                    FormatLib.evers(ExtraLib.MIN_STAKE + ExtraLib.STAKE_FEE))
            );
            return;
        }
        IConcierge(m_concierge).invokeDialog();
    }

    function menuShow(uint32 index) public {
        index;
        Terminal.print(0, "One moment, already checking...");
        printStakes();
    }

    function menuWithdraw(uint32 index) public {
        index;
        Terminal.print(0, "Sure thing!");
        _printWithdrawMenu("Your stakes are waiting for you:");
    }

    function _printWithdrawMenu(string title) private {
        MenuItem[] items;
        for(ExtraStake s: m_unlockedStakes) {
            items.push(MenuItem(
                format("{} evers", FormatLib.evers(s.totalAmount)),
                "",
                tvm.functionId(menuWithdrawStake)
            ));
        }
        if (items.length != 0) {
            items.push(MenuItem("Back", "", tvm.functionId(onBack)));
            Menu.select(title, "", items);
        } else {
            this.substart();
        }
    }

    function menuWithdrawStake(uint32 index) public {
        m_withdrawIndex = index;
        ExtraStake s = m_unlockedStakes[index];
        Terminal.print(0, format("You’ll receive {} evers. They will arrive to your wallet in 54 hours.", FormatLib.evers(s.totalAmount + s.reward)));
        Terminal.print(0, "Processing you withdraw will take a short time.");
        Menu.select("Withdraw now?", "", [
            MenuItem("No, changed my mind", "", tvm.functionId(onBack)),
            MenuItem("Yes, of course", "", tvm.functionId(menuInvokeWithdraw))
        ]);
        
    }

    function menuInvokeWithdraw(uint32 index) public {
        index;
        IConcierge(m_concierge).invokeWithdraw(m_unlockedStakes[m_withdrawIndex].extraAccount);
    }

    function onWithdraw(WithdrawStatus status) public {
        if (status != WithdrawStatus.Success) {
            if (status == WithdrawStatus.LowBalance) {
                Terminal.print(0, "Sorry, your account doesn’t have enougth evers to process this stake. Top up your balance.");
            } else if (status == WithdrawStatus.Canceled) {
                Terminal.print(0, "Sure!");
            } else {
                Terminal.print(0, "Request failed");
            }
        } else {
            Terminal.print(0, "Done! Wait for your evers to arrive, it susually takes up to 54 hours. Thank you for staking with Everscale!");
            m_unlockedStakes[m_withdrawIndex] = m_unlockedStakes[m_unlockedStakes.length - 1];
            m_unlockedStakes.pop();
        }
        _printWithdrawMenu("Don’t forget this also:");
    }

    function printStakes() public {
        uint i = 1;
        if (!m_lockedStakes.empty()) {
            Terminal.print(0, "Everything is safe and sound. Here’s what you deposited:");
        }
        for((uint32 unlockedAt, ExtraStake s): m_lockedStakes) {
            uint32 duration = unlockedAt - math.min(uint32(now), unlockedAt);
            string durationStr = (duration > 1 days) ? 
                format("in {} days", duration / 1 days) : 
                "in the hours to come";
            uint64 rawAmount = ExtraLib.calcRawStake(s.totalAmount, s.annualYield, s.period.value);
            Terminal.print(0, format("{}. {} for {} at {} %\nTill {}, {}.", 
                i, FormatLib.evers(rawAmount), s.period.title, _yieldToStr(s.annualYield), 
                ts2d(unlockedAt), durationStr));

            dbgprint(format("{}", s.extraAccount));
            for((address depool, uint64 amount): s.parts) {
                dbgprint(format("{} tokens - DePool\n{}", FormatLib.evers(amount), depool));
            }
            i++;
        }
        if (m_unlockedStakes.length != 0) {
            Terminal.print(0, "Good news! There is something to withdraw —");
        }
        for (ExtraStake s: m_unlockedStakes) {
            uint64 rawAmount = ExtraLib.calcRawStake(s.totalAmount, s.annualYield, s.period.value);
            uint64 bonus = s.totalAmount - rawAmount + s.reward;
            Terminal.print(0, format("{}. {} evers\nYour reward is {}", i, FormatLib.evers(rawAmount), FormatLib.evers(bonus)));
            dbgprint(format("{}", s.extraAccount));
            for((address depool, uint64 amount): s.parts) {
                dbgprint(format("{} tokens - DePool\n{}", FormatLib.evers(amount), depool));
            }
            i++;
        }

        if (m_unlockedStakes.length != 0) {
            Terminal.print(0, "Or you can choose not to withdraw and continue earning Everscale staking rewards.");
            Menu.select("What’s next?", "", [ 
                MenuItem("Withdraw", "", tvm.functionId(menuWithdraw)),
                MenuItem("Back", "", tvm.functionId(onBack))
            ]);
        } else {
            this.substart();
        }
    }

    function onDialog(uint64 stake, uint32 secs) external override {
        m_chosenStake = stake;
        m_chosenPeriod = secs;
        if (stake == 0 && secs == 0) {
            Menu.select("Sorry, the boosted staking offer is over. Stay in touch for future interesting events — they are on their way!", "", [
                MenuItem("OK, keep me updated", "", tvm.functionId(substart))
            ]);
        } else {
            Terminal.print(0, "Processing your stake will take a short time.");
            Menu.select("Ready to stake?", "", [
                MenuItem("No, changed my mind", "", tvm.functionId(onBack)),
                MenuItem("Yes, of course", "", tvm.functionId(menuInvokeStake))
            ]);
        }
    }

    function menuInvokeStake(uint32 index) public view {
        index;
        IConcierge(m_concierge).invokeStake(m_chosenStake, m_chosenPeriod, m_signature, m_clientKey);
    }

    function onStake(StakeStatus status) external override {
        if (status == StakeStatus.Success) {
            Terminal.print(0, format("Nice doing business with you!\nCome back in {} days to withdraw your funds.", m_chosenPeriod / 86400));
            Terminal.print(0, "If you enjoyed staking with Everscale, tell your friends about it — let them earn too!");
        } else if (status == StakeStatus.LowBalance) {
            Terminal.print(0, format("Sorry, your account does not have {} EVER to process this stake. Change stake amount.", FormatLib.evers(m_chosenStake)));
        } else if (status == StakeStatus.Canceled) {
            Terminal.print(0, "Sure!");
        } else if (status == StakeStatus.NotEnougthExtra) {
            Terminal.print(0, "Sorry, the remaining extra reward is not enougth to boost you stake. Try to low stake amount.");
        } else {
            Terminal.print(0, "Something went wrong. Please run Debot again.");
            dbgprint(format("Failed to stake. {}", statusToStr(status)));
        }
        this.substart();
    }

    function statusToStr(StakeStatus s) private pure returns (string) {
        if (s == StakeStatus.LowBalance) {
            return "Wallet balance is less then stake amount + comission.";
        } else if (s == StakeStatus.ServiceFailed) {
            return "Extra Service failed to handle stake.";
        } else if (s == StakeStatus.InvalidPeriod) {
            return "Invalid period.";
        } else if (s == StakeStatus.CapacityOverrun) {
            return "There is no free space in depools to accept such amount of stake.";
        } else if (s == StakeStatus.Canceled) {
            return "Canceled.";
        }
        return "";
    }

    function _yieldToStr(uint64 yield) private pure returns (string) {
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

    function setConcierge(address addr) public onlyOwner accept {
        m_concierge = addr;
    }

    //
    // Upgradable
    //

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

    //
    // Datetime formatter
    //

    int256 constant JULIAN_BASE = 2440588;
    uint32 constant DAY_IN_SEC = 86400;
    // ts to "Nov 10, 2021"
    function ts2d(uint256 ts) public pure returns (string) {
        int256 tsDays = int(ts / DAY_IN_SEC);

        int256 L = tsDays + JULIAN_BASE + 68569;
        int256 N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 I = 4000 * (L + 1) / 1461001;
        L = L - 1461 * I / 4 + 31;
        int256 _month = 80 * L / 2447;
        int256 _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        I = 100 * (N - 49) + I + L;

        string[] monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return format("{} {}, {}", monthNames[uint256(_month - 1)], uint256(_day), uint256(I));
        
    }
}