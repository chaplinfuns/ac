pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/OneInch/IOneSplitAudit.sol";
import "./interfaces/IAirdropStrategy.sol";
import "./interfaces/IStakingRewards.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/EthAddressLib.sol";
import "./interfaces/IPool.sol";
import "./Access.sol";

contract Borrower is ERC20, Access {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    

    address public token;
    address public factory;
    address public pool;
    address public baseToken;
    address public pair;

    uint public totalDebt;
    uint public totalPrinciple;

    // borrower => debts balance
    mapping(address => uint) public debts;
    mapping(address => uint) public principles;
    
    address public stakingRewards;
    address public onesplit = address(0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e);

    constructor (
        address _admin, 
        address _token,
        address _factory,
        address _pool
    ) public Access(_admin) ERC20(
        string(abi.encodePacked("acf ", ERC20(_token).name())),
        string(abi.encodePacked("a", ERC20(_token).symbol()))
    ){        
        
        token = _token;
        factory = _factory;
        pool = _pool;
        baseToken = IPool(pool).baseToken();
        pair = UniswapV2Library.pairFor(factory, baseToken, token);
    }

    function setStakingRewards(address _stakingRewards) external {
        _onlyGovernance();
        stakingRewards = _stakingRewards;
    }
    
    // return (principle, debts, shares or lp)
    function balanceSnapshot(address user) external view returns (uint, uint, uint) {
        return (principles[user], debts[user], balanceOf(user));
    }

    function balance() public view returns (uint) {
        return IERC20(pair).balanceOf(address(this));
    }

    function addLiquidity_Borrow(uint amount) external {
        
        _defend();
        
        _blockLocked();

        _lockForBlock();
        
        uint pb = _addLiquidity_Borrow(amount);
        require(pb > 0, "!mint");
        _mint(address(this), pb);
        IERC20(address(this)).safeApprove(stakingRewards, 0);
        IERC20(address(this)).safeApprove(stakingRewards, pb);
        IStakingRewards(stakingRewards).stakeFor(msg.sender, pb);
    }

    function _addLiquidity_Borrow(uint amount) internal whenNotPaused nonReentrant returns (uint) {
        (uint bAmount, bool enough) = maxTokenAmountAllowed(amount);
        require(enough, "pool not enough");
        
        // increase totalDebt
        totalDebt = totalDebt.add(bAmount);
        // increase debts balance of msg.sender
        debts[msg.sender] = debts[msg.sender].add(bAmount);
        // increase principle
        totalPrinciple = totalPrinciple.add(amount);

        uint before = balance();
        // add liquidity
        IERC20(token).safeTransferFrom(msg.sender, pair, amount);
        IPool(pool).pull(token, pair, bAmount);
        IUniswapV2Pair(pair).mint(address(this));
        return balance().sub(before);
    }

    function maxTokenAmountAllowed(uint amount) public view returns (uint bAmount, bool enough) {
        (uint r1, uint r2) = UniswapV2Library.getReserves(factory, baseToken, token);
        bAmount = UniswapV2Library.quote(amount, r2, r1);
        enough = bAmount >= IPool(pool).available();
    }

    function removeLiquidity_Pay(uint shares) public {
        
        _defend();
        
        _blockLocked();

        _lockForBlock();
        
        IStakingRewards(stakingRewards).withdrawFor(msg.sender, shares);
        
        _removeLiquidity_Pay(shares);

    }

    function _removeLiquidity_Pay(uint shares) internal whenNotPaused nonReentrant {
        uint ub = balanceOf(msg.sender);
        require(ub >= shares, "balance not enough");
        
        _burn(msg.sender, shares);
        
        uint bb = IERC20(baseToken).balanceOf(address(this));
        uint b = IERC20(token).balanceOf(address(this));

        IERC20(pair).safeTransfer(pair, shares);
        IUniswapV2Pair(pair).burn(address(this));

        uint bbi = IERC20(baseToken).balanceOf(address(this)).sub(bb);
        uint bi = IERC20(token).balanceOf(address(this)).sub(b);

        uint dueDebt = debts[msg.sender].mul(shares).div(ub);
        uint duePrinciple = principles[msg.sender].mul(shares).div(ub);

        // (uint rb, uint r) = UniswapV2Library.getReserves(factory, baseToken, token);
        (address t0,) = UniswapV2Library.sortTokens(baseToken, token);
        (uint rb, uint r) = (0, 0);
        {
            (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
            (rb, r) = t0 == baseToken ? (r0, r1) : (r1, r0);
        }
        
        if (dueDebt < bbi) {
            // swap extra baseToken into token
            uint a = UniswapV2Library.getAmountOut(bbi.sub(dueDebt), rb, r);
            IERC20(baseToken).safeTransfer(pair, bbi.sub(dueDebt));
            IUniswapV2Pair(pair).swap(
                t0 == baseToken ? 0 : a, 
                t0 == baseToken ? a : 0, 
                address(this), 
                new bytes(0)
            );

            bi = bi.add(a);
            
        } else if (dueDebt > bbi) {
            // swap token into baseToken to pay dueDebt
            uint a = UniswapV2Library.getAmountIn(dueDebt.sub(bbi), r, rb);
            IERC20(token).safeTransfer(pair, a);
            IUniswapV2Pair(pair).swap(
                t0 == baseToken ? dueDebt.sub(bbi) : 0,
                t0 == baseToken ? 0 : dueDebt.sub(bbi),
                address(this), 
                new bytes(0)
            );
            bi = bi.sub(a);
        } else {
            // dueDebt == bbi
            // do not change bi
        }
        IERC20(token).safeTransfer(
            msg.sender,
            bi > duePrinciple ? bi.add(duePrinciple).div(2) : bi
        );

        // pay baseToken back to pool
        IPool(pool).push(token, dueDebt);
        // update debt and principles
        debts[msg.sender] = debts[msg.sender].sub(dueDebt);
        principles[msg.sender] = principles[msg.sender].sub(duePrinciple);
        totalDebt = totalDebt.sub(dueDebt);
        totalPrinciple = totalPrinciple.sub(duePrinciple);
        
    }

    function removeAll() external {
        removeLiquidity_Pay(IStakingRewards(stakingRewards).balanceOf(msg.sender));
    }

    function harvest(uint amount, uint parts) external {
        _onlyGovernance();
        
        // swap token to baseToken 
        IERC20(token).safeApprove(onesplit, 0);
        IERC20(token).safeApprove(onesplit, amount);
        (uint _expected, uint[] memory _distribution) = IOneSplitAudit(onesplit).getExpectedReturn(token, baseToken, amount, parts, 0);
        IOneSplitAudit(onesplit).swap(token, baseToken, amount, _expected, _distribution, 0);

        // send baseToken to pool
        IERC20(baseToken).safeTransfer(pool, IERC20(baseToken).balanceOf(address(this)));
    }

    function recover(address tokenAddress, uint256 tokenAmount) external {
        _onlyGovernance();

        // never touch pair and token
        require(tokenAddress != pair && tokenAddress != address(token), "Cannot withdraw pair or token");

        if (tokenAddress != EthAddressLib.ethAddress()) {
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        } else {
            payable(msg.sender).transfer(tokenAmount);
        }
    }
} 