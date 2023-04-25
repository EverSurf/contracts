pragma ton-solidity >=0.65.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/AddressInput/AddressInput.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/AmountInput/AmountInput.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/ConfirmInput/ConfirmInput.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Sdk/Sdk.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Menu/Menu.sol";
import "Upgradable.sol";
import "Transferable.sol";

// A copy of structure from multisig contract
struct Transaction {
    // Transaction Id.
    uint64 id;
    // Transaction confirmations from custodians.
    uint32 confirmationsMask;
    // Number of required confirmations.
    uint8 signsRequired;
    // Number of confirmations already received.
    uint8 signsReceived;
    // Public key of custodian queued transaction.
    uint256 creator;
    // Index of custodian.
    uint8 index;
    
    // Destination address of gram transfer.
    address  dest;

    // Amount of nanograms to transfer.
    uint128 value;
    // Flags for sending internal message (see SENDRAWMSG in TVM spec).
    uint16 sendFlags;
    // Payload used as body of outbound internal message.
    TvmCell payload;
    // Bounce flag for header of outbound internal message.
    bool bounce;
    //state init
    optional(TvmCell) stateInit;
}

struct CustodianInfo {
    uint8 index;
    uint256 pubkey;
}

abstract contract AMultisig {
    function submitTransaction(
        address  dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload,
        optional(TvmCell) stateInit)
    public returns (uint64 transId) {}

    function confirmTransaction(uint64 transactionId) public {}

    function getCustodians() public returns (CustodianInfo[] custodians) {}
    function getTransactions() public view returns (Transaction[] transactions) {}
}

abstract contract Utility {
    function tonsToStr(uint128 nanotons) internal pure returns (string) {
        (uint64 dec, uint64 float) = _tokens(nanotons);
        string floatStr = format("{}", float);
        while (floatStr.byteLength() < 9) {
            floatStr = "0" + floatStr;
        }
        return format("{}.{}", dec, floatStr);
    }

    function _tokens(uint128 nanotokens) internal pure returns (uint64, uint64) {
        uint64 decimal = uint64(nanotokens / 1e9);
        uint64 float = uint64(nanotokens - (decimal * 1e9));
        return (decimal, float);
    }
}
/// @notice Multisig Debot v1 (with debot interfaces).
contract MsigDebot is Debot, Upgradable, Transferable, Utility {

    uint8 constant ABI_2_3 = 50;

    address m_wallet;
    uint128 m_balance;
    CustodianInfo[] m_custodians;
    Transaction[] m_transactions;

    bool m_bounce;
    uint128 m_tons;
    address m_dest;
    TvmCell m_payload;
    optional(TvmCell) m_stateInit;
    bytes m_icon;

    // ID of current transaction that wass choosen for confirmation.
    uint64 m_id;
    // Function Id to jump in case of error.
    uint32 m_retryId;
    // Function id to jump in case of successfull onchain transaction.
    uint32 m_continueId;
    // Default constructor

    //
    // Setters
    //

    function setIcon(bytes icon) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        m_icon = icon;
    }

    //
    // Debot Basic API
    //

    function setABIBytes(bytes dabi) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        m_options |= DEBOT_ABI;
        m_debotAbi = dabi;
    }

    function start() public override {
        _start();
    }

    function _start() private {
        AddressInput.get(tvm.functionId(startChecks), "Which wallet do you want to work with?");
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Multisig v2";
        version = format("{}.{}.{}", 2,0,0);
        publisher = "";
        caption = "DeBot for multisig wallets";
        author = "";
        support = address.makeAddrStd(0, 0x66e01d6df5a8d7677d9ab2daf7f258f1e2a7fe73da5320300395f99e01dc3b5f);
        hello = "Hi, I will help you work with multisig wallets that can have multiple custodians.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, AmountInput.ID, ConfirmInput.ID, AddressInput.ID, Menu.ID ];
    }

    /*
    * Public
    */

    function startChecks(address value) public {
        Sdk.getAccountType(tvm.functionId(checkStatus), value);
        m_wallet = value;
	}

    function checkStatus(int8 acc_type) public {
        if (!_checkActiveStatus(acc_type, "Wallet")) {
            _start();
            return;
        }

        Sdk.getAccountCodeHash(tvm.functionId(checkWalletHash), m_wallet);
    }

    function checkWalletHash(uint256 code_hash) public {
        // setcode msig
        if (code_hash != 0xd66d198766abdbe1253f3415826c946c371f5112552408625aeb0b31e0ef2df3 ||
            // safe msig
            code_hash != 0x7377910a1b5d0c8073ba02523e139c7f42f9772fe0076a4d0b211ccec071eb7a ||
            // update msig
            code_hash != 0xea5f076ec0a49db435eb74fbef888a2fe7d470787c14210d923f487394f53245) {
            _start();
            return;
        }
        preMain();
    }

    function _checkActiveStatus(int8 acc_type, string obj) private returns (bool) {
        if (acc_type == -1)  {
            Terminal.print(0, obj + " is inactive");
            return false;
        }
        if (acc_type == 0) {
            Terminal.print(0, obj + " is uninitialized");
            return false;
        }
        if (acc_type == 2) {
            Terminal.print(0, obj + " is frozen");
            return false;
        }
        return true;
    }

    function preMain() public  {
        _getTransactions(tvm.functionId(setTransactions));
        _getCustodians(tvm.functionId(setCustodians));
        Sdk.getBalance(tvm.functionId(initWallet), m_wallet);
    }

    function setTransactions(Transaction[] transactions) public {
        m_transactions = transactions;
    }

    function setCustodians(CustodianInfo[] custodians) public {
        m_custodians = custodians;
    }

    function initWallet(uint128 nanotokens) public {
        m_balance = nanotokens;
        mainMenu();
    }

    function mainMenu() public {
        string str = format("This wallet has {} tokens on the balance. It has {} custodian(s) and {} unconfirmed transactions.",
            tonsToStr(m_balance), m_custodians.length, m_transactions.length);
        Terminal.print(0, str);

        _gotoMainMenu();
    }

    function startSubmit(uint32 index) public {
        index = index;
        AddressInput.get(tvm.functionId(setDest), "What is the recipient address?");
    }

    function setDest(address value) public {
        m_dest = value;
        Sdk.getAccountType(tvm.functionId(checkRecipient), value);
    }

    function checkRecipient(int8 acc_type) public {
        if (acc_type == 2) {
            Terminal.print(tvm.functionId(Debot.start), "Recipient is frozen.");
            return;
        }
        if (acc_type == -1 || acc_type == 0) {
            ConfirmInput.get(tvm.functionId(submitToInactive), "Recipient is inactive. Continue?");
            m_bounce = false;
            return;
        } else {
            m_bounce = true;
        }

        AmountInput.get(tvm.functionId(setTons), "How many tokens to send?", 9, 1e7, m_balance);
    }

    function submitToInactive(bool value) public {
        if (!value) {
            Terminal.print(tvm.functionId(Debot.start), "Operation aborted.");
            return;
        }
        AmountInput.get(tvm.functionId(setTons), "How many tokens to send?", 9, 1e7, m_balance);
    }

    function setTons(uint128 value) public {
        m_tons = value;
        string fmt = format("Transaction details:\nRecipient: {}.\nAmount: {} tokens.\nConfirm?", m_dest, tonsToStr(value));
        ConfirmInput.get(tvm.functionId(submit), fmt);
    }

    function callSubmitTransaction() public view {
        optional(uint256) pubkey = 0;
        AMultisig(m_wallet).submitTransaction{
            abiVer: ABI_2_3,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_dest, m_tons, m_bounce, false, m_payload, m_stateInit).extMsg;
    }

    function submit(bool value) public {
        if (!value) {
            Terminal.print(0, "Ok, maybe next time.");
            _start();
            return;
        }
        TvmCell empty;
        m_payload = empty;
        m_continueId = tvm.functionId(Debot.start);
        m_retryId = tvm.functionId(submit);
        callSubmitTransaction();
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        // TODO: parse different types of errors: sdkError and exit Code.
        // DeBot can undestand if txn was reejcted by user or if wallet contract throws an exception.
        // DeBot can help user to undestand when keypair is invalid, for example.
        exitCode = exitCode; sdkError = sdkError;
        ConfirmInput.get(m_retryId, "Transaction failed. Do you want to retry transaction?");
    }

    function onSuccess(uint64 transId) public {
        if (m_custodians.length <= 1) {
            Terminal.print(0, "Transaction succeeded.");
        } else {
            string fmt = format("Transaction {:x} submitted and waiting for confirmations from other custodians.", transId);
            Terminal.print(0, fmt);
        }
        _start();
    }

    function showCustodians(uint32 index) public {
        index = index;
        Terminal.print(0, "Wallet custodian public key(s):");
        for (uint i = 0; i < m_custodians.length; i++) {
            Terminal.print(0, format("{:x}", m_custodians[i].pubkey));
        }
        _gotoMainMenu();
    }

    function showTransactions(uint32 index) public {
        index = index;
        Terminal.print(0, "Unconfirmed transactions:");
        for (uint i = 0; i < m_transactions.length; i++) {
            //Terminal.print(0,format("222 {}",i));
            Transaction txn = m_transactions[i];
            //Terminal.print(0, format("ID {:x}",txn.id));
            Terminal.print(0, format("ID {:x}\nRecipient: {}\nAmount: {}\nConfirmations received: {}\nConfirmations required: {}\nCreator custodian public key: {:x}",
                txn.id, txn.dest, tonsToStr(txn.value),
                txn.signsReceived, txn.signsRequired, txn.creator));
        }
        _gotoMainMenu();
    }

    function printMenu(uint32 index) public view {
        index = index;
        _gotoMainMenu();
    }

    function confirmMenu(uint32 index) public view {
        index = index;
        _getTransactions(tvm.functionId(printConfirmMenu));
    }

    function printConfirmMenu(Transaction[] transactions) public {
        m_transactions = transactions;
        if (m_transactions.length == 0) {
            _gotoMainMenu();
            return;
        }

        MenuItem[] items;
        for (uint i = 0; i < m_transactions.length; i++) {
            Transaction txn = m_transactions[i];
            items.push( MenuItem(format("ID {:x}", txn.id), "", tvm.functionId(confirmTxn)) );
        }
        items.push( MenuItem("Back", "", tvm.functionId(printMenu)) );
        Menu.select("Choose transaction:", "", items);
    }

    function confirmTxn(uint32 index) public {
        m_id = m_transactions[index].id;
        confirm(true);
    }

    function confirm(bool value) public {
        if (!value) {
            _start();
            return;
        }
        optional(uint256) pubkey = 0;
        m_retryId = tvm.functionId(confirm);
        AMultisig(m_wallet).confirmTransaction{
            abiVer: ABI_2_3,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onConfirmSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_id).extMsg;
    }

    function onConfirmSuccess() public {
        Terminal.print(0, "Transaction confirmed.");
        confirmMenu(0);
    }

    function _gotoMainMenu() private view {
        _getTransactions(tvm.functionId(printMainMenu));
    }

    function printMainMenu(Transaction[] transactions) public {
        m_transactions = transactions;
        MenuItem[] items;
        items.push( MenuItem("Submit transaction", "", tvm.functionId(startSubmit)) );
        items.push( MenuItem("Show custodians", "", tvm.functionId(showCustodians)) );
        if (m_transactions.length != 0) {
            items.push( MenuItem("Show transactions", "", tvm.functionId(showTransactions)) );
            items.push( MenuItem("Confirm transaction", "", tvm.functionId(confirmMenu)) );
        }
        Menu.select("What's next?", "", items);
    }

    function _getTransactions(uint32 answerId) private view {
        optional(uint256) none;
        AMultisig(m_wallet).getTransactions{
            abiVer: ABI_2_3,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }().extMsg;
    }

    function _getCustodians(uint32 answerId) private view {
        optional(uint256) none;
        AMultisig(m_wallet).getCustodians{
            abiVer: ABI_2_3,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }().extMsg;
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }


    //
    // Functions for external or internal invoke.
    //

    function invokeTransaction(address sender, address recipient, uint128 amount, bool bounce, TvmCell payload,  optional(TvmCell) stateInit) public {
        m_dest = recipient;
        m_tons = amount;
        m_bounce = bounce;
        m_payload = payload;
        m_wallet = sender;
        m_stateInit = stateInit;
        (, uint bits, uint refs) = payload.dataSize(1000);
        ConfirmInput.get(tvm.functionId(retryInvoke), format("Transaction details:\nRecipient address: {}\nAmount: {} tons\nPayload: {}",
            recipient, tonsToStr(amount), (bits == 0 && refs == 0) ? "NO" : "YES"));
    }

    function invokeTransaction2(address value) public {
        m_wallet = value;
        callSubmitTransaction();
    }

    function retryInvoke(bool value) public {
        if (!value) {
            Terminal.print(0, "Transaction aborted.");
            start();
            return;
        }
        m_retryId = tvm.functionId(retryInvoke);
        m_continueId = 0;
        if (m_wallet == address(0)) {
            AddressInput.get(tvm.functionId(invokeTransaction2), "Which wallet do you want to make a transfer from?");
        } else {
            callSubmitTransaction();
        }
    }

    //
    // Getters
    //

    function decodeId(TvmCell body) public view returns (uint32 id) {
        TvmSlice s = body.toSlice();
        s.decode(bool, bool, uint64, uint32);
        return s.decode(uint32);
    }

    function getInvokeMessage(address sender, address recipient, uint128 amount, bool bounce, TvmCell payload, optional(TvmCell) stateInit) public pure
        returns(TvmCell message) {
        TvmCell body = tvm.encodeBody(MsigDebot.invokeTransaction, sender, recipient, amount, bounce, payload, stateInit);
        TvmBuilder message_;
        message_.store(false, true, true, false, address(0), address(this));
        message_.storeTons(0);
        message_.storeUnsigned(0, 1);
        message_.storeTons(0);
        message_.storeTons(0);
        message_.store(uint64(0));
        message_.store(uint32(0));
        message_.storeUnsigned(0, 1); //init: nothing$0
        message_.storeUnsigned(1, 1); //body: right$1
        message_.store(body);
        message = message_.toCell();
    }
}