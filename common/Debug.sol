pragma ton-solidity >= 0.47.0;
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";

abstract contract Debug {
    mapping(address => bool) m_developers;
    address m_wallet;

    function setDeveloper(address addr) public {
        require(msg.pubkey() == tvm.pubkey());
        tvm.accept();
        m_developers[addr] = true;
    }

    function dbgprint(string m) internal {
        if (m_developers.exists(m_wallet)) {
            Terminal.print(0, format("DBG: {}", m));
        }
    }
}