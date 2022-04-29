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
import "../libraries/ExtraLib.sol";  

/// @notice API interface of Extra Service smc.
interface IExtraService {
    /// @notice Allows to make boosted stake. 
    /// Should be called by other smart contract.
    /// @param depools Set of pairs [depool -> amount]. User stake will be split 
    /// between this depools according to defined amounts. Every stake part should
    /// include bonus funds according to period and stake category.
    /// Remark: all depools MUST be in Depooler rating table.
    /// Note: number of stake parts MUST be <= ExtraLib.MAX_STAKE_PARTS.
    /// @param period One of the predefined lock periods of Boosted Program.
    /// @param signature Not used in Boosted Staking Program 1.0.
    /// Remark: It's a part of authorization feature - allow to make boosted stakes
    /// to whitelisted clients only. in ver 1.0 Everyone can make a boosted stake.
    /// @param clientKey Not used in Boosted Staking Program 1.0.
    /// Remark: Client public key used to check @signature argument.
    function stake(
        mapping(address => uint64) depools,
        ExtraLib.Period period,
        bytes signature,
        uint256 clientKey
    ) external;
}