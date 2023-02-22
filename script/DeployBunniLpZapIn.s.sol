// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {LibString} from "solmate/utils/LibString.sol";

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {BunniLpZapIn} from "../src/BunniLpZapIn.sol";

contract DeployBunniLpZapInScript is CREATE3Script {
    using LibString for uint256;

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (BunniLpZapIn c) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address zeroExProxy = vm.envAddress("ZEROEX_PROXY");
        address weth = vm.envAddress(string.concat("WETH_", block.chainid.toString()));
        address bunniHub = vm.envAddress("BUNNI_HUB");

        vm.startBroadcast(deployerPrivateKey);

        c = BunniLpZapIn(
            create3.deploy(
                getCreate3ContractSalt("BunniLpZapIn"),
                bytes.concat(type(BunniLpZapIn).creationCode, abi.encode(zeroExProxy, weth, bunniHub))
            )
        );

        vm.stopBroadcast();
    }
}
