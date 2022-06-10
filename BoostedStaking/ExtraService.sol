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
import "../common/Upgradable.sol";
import "../common/Modifiers.sol";
import "./interfaces/IExtraService.sol";
import "ExtraAccount.sol";

contract ExtraService is IExtraService, Upgradable, Modifiers {
    TvmCell m_accountCode;
    uint64 m_threshold;
    uint8 public revision;
    ExtraLib.Statistics m_stats;

    constructor(TvmCell account) public onlyOwner accept {
        m_accountCode = account.toSlice().loadRef();
        m_threshold = 1 ton;
        revision = 1;
    }

    /// @notice API. Allows to make extra stake.
    function stake(
        mapping(address => uint64) depools,
        ExtraLib.Period period,
        bytes signature,
        uint256 clientKey
    ) external override minValue(ExtraLib.STAKE_FEE) {
        signature; clientKey;
        uint64 requestedStake = 0;
        uint64 parts = 0;
        for((, uint64 amount): depools) {
            requestedStake += amount;
            parts++;
            require(parts <= ExtraLib.MAX_STAKE_PARTS, ExtraLib.ERR_TOO_MANY_STAKE_PARTS);
        }
        
        uint64 clientStake = uint64(msg.value) - ExtraLib.STAKE_FEE;
        require(clientStake >= ExtraLib.MIN_STAKE, ExtraLib.ERR_LOW_VALUE);
        (uint64 annualYield ,uint64 bonus) = ExtraLib.calcExtraBonus(clientStake, period);
        uint64 expectedStake = clientStake + bonus;
        require(expectedStake == requestedStake, ExtraLib.ERR_INVALID_STAKE);
        require(
            address(this).balance >= (requestedStake + parts * ExtraLib.DEPOOL_FEE + m_threshold), 
            ExtraLib.ERR_LOW_BALANCE
        );

        // Reserve original balance minus bonus and other fees
        tvm.rawReserve(bonus + parts * (ExtraLib.DEPOOL_FEE + 0.1 ton), 4 + 8);

        TvmCell accountState = _buildAccountImage(msg.sender, uint32(now));
        new ExtraAccount{
            value: 0,
            flag: 128,
            bounce: true,
            stateInit: accountState
        }(depools, period, annualYield);

        m_stats.totalBonusPaid += bonus;
    }

    function setAccount(TvmCell image) public onlyOwner accept {
        m_accountCode = image.toSlice().loadRef();
    }

    function setTotalBonus(uint64 val) public onlyOwner accept {
        m_stats.totalBonus = val;
    }

    //
    // Internals
    //

    function _buildAccountImage(
        address stakeOwner,
        uint32 createdAt
    ) internal view returns (TvmCell) {
        TvmBuilder b; b.store(address(this), stakeOwner);
        TvmCell code = tvm.setCodeSalt(m_accountCode, b.toCell());
        return tvm.buildStateInit({
            code: code,
            varInit: {m_createdAt: createdAt},
            contr: ExtraAccount
        });
    }

    //
    // Getters
    //

    function getStats() external override view returns (ExtraLib.Statistics stats) {
        stats = m_stats;
    }

    function getPeriods() external override returns (mapping(uint32 => ExtraLib.PeriodInfo) periods) {
        periods = ExtraLib.periodMap();
    }

    //
    // Upgradable
    //

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

}