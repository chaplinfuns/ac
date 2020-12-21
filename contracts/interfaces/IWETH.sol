pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external; 
    function balanceOf(address owner) external returns (uint256);
    function approve(address to, uint value) external returns (bool);
}
