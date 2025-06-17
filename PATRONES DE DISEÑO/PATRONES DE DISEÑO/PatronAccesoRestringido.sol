// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract RestrictedAccess {
    address public owner = msg.sender;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function restrictedAction() public onlyOwner {
        // Lógica restringida
    }
}