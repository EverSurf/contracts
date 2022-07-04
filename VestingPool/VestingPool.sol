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
import "Modifiers.sol";
import "VestLib.sol";
import "./interfaces/IVestingPool.sol";

contract VestingPool is IVestingPool, Modifiers {
    uint32 constant VESTING_PERIOD = 30 days;
    uint128 constant CONSTRUCTOR_GAS = 0.1 ton;
    uint static id;
    address static creator;
    uint32 m_createdAt;
    uint32 m_cliffEnd;
    uint32 m_vestingEnd;
    uint32 m_vestingFrom;
    uint128 m_totalAmount;
    uint128 m_remainingAmount;
    uint128 m_vestingAmount;
    address m_recipient;
    mapping(uint256 => bool) m_claimers;

    constructor(
        uint128 amount,
        uint8 cliffMonths,
        uint8 vestingMonths,
        address recipient,
        mapping(uint256 => bool) claimers
    ) public contractOnly minValue(amount + VestLib.calcPoolConstructorFee(vestingMonths)) {
        address service = tvm.codeSalt(tvm.code()).get().toSlice().decode(address);
        require(service == msg.sender, ERR_INVALID_SENDER);

        m_createdAt = uint32(now);
        m_cliffEnd = m_createdAt + uint32(cliffMonths) * 30 days;
        m_vestingEnd = m_cliffEnd + uint32(vestingMonths) * 30 days;
        m_totalAmount = amount;
        m_remainingAmount = m_totalAmount;
        m_recipient = recipient;
        m_claimers = claimers;
        m_vestingFrom = m_cliffEnd;
        m_vestingAmount = vestingMonths > 0 ? m_totalAmount / vestingMonths : m_totalAmount;

        IOnPoolActivated(service).onPoolActivated{
            value: 0.03 ever, bounce: false, flag: 0
        }();
    }

    //
    // Claim interface
    //

    function claim(uint poolId) external override onlyOwners(m_claimers) {
        require(poolId == id);
        (uint128 unlocked, uint32 unlockedPeriod) = calcUnlocked();
        require(unlocked > 0);
        tvm.accept();
        m_remainingAmount -= unlocked;
        m_vestingFrom += unlockedPeriod;
        m_recipient.transfer(unlocked, true, 2);

        if (m_remainingAmount == 0) {
            selfdestruct(creator);
        }
    }

    function calcUnlocked() private view returns (uint128, uint32) {
        uint128 unlocked = 0;
        uint32 vestingPeriods = 0;
        uint32 _now = uint32(now);
        if (_now > m_cliffEnd) {
            vestingPeriods = (_now - m_vestingFrom) / (VESTING_PERIOD);
            if (_now > m_vestingEnd) {
                unlocked = m_remainingAmount;
            } else {
                unlocked = math.min(m_remainingAmount, (vestingPeriods * m_vestingAmount));

            }
        } 
        return (unlocked, vestingPeriods * VESTING_PERIOD);
    }

    //
    // OnBounce
    //

    onBounce(TvmSlice slice) external view {
        slice;
        creator.transfer(0, false, 64);
    }

    //
    // Getters
    // 

    function get() external view override returns (
        uint poolId, 
        address poolCreator,
        uint32 createdAt,
        address recipient,
        uint32 cliffEnd,
        uint32 vestingEnd,
        uint128 totalAmount,
        uint128 remainingAmount,
        uint128 unlockedAmount
        ) 
    {
        poolId = id;
        poolCreator = creator;
        createdAt = m_createdAt;
        recipient = m_recipient;
        cliffEnd = m_cliffEnd;
        vestingEnd = m_vestingEnd;
        totalAmount = m_totalAmount;
        remainingAmount = m_remainingAmount;
        (uint128 unlocked,) = calcUnlocked();
        unlockedAmount = unlocked;
    }

}