pragma solidity >=0.6.0 <0.7.0;

interface IPool {
    function baseToken() external view returns (address);
    function available() external view returns (uint);
    function pull(address token, address to, uint amount) external;
    function push(address token, uint amount) external;
}