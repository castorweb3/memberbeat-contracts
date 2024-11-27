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

import {Test, console} from "forge-std/Test.sol";
import {MemberBeatSubscriptionManager, MemberBeatDataTypes} from "src/MemberBeatSubscriptionManager.sol";
import {DeploySubscriptionManager} from "script/DeploySubscriptionManager.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";

contract SubscriptionManagerUnitTest is Test, MemberBeatDataTypes, TestingUtils {
    DeploySubscriptionManager deployer;

    MemberBeatSubscriptionManager subscriptionManager;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;

    function setUp() public {
        deployer = new DeploySubscriptionManager();
        (subscriptionManager, helperConfig) = deployer.deploySubscriptionManager(SERVICE_PROVIDER_FEE);
        config = helperConfig.getActiveConfig();
    }

    function testCalculateServiceProviderFee() public view {
        uint256 amount = 1234567891234567890;
        console.log("amount", amount);
        uint256 actualFee = subscriptionManager.calculateServiceProviderFee(amount);
        console.log("   fee", actualFee);

        uint256 feeFactor = subscriptionManager.SERVICE_PROVIDER_FEE_FACTOR();
        uint256 scaledAmount = amount * uint256(subscriptionManager.getServiceProviderFee());
        uint256 expectedFee = (scaledAmount + feeFactor - 1) / feeFactor;
        assertEq(expectedFee, actualFee);
    }
}
