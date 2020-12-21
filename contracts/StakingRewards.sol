pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./libraries/EthAddressLib.sol";
import "./Access.sol";

/**
 * @title Badger Staking Rewards
 * @dev Gated rewards mechanics for Badger Setts, based on Synthetix * StakingRewards
 */
contract StakingRewards is Access {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    mapping(address => bool) public approvedStaker;

    constructor(
        address _admin,
        address _rewardsToken,
        address _stakingToken
    ) Access(_admin) public {

        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);

        rewardsDuration = 7 days;
    }


    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply));
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function allowStakeFor() external view returns (bool) {
        return approvedStaker[msg.sender];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stakeFor(address user, uint256 amount) external nonReentrant whenNotPaused updateReward(user) {
        _onlyApprovedStaker();
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[user] = _balances[user].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit StakedFor(msg.sender, user, amount);
    }

    function withdrawFor(address user, uint256 amount) external nonReentrant whenNotPaused updateReward(user) {
        _onlyApprovedStaker();
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[user] = _balances[user].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit WithdrawnFor(msg.sender, user, amount);
    }


    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        // _onlyApprovedStaker();
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward(address user) public nonReentrant updateReward(user) {
        uint256 reward = rewards[user];
        if (reward > 0) {
            rewards[user] = 0;
            safeRewardTokenTransfer(user, reward);
            emit RewardPaid(user, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward(msg.sender);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    
    function notifyRewardAmount(uint256 reward) external updateReward(address(0)) {
        _onlyGovernance();
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));

        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }


    function setRewardsDuration(uint256 _rewardsDuration) external {
        _onlyGovernance();
        require(block.timestamp > periodFinish, "Previous rewards period must be complete before changing the duration for the new period");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }


    function setApprovedStaker(address staker) external {
        _onlyGovernance();
        approvedStaker[staker] = true;
    }


    function _onlyApprovedStaker() internal {
        require(approvedStaker[msg.sender], "!approvedStaker");
    }

    function safeRewardTokenTransfer(address to, uint amount) internal {
        rewardsToken.safeTransfer(
            to,
            Math.min(rewardsToken.balanceOf(address(this)), amount)
        );
    }

    function recover(address tokenAddress, uint256 tokenAmount) external {
        _onlyGovernance();

        // Cannot recover the staking token or the rewards token
        require(tokenAddress != address(stakingToken) && tokenAddress != address(rewardsToken), "Cannot withdraw the staking or rewards tokens");
        if (tokenAddress != EthAddressLib.ethAddress()) {
            IERC20(tokenAddress).safeTransfer(admin, tokenAmount);
        } else {
            address(uint160(admin)).transfer(tokenAmount);
        }
        emit Recovered(tokenAddress, tokenAmount);
    }


    /* ========== EVENTS ========== */
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event StakedFor(address indexed sender, address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnFor(address indexed sender, address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}
