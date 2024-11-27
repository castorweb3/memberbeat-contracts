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
    SubscriptionPlansRegistry,
    TokenPriceFeedRegistry,
    MemberBeatDataTypes
} from "src/MemberBeatSubscriptionManager.sol";
import {DeploySubscriptionManager} from "script/DeploySubscriptionManager.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.t.sol";
import {DateTime} from "@solidity-datetime/contracts/DateTime.sol";
import {Vm} from "forge-std/Vm.sol";

contract SubscriptionManagerIntegrationTest is Test, MemberBeatDataTypes, TestingUtils {
    DeploySubscriptionManager deployer;

    MemberBeatSubscriptionManager subscriptionManager;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    address[] tokens;
    address token1;
    address token2;

    BillingPlan[] fiatBillingPlans;
    uint256 START_TIMESTAMP = 1730101868;

    event SubscriptionDueForCharge(uint256 indexed subscriptionIndex);

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

        uint256 serviceProviderBalance = IERC20(token1).balanceOf(config.account);
        console.log("Service provider balance at startup", serviceProviderBalance);

        // Setting up the fiat price plans
        uint256[] memory emptyTokenPrices;

        ERC20Mock token1ERC20 = ERC20Mock(token1);
        token1ERC20.mint(RANDOM_USER, INITIAL_RANDOM_USER_BALANCE);

        ERC20Mock token2ERC20 = ERC20Mock(token2);
        token2ERC20.mint(RANDOM_USER, INITIAL_RANDOM_USER_BALANCE);

        Period[4] memory periods = [Period.Day, Period.Month, Period.Month, Period.Year];
        uint16[4] memory periodValues = [uint16(7), uint16(1), uint16(3), uint16(1)];
        uint256[4] memory fiatPrices = [uint256(0 ether), uint256(49 ether), uint256(129 ether), uint256(469 ether)];

        for (uint256 i = 0; i < periods.length; i++) {
            fiatBillingPlans.push(
                createBillingPlan(
                    periods[1], periodValues[i], PricingType.FiatPrice, tokens, emptyTokenPrices, fiatPrices[i]
                )
            );
        }
    }

    modifier addedFiatPlanData() {
        vm.startPrank(config.account);
        subscriptionManager.createPlan(PLAN_ID, PLAN_NAME, fiatBillingPlans);
        vm.stopPrank();
        _;
    }

    modifier addedFiatPlan2Data() {
        vm.startPrank(config.account);
        subscriptionManager.createPlan(PLAN_ID_2, PLAN_NAME_2, fiatBillingPlans);
        vm.stopPrank();
        _;
    }

    modifier approvesToken(address _user, address _token, uint8 _billingPlanIndex) {
        vm.startPrank(_user);

        BillingPlan memory fiatBillingPlan = fiatBillingPlans[_billingPlanIndex];
        uint256 tokenAmount = subscriptionManager.convertFiatToTokenAmount(_token, fiatBillingPlan.fiatPrice);
        uint256 allowance = tokenAmount * fiatBillingPlan.periodValue;

        IERC20 token = IERC20(_token);
        token.approve(address(subscriptionManager), allowance * 13);
        _;
    }

    modifier fiatSubscribes(address _user, address _token, uint256 _planId, uint8 _billingPlanIndex) {
        vm.recordLogs();
        vm.startPrank(_user);
        subscriptionManager.subscribe(_planId, _billingPlanIndex, _token, block.timestamp);
        vm.stopPrank();
        _;
    }

    modifier fiatSubscribesPending(
        address _user,
        address _token,
        uint256 _planId,
        uint8 _billingPlanIndex,
        uint256 _pendingDays
    ) {
        vm.startPrank(_user);
        subscriptionManager.subscribe(
            PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, _token, DateTime.addDays(block.timestamp, _pendingDays)
        );
        vm.stopPrank();
        _;
    }

    function testSubscribeRevertsIfPlanIsInvalid() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__InvalidSubscriptionData.selector);
        subscriptionManager.subscribe(INVALID_PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, tokens[0], block.timestamp);
    }

    function testSubscribeRevertsIfTokenIsInvalid() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__InvalidSubscriptionData.selector);
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, INVALID_TOKEN, block.timestamp);
    }

    function testSubscribeRevertsIfUserAlreadySubscribed()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__AlreadySubscribed.selector,
                RANDOM_USER,
                PLAN_ID
            )
        );
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, tokens[0], block.timestamp);
    }

    function testSubscribeRevertsIfPlanNotFound() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__PlanNotFound.selector, RANDOM_PLAN_ID
            )
        );
        subscriptionManager.subscribe(RANDOM_PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, tokens[0], block.timestamp);
    }

    function testSubscribeRevertsIfBillingPlanNotFound() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionPlansRegistry.SubscriptionPlansRegistry__BillingPlanNotFound.selector,
                PLAN_ID,
                INVALID_BILLING_PLAN_INDEX
            )
        );
        subscriptionManager.subscribe(PLAN_ID, INVALID_BILLING_PLAN_INDEX, tokens[0], block.timestamp);
    }

    function testSubscribeRevertsIfTokenNotAllowed() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__TokenNotAllowed.selector, RANDOM_TOKEN
            )
        );
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, RANDOM_TOKEN, block.timestamp);
    }

    function testSubscribeRevertsIfTokenAmountCalculationFailed() public addedFiatPlanData {
        MockV3Aggregator priceFeed = MockV3Aggregator(config.priceFeeds[0]);
        priceFeed.updateAnswer(0);

        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__TokenAmountCalculationFailed.selector,
                PLAN_ID,
                RANDOM_USER,
                token1
            )
        );
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, token1, block.timestamp);
    }

    function testSubscribeRevertsIfAllowanceIsTooLow() public addedFiatPlanData {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__AllowanceTooLow.selector, RANDOM_USER
            )
        );
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, token1, block.timestamp);
    }

    function testSubscribeRevertsIfUserHasNotEnoughBalance() public addedFiatPlanData {
        vm.startPrank(POOR_USER);

        BillingPlan memory fiatBillingPlan = fiatBillingPlans[ONE_MONTH_BILLING_PLAN_INDEX];
        uint256 tokenAmount = subscriptionManager.convertFiatToTokenAmount(token1, fiatBillingPlan.fiatPrice);
        uint256 allowance = tokenAmount * fiatBillingPlan.periodValue;

        IERC20 token = IERC20(token1);
        token.approve(address(subscriptionManager), allowance);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, POOR_USER, 0, allowance));
        subscriptionManager.subscribe(PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, token1, block.timestamp);
        vm.stopPrank();
    }

    function testSubscribeCreatesASubscription()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        Subscription memory subscriptionCreated = subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID);
        assertEq(subscriptionCreated.account, RANDOM_USER);
        assertEq(subscriptionCreated.planId, PLAN_ID);
        assertEq(subscriptionCreated.token, token1);
        assert(subscriptionCreated.startTimestamp == block.timestamp);
        uint256 actualNextChargeTimestamp = subscriptionCreated.nextChargeTimestamp;
        uint256 expectedNextChargeTimestamp = DateTime.addMonths(
            subscriptionCreated.startTimestamp, fiatBillingPlans[ONE_MONTH_BILLING_PLAN_INDEX].periodValue
        );
        assert(actualNextChargeTimestamp == expectedNextChargeTimestamp);
        assert(subscriptionCreated.status == Status.Active);

        BillingPlan memory fiatBillingPlan = fiatBillingPlans[ONE_MONTH_BILLING_PLAN_INDEX];
        BillingPlan memory billingPlan = subscriptionCreated.billingPlan;
        assert(billingPlan.period == fiatBillingPlan.period);
        assert(billingPlan.periodValue == fiatBillingPlan.periodValue);
        assert(billingPlan.pricingType == fiatBillingPlan.pricingType);
        assert(billingPlan.tokenAddresses.length == fiatBillingPlan.tokenAddresses.length);
        assert(billingPlan.tokenPrices.length == fiatBillingPlan.tokenPrices.length);
        assert(billingPlan.fiatPrice == fiatBillingPlan.fiatPrice);

        uint256 tokenAmountSpent =
            subscriptionManager.convertFiatToTokenAmount(subscriptionCreated.token, billingPlan.fiatPrice);

        IERC20 token = IERC20(token1);
        uint256 expectedUserBalance = INITIAL_RANDOM_USER_BALANCE - tokenAmountSpent;
        uint256 actualUserBalance = token.balanceOf(RANDOM_USER);
        assertEq(expectedUserBalance, actualUserBalance);

        uint256 serviceProviderFee = subscriptionManager.calculateServiceProviderFee(tokenAmountSpent);
        uint256 expectedSubscriptionManagerBalance = tokenAmountSpent - serviceProviderFee;
        uint256 actualSubscriptionManagerBalance = token.balanceOf(address(subscriptionManager));
        assertEq(expectedSubscriptionManagerBalance, actualSubscriptionManagerBalance);

        uint256 expectedServiceProviderBalance = serviceProviderFee;
        uint256 actualServiceProviderBalance = token.balanceOf(address(config.serviceProvider));
        assertEq(expectedServiceProviderBalance, actualServiceProviderBalance);

        vm.prank(RANDOM_USER);
        Subscription[] memory createdSubscriptions = subscriptionManager.getSubscriptions();
        assertEq(createdSubscriptions.length, 1);
    }

    function testSubscribeCreatesAPendingSubscription()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribesPending(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX, SUBSCRIBE_PENDING_DAYS)
    {
        Subscription memory subscriptionCreated = subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID);
        assertEq(subscriptionCreated.account, RANDOM_USER);
        assertEq(subscriptionCreated.planId, PLAN_ID);
        assertEq(subscriptionCreated.token, token1);
        uint256 startTimestamp = DateTime.addDays(block.timestamp, SUBSCRIBE_PENDING_DAYS);
        assert(subscriptionCreated.startTimestamp == startTimestamp);
        assert(subscriptionCreated.nextChargeTimestamp == startTimestamp);
        assert(subscriptionCreated.status == Status.Pending);

        BillingPlan memory fiatBillingPlan = fiatBillingPlans[ONE_MONTH_BILLING_PLAN_INDEX];
        BillingPlan memory billingPlan = subscriptionCreated.billingPlan;
        assert(billingPlan.period == fiatBillingPlan.period);
        assert(billingPlan.periodValue == fiatBillingPlan.periodValue);
        assert(billingPlan.pricingType == fiatBillingPlan.pricingType);
        assert(billingPlan.tokenAddresses.length == fiatBillingPlan.tokenAddresses.length);
        assert(billingPlan.tokenPrices.length == fiatBillingPlan.tokenPrices.length);
        assert(billingPlan.fiatPrice == fiatBillingPlan.fiatPrice);

        IERC20 token = IERC20(token1);
        uint256 expectedUserBalance = INITIAL_RANDOM_USER_BALANCE;
        uint256 actualUserBalance = token.balanceOf(RANDOM_USER);
        assertEq(expectedUserBalance, actualUserBalance);

        uint256 expectedSubscriptionManagerBalance = 0;
        uint256 actualSubscriptionManagerBalance = token.balanceOf(address(subscriptionManager));
        assertEq(expectedSubscriptionManagerBalance, actualSubscriptionManagerBalance);
    }

    function testSubscribeEmitsSubscriptionChargedEvent()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory subscriptionChargedEvent, bool found) =
            findEvent(entries, "SubscriptionCharged(address,uint256,address,uint256)");
        assert(found);

        address account = address(uint160(uint256(subscriptionChargedEvent.topics[1])));
        uint16 billingCycle = uint16(uint256(subscriptionChargedEvent.topics[2]));
        address token = address(uint160(uint256(subscriptionChargedEvent.topics[3])));

        assertEq(account, RANDOM_USER);
        assertEq(billingCycle, 1);
        assertEq(token, token1);
    }

    function testSubscribeEmitsSubscriptionCreatedEvent()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory subscriptionCreatedEvent, bool found) = findEvent(
            entries, "SubscriptionCreated(address,address,uint256,(uint8,uint16,uint8,address[],uint256[],uint256))"
        );
        assert(found);

        address account = address(uint160(uint256(subscriptionCreatedEvent.topics[1])));
        address token = address(uint160(uint256(subscriptionCreatedEvent.topics[2])));
        uint256 planId = uint256(subscriptionCreatedEvent.topics[3]);

        assertEq(account, RANDOM_USER);
        assertEq(token, token1);
        assertEq(planId, PLAN_ID);
    }

    function testGetSubscribeRevertsIfUserNotSubscribed()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__NotSubscribed.selector,
                POOR_USER,
                ONE_MONTH_BILLING_PLAN_INDEX
            )
        );
        subscriptionManager.getUserSubscription(POOR_USER, ONE_MONTH_BILLING_PLAN_INDEX);
    }

    /**
     *
     * Unsubscribe tests
     *
     */
    function testUnsubscribeRevertsIfUserNotSubscribed() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__NotSubscribed.selector,
                RANDOM_USER,
                PLAN_ID
            )
        );
        subscriptionManager.unsubscribe(PLAN_ID);
    }

    function testUnsubscribeRemovesSubscription()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(RANDOM_USER);
        subscriptionManager.unsubscribe(PLAN_ID);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__NotSubscribed.selector,
                RANDOM_USER,
                PLAN_ID
            )
        );
        subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID);

        vm.prank(RANDOM_USER);
        Subscription[] memory createdSubscriptions = subscriptionManager.getSubscriptions();
        assertEq(createdSubscriptions.length, 0);
    }

    function testUnsubscribeEmitsSubscriptionCancelledEvent()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(RANDOM_USER);
        subscriptionManager.unsubscribe(PLAN_ID);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory subscriptionCancelledEvent, bool found) =
            findEvent(entries, "SubscriptionCancelled(address,uint256)");
        assert(found);

        address account = address(uint160(uint256(subscriptionCancelledEvent.topics[1])));
        uint256 planId = uint256(subscriptionCancelledEvent.topics[2]);

        assertEq(account, RANDOM_USER);
        assertEq(planId, PLAN_ID);
    }

    function testUnsubscribeRemovesOneSubscriptionButKeepsAnotherOne()
        public
        addedFiatPlanData
        addedFiatPlan2Data
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        approvesToken(RANDOM_USER, token2, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token2, PLAN_ID_2, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(RANDOM_USER);
        Subscription[] memory createdSubscriptions = subscriptionManager.getSubscriptions();
        assertEq(createdSubscriptions.length, 2);

        vm.prank(RANDOM_USER);
        subscriptionManager.unsubscribe(PLAN_ID);
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__NotSubscribed.selector,
                RANDOM_USER,
                PLAN_ID
            )
        );
        subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID);

        Subscription memory subscription2 = subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID_2);
        assertEq(subscription2.planId, PLAN_ID_2);

        vm.prank(RANDOM_USER);
        createdSubscriptions = subscriptionManager.getSubscriptions();
        assertEq(createdSubscriptions.length, 1);
    }

    function testProcessDueSubscriptionsEmitsSubscriptionChargedEvent()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.warp(DateTime.addMonths(block.timestamp, 1) + 1);

        uint256 expectedSubscriptionIndex = 0;

        vm.startPrank(config.account);
        vm.expectEmit(true, false, false, false, address(subscriptionManager));
        emit SubscriptionDueForCharge(expectedSubscriptionIndex);
        subscriptionManager.processDueSubscriptions();

        vm.stopPrank();
    }

    function testProcessDueSubscriptionsFor12MonthsEmitsSubscriptionChargedEvent()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        uint256 expectedSubscriptionIndex = 0;

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (Vm.Log memory subscriptionChargedEvent, bool found) =
            findEvent(entries, "SubscriptionCharged(address,uint256,address,uint256)");
        assert(found);

        uint256 tokenAmount = abi.decode(subscriptionChargedEvent.data, (uint256));

        vm.startPrank(config.account);

        // initially take the amount and fee from the first subscription
        uint256 totalTokenAmount = tokenAmount;
        uint256 totalServiceProviderFee = subscriptionManager.calculateServiceProviderFee(tokenAmount);

        for (uint256 i = 1; i < 12; i++) {
            uint256 timestamp = DateTime.addMonths(block.timestamp, 1) + 1;
            console.log("Processing subscriptions at timestamp", timestamp);
            vm.warp(timestamp);

            vm.expectEmit(true, false, false, false, address(subscriptionManager));
            emit SubscriptionDueForCharge(expectedSubscriptionIndex);
            subscriptionManager.processDueSubscriptions();

            subscriptionManager.handleSubscriptionCharge(expectedSubscriptionIndex);
            entries = vm.getRecordedLogs();
            (subscriptionChargedEvent, found) =
                findEvent(entries, "SubscriptionCharged(address,uint256,address,uint256)");
            assert(found);

            tokenAmount = abi.decode(subscriptionChargedEvent.data, (uint256));
            totalTokenAmount += tokenAmount;
            totalServiceProviderFee += subscriptionManager.calculateServiceProviderFee(tokenAmount);
        }

        vm.stopPrank();

        console.log("Total token amount", totalTokenAmount);
        console.log("Total service provider fee", totalServiceProviderFee);

        uint256 serviceProviderBalance = IERC20(token1).balanceOf(config.serviceProvider);
        console.log("Service provider balance", serviceProviderBalance);
        assertEq(serviceProviderBalance, totalServiceProviderFee);

        uint256 ownerBalance = IERC20(token1).balanceOf(address(subscriptionManager));
        console.log("Owner balance", ownerBalance);
        assertEq(ownerBalance, totalTokenAmount - totalServiceProviderFee);
    }

    function testGetNextChargeTimestampAddOneDayToDailyBillingPlan()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(config.account);
        Subscription memory subscription = subscriptionManager.getSubscriptionAtIndex(0);

        uint256 actualTimestamp = subscriptionManager.getNextChargeTimestamp(subscription);

        uint256 referentTimestamp =
            subscription.nextChargeTimestamp > 0 ? subscription.nextChargeTimestamp : subscription.startTimestamp;
        uint256 expectedTimestamp = DateTime.addMonths(referentTimestamp, 1);
        assertEq(actualTimestamp, expectedTimestamp);
    }

    function testGetSubscriptionAtIndexRevertsIfNotOwner() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.getSubscriptionAtIndex(0);
    }

    function testGetSubscriptionAtIndexRevertsIfNotFound() public {
        vm.prank(config.account);
        uint256 index = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__SubscriptionNotFound.selector, index
            )
        );
        subscriptionManager.getSubscriptionAtIndex(index);
    }

    function testGetSubscriptionAtIndexReturnsASubscription()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        vm.prank(config.account);
        uint256 index = 0;
        Subscription memory subscription = subscriptionManager.getSubscriptionAtIndex(index);
        assertEq(subscription.account, RANDOM_USER);
        assertEq(subscription.planId, PLAN_ID);
    }

    function testHandleSubscriptionChargeRevertsIfNotAuthorized() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.handleSubscriptionCharge(0);
    }

    function testHandleSubscriptionChargeRevertsIfSubscriptionNotFound() public {
        vm.prank(config.account);
        uint256 index = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                MemberBeatSubscriptionManager.MemberBeatSubscriptionManager__SubscriptionNotFound.selector, index
            )
        );
        subscriptionManager.handleSubscriptionCharge(index);
    }

    // Free trial tests
    function testSubscribeFreeTrialCreatesASubscription()
        public
        addedFiatPlanData
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, FREE_TRIAL_BILLING_PLAN_INDEX)
    {
        Subscription memory subscriptionCreated = subscriptionManager.getUserSubscription(RANDOM_USER, PLAN_ID);
        assertEq(subscriptionCreated.account, RANDOM_USER);
        assertEq(subscriptionCreated.planId, PLAN_ID);
        assertEq(subscriptionCreated.token, token1);
        assertEq(subscriptionCreated.startTimestamp, block.timestamp);
        uint256 actualNextChargeTimestamp = subscriptionCreated.nextChargeTimestamp;
        uint256 expectedNextChargeTimestamp = DateTime.addMonths(
            subscriptionCreated.startTimestamp, fiatBillingPlans[FREE_TRIAL_BILLING_PLAN_INDEX].periodValue
        );
        assertEq(actualNextChargeTimestamp, expectedNextChargeTimestamp);
        assertEq(uint256(subscriptionCreated.status), uint256(Status.Active));

        BillingPlan memory fiatBillingPlan = fiatBillingPlans[FREE_TRIAL_BILLING_PLAN_INDEX];
        BillingPlan memory billingPlan = subscriptionCreated.billingPlan;
        assert(billingPlan.period == fiatBillingPlan.period);
        assert(billingPlan.periodValue == fiatBillingPlan.periodValue);
        assert(billingPlan.pricingType == fiatBillingPlan.pricingType);
        assert(billingPlan.tokenAddresses.length == fiatBillingPlan.tokenAddresses.length);
        assert(billingPlan.tokenPrices.length == fiatBillingPlan.tokenPrices.length);
        assert(billingPlan.fiatPrice == fiatBillingPlan.fiatPrice);

        uint256 tokenAmountSpent =
            subscriptionManager.convertFiatToTokenAmount(subscriptionCreated.token, billingPlan.fiatPrice);

        IERC20 token = IERC20(token1);
        uint256 expectedUserBalance = INITIAL_RANDOM_USER_BALANCE - tokenAmountSpent;
        uint256 actualUserBalance = token.balanceOf(RANDOM_USER);
        assertEq(expectedUserBalance, actualUserBalance);

        uint256 expectedSubscriptionManagerBalance = tokenAmountSpent;
        uint256 actualSubscriptionManagerBalance = token.balanceOf(address(subscriptionManager));
        assertEq(expectedSubscriptionManagerBalance, actualSubscriptionManagerBalance);
    }

    // Conversions test
    function testConvertFiatToTokenAmountRevertsIfTokenNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, RANDOM_TOKEN
            )
        );
        uint256 fiatAmount = 39.99 ether;
        subscriptionManager.convertFiatToTokenAmount(RANDOM_TOKEN, fiatAmount);
    }

    function testConvertFiatToTokenAmountCalculatesCorrectAmount() public view {
        uint256 fiatAmount = 39.99 ether;
        uint256 actualTokenAmount = subscriptionManager.convertFiatToTokenAmount(token1, fiatAmount);
        uint256 expectedTokenAmount = fiatAmount * 1e18 / (ETH_FIAT_PRICE * 1e10);
        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    function testGetSubscriptionsReturnsEmptyArray() public {
        vm.prank(RANDOM_USER);
        Subscription[] memory subscriptions = subscriptionManager.getSubscriptions();
        assertEq(subscriptions.length, 0);
    }

    function testOwnerCanClaimChargedTokens()
        public
        addedFiatPlanData
        approvesToken(RANDOM_USER, token1, ONE_MONTH_BILLING_PLAN_INDEX)
        fiatSubscribes(RANDOM_USER, token1, PLAN_ID, ONE_MONTH_BILLING_PLAN_INDEX)
    {
        uint256 expectedBalance = IERC20(token1).balanceOf(address(subscriptionManager));

        vm.startPrank(config.account);
        subscriptionManager.claimTokens();
        vm.stopPrank();

        uint256 actualBalance = IERC20(token1).balanceOf(config.account);
        assertEq(actualBalance, expectedBalance);
    }
}
