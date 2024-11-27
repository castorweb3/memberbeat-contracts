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
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "./Handler.t.sol";
import {MemberBeatSubscriptionManager, MemberBeatDataTypes} from "src/MemberBeatSubscriptionManager.sol";
import {DeploySubscriptionManager} from "script/DeploySubscriptionManager.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariant is StdInvariant, Test, MemberBeatDataTypes, TestingUtils {
    DeploySubscriptionManager deployer;

    MemberBeatSubscriptionManager subscriptionManager;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    address[] users;
    address[] tokens;
    address token1;
    address token2;

    Handler handler;

    BillingPlan[] fiatBillingPlans;
    uint256 constant START_TIMESTAMP = 1731744363; // 16/11/2024
    uint256 constant MAX_USERS = 1;
    uint256 constant INITIAL_USER_BALANCE = 10000e18;

    function setUp() public {
        vm.warp(START_TIMESTAMP);
        console.log("Start timestamp", block.timestamp);

        deployer = new DeploySubscriptionManager();
        (subscriptionManager, helperConfig) = deployer.deploySubscriptionManager(SERVICE_PROVIDER_FEE);

        config = helperConfig.getActiveConfig();
        tokens = config.tokens;

        token1 = tokens[0];
        token2 = tokens[1];
        if (token1 == address(0) || token2 == address(0)) {
            revert TestingConstants__TestRequiresAtLeastTwoTokens();
        }

        ERC20Mock token1ERC20 = ERC20Mock(token1);
        ERC20Mock token2ERC20 = ERC20Mock(token2);

        for (uint256 i = 0; i < MAX_USERS; i++) {
            address user = address(uint160(i + 1));
            token1ERC20.mint(user, INITIAL_USER_BALANCE);
            token2ERC20.mint(user, INITIAL_USER_BALANCE);
            vm.startPrank(user);
            token1ERC20.approve(address(subscriptionManager), INITIAL_USER_BALANCE);
            token2ERC20.approve(address(subscriptionManager), INITIAL_USER_BALANCE);
            vm.stopPrank();
            users.push(user);
        }

        // Setting up the fiat price plans
        uint256[] memory emptyTokenPrices;
        uint256[2] memory basicFiatPrices = [uint256(49 ether), uint256(469 ether)];
        uint256[2] memory standardFiatPrices = [uint256(69 ether), uint256(659 ether)];
        uint256[2] memory premiumFiatPrices = [uint256(99 ether), uint256(949 ether)];

        // Setting up plans
        vm.startPrank(config.account);

        BillingPlan[] memory basicBillingPlans = new BillingPlan[](2);
        basicBillingPlans[0] = createBillingPlan(
            Period.Month, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, basicFiatPrices[0]
        );
        basicBillingPlans[1] = createBillingPlan(
            Period.Year, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, basicFiatPrices[1]
        );
        subscriptionManager.createPlan(1, "Basic", basicBillingPlans);

        BillingPlan[] memory standardBillingPlans = new BillingPlan[](2);
        standardBillingPlans[0] = createBillingPlan(
            Period.Month, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, standardFiatPrices[0]
        );
        standardBillingPlans[1] = createBillingPlan(
            Period.Year, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, standardFiatPrices[1]
        );
        subscriptionManager.createPlan(2, "Standard", standardBillingPlans);

        BillingPlan[] memory premiumBillingPlans = new BillingPlan[](2);
        premiumBillingPlans[0] = createBillingPlan(
            Period.Month, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, premiumFiatPrices[0]
        );
        premiumBillingPlans[1] = createBillingPlan(
            Period.Year, uint16(1), PricingType.FiatPrice, tokens, emptyTokenPrices, premiumFiatPrices[1]
        );
        subscriptionManager.createPlan(3, "Premium", premiumBillingPlans);

        vm.stopPrank();

        Plan[] memory plans = subscriptionManager.getPlans();
        uint256 minPlanId = plans[0].planId;
        uint256 maxPlanId = plans[plans.length - 1].planId;
        uint8 minBillingPlanIndex = 0;
        uint8 maxBillingPlanIndex = uint8(basicFiatPrices.length - 1);
        uint256 maxTestingMonths = 1;

        // Initialize handler and target testing stuff
        handler = new Handler(
            subscriptionManager,
            users,
            tokens,
            minPlanId,
            maxPlanId,
            minBillingPlanIndex,
            maxBillingPlanIndex,
            maxTestingMonths
        );
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.subscribeNow.selector;
        selectors[1] = handler.warp.selector;
        selectors[2] = handler.unsubscribe.selector;

        console.log("Handler address", address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_usersDontHaveDuplicateSubscriptionPlans() public {
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            Subscription[] memory subscriptions = subscriptionManager.getSubscriptions();

            for (uint256 j = 0; j < subscriptions.length; j++) {
                Subscription memory sub = subscriptions[j];
                console.log("Subscription account", sub.account);
                console.log("Subscription planId", sub.planId);
            }

            bool duplicatesExist = false;
            for (uint256 j = 0; j < subscriptions.length; j++) {
                Subscription memory sub = subscriptions[j];
                for (uint256 k = j + 1; k < subscriptions.length; k++) {
                    if (sub.account == subscriptions[k].account && sub.planId == subscriptions[k].planId) {
                        duplicatesExist = true;
                        break;
                    }
                }
            }

            assertEq(duplicatesExist, false);

            vm.stopPrank();
        }

        console.log("Total subscribes", handler.totalSubscribes());
        console.log("Total unsubscribes", handler.totalUnsubscribes());
        console.log("Total warps", handler.totalWarps());
    }

    function statefulFuzz_tokenBalancesAreCorrect() public view {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            for (uint256 j = 0; j < tokens.length; j++) {
                address token = tokens[j];
                uint256 totalSpent = handler.getUserTokenAmountSpent(user, token);

                uint256 expectedUserBalance = INITIAL_USER_BALANCE - totalSpent;
                uint256 actualUserBalance = IERC20(token).balanceOf(user);
                assertEq(actualUserBalance, expectedUserBalance);

                console.log("expected user balance", expectedUserBalance);
                console.log("actual user balance", actualUserBalance);
            }
        }

        for (uint256 k = 0; k < tokens.length; k++) {
            address token = tokens[k];
            uint256 expectedSubscriptionManagerBalance = handler.getSubscriptionManagerTokenAmountCharged(token);
            uint256 actualSubscriptionManagerBalance = IERC20(token).balanceOf(address(subscriptionManager));

            assertEq(actualSubscriptionManagerBalance, expectedSubscriptionManagerBalance);

            console.log("expected sm balance", expectedSubscriptionManagerBalance);
            console.log("actual sm balance", actualSubscriptionManagerBalance);
        }

        for (uint256 m = 0; m < tokens.length; m++) {
            address token = tokens[m];
            uint256 expectedServiceProviderBalance = handler.getServiceProviderTokenFeeCharged(token);
            uint256 actualServiceProviderBalance =
                IERC20(token).balanceOf(address(subscriptionManager.getServiceProvider()));

            assertEq(actualServiceProviderBalance, expectedServiceProviderBalance);

            console.log("expected sp balance", expectedServiceProviderBalance);
            console.log("actual sp balance", actualServiceProviderBalance);
        }
    }
}
