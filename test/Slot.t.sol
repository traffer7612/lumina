// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { CeitnotStorage } from "../src/CeitnotStorage.sol";

contract SlotTest is Test {
    function testEngineStorageSlot() public view {
        bytes32 s = CeitnotStorage.getStorageSlot();
        assertEq(s, bytes32(uint256(0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500)));
    }
}
