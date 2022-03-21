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
pragma ton-solidity >=0.40.0;

library FormatLib {
    function _splitAmount(uint128 amount, uint8 decimals) internal pure returns (uint128, uint128) {
        return math.divmod(amount, uint128(10)**decimals);
    }

    function formatAmount(uint128 amount, uint8 decimals, uint8 round) public pure returns (string str) {
        if (amount == 0) {
            string zero = "0";
            while (zero.byteLength() < round) {
                zero = "0" + zero;
            }
            return format("0.{}", zero);
        }
        (uint128 integer, uint128 float) = _splitAmount(amount, decimals);
        float = float / uint128(10)**(decimals - round);
        
        string roundFloat = decimals > 0 ? format("{}", float) : "";
        while (roundFloat.byteLength() < round) {
            roundFloat = "0" + roundFloat;
        }
        if (decimals > 0) {
            roundFloat = "." + roundFloat;
        }

        string fmtInt = "";
        while(integer >= 1000) {
            uint128 b = 0;
            (integer, b) = math.divmod(integer, 1000);
            fmtInt = format("{:03}", b) + fmtInt;
            if (integer > 0) {
                fmtInt = "," + fmtInt;
            }
        }
        fmtInt = format("{}", integer) + fmtInt;
        string result = format("{}{}", fmtInt, roundFloat);
        return result;
    }

    function evers(uint128 amount) public pure returns (string) {
        return formatAmount(amount, 9, 2);
    }
}