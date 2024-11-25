// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { StdStorage, Test, stdStorage } from "forge-std/Test.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BsxToken } from "src/BsxToken.sol";
import { IStakingVault, StakingVault } from "src/StakingVault.sol";

contract StakingVaultTest is Test {
    using stdStorage for StdStorage;

    StakingVault private stakingVault;

    address private user = makeAddr("user");
    address private owner = makeAddr("owner");

    BsxToken private stakingToken;
    uint256 private rewardRate = 10 ether;
    uint256 private rewardPeriod = 30 days;

    function setUp() public {
        vm.startPrank(owner);

        stakingToken = new BsxToken(owner);

        address stakingVaultImpl = address(new StakingVault());
        address stakingVaultProxy = address(
            new TransparentUpgradeableProxy(
                stakingVaultImpl,
                owner,
                abi.encodeWithSelector(
                    StakingVault.initialize.selector, owner, address(stakingToken), rewardRate, rewardPeriod
                )
            )
        );
        stakingVault = StakingVault(stakingVaultProxy);

        stakingToken.transfer(user, 100_000 ether);

        vm.stopPrank();

        vm.prank(user);
        stakingToken.approve(address(stakingVault), type(uint256).max);
    }

    function test_initialize() public view {
        assertEq(stakingVault.owner(), owner);
        assertEq(address(stakingVault.stakingToken()), address(stakingToken));
        assertEq(stakingVault.rewardRate(), 10 ether);
        assertEq(stakingVault.rewardPeriod(), 30 days);
    }

    function test_stake() public {
        vm.startPrank(user);

        uint256 balanceBefore = stakingToken.balanceOf(user);
        uint256 stakeAmount = 6000 ether;
        vm.expectEmit();
        emit IStakingVault.Staked(user, stakeAmount);
        stakingVault.stake(stakeAmount);

        assertEq(stakingToken.balanceOf(user), balanceBefore - stakeAmount);
        assertEq(stakingToken.balanceOf(address(stakingVault)), stakeAmount);
        assertEq(stakingToken.nonces(user), 0);

        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 0);
        assertEq(stakingVault.balanceOf(user), stakeAmount);
        assertEq(stakingVault.totalSupply(), stakeAmount);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 0);

        skip(5 * rewardPeriod);

        assertEq(stakingVault.getRewards(user), (5 * rewardRate * stakeAmount) / 1e18);
        assertEq(stakingVault.getAccumulatedRewardPerToken(), 5 * rewardRate);
    }

    function test_stake_forAccount() public {
        vm.startPrank(user);

        uint256 balanceBefore = stakingToken.balanceOf(user);
        uint256 stakeAmount = 6000 ether;
        vm.expectEmit();
        emit IStakingVault.Staked(user, stakeAmount);
        stakingVault.stake(user, stakeAmount);

        assertEq(stakingToken.balanceOf(user), balanceBefore - stakeAmount);
        assertEq(stakingToken.balanceOf(address(stakingVault)), stakeAmount);
        assertEq(stakingToken.nonces(user), 0);

        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 0);
        assertEq(stakingVault.balanceOf(user), stakeAmount);
        assertEq(stakingVault.totalSupply(), stakeAmount);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 0);

        skip(5 * rewardPeriod);

        assertEq(stakingVault.getRewards(user), (5 * rewardRate * stakeAmount) / 1e18);
        assertEq(stakingVault.getAccumulatedRewardPerToken(), 5 * rewardRate);
    }

    function test_stake_multipleTimes() public {
        vm.startPrank(user);

        // first stake
        uint256 stakeAmount1 = 10_000 ether;
        vm.expectEmit();
        emit IStakingVault.Staked(user, stakeAmount1);
        stakingVault.stake(user, stakeAmount1);

        assertEq(stakingToken.balanceOf(user), 90_000 ether);
        assertEq(stakingToken.balanceOf(address(stakingVault)), 10_000 ether);
        assertEq(stakingVault.balanceOf(user), 10_000 ether);
        assertEq(stakingVault.totalSupply(), 10_000 ether);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 0);

        assertEq(stakingVault.getRewards(user), 0);
        assertEq(stakingVault.lastAccumulatedRewards(user), 0);

        // second stake
        skip(4 * rewardPeriod);

        uint256 stakeAmount2 = 20_000 ether;
        vm.expectEmit();
        emit IStakingVault.Staked(user, stakeAmount2);
        stakingVault.stake(user, stakeAmount2);

        assertEq(stakingToken.balanceOf(user), 70_000 ether);
        assertEq(stakingToken.balanceOf(address(stakingVault)), 30_000 ether);
        assertEq(stakingVault.balanceOf(user), 30_000 ether);
        assertEq(stakingVault.totalSupply(), 30_000 ether);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 4 * rewardRate);

        assertEq(stakingVault.getRewards(user), 4 * rewardRate * stakeAmount1 / 1e18);
        assertEq(stakingVault.lastAccumulatedRewards(user), 4 * rewardRate);

        skip(2 * rewardPeriod);

        assertEq(stakingVault.getRewards(user), (6 * rewardRate * stakeAmount1 + 2 * rewardRate * stakeAmount2) / 1e18);
        assertEq(stakingVault.getAccumulatedRewardPerToken(), 4 * rewardRate + 2 * rewardRate);
    }

    function test_stake_revertIfZeroAmount() public {
        vm.expectRevert(IStakingVault.ZeroAmount.selector);
        stakingVault.stake(user, 0);
    }

    function test_stake_revertIfZeroAddress() public {
        vm.expectRevert(IStakingVault.ZeroAddress.selector);
        stakingVault.stake(address(0), 1);
    }

    function test_requestUnstake() public {
        vm.startPrank(user);

        uint256 stakeAmount = 10_000 ether;
        stakingVault.stake(user, stakeAmount);

        skip(2 * rewardPeriod);

        uint256 requestId = 5;
        uint256 unstakeAmount = 4000 ether;
        vm.expectEmit();
        emit IStakingVault.UnstakeRequested(user, requestId, unstakeAmount);
        stakingVault.requestUnstake(requestId, unstakeAmount);

        assertEq(stakingToken.balanceOf(user), 90_000 ether);
        assertEq(stakingToken.balanceOf(address(stakingVault)), 10_000 ether);

        assertEq(stakingVault.balanceOf(user), 6000 ether);
        assertEq(stakingVault.totalSupply(), 6000 ether);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), 2 * rewardRate);

        assertEq(stakingVault.getRewards(user), 2 * rewardRate * stakeAmount / 1e18);
        assertEq(stakingVault.lastAccumulatedRewards(user), 2 * rewardRate);

        IStakingVault.UnstakeRequest memory unstakeRequest = stakingVault.getUnstakeRequest(user, requestId);
        assertEq(unstakeRequest.amount, unstakeAmount);
        assertEq(unstakeRequest.requestTimestamp, block.timestamp);
        assertEq(uint8(unstakeRequest.state), uint8(IStakingVault.UnstakeRequestState.PENDING));
    }

    function test_requestUnstake_revertIfZeroAmount() public {
        vm.expectRevert(IStakingVault.ZeroAmount.selector);
        stakingVault.requestUnstake(0, 0);
    }

    function test_requestUnstake_revertIfRequestAmountGreaterThanStakedAmount() public {
        uint256 amount = 1;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IStakingVault.InsufficientStakeBalance.selector, user, amount, 0));
        stakingVault.requestUnstake(0, amount);
    }

    function test_requestUnstake_revertIfInvalidState() public {
        vm.startPrank(user);
        stakingVault.stake(user, 5 ether);

        uint256 requestId = 3;
        uint256 requestSlot = stdstore.target(address(stakingVault)).sig("getUnstakeRequest(address,uint256)").with_key(
            user
        ).with_key(requestId).find();

        for (uint8 i = 0; i <= uint8(type(IStakingVault.UnstakeRequestState).max); i++) {
            IStakingVault.UnstakeRequestState state = IStakingVault.UnstakeRequestState(i);
            if (state != IStakingVault.UnstakeRequestState.NONE) {
                vm.store(address(stakingVault), bytes32(requestSlot + 2), bytes32(uint256(state)));

                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStakingVault.InvalidRequestState.selector,
                        user,
                        requestId,
                        state,
                        IStakingVault.UnstakeRequestState.NONE
                    )
                );
                stakingVault.requestUnstake(requestId, 4 ether);
            }
        }
    }

    function test_cancelUnstakeRequest() public {
        vm.startPrank(user);

        // stake
        uint256 stakeAmount = 40_000 ether;
        stakingVault.stake(user, stakeAmount);

        // unstake after 1 reward period
        skip(rewardPeriod);
        uint256 rewards = rewardRate * stakeAmount / 1e18;
        uint256 accRewards = rewardRate;

        uint256 requestId = 5;
        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;
        uint256 unstakeAmount = 4000 ether;
        uint256 ts = block.timestamp;
        stakingVault.requestUnstake(requestId, unstakeAmount);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), accRewards);

        // cancel unstake request after 5 days
        skip(5 days);
        rewards += (5 days * rewardRate / rewardPeriod) * (stakeAmount - unstakeAmount) / 1e18;
        accRewards += (5 days * rewardRate / rewardPeriod);

        vm.expectEmit();
        emit IStakingVault.RequestCancelled(user, requestId);
        stakingVault.cancelUnstakeRequests(requestIds);

        assertEq(stakingToken.balanceOf(user), 60_000 ether);
        assertEq(stakingToken.balanceOf(address(stakingVault)), stakeAmount);

        assertEq(stakingVault.balanceOf(user), stakeAmount);
        assertEq(stakingVault.totalSupply(), stakeAmount);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), accRewards);

        assertEq(stakingVault.getRewards(user), rewards);
        assertEq(stakingVault.lastAccumulatedRewards(user), accRewards);

        IStakingVault.UnstakeRequest memory unstakeRequest = stakingVault.getUnstakeRequest(user, requestId);
        assertEq(unstakeRequest.amount, unstakeAmount);
        assertEq(unstakeRequest.requestTimestamp, ts);
        assertEq(uint8(unstakeRequest.state), uint8(IStakingVault.UnstakeRequestState.CANCELLED));
    }

    function test_cancelUnstakeRequest_revertIfEmptyRequestIds() public {
        vm.expectRevert(IStakingVault.EmptyRequestIds.selector);
        stakingVault.cancelUnstakeRequests(new uint256[](0));
    }

    function test_cancelUnstakeRequest_revertIfInvalidState() public {
        vm.startPrank(user);
        stakingVault.stake(user, 10 ether);

        uint256 requestId = 3;
        stakingVault.requestUnstake(requestId, 8 ether);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;
        uint256 requestSlot = stdstore.target(address(stakingVault)).sig("getUnstakeRequest(address,uint256)").with_key(
            user
        ).with_key(requestId).find();

        for (uint8 i = 0; i <= uint8(type(IStakingVault.UnstakeRequestState).max); i++) {
            IStakingVault.UnstakeRequestState state = IStakingVault.UnstakeRequestState(i);
            if (state != IStakingVault.UnstakeRequestState.PENDING) {
                vm.store(address(stakingVault), bytes32(requestSlot + 2), bytes32(uint256(state)));

                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStakingVault.InvalidRequestState.selector,
                        user,
                        requestId,
                        state,
                        IStakingVault.UnstakeRequestState.PENDING
                    )
                );
                stakingVault.cancelUnstakeRequests(requestIds);
            }
        }
    }

    function test_unstake() public {
        vm.startPrank(user);
        uint256 stakeAmount = 40_000 ether;
        stakingVault.stake(user, stakeAmount);

        uint256[] memory requestIds = new uint256[](3);
        uint256 rewards = 0;
        uint256 accRewards = 0;

        assertEq(stakingVault.UNSTAKE_COOLDOWN(), 14 days);

        // first request
        skip(rewardPeriod);
        rewards = rewardRate * stakeAmount / 1e18;
        accRewards = rewardRate;
        requestIds[0] = 5;
        stakingVault.requestUnstake(requestIds[0], 10_000 ether);
        stakeAmount -= 10_000 ether;

        // second request
        skip(3 days);
        rewards += (3 days * rewardRate / rewardPeriod) * stakeAmount / 1e18;
        accRewards += 3 days * rewardRate / rewardPeriod;
        requestIds[1] = 2;
        stakingVault.requestUnstake(requestIds[1], 4000 ether);
        stakeAmount -= 4000 ether;

        // third request
        skip(10 days);
        rewards += (10 days * rewardRate / rewardPeriod) * stakeAmount / 1e18;
        accRewards += 10 days * rewardRate / rewardPeriod;
        requestIds[2] = 12;
        stakingVault.requestUnstake(requestIds[2], 2000 ether);
        stakeAmount -= 2000 ether;

        uint256 lastUpdate = block.timestamp;

        // unstake
        skip(14 days);
        rewards += (14 days * rewardRate / rewardPeriod) * stakeAmount / 1e18;

        vm.expectEmit();
        emit IStakingVault.RequestExecuted(user, requestIds[0]);
        emit IStakingVault.RequestExecuted(user, requestIds[1]);
        emit IStakingVault.RequestExecuted(user, requestIds[2]);
        emit IStakingVault.Unstaked(user, 16_000 ether);
        stakingVault.unstake(requestIds);

        assertEq(stakingToken.balanceOf(address(stakingVault)), 24_000 ether);
        assertEq(stakingVault.balanceOf(user), 24_000 ether);
        assertEq(stakingVault.totalSupply(), 24_000 ether);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), lastUpdate);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), accRewards);
        assertEq(stakingVault.getRewards(user), rewards);
    }

    function test_unstake_revertIfEmptyRequestIds() public {
        vm.expectRevert(IStakingVault.EmptyRequestIds.selector);
        stakingVault.unstake(new uint256[](0));
    }

    function test_unstake_revertIfInvalidState() public {
        vm.startPrank(user);
        stakingVault.stake(user, 2 ether);

        uint256 requestId = 6;
        stakingVault.requestUnstake(requestId, 2 ether);

        skip(30 days);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;
        uint256 requestSlot = stdstore.target(address(stakingVault)).sig("getUnstakeRequest(address,uint256)").with_key(
            user
        ).with_key(requestId).find();

        for (uint8 i = 0; i <= uint8(type(IStakingVault.UnstakeRequestState).max); i++) {
            IStakingVault.UnstakeRequestState state = IStakingVault.UnstakeRequestState(i);
            if (state != IStakingVault.UnstakeRequestState.PENDING) {
                vm.store(address(stakingVault), bytes32(requestSlot + 2), bytes32(uint256(state)));

                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStakingVault.InvalidRequestState.selector,
                        user,
                        requestId,
                        state,
                        IStakingVault.UnstakeRequestState.PENDING
                    )
                );
                stakingVault.unstake(requestIds);
            }
        }
    }

    function test_unstake_revertIfCooldown() public {
        vm.startPrank(user);
        stakingVault.stake(user, 1 ether);

        uint256 requestId = 6;
        stakingVault.requestUnstake(requestId, 1 ether);
        uint256 initTimestamp = block.timestamp;

        skip(14 days - 1);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;
        vm.expectRevert(
            abi.encodeWithSelector(IStakingVault.Cooldown.selector, user, requestId, initTimestamp + 14 days)
        );
        stakingVault.unstake(requestIds);
    }

    function test_updateRewardConfig() public {
        // user stake
        uint256 stakeAmount1 = 40_000 ether;
        vm.prank(user);
        stakingVault.stake(user, stakeAmount1);

        // skip 3 reward periods
        skip(3 * rewardPeriod);
        uint256 userRewards = 3 * rewardRate * stakeAmount1 / 1e18;
        uint256 accRewards = 3 * rewardRate;
        assertEq(stakingVault.getRewards(user), userRewards);

        uint256 newRewardRate = 20 ether;
        uint256 newRewardPeriod = 15 days;

        vm.prank(owner);
        vm.expectEmit();
        emit IStakingVault.RewardConfigUpdated(newRewardRate, newRewardPeriod);
        stakingVault.updateRewardConfig(newRewardRate, newRewardPeriod);

        assertEq(stakingVault.rewardRate(), newRewardRate);
        assertEq(stakingVault.rewardPeriod(), newRewardPeriod);
        assertEq(stakingVault.lastRewardUpdateTimestamp(), block.timestamp);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), accRewards);

        // skip 2 new reward periods
        skip(2 * newRewardPeriod);
        userRewards += 2 * newRewardRate * stakeAmount1 / 1e18;
        accRewards += 2 * newRewardRate;
        assertEq(stakingVault.getRewards(user), userRewards);

        uint256 stakeAmount2 = 10 ether;
        vm.prank(user);
        stakingVault.stake(user, stakeAmount2);
        assertEq(stakingVault.lastAccumulatedRewardPerToken(), accRewards);

        // skip 1 new reward period
        skip(newRewardPeriod);
        userRewards += newRewardRate * (stakeAmount1 + stakeAmount2) / 1e18;
        assertEq(stakingVault.getRewards(user), userRewards);
    }

    function test_updateRewardConfig_revertIfNotOwner() public {
        address anyone = makeAddr("anyone");

        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, anyone));
        stakingVault.updateRewardConfig(0, 0);
    }

    function test_updateRewardConfig_revertIfZeroRewardPeriod() public {
        uint256 _rewardRate = 1;
        uint256 _rewardPeriod = 0;
        vm.prank(owner);
        vm.expectRevert(IStakingVault.ZeroRewardPeriod.selector);
        stakingVault.updateRewardConfig(_rewardRate, _rewardPeriod);
    }

    function test_approve_disabled() public {
        vm.expectRevert(IStakingVault.NonTransferable.selector);
        stakingVault.approve(user, 1 ether);
    }

    function test_transfer_disabled() public {
        vm.expectRevert(IStakingVault.NonTransferable.selector);
        stakingVault.transfer(user, 1 ether);
    }

    function test_transferFrom_disabled() public {
        vm.expectRevert(IStakingVault.NonTransferable.selector);
        stakingVault.transferFrom(user, user, 1 ether);
    }
}
