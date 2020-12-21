pragma solidity >=0.6.0 <0.7.0;

interface IAirdropStrategy {
    function getAirdropAmount(address token, uint amount) external view returns (uint);
}