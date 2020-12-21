pragma solidity >=0.6.0 <0.7.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IAirdropStrategy.sol";
import "./Access.sol";

contract AirdropStrategy is Access, IAirdropStrategy {
    using SafeMath for uint;

    struct Ratio {
        uint decimals;
        uint ratio;
        uint deadline;
    }

    mapping(address => Ratio) public ratios; 
    
    constructor (
        address _admin
    ) public Access(_admin) {}

    // ratio should have decimals of 18, 1 token => 100 acf: ratio = 100 ether
    function setAirdropRatio(address token, uint ratio, uint deadline) external {
        _onlyGovernance();
        uint decimals = 10 ** uint(ERC20(token).decimals());
        ratios[token] = Ratio({
            decimals: decimals,
            ratio: ratio,
            deadline: deadline
        });
        require(ratios[token].decimals != 0, "!decimals");
        require(ratios[token].ratio != 0, "!ratio");
        require(ratios[token].deadline != 0, "!deadline");
    }

    function getAirdropAmount(address token, uint amount) external override view returns(uint) {
        if (block.timestamp > ratios[token].deadline || ratios[token].ratio == 0) {
            return 0;
        }
        return ratios[token].ratio.mul(amount).div(ratios[token].decimals);
    }

}