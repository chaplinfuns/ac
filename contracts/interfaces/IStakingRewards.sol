pragma solidity >=0.6.0 <0.7.0;

interface IStakingRewards {
    function stakeFor(address user, uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawFor(address user, uint256 amount) external;
    function balanceOf(address account) external view returns (uint);
    function periodFinish() external view returns (uint);
    function getReward(address user) external;
    function allowStakeFor() external view returns (bool);
}