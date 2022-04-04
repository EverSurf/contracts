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

/// @dev Operation statuses from Concierge debot.
enum StakeStatus {
    Success,
    LowBalance,
    ServiceFailed,
    InvalidPeriod,
    CapacityOverrun,
    Canceled,
    NotEnougthExtra
}

enum WithdrawStatus {
    Success,
    LowBalance,
    ExtraAccountFailed,
    StakeNotFound,
    AlreadyReturned,
    AlreadyRequested,
    Canceled
}

/// @notice Info about one boosted stake.
struct ExtraStake {
    mapping(address => uint64) parts;
    uint64 totalAmount;
    uint64 reward;
    uint32 unlockedAt;
    address extraAccount;
    bool requested;
    uint64 annualYield;
    ExtraLib.PeriodInfo period;
}

/// @title Boosted Staking API interface
interface IConcierge {
    /// Allows client debots to gather paremeters from user for boosted stake. 
    /// See IOnDialog for return arguments.
    function invokeDialog() external;
    /// Send boosted stake.
    /// @dev signature argument is not used now and can be empty.
    /// @param stake Stake amount in nanoevrs.
    /// @param secs Stake lock period in seconds. Note: on of the predefined 
    /// values from ExtraLib.Period enum (converted to seconds).
    /// @param signature Client signature. Note: not used.
    /// @param clientKey Public key which should be used to check signature. 
    /// Note: not used.
    /// @dev See IOnStake for return arguments.
    function invokeStake(uint64 stake, uint32 secs, bytes signature, uint256 clientKey) external;
    /// Return user boosted stakes.
    /// @dev See IOnGetStakes for return arguments.
    function invokeGetStakes() external;
    /// Allows to return user stake.
    /// @param extraAccount Address of user boosted stake account.
    function invokeWithdraw(address extraAccount) external;
}

interface IOnDialog {
    /// Return arguments for invokeDialog call.
    /// @param stake Stake value in nanoevers entered by the user.
    /// @param secs Stake lock period in seconds.
    function onDialog(uint64 stake, uint32 secs) external;
}

interface IOnStake {
    /// Return arguments for invokeStake call.
    /// @param status Status of operation.
    function onStake(StakeStatus status) external;
}

interface IOnGetStakes {
    /// Return arguments for invokeGetStakes call.
    /// @param stakes List of user boosted stakes.
    function onGetStakes(ExtraStake[] stakes) external;
}

interface IOnWithdraw {
    /// Return arguments for invokeWithdraw call.\
    /// @param status Status of withdraw operation.
    function onWithdraw(WithdrawStatus status) external;
}


contract Test is IOnGetStakes, IOnWithdraw, IOnStake {
    function onStake(StakeStatus status) external override {}
    function onGetStakes(ExtraStake[] stakes) external override {}
    function onWithdraw(WithdrawStatus status) external override {}
}