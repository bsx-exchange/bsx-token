// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/Test.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ERC20Mintable } from "src/ERC20Mintable.sol";

contract ERC20MintableTest is Test {
    address private admin = makeAddr("admin");
    address private minter = makeAddr("minter");
    address private user = makeAddr("user");
    ERC20Mintable private erc20Mintable;

    bytes32 private constant ADMIN_ROLE = keccak256("BSX_ADMIN_ROLE");
    bytes32 private constant MINTER_ROLE = keccak256("BSX_MINTER_ROLE");

    function setUp() public {
        address erc20MintableImpl = address(new ERC20Mintable());
        address erc20MintableProxy = address(
            new TransparentUpgradeableProxy(
                erc20MintableImpl, admin, abi.encodeWithSelector(ERC20Mintable.initialize.selector, admin)
            )
        );
        erc20Mintable = ERC20Mintable(erc20MintableProxy);
    }

    function test_grantMinterRole() public {
        vm.prank(admin);
        erc20Mintable.grantMinterRole(minter);

        assertEq(erc20Mintable.hasRole(erc20Mintable.MINTER_ROLE(), minter), true);
    }

    function test_grantMinterRole_onlyAdmin() public {
        address caller = makeAddr("caller");

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, ADMIN_ROLE)
        );
        erc20Mintable.grantMinterRole(minter);
    }

    function test_revokeMinterRole() public {
        vm.prank(admin);
        erc20Mintable.grantMinterRole(minter);

        vm.prank(admin);
        erc20Mintable.revokeMinterRole(minter);

        assertEq(erc20Mintable.hasRole(erc20Mintable.MINTER_ROLE(), minter), false);
    }

    function test_revokeMinterRole_onlyAdmin() public {
        address caller = makeAddr("caller");

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, ADMIN_ROLE)
        );
        erc20Mintable.revokeMinterRole(minter);
    }

    function test_transferAdminRole() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        erc20Mintable.transferAdminRole(newAdmin);

        assertEq(erc20Mintable.hasRole(ADMIN_ROLE, admin), false);
        assertEq(erc20Mintable.hasRole(ADMIN_ROLE, newAdmin), true);
    }

    function test_transferAdminRole_onlyAdmin() public {
        address caller = makeAddr("caller");

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, ADMIN_ROLE)
        );
        erc20Mintable.transferAdminRole(user);
    }

    function test_mint() public {
        vm.prank(admin);
        erc20Mintable.grantMinterRole(minter);

        vm.prank(minter);
        erc20Mintable.mint(user, 1 ether);
        assertEq(erc20Mintable.balanceOf(user), 1 ether);
    }

    function test_mint_onlyMinter() public {
        address caller = makeAddr("caller");

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, MINTER_ROLE)
        );
        erc20Mintable.mint(user, 1 ether);
    }

    function test_burn() public {
        vm.prank(admin);
        erc20Mintable.grantMinterRole(minter);

        vm.prank(minter);
        erc20Mintable.mint(user, 1 ether);

        vm.prank(user);
        erc20Mintable.burn(1 ether);
        assertEq(erc20Mintable.balanceOf(user), 0);
    }

    function test_approve_disabled() public {
        vm.expectRevert(ERC20Mintable.NonTransferable.selector);
        erc20Mintable.approve(user, 1 ether);
    }

    function test_transfer_disabled() public {
        vm.expectRevert(ERC20Mintable.NonTransferable.selector);
        erc20Mintable.transfer(user, 1 ether);
    }

    function test_transferFrom_disabled() public {
        vm.expectRevert(ERC20Mintable.NonTransferable.selector);
        erc20Mintable.transferFrom(user, admin, 1 ether);
    }
}
