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
pragma ton-solidity >= 0.61.0;

library VestLib {
    uint128 constant FEE_CLAIM = 0.1 ever;
    uint128 constant FEE_CREATE = 0.1 ever;
    uint128 constant CONSTRUCTOR_GAS = 0.1 ever;
    uint128 constant STORAGE_FEE = 1 ever;
    uint256 constant MAX_CLAIMERS = 10;

    function calcCreateGasFee(uint8 vestingMonths) public returns (uint128) {
        return FEE_CREATE + calcPoolConstructorFee(vestingMonths);
    }

    function calcPoolConstructorFee(uint8 vestingMonths) public returns (uint128) {
        return vestingMonths * FEE_CLAIM + CONSTRUCTOR_GAS + STORAGE_FEE;
    }
}