pragma ton-solidity >= 0.47.0;

interface IDePool {
    function addOrdinaryStake(uint64 stake) external;
    function withdrawAll() external;
    function withdrawFromPoolingRound(uint64 withdrawValue) external;
}