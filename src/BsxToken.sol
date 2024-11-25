// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

contract BsxToken is ERC20, ERC20Permit, ERC20Votes {
    string internal constant _NAME = "BSX";
    string internal constant _SYMBOL = "BSX";
    uint256 internal constant _TOTAL_SUPPLY = 1_000_000_000 ether;

    constructor(address _initDistributor) ERC20(_NAME, _SYMBOL) ERC20Permit(_NAME) {
        _mint(_initDistributor, _TOTAL_SUPPLY);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _maxSupply() internal pure virtual override returns (uint256) {
        return _TOTAL_SUPPLY;
    }
}
