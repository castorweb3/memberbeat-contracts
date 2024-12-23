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
import {
    MemberBeatSubscriptionManager,
    TokenPriceFeedRegistry,
    MemberBeatDataTypes,
    SubscriptionPlansRegistry
} from "src/MemberBeatSubscriptionManager.sol";
import {DeploySubscriptionManager} from "script/DeploySubscriptionManager.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";
import {Vm} from "forge-std/Vm.sol";

contract SubscriptionPlansRegistryUnitTest is Test, MemberBeatDataTypes, TestingUtils {
    DeploySubscriptionManager deployer;

    MemberBeatSubscriptionManager subscriptionManager;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    address[] tokens;

    address token1;
    address token2;

    BillingPlan fiatBillingPlan;
    BillingPlan fiatBillingPlanUpdate;
    BillingPlan tokenBillingPlan;

    function setUp() public {
        deployer = new DeploySubscriptionManager();
        (subscriptionManager, helperConfig) = deployer.deploySubscriptionManager(SERVICE_PROVIDER_FEE);
        config = helperConfig.getActiveConfig();

        tokens = config.tokens;

        token1 = tokens[0];
        token2 = tokens[1];
        if (token1 == address(0) || token2 == address(0)) {
            revert TestingConstants__TestRequiresAtLeastTwoTokens();
        }

        uint256[] memory emptyTokenPrices;
        uint256[] memory tokenPrices = new uint256[](2);
        tokenPrices[0] = 0.1 ether;
        tokenPrices[1] = 0.09 ether;

        fiatBillingPlan =
            createBillingPlan(Period.Month, 1, PricingType.FiatPrice, tokens, emptyTokenPrices, ONE_MONTH_FIAT_PRICE);
        fiatBillingPlanUpdate = createBillingPlan(
            Period.Month, 3, PricingType.FiatPrice, tokens, emptyTokenPrices, ONE_MONTH_FIAT_PRICE_UPDATE
        );
        tokenBillingPlan = createBillingPlan(Period.Month, 1, PricingType.TokenPrice, tokens, tokenPrices, 0);
    }

    modifier createdPlan() {
        vm.recordLogs();
        vm.prank(config.account);
        subscriptionManager.createPlan(PLAN_ID, PLAN_NAME, new BillingPlan[](0));
        _;
    }

    modifier addedFiatBillingPlan() {
        vm.recordLogs();
        vm.prank(config.account);
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);
        _;
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        return string(abi.encodePacked(_bytes32));
    }

    function testCreatePlanRevertsIfNotOwner() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.createPlan(PLAN_ID, PLAN_NAME, new BillingPlan[](0));
    }

    function testCreatePlanRevertsIfPlanAlreadyRegistered() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanAlreadyRegistered.selector, PLAN_ID
            )
        );
        subscriptionManager.createPlan(PLAN_ID, PLAN_NAME, new BillingPlan[](0));
    }

    function testCreatePlanEmitsPlanCreatedEvent() public createdPlan {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        (Vm.Log memory planCreatedEvent, bool found) = findEvent(entries, "PlanCreated(uint256,string)");
        assert(found);

        uint256 planId = uint256(planCreatedEvent.topics[1]);
        assertEq(planId, PLAN_ID);
    }

    function testUpdatePlanRevertsIfNotOwner() public createdPlan {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.updatePlan(PLAN_ID, NEW_PLAN_NAME, new BillingPlan[](0));
    }

    function testUpdatePlanRevertsIfPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.updatePlan(RANDOM_PLAN_ID, NEW_PLAN_NAME, new BillingPlan[](0));
    }

    function testUpdatePlanUpdatesAPlan() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.updatePlan(PLAN_ID, NEW_PLAN_NAME, new BillingPlan[](0));

        Plan memory plan = subscriptionManager.getPlan(PLAN_ID);

        assertEq(plan.planId, PLAN_ID);
        assertEq(plan.planName, NEW_PLAN_NAME);
    }

    function testUpdatePlanEmitsPlanUpdatedEvent() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.updatePlan(PLAN_ID, NEW_PLAN_NAME, new BillingPlan[](0));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory planUpdatedEvent, bool found) = findEvent(entries, "PlanUpdated(uint256,string)");
        assert(found);

        uint256 planId = uint256(planUpdatedEvent.topics[1]);
        assertEq(planId, PLAN_ID);
    }

    function testDeletePlanRevertsIfNotOwner() public createdPlan {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.deletePlan(PLAN_ID);
    }

    function testDeletePlanRevertsIfPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.deletePlan(RANDOM_PLAN_ID);
    }

    function testDeletePlanDeletesAPlan() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.deletePlan(PLAN_ID);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, PLAN_ID)
        );
        subscriptionManager.getPlan(PLAN_ID);
    }

    function testDeletePlanEmitsPlanDeletedEvent() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.deletePlan(PLAN_ID);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory planDeletedEvent, bool found) = findEvent(entries, "PlanDeleted(uint256)");
        assert(found);

        uint256 planId = uint256(planDeletedEvent.topics[1]);
        assertEq(planId, PLAN_ID);
    }

    function testSyncPlansRevertsIfNotOwner() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.syncPlans(new Plan[](0));
    }

    function testSyncPlanSynchronizesThePlans() public createdPlan addedFiatBillingPlan {
        BillingPlan[] memory billingPlans = new BillingPlan[](1);
        billingPlans[0] = fiatBillingPlan;

        Plan[] memory plans4firstSync = new Plan[](3);
        plans4firstSync[0] = Plan({planId: PLAN_ID, planName: NEW_PLAN_NAME, billingPlans: billingPlans});
        plans4firstSync[1] = Plan({planId: PLAN_ID_2, planName: PLAN_NAME_2, billingPlans: billingPlans});
        plans4firstSync[2] = Plan({planId: PLAN_ID_3, planName: PLAN_NAME_3, billingPlans: billingPlans});

        vm.prank(config.account);
        subscriptionManager.syncPlans(plans4firstSync);

        Plan memory plan1 = subscriptionManager.getPlan(PLAN_ID);
        assertEq(plan1.planName, NEW_PLAN_NAME);
        Plan memory plan2 = subscriptionManager.getPlan(PLAN_ID_2);
        assertEq(plan2.planName, PLAN_NAME_2);

        Plan[] memory plans4secondSync = new Plan[](3);
        plans4secondSync[0] = Plan({planId: PLAN_ID, planName: NEW_PLAN_NAME, billingPlans: billingPlans});
        plans4secondSync[1] = Plan({planId: PLAN_ID_2, planName: PLAN_NAME_2, billingPlans: billingPlans});

        vm.prank(config.account);
        subscriptionManager.syncPlans(plans4secondSync);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, PLAN_ID_3
            )
        );
        subscriptionManager.getPlan(PLAN_ID_3);
    }

    function testAddBillingPlanRevertsIfNotOwner() public createdPlan {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);
    }

    function testAddBillingPlanRevertsIfPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.addBillingPlan(RANDOM_PLAN_ID, fiatBillingPlan);
    }

    function testAddFiatBillingPlanRevertsIfTokenAddressesNotProvided() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__TokenAddressesNotProvided.selector, PLAN_ID
            )
        );
        fiatBillingPlan.tokenAddresses = new address[](0);
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);
    }

    function testAddFiatBillingPlanAddsABillingPlan() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        Plan memory plan = subscriptionManager.getPlan(PLAN_ID);
        assertEq(plan.billingPlans.length, 1);
        BillingPlan memory actualBillingPlan = plan.billingPlans[0];
        assert(actualBillingPlan.period == fiatBillingPlan.period);
        assert(actualBillingPlan.periodValue == fiatBillingPlan.periodValue);
        assert(actualBillingPlan.pricingType == fiatBillingPlan.pricingType);
        assert(actualBillingPlan.tokenAddresses.length == fiatBillingPlan.tokenAddresses.length);
        assert(actualBillingPlan.tokenPrices.length == fiatBillingPlan.tokenPrices.length);
        assert(actualBillingPlan.fiatPrice == fiatBillingPlan.fiatPrice);
    }

    function testAddFiatBillingPlanEmitsBillingPlanAddedEvent() public createdPlan {
        vm.prank(config.account);
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory billingPlanAddedEvent, bool found) = findEvent(entries, "BillingPlanAdded(uint256,uint8)");
        assert(found);

        uint256 planId = uint256(billingPlanAddedEvent.topics[1]);
        uint8 billingPlanIndex = uint8(uint256(billingPlanAddedEvent.topics[2]));

        assertEq(planId, PLAN_ID);
        assertEq(billingPlanIndex, 0);
    }

    function testAddTokenBillingPlanRevertsIfTokenAddressesNotProvided() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__TokenAddressesNotProvided.selector, PLAN_ID
            )
        );
        tokenBillingPlan.tokenAddresses = new address[](0);
        subscriptionManager.addBillingPlan(PLAN_ID, tokenBillingPlan);
    }

    function testAddTokenBillingPlanRevertsIfTokenPricesNotProvided() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__TokenPricesNotProvided.selector, PLAN_ID
            )
        );
        tokenBillingPlan.tokenPrices = new uint256[](0);
        subscriptionManager.addBillingPlan(PLAN_ID, tokenBillingPlan);
    }

    function testAddTokenBillingPlanRevertsIfTokenAddressesAndPricesMismatch() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__TokenAddressesDontMatchTokenPrices.selector,
                PLAN_ID
            )
        );
        tokenBillingPlan.tokenPrices.push(uint256(0.2 ether));
        subscriptionManager.addBillingPlan(PLAN_ID, tokenBillingPlan);
    }

    function testAddTokenBillingPlanRevertsIfInvalidTokenAddress() public createdPlan {
        vm.prank(config.account);
        tokenBillingPlan.tokenAddresses[0] = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidTokenAddress.selector,
                PLAN_ID,
                tokenBillingPlan.tokenAddresses[0]
            )
        );
        subscriptionManager.addBillingPlan(PLAN_ID, tokenBillingPlan);
    }

    function testAddBillingPlanRevertsIfPeriodIsInvalid() public createdPlan {
        vm.startPrank(config.account);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidPeriod.selector,
                PLAN_ID,
                Period.Month,
                0
            )
        );
        fiatBillingPlan.periodValue = 0;
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidPeriod.selector,
                PLAN_ID,
                Period.Day,
                INVALID_DAY
            )
        );
        fiatBillingPlan.period = Period.Day;
        fiatBillingPlan.periodValue = INVALID_DAY;
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidPeriod.selector,
                PLAN_ID,
                Period.Month,
                INVALID_MONTH
            )
        );
        fiatBillingPlan.period = Period.Month;
        fiatBillingPlan.periodValue = INVALID_MONTH;
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidPeriod.selector,
                PLAN_ID,
                Period.Year,
                INVALID_YEAR
            )
        );
        fiatBillingPlan.period = Period.Year;
        fiatBillingPlan.periodValue = INVALID_YEAR;
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanWithInvalidPeriod.selector,
                PLAN_ID,
                Period.Lifetime,
                INVALID_LIFETIME
            )
        );
        fiatBillingPlan.period = Period.Lifetime;
        fiatBillingPlan.periodValue = INVALID_LIFETIME;
        subscriptionManager.addBillingPlan(PLAN_ID, fiatBillingPlan);

        vm.stopPrank();
    }

    function testUpdateBillingPlanRevertsIfNotOwner() public createdPlan {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.updateBillingPlan(PLAN_ID, 0, fiatBillingPlanUpdate);
    }

    function testUpdateBillingPlanRevertsIfPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.updateBillingPlan(RANDOM_PLAN_ID, 0, fiatBillingPlanUpdate);
    }

    function testUpdateBillingPlanRevertsIfBillingPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__BillingPlanNotFound.selector,
                PLAN_ID,
                INVALID_BILLING_PLAN_INDEX
            )
        );
        subscriptionManager.updateBillingPlan(PLAN_ID, INVALID_BILLING_PLAN_INDEX, fiatBillingPlanUpdate);
    }

    function testUpdateBillingPlanUpdatestABillingPlan() public createdPlan addedFiatBillingPlan {
        vm.prank(config.account);
        subscriptionManager.updateBillingPlan(PLAN_ID, 0, fiatBillingPlanUpdate);

        BillingPlan memory actualBillingPlan = subscriptionManager.getBillingPlan(PLAN_ID, 0);
        assert(actualBillingPlan.period == fiatBillingPlanUpdate.period);
        assert(actualBillingPlan.periodValue == fiatBillingPlanUpdate.periodValue);
        assert(actualBillingPlan.pricingType == fiatBillingPlanUpdate.pricingType);
        assert(actualBillingPlan.tokenAddresses.length == fiatBillingPlanUpdate.tokenAddresses.length);
        assert(actualBillingPlan.tokenPrices.length == fiatBillingPlanUpdate.tokenPrices.length);
        assert(actualBillingPlan.fiatPrice == fiatBillingPlanUpdate.fiatPrice);
    }

    function testUpdateBillingPlanEmitsBillingPlanUpdatedEvent() public createdPlan addedFiatBillingPlan {
        vm.prank(config.account);
        subscriptionManager.updateBillingPlan(PLAN_ID, 0, fiatBillingPlanUpdate);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory billingPlanUpdatedEvent, bool found) = findEvent(entries, "BillingPlanUpdated(uint256,uint8)");
        assert(found);

        uint256 planId = uint256(billingPlanUpdatedEvent.topics[1]);
        uint8 billingPlanIndex = uint8(uint256(billingPlanUpdatedEvent.topics[2]));

        assertEq(planId, PLAN_ID);
        assertEq(billingPlanIndex, 0);
    }

    function testRemoveBillingPlanRevertsIfNotOwner() public createdPlan {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.removeBillingPlan(PLAN_ID, 0);
    }

    function testRemoveBillingPlanRevertsIfPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.removeBillingPlan(RANDOM_PLAN_ID, 0);
    }

    function testRemoveBillingPlanRevertsIfBillingPlanNotFound() public createdPlan {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__BillingPlanNotFound.selector,
                PLAN_ID,
                INVALID_BILLING_PLAN_INDEX
            )
        );
        subscriptionManager.removeBillingPlan(PLAN_ID, INVALID_BILLING_PLAN_INDEX);
    }

    function testRemoveBillingPlanRemovesABillingPlan() public createdPlan addedFiatBillingPlan {
        vm.prank(config.account);
        subscriptionManager.removeBillingPlan(PLAN_ID, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__BillingPlanNotFound.selector, PLAN_ID, 0
            )
        );
        subscriptionManager.getBillingPlan(PLAN_ID, 0);
    }

    function testRemoveBillingPlanEmitsBillingPlanRemovedEvent() public createdPlan addedFiatBillingPlan {
        vm.prank(config.account);
        subscriptionManager.removeBillingPlan(PLAN_ID, 0);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory billingPlanRemovedEvent, bool found) = findEvent(entries, "BillingPlanRemoved(uint256,uint8)");
        assert(found);

        uint256 planId = uint256(billingPlanRemovedEvent.topics[1]);
        uint8 billingPlanIndex = uint8(uint256(billingPlanRemovedEvent.topics[2]));

        assertEq(planId, PLAN_ID);
        assertEq(billingPlanIndex, 0);
    }

    function testGetBillingPlanRevertsIfPlanNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.getBillingPlan(RANDOM_PLAN_ID, 0);
    }

    function testGetBillingPlanRevertsIfBillingPlanNotFound() public createdPlan addedFiatBillingPlan {
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__BillingPlanNotFound.selector,
                PLAN_ID,
                INVALID_BILLING_PLAN_INDEX
            )
        );
        subscriptionManager.getBillingPlan(PLAN_ID, INVALID_BILLING_PLAN_INDEX);
    }
}
