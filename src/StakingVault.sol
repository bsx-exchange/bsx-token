// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IStakingVault } from "./interfaces/IStakingVault.sol";

contract StakingVault is IStakingVault, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, ERC20VotesUpgradeable {
    using SafeERC20 for IERC20;

    string public constant NAME = "Staking Vault BSX";
    string public constant SYMBOL = "svBSX";
    string public constant VERSION = "1";
    uint256 public constant UNSTAKE_COOLDOWN = 14 days;
    uint256 public constant REWARD_SCALE = 1e18;

    uint256 public rewardRate;
    uint256 public rewardPeriod;
    uint256 public lastRewardUpdateTimestamp;
    uint256 public lastAccumulatedRewardPerToken;

    IERC20 public stakingToken;

    mapping(address account => uint256 lastAccumulatedReward) public lastAccumulatedRewards;
    mapping(address account => uint256 reward) private _rewards;
    mapping(address account => mapping(uint256 requestId => UnstakeRequest unstakeRequest)) private _unstakeRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        IERC20 _stakingToken,
        uint256 _rewardRate,
        uint256 _rewardPeriod
    )
        external
        initializer
    {
        __EIP712_init(NAME, VERSION);
        __ERC20_init(NAME, SYMBOL);
        __ERC20Votes_init();
        __Ownable_init(_owner);
        __Ownable2Step_init();
        __ReentrancyGuard_init();

        stakingToken = _stakingToken;
        rewardRate = _rewardRate;
        rewardPeriod = _rewardPeriod;
        lastRewardUpdateTimestamp = block.timestamp;
    }

    modifier updateReward(address account) {
        lastAccumulatedRewardPerToken = getAccumulatedRewardPerToken();
        lastRewardUpdateTimestamp = block.timestamp;
        _rewards[account] = getRewards(account);
        lastAccumulatedRewards[account] = lastAccumulatedRewardPerToken;
        _;
    }

    function stake(uint256 amount) external {
        stake(msg.sender, amount);
    }

    /// @inheritdoc IStakingVault
    function stake(address account, uint256 amount) public nonReentrant updateReward(account) {
        if (amount == 0) revert ZeroAmount();

        _mint(account, amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(account, amount);
    }

    /// @inheritdoc IStakingVault
    function requestUnstake(uint256 requestId, uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();

        address account = msg.sender;
        if (balanceOf(account) < amount) {
            revert InsufficientStakeBalance(account, amount, balanceOf(account));
        }

        UnstakeRequestState status = _unstakeRequests[account][requestId].state;
        if (status != UnstakeRequestState.NONE) {
            revert InvalidRequestState(account, requestId, status, UnstakeRequestState.NONE);
        }

        _unstakeRequests[account][requestId] =
            UnstakeRequest({ amount: amount, requestTimestamp: block.timestamp, state: UnstakeRequestState.PENDING });
        _burn(account, amount);

        emit UnstakeRequested(account, requestId, amount);
    }

    /// @inheritdoc IStakingVault
    function cancelUnstakeRequests(uint256[] calldata requestIds) external nonReentrant updateReward(msg.sender) {
        uint256 totalRequests = requestIds.length;
        if (totalRequests == 0) revert EmptyRequestIds();

        address account = msg.sender;
        uint256 amount = 0;
        for (uint256 i = 0; i < totalRequests; i++) {
            uint256 requestId = requestIds[i];
            UnstakeRequest storage request = _unstakeRequests[account][requestId];
            if (request.state != UnstakeRequestState.PENDING) {
                revert InvalidRequestState(account, requestId, request.state, UnstakeRequestState.PENDING);
            }

            request.state = UnstakeRequestState.CANCELLED;
            amount += request.amount;

            emit RequestCancelled(account, requestId);
        }

        _mint(account, amount);
    }

    /// @inheritdoc IStakingVault
    function unstake(uint256[] calldata requestIds) external nonReentrant {
        uint256 totalRequests = requestIds.length;
        if (totalRequests == 0) revert EmptyRequestIds();

        address account = msg.sender;
        uint256 amount = 0;
        for (uint256 i = 0; i < totalRequests; i++) {
            uint256 requestId = requestIds[i];
            UnstakeRequest storage request = _unstakeRequests[account][requestId];
            if (request.state != UnstakeRequestState.PENDING) {
                revert InvalidRequestState(account, requestId, request.state, UnstakeRequestState.PENDING);
            }
            if (block.timestamp < request.requestTimestamp + UNSTAKE_COOLDOWN) {
                revert Cooldown(account, requestId, request.requestTimestamp + UNSTAKE_COOLDOWN);
            }
            request.state = UnstakeRequestState.EXECUTED;

            amount += request.amount;
            emit RequestExecuted(account, requestId);
        }

        stakingToken.safeTransfer(account, amount);
        emit Unstaked(account, amount);
    }

    /// @inheritdoc IStakingVault
    function updateRewardConfig(uint256 _rewardRate, uint256 _rewardPeriod) external onlyOwner {
        if (_rewardPeriod == 0) {
            revert ZeroRewardPeriod();
        }

        lastAccumulatedRewardPerToken = getAccumulatedRewardPerToken();
        lastRewardUpdateTimestamp = block.timestamp;

        rewardRate = _rewardRate;
        rewardPeriod = _rewardPeriod;

        emit RewardConfigUpdated(_rewardRate, _rewardPeriod);
    }

    /// @notice Non-transferable token
    function approve(address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }

    /// @notice Non-transferable token
    function transfer(address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }

    /// @notice Non-transferable token
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }

    /// @inheritdoc IStakingVault
    function getAccumulatedRewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return lastAccumulatedRewardPerToken;
        }
        return lastAccumulatedRewardPerToken
            + Math.mulDiv(block.timestamp - lastRewardUpdateTimestamp, rewardRate, rewardPeriod);
    }

    /// @inheritdoc IStakingVault
    function getUnstakeRequest(address account, uint256 requestId) external view returns (UnstakeRequest memory) {
        return _unstakeRequests[account][requestId];
    }

    /// @inheritdoc IStakingVault
    function getRewards(address account) public view returns (uint256) {
        return _rewards[account]
            + Math.mulDiv(
                balanceOf(account), getAccumulatedRewardPerToken() - lastAccumulatedRewards[account], REWARD_SCALE
            );
    }
}
