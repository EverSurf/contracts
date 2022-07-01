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