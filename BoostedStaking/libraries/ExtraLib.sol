/*
    Boosted Staking
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

library ExtraLib {
    uint64 constant STAKE_FEE = 1 ton;
    uint64 constant WITHDRAW_FEE = 0.1 ton;
    uint64 constant DEPOOL_FEE = 0.5 ton;
    uint64 constant TREASURY_FEE = 0.5 ton;
    uint32 constant MAX_STAKE_PARTS = 10;
    uint64 constant ACCOUNT_GAS_FEE = 0.1 ton;
    uint64 constant MIN_STAKE = 100 ton;
    uint64 constant INDEX_DEPLOY_FEE = 0.03 ton;
    uint8 constant INDEX_REVISION = 2;

    uint constant ERR_TOO_MANY_STAKE_PARTS = 201;
    uint constant ERR_LOW_VALUE = 202;
    uint constant ERR_LOW_BALANCE = 203;
    uint constant ERR_INVALID_STAKE = 204;
    uint constant ERR_STAKE_LOCKED = 205;
    uint constant ERR_NOT_ENOUGH_BONUS = 206;
    
    enum Period {
        d0,
        d2,
        m6,
        m12,
        m18,
        m24
    }

    enum StakeCategory {
        upto1k,
        upto10k,
        upto100k,
        more100k
    }

    struct Stake {
        address depool;
        uint64 nanotons;
    }

    struct PeriodInfo {
        Period value;
        string title;
    }

    struct Statistics {
        uint64 totalBonus;
        uint64 totalBonusPaid;
        uint stakeCounter;
        TvmCell accountIndexCode;
        mapping(uint8 => uint32) periodSlice;
        mapping(uint8 => uint32) stakeSlice;
    }

    function periodToSeconds(Period period) internal pure returns (uint32) {
        if (period == Period.d0) {
            return 0;
        } else if (period == Period.d2) {
            return 2 days;
        } else if (period == Period.m6) {
            return 182 days;
        } else if (period == Period.m12) {
            return 365 days;
        } else if (period == Period.m18) {
            return 547 days;
        } else if (period == Period.m24) {
            return 730 days;
        } 
        return 0;
    }

    function periodMap() public pure returns (mapping(uint32 => PeriodInfo)) {
        // seconds to info
        mapping(uint32 => PeriodInfo) map;

        map[periodToSeconds(Period.m6)] = PeriodInfo(Period.m6, "6 months");
        map[periodToSeconds(Period.m12)] = PeriodInfo(Period.m12, "1 year");
        map[periodToSeconds(Period.m18)] = PeriodInfo(Period.m18, "year and a half");
        map[periodToSeconds(Period.m24)] = PeriodInfo(Period.m24, "2 years");
        // TODO For tests only
        map[periodToSeconds(Period.d0)] = PeriodInfo(Period.d0, "0 days");
        map[periodToSeconds(Period.d2)] = PeriodInfo(Period.d2, "2 days");
        return map;
    }

    function calcExtraBonus(uint64 amount, Period period) public pure returns (uint64, uint64) {
        uint64 basic = 3000000; // 3% with 6 digits after the point
        if (amount < 1000 ton) {
            basic += 0;
        } else if (amount < 10000 ton) {
            basic += 2000000;
        } else if (amount < 100000 ton) {
            basic += 4000000;
        } else {
            basic += 6000000;
        }

        uint64 annual = 0;
        if (period == Period.m6) {
            annual = basic;
            basic /= 2;
        } else if (period == Period.m12) {
            basic += 2000000;
            annual = basic;
        } else if (period == Period.m18) {
            basic += 4000000;
            annual = basic;
            basic += basic / 2;
        } else if (period == Period.m24) {
            basic += 6000000;
            annual = basic;
            basic *= 2;
        } else if (period == Period.d0) {
            basic = 1;
            annual = basic;
        } else if (period == Period.d2) { 
            basic = 2;
            annual = basic;
        }


        return (annual, uint64(math.muldivc(uint256(amount), uint256(basic), 100000000)));
    }

    function calcRawStake(uint64 amount, uint64 annualYield, Period period) public returns (uint64) {
        uint multiplier = 10;
        if (period == Period.m6) {
            multiplier = 5;
        } else if (period == Period.m18) {
            multiplier = 15;
        } else if (period == Period.m24) {
            multiplier = 20;
        }
        uint yield = math.muldiv(uint256(annualYield), multiplier, 10) + 100 * 1000000;
        return uint64(math.muldiv(uint256(amount), 100 * 1000000, uint256(yield)));
    }

    function getStakeCategory(uint64 amount) public returns (StakeCategory) {
        if (amount < 1000 ton) {
            return StakeCategory.upto1k;
        } else if (amount < 10000 ton) {
            return StakeCategory.upto10k;
        } else if (amount < 100000 ton) {
            return StakeCategory.upto100k;
        } else {
            return StakeCategory.more100k;
        }
    }

    function calcWithdrawGasFees(uint64 count) public pure returns (uint64) {
        return WITHDRAW_FEE + count * (DEPOOL_FEE + ACCOUNT_GAS_FEE);
    }

    function checkBonusCapacity(Statistics stats, uint64 bonus) public returns (bool) {
        if (int(bonus) > (int(stats.totalBonus) - stats.totalBonusPaid)) {
            return false;
        }
        return true;
    }

    function calcUnusedServicePart(
        uint64 stake,
        uint64 msgValue,
        uint32 createdAt,
        uint32 unlockedAt,
        ExtraLib.Period period,
        uint64 annualYield
    ) public returns (uint64) {
        uint64 origStake = calcRawStake(stake, annualYield, period);
        uint64 returnToService = uint64(math.muldiv(
            uint256(unlockedAt - uint32(now)), 
            uint256(stake - origStake), //bonus 
            uint256(unlockedAt - createdAt)
        ));
        
        return returnToService < 1 ton ? 0 : returnToService;
    }

}