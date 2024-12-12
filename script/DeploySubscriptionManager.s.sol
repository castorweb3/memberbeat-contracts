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

import {Script} from "forge-std/Script.sol";
import {MemberBeatSubscriptionManager, TokenPriceFeedRegistry} from "src/MemberBeatSubscriptionManager.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MemberBeatToken} from "@memberbeat-token/MemberBeatToken.sol";

contract DeploySubscriptionManager is Script {
    function run() public {
        deploySubscriptionManager(vm.envInt("SERVICE_PROVIDER_FEE"));
    }

    function deploySubscriptionManager(int256 serviceProviderFee)
        public
        returns (MemberBeatSubscriptionManager, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveConfig();

        vm.startBroadcast(config.account);
        MemberBeatSubscriptionManager subscriptionManager =
            new MemberBeatSubscriptionManager(config.serviceProvider, serviceProviderFee, config.memberBeatToken);

        MemberBeatToken(config.memberBeatToken).setSubscriptionManager(address(subscriptionManager));

        address[] memory tokens = config.tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            subscriptionManager.addTokenPriceFeed(tokens[i], config.priceFeeds[i]);
        }
        vm.stopBroadcast();
        return (subscriptionManager, helperConfig);
    }
}
