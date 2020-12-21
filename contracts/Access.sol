pragma solidity >=0.6.0 <0.7.0;
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Access is Pausable, ReentrancyGuard {
    address public admin;
    address public governance;

    mapping (address => bool) public approved;
    mapping(address => uint256) public blockLock;

    bytes32 public constant DEFAULT_GOV_ROLE = keccak256("DEFAULT_GOV_ROLE");

    constructor(
        address _admin
    ) public {
        admin = _admin;
        governance = _admin;
    }
    
    function _onlyAdmin() internal {
        require(admin == msg.sender, "!admin");
    }
    
    function _onlyGovernance() internal {
        require(governance == msg.sender, "!governance");
    }

    function _onlyAuth() internal {
        require(admin == msg.sender || governance == msg.sender, "!gov !admin");
    }

    function setGovernance(address gov) external {
        _onlyAuth();
        governance = gov;
    }

    function revokeGovernance(address gov) external {
        _onlyAuth();
        governance = address(0);
    }

    function approveContractAccess(address account) external {
        _onlyGovernance();
        approved[account] = true;
    }

    function revokeContractAccess(address account) external {
        _onlyGovernance();
        approved[account] = false;
    }

    function pause() external {
        _onlyGovernance();
        _pause();
    }

    function unpause() external {
        _onlyGovernance();
        _unpause();
    }

    function _defend() internal view returns (bool) {
        require(approved[msg.sender] || msg.sender == tx.origin, "Access denied for caller");
    }

    function _blockLocked() internal view {
        require(blockLock[msg.sender] < block.number, "blockLocked");
    }

    function _lockForBlock() internal {
        blockLock[msg.sender] = block.number;
    }

    receive() external payable {}
}