/*
    Vesting Pool
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
pragma ton-solidity >=0.61.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "./interfaces/IVestingService.sol";
import "VestingPool.sol";
import "Modifiers.sol";
import "VestLib.sol";

contract VestingService is IVestingService, IOnPoolActivated, Modifiers {
    uint constant ERR_TOO_MANY_CLAIMERS = 201;
    uint constant ERR_NO_CLAIMERS = 202;
    uint constant ERR_INVALID_RECIPIENT = 203;

    TvmCell m_poolCode;
    uint256 m_nextId;
    mapping(address => address) public m_onbounceMap;


    modifier checkMinMaxClaimers(uint256[] claimers) {
        require(claimers.length > 0, ERR_NO_CLAIMERS);
        require(claimers.length <= VestLib.MAX_CLAIMERS, ERR_TOO_MANY_CLAIMERS);
        _;
    }

    modifier validRecipient(address addr) {
        require(addr.value != 0 && addr.wid == 0, ERR_INVALID_RECIPIENT);
        _;
    }

    constructor(TvmCell poolImage) public onlyOwner accept {
        m_poolCode = poolImage.toSlice().loadRef();
        m_nextId = 1;
    }

    /// @notice Allows to create pool with cliff and vesting params
    /// @param amount Total amount of funds in Pool, in nanoevers
    /// @param cliffMonths Lock period before vesting starts, in months
    /// @param vestingMonths Total vesting period with step = 1 month, in months
    /// @param recipient Recipient address of pool funds
    /// @param claimers Array of public keys which allowed to request funds from pool.
    function createPool(
        uint128 amount,
        uint8 cliffMonths,
        uint8 vestingMonths,
        address recipient,
        uint256[] claimers
    ) external override
        contractOnly
        validRecipient(recipient)
        checkMinMaxClaimers(claimers)
        minValue(amount + VestLib.calcCreateGasFee(vestingMonths))
    {
        mapping(uint256 => bool) claimersMap;
        for(uint256 pubkey: claimers) {
            claimersMap[pubkey] = true;
        }
        address pool = new VestingPool{
            value: 0,
            flag: 64,
            bounce: true,
            stateInit: buildPoolImage(msg.sender, m_nextId)
        }(amount, cliffMonths, vestingMonths, recipient, claimersMap);
        m_nextId++;
        m_onbounceMap[pool] = msg.sender;
    }

    //
    // Internals
    //

    function buildPoolImage(
        address creator,
        uint256 id
    ) private view returns (TvmCell) {
        TvmBuilder b; b.store(address(this));
        TvmCell code = tvm.setCodeSalt(m_poolCode, b.toCell());
        return tvm.buildStateInit({
            code: code,
            varInit: {id: id, creator: creator},
            contr: VestingPool
        });
    }

    //
    // Getters
    //

    function getPoolCodeHash() external override view returns (uint256 codeHash) {
        TvmBuilder b; b.store(address(this));
        TvmCell code = tvm.setCodeSalt(m_poolCode, b.toCell());
        codeHash = tvm.hash(code);
    }

    function getCreateFee(uint8 vestingMonths) external override pure returns (uint128 fee) {
        fee = VestLib.calcCreateGasFee(vestingMonths);
    }

    //
    // OnBounce
    //

    onBounce(TvmSlice slice) external {
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(VestingPool)) {
            optional(address) entry = m_onbounceMap.fetch(msg.sender);
            if (entry.hasValue()) {
                delete m_onbounceMap[msg.sender];
                address poolCreator = entry.get();
                poolCreator.transfer(0, false, 64);
            }
        }
    }

    function onPoolActivated() external override {
        optional(address) entry = m_onbounceMap.fetch(msg.sender);
        if (entry.hasValue()) {
            delete m_onbounceMap[msg.sender];
        }
    }

}