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
interface IVestingService {
    function createPool(
        uint128 amount,
        uint8 cliffPeriod,
        uint8 vestingPeriod,
        address recipient,
        uint256[] claimers
    ) external;

    function getCreateFee(uint8 vestingMonths) external pure returns (uint128 fee);

    function getPoolCodeHash() external view returns (uint256 codeHash);
}