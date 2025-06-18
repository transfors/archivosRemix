// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title MyContractV1 - Versión 1
contract MyContractV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public value;

    function initialize() public initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
    value = 0;
}


    function setValue(uint256 _value) public virtual {
        value = _value;
    }

    function getVersion() public pure virtual returns (string memory) {
        return "V1";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

/// @title MyContractV2 - Versión 2
contract MyContractV2 is MyContractV1 {
    function setValue(uint256 _value) public override {
        value = _value * 2;
    }

    function getVersion() public pure override returns (string memory) {
        return "V2";
    }
}
