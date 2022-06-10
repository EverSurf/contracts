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
import "https://raw.githubusercontent.com/tonlabs/ton-labs-contracts/master/solidity/depool/IParticipant.sol";
import "./libraries/ExtraLib.sol";
import "./interfaces/IDePool.sol";
import "../common/Modifiers.sol";

contract ExtraAccount is IParticipant, Modifiers {
    // Copy from DePool.sol file.
    uint8 constant STATUS_NO_POOLING_STAKE = 27;
    uint constant ERR_UNKNOWN_ADDR = 127;
    uint64 constant STORAGE_FEE = 0.001 ton;

    // Unixtime when funds will be available to the user.
    uint32 m_unlockedAt;
    // List of staked depools (addr -> amount)
    mapping(address => uint64) m_depools;
    // Total rewards from depools.
    uint64 m_rewards;
    // True if funds are unlocked and requested to withdraw.
    bool m_requested;
    // Extra Annual yield multiplied by 10^6
    uint64 m_annualYield;
    // Lock period
    ExtraLib.Period m_period;
    // Unixtime at which account is created, seconds
    uint32 static m_createdAt;
    // Address of the smc from which the stake was sent (usually multisig)
    address m_stakeOwner;
    // Address of the Extra Service
    address m_service;
    // Account revision number
    uint8 m_revision = 4;


    constructor(
        mapping(address => uint64) depools,
        ExtraLib.Period period,
        uint64 yield
    ) public contractOnly {
        (m_service, m_stakeOwner) = _decodeSalt();
        m_unlockedAt = m_createdAt + ExtraLib.periodToSeconds(period);
        require(msg.sender == m_service, ERR_INVALID_SENDER);

        m_depools = depools;
        m_annualYield = yield;
        m_period = period;

        for((address addr, uint64 stake): depools) {
            _makeOrdinaryStake(addr, stake);
        }
    }

    function withdraw() public senderIs(m_stakeOwner) {
        require(uint32(now) >= m_unlockedAt, ExtraLib.ERR_STAKE_LOCKED);
        uint64 count = 0;
        for ((address addr,): m_depools) {
            _withdrawInstant(addr);
            count++;
        }
        require(msg.value >= ExtraLib.calcWithdrawGasFees(count), ExtraLib.ERR_LOW_VALUE);
        m_requested = true;
    }

    function _decodeSalt() internal pure returns(address, address) {
        return tvm.codeSalt(tvm.code()).get().toSlice().decode(address, address);
    }

    /// @notice DePool API. Notification from DePool when round is completed.
    function onRoundComplete(
        uint64 roundId,
        uint64 reward,
        uint64 ordinaryStake,
        uint64 vestingStake,
        uint64 lockStake,
        bool reinvest,
        uint8 reason
    ) external override {
        optional(uint64) stakeOpt = m_depools.fetch(msg.sender);
        require(stakeOpt.hasValue(), ERR_INVALID_SENDER);
        // Increase gas to complete function.
        tvm.accept();
        m_rewards += reward;

        // If DePool is closed or
        // if user requests to return stake 
        // then income value will be >= all stake + reward.
        // But in case of slashing this value can be less then original stake,
        // so some threshold value is used to identify stake return.
        // DePool never returns such a big value on answer.
        if (msg.value >= 10 ton) {
            tvm.commit();
            _returnStakeAndDestroyIfEmpty(stakeOpt.get());
        }
    }

    /// @notice DePool API. Answer from DePool on stake operation.
    function receiveAnswer(uint32 errcode, uint64 comment) external override contractOnly {
        optional(uint64) stakeOpt = m_depools.fetch(msg.sender);
        require(stakeOpt.hasValue(), ERR_INVALID_SENDER);
        tvm.accept();
        if (errcode != 0) {
            if (errcode == STATUS_NO_POOLING_STAKE) {
                _withdrawAll(msg.sender);
            } else {
                if (msg.value >= stakeOpt.get()) {
                    tvm.commit();
                    _returnStakeAndDestroyIfEmpty(stakeOpt.get());
                }
            }
        } else {
            m_service.transfer({value: 0, flag: 64, bounce: false});
        }
    }

    receive() external {
        optional(uint64) stakeOpt = m_depools.fetch(msg.sender);
        if (stakeOpt.hasValue()) {
            tvm.commit();
            _returnStakeAndDestroyIfEmpty(stakeOpt.get());
        }
    }

    function onTransfer(address source, uint128 amount) external override {
        revert(1000);
    }

    //
    // Internals
    //

    function _returnStakeAndDestroyIfEmpty(uint64 stake) private {
        delete m_depools[msg.sender];
        if (uint32(now) < m_unlockedAt) {
            uint64 servicePart = ExtraLib.calcUnusedServicePart(stake, uint64(msg.value), 
                m_createdAt, m_unlockedAt, m_period, m_annualYield);
            if (servicePart > 0) {
                m_service.transfer({value: servicePart, flag: 2, bounce: false});
            }
        }
        if (m_depools.empty()) {
            selfdestruct(m_stakeOwner);
        } else {
            tvm.rawReserve(STORAGE_FEE, 2);
            m_stakeOwner.transfer({value: 0, flag: 128, bounce: false});
        }
    }

    

    function _makeOrdinaryStake(address depool, uint64 stake) private pure {
       IDePool(depool).addOrdinaryStake{value: stake + ExtraLib.DEPOOL_FEE, flag: 1, bounce: true}(stake);
    }

    function _withdrawAll(address depool) private pure {
       IDePool(depool).withdrawAll{value: ExtraLib.DEPOOL_FEE, flag: 1, bounce: true}();
    }

    function _withdrawInstant(address depool) private pure {
       IDePool(depool).withdrawFromPoolingRound{value: ExtraLib.DEPOOL_FEE, flag: 1, bounce: true}(0xFFFFFFFFFFFFFFFF);
    }

    function get() public view returns (
        address service, address owner, uint32 unlockedAt, 
        mapping(address => uint64) depools, uint64 rewards,
        bool requested, uint8 revision) {
        return (m_service, m_stakeOwner, m_unlockedAt, m_depools, m_rewards, m_requested, m_revision);
    }

    //
    // Destroy
    //

    function destroy() public senderIs(m_stakeOwner) {
        require(uint32(now) >= m_unlockedAt, ExtraLib.ERR_STAKE_LOCKED);
        selfdestruct(m_stakeOwner);
    }
}