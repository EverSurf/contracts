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
interface IVestingPool {
    function claim(uint poolId) external;
    function get() external view returns(
        uint poolId, 
        address poolCreator,
        uint32 createdAt,
        address recipient,
        uint32 cliffEnd,
        uint32 vestingEnd,
        uint128 totalAmount,
        uint128 remainingAmount,
        uint128 unlockedAmount
        );
}

interface IdbgPool {
    function unlock() external;
}