// SPDX-License-Identifier: GPL-3.0

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenPriceFeedRegistry} from "src/registry/TokenPriceFeedRegistry.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.t.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.t.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";

contract HelperConfig is Script, TestingUtils {
    struct NetworkConfig {
        address account;
        address serviceProvider;
        address[] tokens;
        address[] priceFeeds;
    }

    NetworkConfig activeConfig;
    address[] tokens;
    address[] priceFeeds;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeConfig = getSepoliaEthConfig();
        } else if (block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID) {
            activeConfig = getArbitrumSepoliaEthConfig();
        } else {
            activeConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return activeConfig;
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return activeConfig;
    }

    function getArbitrumSepoliaEthConfig() public returns (NetworkConfig memory) {
        address account = address(uint160(vm.envUint("OWNER_ACCOUNT")));
        address serviceProvider = address(uint160(vm.envUint("SERVICE_PROVIDER_ACCOUNT")));

        console.log("Arbitrum account", account);
        console.log("Arbitrum provider", serviceProvider);

        address[] memory _tokens = new address[](0);
        address[] memory _priceFeeds = new address[](0);

        activeConfig = NetworkConfig({
            account: account,
            serviceProvider: serviceProvider,
            tokens: _tokens,
            priceFeeds: _priceFeeds
        });
        return activeConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeConfig.account != address(0)) {
            return activeConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethFiatPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_FIAT_PRICE));
        ERC20Mock ethMock = new ERC20Mock("Ethereum", "wETH", msg.sender, 1000e8);

        MockV3Aggregator btcFiatPriceFeed = new MockV3Aggregator(DECIMALS, int256(BTC_FIAT_PRICE));
        ERC20Mock btcMock = new ERC20Mock("Bitcoin", "wBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        tokens.push(address(ethMock));
        priceFeeds.push(address(ethFiatPriceFeed));

        tokens.push(address(btcMock));
        priceFeeds.push(address(btcFiatPriceFeed));        

        address account = address(uint160(vm.envUint("ANVIL_ACCOUNT")));
        address serviceProvider = address(uint160(vm.envUint("ANVIL_SERVICE_PROVIDER_ACCOUNT")));
        activeConfig =
            NetworkConfig({account: account, serviceProvider: serviceProvider, tokens: tokens, priceFeeds: priceFeeds});

        return activeConfig;
    }
}
