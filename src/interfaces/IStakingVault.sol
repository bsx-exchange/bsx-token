// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IStakingVault {
    /* ========== STRUCTS & ENUMS ========== */

    enum UnstakeRequestState {
        NONE,
        PENDING,
        CANCELLED,
        EXECUTED
    }

    struct UnstakeRequest {
        uint256 amount;
        uint256 requestTimestamp;
        UnstakeRequestState state;
    }

    /* ========== ERRORS ========== */

    /// @notice Thrown when cooldown period is not over
    error Cooldown(address account, uint256 requestId, uint256 cooldownTime);

    /// @notice Thrown when request ids are empty
    error EmptyRequestIds();

    /// @notice Thrown when account unstake more than their stake balance
    error InsufficientStakeBalance(address account, uint256 amount, uint256 available);

    /// @notice Thrown when unstake request is in invalid state
    error InvalidRequestState(
        address account, uint256 requestId, UnstakeRequestState current, UnstakeRequestState expected
    );

    /// @notice Thrown when reward period is zero
    error ZeroRewardPeriod();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when reward token is not transferable
    error NonTransferable();

    /* ========== EVENTS ========== */

    /// @notice Emitted when account stakes tokens
    event Staked(address indexed account, uint256 amount);

    /// @notice Emitted when account requests unstake
    event UnstakeRequested(address indexed account, uint256 requestId, uint256 amount);

    /// @notice Emitted when account cancels unstake request
    event RequestCancelled(address indexed account, uint256 requestId);

    /// @notice Emitted when account unstake request is executed
    event RequestExecuted(address indexed account, uint256 requestId);

    /// @notice Emitted when account unstakes tokens after cooldown period
    event Unstaked(address indexed account, uint256 amount);

    /// @notice Emitted when account claims rewards
    event RewardsClaimed(address indexed account, uint256 amount);

    /// @notice Emitted when reward config is updated
    event RewardConfigUpdated(uint256 rewardRate, uint256 rewardPeriod);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Stake tokens to the vault for current account
    /// @dev Emits {Staked} event
    function stake(uint256 amount) external;

    /// @notice Stake tokens to the vault for specific account
    /// @dev Emits {Staked} event
    function stake(address account, uint256 amount) external;

    /// @notice Request unstake tokens from the vault. Cooldown period is 14 days
    /// @dev Emits {UnstakeRequested} event
    function requestUnstake(uint256 requestId, uint256 amount) external;

    /// @notice Cancel unstake requests
    /// @dev Emits {UnstakeCancelled} event
    function cancelUnstakeRequests(uint256[] memory requestIds) external;

    /// @notice Unstake tokens from the vault after cooldown period
    /// @dev Emits {Unstaked} event
    function unstake(uint256[] memory requestIds) external;

    /// @notice Update reward config
    /// @dev Emits {RewardConfigUpdated} event
    function updateRewardConfig(uint256 rewardRate, uint256 rewardPeriod) external;

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice Get current accumulated reward per token
    function getAccumulatedRewardPerToken() external view returns (uint256);

    /// @notice Get unstake request
    function getUnstakeRequest(address account, uint256 requestId) external view returns (UnstakeRequest memory);

    /// @notice Get current unclaimed rewards for account
    function getRewards(address account) external view returns (uint256);
}
