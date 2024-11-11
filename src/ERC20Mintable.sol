// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Mintable is ERC20Upgradeable, AccessControlUpgradeable {
    string public constant NAME = "aBSX";
    string public constant SYMBOL = "aBSX";

    bytes32 public constant ADMIN_ROLE = keccak256("BSX_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("BSX_MINTER_ROLE");

    error NonTransferable();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        __ERC20_init(NAME, SYMBOL);

        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _grantRole(ADMIN_ROLE, admin);
    }

    function grantMinterRole(address account) external {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) external {
        revokeRole(MINTER_ROLE, account);
    }

    function transferAdminRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, account);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }

    function approve(address, uint256) public pure override returns (bool) {
        revert NonTransferable();
    }
}
