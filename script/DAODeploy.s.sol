// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DAOContract} from "../src/DAOContract.sol";

contract DAODeploy is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address governanceToken = vm.envAddress("TOKEN_CONTRACT_ADDRESS");

        vm.startBroadcast();
        DAOContract dao = new DAOContract(
            governanceToken,
            1000 * 10**12, // my token decimals
            10 minutes
        );

        vm.stopBroadcast();
    }
}
