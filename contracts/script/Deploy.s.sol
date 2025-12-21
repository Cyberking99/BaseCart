// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BaseCartFactory} from "../src/BaseCartFactory.sol";

contract DeployScript is Script {
    BaseCartFactory public baseCartFactory;

    function setUp() public {}

    function run() public {
    	uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        baseCartFactory = new BaseCartFactory();
        console.log("BaseCartFactory deployed at: ", address(baseCartFactory));
        vm.stopBroadcast();
    }
}
