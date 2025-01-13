// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlankContract {
    uint256 private storedInteger;

    function updateInteger(uint256 _newInteger) public {
        storedInteger = _newInteger;
    }

    function getInteger() public view returns (uint256) {
        return storedInteger;
    }
}
