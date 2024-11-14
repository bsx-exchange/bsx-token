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

    /// @notice Thrown when user unstakes more than their stake balance
    error InsufficientStakeBalance(address account, uint256 amount, uint256 available);

    /// @notice Thrown when unstake request is in invalid state
    error InvalidRequestState(
        address user, uint256 requestId, UnstakeRequestState current, UnstakeRequestState expected
    );

    /// @notice Thrown when reward period is zero
    error ZeroRewardPeriod();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when reward token is not transferable
    error NonTransferable();

    /* ========== EVENTS ========== */

    /// @notice Emitted when user stakes tokens
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when user requests unstake
    event UnstakeRequested(address indexed user, uint256 requestId, uint256 amount);

    /// @notice Emitted when user cancels unstake request
    event RequestCancelled(address indexed user, uint256 requestId);

    /// @notice Emitted when user unstake request is executed
    event RequestExecuted(address indexed user, uint256 requestId);

    /// @notice Emitted when user unstakes tokens after cooldown period
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when user claims rewards
    event RewardsClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when reward config is updated
    event RewardConfigUpdated(uint256 rewardRate, uint256 rewardPeriod);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Stake tokens to the vault
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

    /// @notice Get current unclaimed rewards for user
    function getRewards(address account) external view returns (uint256);
}
