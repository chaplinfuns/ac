pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./interfaces/IAirdropStrategy.sol";
import "./interfaces/IStakingRewards.sol";
import "./libraries/UniswapV2Library.sol";
import "./Access.sol";

contract Pool is Access, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    
    address public baseToken;
    uint public totalDebt;
    uint public totalReserve;

    // token => borrower contract
    mapping(address => address) public approvedBorrower;

    // borrower contract => debts balance
    mapping(address => uint) public debts;

    address public acf;
    address public stakingRewards;

    constructor (
        address _admin, 
        address _token, 
        address _acf
    ) public Access(_admin) ERC20(
        string(abi.encodePacked("acf pool ", ERC20(_token).name())),
        string(abi.encodePacked("ap", ERC20(_token).symbol()))
    ){        
        baseToken = _token;
        acf = _acf;
    } 
    
    function setStakingRewards(address _stakingRewards) external {
        _onlyGovernance();
        stakingRewards = _stakingRewards;
    }
    
    function approveBorrower(address token, address borrower) external {
        _onlyGovernance();
        approvedBorrower[token] = borrower;
        // // sanity check
        // address pair = UniswapV2Library.pairFor(factory, baseToken, token);
        // (uint r1, uint r2) = UniswapV2Library.getReserves(factory, baseToken, token);
        // require(r1 != 0 && r2 != 0, "!pair");
    }

    function revokeBorrower(address token) external {
        _onlyGovernance();
        require(IERC20(approvedBorrower[token]).totalSupply() == 0, "!empty");
        delete approvedBorrower[token];
    }


    function available() public view returns (uint) {
        return IERC20(baseToken).balanceOf(address(this));
    }

    function balance() public view returns (uint) {
        return totalDebt.add(available());
    }

    function pull(address token, address to, uint amount) external {
        require(approvedBorrower[token] == msg.sender, "!borrower");
        IERC20(baseToken).safeTransfer(to, amount);
        debts[msg.sender] = debts[msg.sender].add(amount);
        totalDebt = totalDebt.add(amount);
    }

    function push(address token, uint amount) external  {
        require(approvedBorrower[token] == msg.sender, "!borrower");
        IERC20(baseToken).safeTransfer(msg.sender, amount);
        debts[msg.sender] = debts[msg.sender].sub(amount);
        totalDebt = totalDebt.sub(amount);
    }

    function deposit(uint amount) external  {
        _depositFor(msg.sender, msg.sender, amount);
    }
    
    function depositFor(address user, uint amount) external {
        _depositFor(msg.sender, user, amount);
    }

    function _depositFor(address sender, address user, uint amount) internal whenNotPaused nonReentrant {
        uint256 _pool = balance();
        uint256 _before = IERC20(baseToken).balanceOf(address(this));
        IERC20(baseToken).safeTransferFrom(sender, address(this), amount);
        uint256 _after = IERC20(baseToken).balanceOf(address(this));
        amount = _after.sub(_before); // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount.mul(totalSupply())).div(_pool);
        }
        _mint(user, shares);
    }

    function withdraw(uint shares) public whenNotPaused nonReentrant {
        uint r = balance().mul(shares).div(totalSupply());
        // check balance
        uint a = available();
        require(a >= r, "!available");
        
        _burn(msg.sender, shares);

        IERC20(baseToken).safeTransfer(msg.sender, r);
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    // always non-decreasing due to borrower.harvest() method
    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }
} 