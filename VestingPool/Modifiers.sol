pragma ton-solidity >= 0.47.0;

abstract contract Modifiers {
    uint constant ERR_LOW_FEE = 101;
    uint constant ERR_INVALID_SENDER = 102;
    uint constant ERR_EMPTY_CELL = 103;
    uint constant ERR_ADDR_ZERO = 104;
    uint constant ERR_LOW_AMOUNT = 105;
    uint constant ERR_LOW_BALANCE = 106;
    uint constant ERR_NOT_SELF = 107;

    modifier onlyOwner() {
        require(msg.pubkey() == tvm.pubkey(), 100);
        _;
    }

    modifier onlyOwners(mapping(uint256 => bool) keys) {
        require(keys.exists(msg.pubkey()), 100);
        _;
    }

    modifier accept() {
        tvm.accept();
        _;
    }

    modifier contractOnly() {
        require(msg.sender != address(0));
        _;
    }

    modifier minValue(uint128 val) {
        require(msg.value >= val, ERR_LOW_FEE);
        _;
    }

    modifier senderIs(address expected) {
        require(msg.sender == expected, ERR_INVALID_SENDER);
        _;
    }

}