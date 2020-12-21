pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/IAirdropStrategy.sol";
import "./interfaces/IStakingRewards.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/EthAddressLib.sol";
import "./Access.sol";

contract Cellar is Access {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    address public factory;
    address public token;
    address public acf;
    address public pair; 

    address public strategy;
    address public stakingRewards;

    uint public fee;
    uint public constant fee_denominator = 10000;
    address private feeCollector;

    
    constructor (
        address _admin,
        address _factory, 
        address _token, 
        address _acf,
        address _strategy,
        address _feeCollector,
        uint _fee
    ) public Access(_admin) {
        
        factory = _factory;
        token = _token;
        acf = _acf;
        pair = UniswapV2Library.pairFor(factory, token, acf);
        strategy = _strategy;
        feeCollector = _feeCollector;
        fee = _fee;
    }
    
    function setStakingRewards(address _stakingRewards) external {
        _onlyGovernance();
        stakingRewards = _stakingRewards;
    }
    
    function setAirdropStrategy(address _strategy) external {
        _onlyGovernance();
        strategy = _strategy;
    }
    
    function setFee(uint _fee) external {
        _onlyGovernance();
        require(_fee <= fee_denominator, "incorrect fee");
        fee = _fee;
    }

    function setFeeCollector(address collector) external {
        _onlyGovernance();
        require(collector != address(0), "!collector");
        feeCollector = collector;
    }
    


    function addLiquidity(uint amount) external nonReentrant whenNotPaused {
        _defend();
        
        _blockLocked();

        _lockForBlock();
        
        _addLiquidity(amount);

    }
    
    function _addLiquidity(uint amount) internal {
        // airdrop specific amount of acf to msg.sender to help msg.sender provide liquidity
        uint acf_ = IAirdropStrategy(strategy).getAirdropAmount(token, amount);
        acf_ = Math.min(acf_, IERC20(acf).balanceOf(address(this)));

        // calculate how many tokens are required for adding liquidity
        (uint tokenAmount, uint acfAmount) = _calculatePairAmounts(amount, acf_);
        
        // transfer tokens to pair and mint lp tokens
        IERC20(token).safeTransferFrom(msg.sender, pair, tokenAmount);
        IERC20(acf).safeTransfer(pair, acfAmount);
        uint shares = IUniswapV2Pair(pair).mint(address(this));
        require(shares > 0, "!shares");

        require(IStakingRewards(stakingRewards).allowStakeFor(), "!stakeFor");
        _stake(shares);
        

    }

    // TODO: check if necessary to add slippery control => no need
    function _calculatePairAmounts(uint _token, uint _acf) internal view returns(uint tokenInput, uint acfInput) {
        (uint r1, uint r2) = UniswapV2Library.getReserves(factory, token, acf);
        if (r1 == 0 && r2 == 0) {
            (tokenInput, acfInput) = (_token, _acf);
        } else {
            uint acfOpt = UniswapV2Library.quote(_token, r1, r2);
            if (acfOpt <= _acf) {
                (tokenInput, acfInput) = (_token, acfOpt);
            } else {
                uint tokenOpt = UniswapV2Library.quote(_acf, r2, r1);
                require(tokenOpt <= _token, "unexpected error");
                (tokenInput, acfInput) = (tokenOpt, _acf);
            }
        }
    }


    function _stake(uint shares) internal {
        // transfer lp token to Staking Reward contract and do Stake For user 
        IERC20(pair).safeApprove(stakingRewards, 0);
        IERC20(pair).safeApprove(stakingRewards, shares);
        IStakingRewards(stakingRewards).stakeFor(msg.sender, shares);
    }


    function removeLiquidity(uint shares, uint minAmt0, uint minAmt1) public nonReentrant whenNotPaused {
        _defend();
        
        _blockLocked();

        _lockForBlock();

        _removeLiquidity(shares, minAmt0, minAmt1);

    }

    function _removeLiquidity(uint shares, uint minAmt0, uint minAmt1) internal {

        IStakingRewards(stakingRewards).withdrawFor(msg.sender, shares);
        // extract reward token
        IStakingRewards(stakingRewards).getReward(msg.sender);
        
        // remove liquidity, send liquidity to pair
        IUniswapV2Pair(pair).transfer(pair, shares.mul(fee_denominator.sub(fee)).div(fee_denominator));
        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(msg.sender);
        // condition check
        require(amount0 >= minAmt0, "insufficient amount0");
        require(amount1 >= minAmt1, "insufficient amount1");
    }

    function exit() external {
        removeLiquidity(IStakingRewards(stakingRewards).balanceOf(msg.sender), 0, 0);
       
    }

    function extractFee() external {
        IERC20(pair).safeTransfer(feeCollector, IERC20(pair).balanceOf(address(this)));
    }



    function recover(address tokenAddress, uint256 tokenAmount) external {
        _onlyGovernance();

        // never touch pair and token
        require(tokenAddress != pair && 
            tokenAddress != address(token) && 
            tokenAddress != acf, 
            "Cannot withdraw pair or token"
        );

        if (tokenAddress != EthAddressLib.ethAddress()) {
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        } else {
            payable(msg.sender).transfer(tokenAmount);
        }
    }

} 