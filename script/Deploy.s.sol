// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {BunniLpZapIn} from "../src/BunniLpZapIn.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (BunniLpZapIn c) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 param = 123;

        vm.startBroadcast(deployerPrivateKey);

        c = BunniLpZapIn(
            create3.deploy(
                getCreate3ContractSalt("BunniLpZapIn"), bytes.concat(type(BunniLpZapIn).creationCode, abi.encode(param))
            )
        );

        vm.stopBroadcast();
    }
}
