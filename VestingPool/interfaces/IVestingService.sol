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