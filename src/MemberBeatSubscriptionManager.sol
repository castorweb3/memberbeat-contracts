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

import {IMemberBeatSubscriptionManager} from "./IMemberBeatSubscriptionManager.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MemberBeatDataTypes} from "src/common/MemberBeatDataTypes.sol";
import {SubscriptionPlansRegistry} from "src/registry/SubscriptionPlansRegistry.sol";
import {TokenPriceFeedRegistry} from "src/registry/TokenPriceFeedRegistry.sol";
import {DateTime} from "@solidity-datetime/contracts/DateTime.sol";

/**
 * @title MemberBeatSubscriptionManager
 * @notice Manages subscriptions, including creation, charging, and cancellation of subscriptions.
 * @dev This contract integrates with SubscriptionPlansRegistry and TokenPriceFeedRegistry to handle subscription plans and token price feeds. It includes functionality for subscribing, unsubscribing, creating, updating, and deleting plans, as well as charging subscriptions.
 * @dev Utilizes the SafeERC20 library for safe token transfers.
 */
contract MemberBeatSubscriptionManager is IMemberBeatSubscriptionManager, Ownable {
    using SafeERC20 for IERC20;

    // Stores the next subscription index
    // @dev This serves as an auto-increment ID for new subscriptions
    uint256 private s_nextSubscriptionIndex;

    // Mapping of subscription index to Subscription struct
    mapping(uint256 => Subscription) s_subscriptions; // nextSubscriptionIndex => Subscription

    // Mapping of user account to another mapping of plan ID to subscription index
    mapping(address => mapping(uint256 => uint256)) private s_userSubscriptionsByPlanId; // user account => planId => subscription index

    // Mapping of user account to an array of subscription indexes
    mapping(address => uint256[]) private s_userSubscriptionsIndexes; // user account => subscription index

    // Mapping of charge day to an array of subscription indexes
    mapping(uint256 => uint256[]) private s_subscriptionsByChargeDay; // day => subscription index

    // Array to store addresses of tokens that have been charged
    // @dev This allows the owner to transfer token balances to their wallet
    // @dev The array is reset after the balances are transferred
    address[] private s_chargedTokenAddresses;

    // Reference to the SubscriptionPlansRegistry contract
    SubscriptionPlansRegistry private immutable i_subscriptionPlansRegistry;

    // Reference to the TokenPriceFeedRegistry contract
    TokenPriceFeedRegistry private immutable i_tokenPriceFeedRegistry;

    // Address of the service provider
    address private immutable i_serviceProvider;

    // Fee charged by the service provider
    int256 private immutable i_serviceProviderFee;

    // Factor for calculating the service provider fee
    uint256 public constant SERVICE_PROVIDER_FEE_FACTOR = 1e18;

    event SubscriptionCreated(
        address indexed account, address indexed token, uint256 indexed planId, BillingPlan billingPlan
    );
    event SubscriptionCharged(
        address indexed account, uint256 indexed billingCycle, address indexed token, uint256 tokenAmount
    );
    event SubscriptionCancelled(address indexed account, uint256 indexed planId);
    event SubscriptionDueForCharge(uint256 indexed subscriptionIndex);

    error MemberBeatSubscriptionManager__InvalidServiceProviderAddress();
    error MemberBeatSubscriptionManager__InvalidSubscriptionData();
    error MemberBeatSubscriptionManager__AlreadySubscribed(address account, uint256 planId);
    error MemberBeatSubscriptionManager__NotSubscribed(address account, uint256 planId);
    error MemberBeatSubscriptionManager__TokenNotAllowed(address token);
    error MemberBeatSubscriptionManager__TokenAmountCalculationFailed(uint256 planId, address account, address token);
    error MemberBeatSubscriptionManager__AllowanceTooLow(address account);
    error MemberBeatSubscriptionManager__TokenApprovalFailed(address account, address token);
    error MemberBeatSubscriptionManager__TokenFeeTransferFailed(address account, address token, uint256 fee);
    error MemberBeatSubscriptionManager__InvalidBillingPeriod(uint256 period);
    error MemberBeatSubscriptionManager__SubscriptionNotDue(uint256 subscriptionIndex);
    error MemberBeatSubscriptionManager__SubscriptionNotFound(uint256 subscriptionIndex);

    modifier onlyAuthorized() {
        _checkOwner();
        _;
    }

    constructor(address _serviceProvider, int256 _serviceProviderFee) Ownable(msg.sender) {
        if (_serviceProvider == address(0)) {
            revert MemberBeatSubscriptionManager__InvalidServiceProviderAddress();
        }

        i_subscriptionPlansRegistry = new SubscriptionPlansRegistry();
        i_tokenPriceFeedRegistry = new TokenPriceFeedRegistry();
        i_serviceProvider = _serviceProvider;
        i_serviceProviderFee = _serviceProviderFee;
    }

    /**
     * @notice Subscribes a user to a plan.
     * @param _planId The ID of the plan to subscribe to.
     * @param _billingPlanIndex The index of the billing plan within the selected plan.
     * @param _token The address of the token to be used for the subscription.
     * @param _startTimestamp The start timestamp for the subscription.
     * @return Returns the subscription details and the spent token amount.
     */
    function subscribe(uint256 _planId, uint8 _billingPlanIndex, address _token, uint256 _startTimestamp)
        public
        returns (Subscription memory, uint256)
    {
        if (_planId == 0 || _token == address(0)) {
            revert MemberBeatSubscriptionManager__InvalidSubscriptionData();
        }

        uint256 existingSubscriptionIndex = s_userSubscriptionsByPlanId[msg.sender][_planId];
        if (s_subscriptions[existingSubscriptionIndex].planId == _planId) {
            revert MemberBeatSubscriptionManager__AlreadySubscribed(msg.sender, _planId);
        }

        BillingPlan memory billingPlan = i_subscriptionPlansRegistry.getBillingPlan(_planId, _billingPlanIndex);
        Status status = _startTimestamp > block.timestamp ? Status.Pending : Status.Active;
        uint256 nextChargeTimestamp = status == Status.Pending ? _startTimestamp : 0;

        Subscription memory subscription = Subscription({
            account: msg.sender,
            planId: _planId,
            token: _token,
            startTimestamp: _startTimestamp,
            nextChargeTimestamp: nextChargeTimestamp,
            status: status,
            billingCycle: 0,
            billingPlan: billingPlan
        });

        uint256 newIndex = s_nextSubscriptionIndex;
        s_nextSubscriptionIndex++;

        s_subscriptions[newIndex] = subscription;
        s_userSubscriptionsByPlanId[msg.sender][_planId] = newIndex;
        s_userSubscriptionsIndexes[msg.sender].push(newIndex);

        emit SubscriptionCreated(msg.sender, _token, _planId, billingPlan);

        uint256 tokenAmount = 0;
        if (status == Status.Active) {
            tokenAmount = chargeSubscription(newIndex, subscription);
        } else {
            scheduleSubscription(newIndex, subscription);
        }

        return (subscription, tokenAmount);
    }

    /**
     * @notice Unsubscribes a user from a plan.
     * @param _planId The ID of the plan to unsubscribe from.
     */
    function unsubscribe(uint256 _planId) external {
        _unsubscribe(msg.sender, _planId);
    }

    /**
     * @notice Creates a new plan.
     * @param _planId The ID of the new plan.
     * @param _planName The name of the new plan.
     * @param _billingPlans The billing plans associated with the new plan.
     */
    function createPlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans)
        external
        onlyOwner
    {
        i_subscriptionPlansRegistry.createPlan(_planId, _planName, _billingPlans);
    }

    /**
     * @notice Updates an existing plan.
     * @param _planId The ID of the plan to update.
     * @param _planName The updated name of the plan.
     * @param _billingPlans The updated billing plans associated with the plan.
     */
    function updatePlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans)
        external
        onlyOwner
    {
        i_subscriptionPlansRegistry.updatePlan(_planId, _planName, _billingPlans);
    }

    /**
     * @notice Deletes an existing plan.
     * @param _planId The ID of the plan to delete.
     */
    function deletePlan(uint256 _planId) external onlyOwner {
        i_subscriptionPlansRegistry.deletePlan(_planId);
    }

    /**
     * @notice Retrieves a plan by its ID.
     * @param _planId The ID of the plan to retrieve.
     * @return Returns the plan details.
     */
    function getPlan(uint256 _planId) external view returns (Plan memory) {
        return i_subscriptionPlansRegistry.getPlan(_planId);
    }

    /**
     * @notice Retrieves all plans.
     * @return Returns an array of all plans.
     */
    function getPlans() external view returns (Plan[] memory) {
        return i_subscriptionPlansRegistry.getPlans();
    }

    /**
     * @notice Adds a billing plan to an existing plan.
     * @param _planId The ID of the plan to add the billing plan to.
     * @param _billingPlan The billing plan to add.
     */
    function addBillingPlan(uint256 _planId, BillingPlan memory _billingPlan) external onlyOwner {
        i_subscriptionPlansRegistry.addBillingPlan(_planId, _billingPlan);
    }

    /**
     * @notice Updates a billing plan within an existing plan.
     * @param _planId The ID of the plan containing the billing plan to update.
     * @param _billingPlanIndex The index of the billing plan within the plan.
     * @param _billingPlan The updated billing plan details.
     */
    function updateBillingPlan(uint256 _planId, uint8 _billingPlanIndex, BillingPlan memory _billingPlan)
        external
        onlyOwner
    {
        i_subscriptionPlansRegistry.updateBillingPlan(_planId, _billingPlanIndex, _billingPlan);
    }

    /**
     * @notice Removes a billing plan from an existing plan.
     * @param _planId The ID of the plan containing the billing plan to remove.
     * @param _billingPlanIndex The index of the billing plan within the plan.
     */
    function removeBillingPlan(uint256 _planId, uint8 _billingPlanIndex) external onlyOwner {
        i_subscriptionPlansRegistry.removeBillingPlan(_planId, _billingPlanIndex);
    }

    /**
     * @notice Transfers the balances of all charged tokens from the contract to the owner's wallet.
     * @dev This function retrieves the list of charged token addresses, transfers their balances to the owner's address, and then resets the list of charged token addresses.
     * @dev This function can only be called by the contract owner.
     * @dev Since this function is for the owner only, and the tokens are in our control, it is safe to loop and transfer.
     */
    function claimTokens() external onlyOwner {
        address[] memory tokens = s_chargedTokenAddresses;
        uint256 tokensCount = tokens.length;
        for (uint256 i = 0; i < tokensCount; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            token.safeTransfer(owner(), balance);
        }
        delete s_chargedTokenAddresses;
    }

    /**
     * @notice Retrieves a specific billing plan from the subscription plans registry.
     * @param _planId The ID of the subscription plan.
     * @param _billingPlanIdex The index of the billing plan within the subscription plan.
     * @return BillingPlan struct containing details of the requested billing plan.
     */
    function getBillingPlan(uint256 _planId, uint8 _billingPlanIdex) public view returns (BillingPlan memory) {
        return i_subscriptionPlansRegistry.getBillingPlan(_planId, _billingPlanIdex);
    }

    /**
     * @notice Adds a price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _priceFeedAddress The address of the price feed.
     */
    function addTokenPriceFeed(address _tokenAddress, address _priceFeedAddress) external onlyOwner {
        i_tokenPriceFeedRegistry.addTokenPriceFeed(_tokenAddress, _priceFeedAddress);
    }

    /**
     * @notice Updates the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _newPriceFeedAddress The new address of the price feed.
     */
    function updateTokenPriceFeed(address _tokenAddress, address _newPriceFeedAddress) external onlyOwner {
        i_tokenPriceFeedRegistry.updateTokenPriceFeed(_tokenAddress, _newPriceFeedAddress);
    }

    /**
     * @notice Retrieves the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @return Returns the address of the price feed.
     */
    function getTokenPriceFeed(address _tokenAddress) external view returns (address) {
        return i_tokenPriceFeedRegistry.getTokenPriceFeed(_tokenAddress);
    }

    /**
     * @notice Checks if a token is registered.
     * @param _tokenAddress The address of the token.
     * @return Returns true if the token is registered, otherwise false.
     */
    function isTokenRegistered(address _tokenAddress) external view returns (bool) {
        return i_tokenPriceFeedRegistry.isTokenRegistered(_tokenAddress);
    }

    /**
     * @notice Retrieves all registered tokens.
     * @return Returns an array of addresses of all registered tokens.
     */
    function getRegisteredTokens() external view returns (address[] memory) {
        return i_tokenPriceFeedRegistry.getRegisteredTokens();
    }

    /**
     * @notice Retrieves all subscriptions.
     * @return Returns an array of all subscriptions.
     */
    function getSubscriptions() external view returns (Subscription[] memory) {
        uint256[] memory indexes = s_userSubscriptionsIndexes[msg.sender];
        uint256 totalSubscriptions = indexes.length;
        Subscription[] memory subscriptions = new Subscription[](totalSubscriptions);
        for (uint256 i = 0; i < totalSubscriptions; i++) {
            subscriptions[i] = s_subscriptions[indexes[i]];
        }
        return subscriptions;
    }

    /**
     * @notice Retrieves a user's subscription for a specific plan.
     * @param _account The address of the user.
     * @param _planId The ID of the plan.
     * @return Returns the user's subscription details for the specified plan.
     */
    function getUserSubscription(address _account, uint256 _planId) external view returns (Subscription memory) {
        (Subscription memory subscription,) = getUserSubscriptionWithIndex(_account, _planId);
        if (subscription.account == address(0) || subscription.account != _account) {
            revert MemberBeatSubscriptionManager__NotSubscribed(_account, _planId);
        }
        return subscription;
    }

    /**
     * @notice Checks if the caller is the owner of the contract.
     * @return Returns true if the caller is the owner, otherwise false.
     */
    function isOwner() external view returns (bool) {
        return msg.sender == owner();
    }

    /**
     * @notice Processes subscriptions that are due for charge.
     * @dev This function checks each subscription scheduled for today and emits an event if the subscription is due for a charge.
     */
    function processDueSubscriptions() external onlyAuthorized {
        uint256 currentDay = block.timestamp / 1 days * 1 days;
        uint256[] storage subscriptionIndexes = s_subscriptionsByChargeDay[currentDay];
        for (uint256 j = 0; j < subscriptionIndexes.length; j++) {
            uint256 subscriptionIndex = subscriptionIndexes[j];
            Subscription storage subscription = s_subscriptions[subscriptionIndex];
            if (
                (subscription.status == Status.Active || subscription.status == Status.Pending)
                    && subscription.nextChargeTimestamp <= block.timestamp
            ) {
                emit SubscriptionDueForCharge(subscriptionIndex);
            }
        }
    }

    /**
     * @notice Handles the charge process for a specific subscription.
     * @dev This function checks if a subscription is due for charge and processes the charge if applicable.
     * @param subscriptionIndex The index of the subscription to be charged.
     */
    function handleSubscriptionCharge(uint256 subscriptionIndex) external onlyAuthorized {
        Subscription memory subscription = getSubscriptionAtIndex(subscriptionIndex);
        if (
            (subscription.status != Status.Active && subscription.status != Status.Pending)
                || subscription.nextChargeTimestamp > block.timestamp
        ) {
            revert MemberBeatSubscriptionManager__SubscriptionNotDue(subscriptionIndex);
        }

        chargeSubscription(subscriptionIndex, subscription);
    }

    /**
     * @notice Calculates the next charge timestamp for a given subscription.
     * @param subscription The subscription details for which the next charge timestamp is calculated.
     * @return The next charge timestamp for the subscription.
     */
    function getNextChargeTimestamp(Subscription memory subscription) public pure returns (uint256) {
        BillingPlan memory billingPlan = subscription.billingPlan;
        uint256 referentTimestamp =
            subscription.nextChargeTimestamp > 0 ? subscription.nextChargeTimestamp : subscription.startTimestamp;
        if (billingPlan.period == Period.Day) {
            return DateTime.addDays(referentTimestamp, billingPlan.periodValue);
        } else if (billingPlan.period == Period.Month) {
            return DateTime.addMonths(referentTimestamp, billingPlan.periodValue);
        } else if (billingPlan.period == Period.Year) {
            return DateTime.addYears(referentTimestamp, billingPlan.periodValue);
        }

        revert MemberBeatSubscriptionManager__InvalidBillingPeriod(uint256(billingPlan.period));
    }

    /**
     * @notice Calculates the service provider fee for a given amount.
     * @param amount The amount to calculate the fee for.
     * @return The calculated service provider fee.
     */
    function calculateServiceProviderFee(uint256 amount) public view returns (uint256) {
        uint256 scaledAmount = amount * uint256(i_serviceProviderFee);
        uint256 fee = (scaledAmount + SERVICE_PROVIDER_FEE_FACTOR - 1) / SERVICE_PROVIDER_FEE_FACTOR;
        return fee;
    }

    /**
     * @notice Converts a fiat amount to a token amount.
     * @param _tokenAddress The address of the token.
     * @param _fiatAmount The fiat amount to be converted.
     * @return The equivalent token amount.
     */
    function convertFiatToTokenAmount(address _tokenAddress, uint256 _fiatAmount) public view returns (uint256) {
        return i_tokenPriceFeedRegistry.convertFiatToTokenAmount(_tokenAddress, _fiatAmount);
    }

    /**
     * @notice Retrieves a subscription at a specific index.
     * @param _index The index of the subscription to retrieve.
     * @return The subscription details.
     * @dev This function can only be called by the owner.
     */
    function getSubscriptionAtIndex(uint256 _index) public view onlyOwner returns (Subscription memory) {
        Subscription storage subscription = s_subscriptions[_index];
        if (subscription.account == address(0)) {
            revert MemberBeatSubscriptionManager__SubscriptionNotFound(_index);
        }

        return subscription;
    }

    /**
     * @notice Retrieves the address of the service provider.
     * @return The address of the service provider.
     */
    function getServiceProvider() public view returns (address) {
        return i_serviceProvider;
    }

    /**
     * @notice Retrieves the service provider fee.
     * @return The service provider fee as an integer.
     */
    function getServiceProviderFee() public view returns (int256) {
        return i_serviceProviderFee;
    }

    /**
     * @notice Finds the index of a token in the billing plan.
     * @param _billingPlan The billing plan to search within.
     * @param _token The address of the token to find.
     * @return The index of the token in the billing plan.
     * @dev Reverts if the token is not allowed in the billing plan.
     */
    function findBillingPlanTokenIndex(BillingPlan memory _billingPlan, address _token)
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < _billingPlan.tokenAddresses.length; i++) {
            if (_billingPlan.tokenAddresses[i] == _token) {
                return i;
            }
        }
        revert MemberBeatSubscriptionManager__TokenNotAllowed(_token);
    }

    /**
     * @notice Schedules a subscription for the next charge.
     * @param subscriptionIndex The index of the subscription.
     * @param subscription The subscription details.
     */
    function scheduleSubscription(uint256 subscriptionIndex, Subscription memory subscription) private {
        if (subscription.nextChargeTimestamp > 0) {
            uint256 nextChargeTimestampDay = subscription.nextChargeTimestamp / 1 days * 1 days;
            s_subscriptionsByChargeDay[nextChargeTimestampDay].push(subscriptionIndex);
        }
    }

    /**
     * @notice Charges a subscription based on its index.
     * @dev This function processes the subscription charge, updates the next charge timestamp, and handles the transfer of tokens.
     * @param subscriptionIndex The index of the subscription to be charged.
     * @param subscription The subscription details.
     * @return tokenAmount The amount of tokens charged.
     */
    function chargeSubscription(uint256 subscriptionIndex, Subscription memory subscription)
        private
        returns (uint256 tokenAmount)
    {
        BillingPlan memory billingPlan = subscription.billingPlan;

        uint256 tokenIndex = findBillingPlanTokenIndex(billingPlan, subscription.token);

        tokenAmount = 0;
        if (billingPlan.pricingType == PricingType.TokenPrice) {
            tokenAmount = billingPlan.tokenPrices[tokenIndex];
        } else if (billingPlan.pricingType == PricingType.FiatPrice) {
            tokenAmount = i_tokenPriceFeedRegistry.convertFiatToTokenAmount(subscription.token, billingPlan.fiatPrice);

            if (billingPlan.fiatPrice > 0 && tokenAmount <= 0) {
                revert MemberBeatSubscriptionManager__TokenAmountCalculationFailed(
                    subscription.planId, subscription.account, subscription.token
                );
            }
        }

        subscription.nextChargeTimestamp = getNextChargeTimestamp(subscription);
        subscription.billingCycle++;
        s_subscriptions[subscriptionIndex] = subscription;

        scheduleSubscription(subscriptionIndex, subscription);

        if (tokenAmount > 0) {
            IERC20 token = IERC20(subscription.token);

            uint256 allowance = token.allowance(subscription.account, address(this));
            if (allowance < tokenAmount) {
                revert MemberBeatSubscriptionManager__AllowanceTooLow(subscription.account);
            }

            s_chargedTokenAddresses.push(subscription.token);

            emit SubscriptionCharged(subscription.account, subscription.billingCycle, subscription.token, tokenAmount);

            token.safeTransferFrom(subscription.account, address(this), tokenAmount);

            if (i_serviceProviderFee > 0) {
                uint256 serviceProviderFee = calculateServiceProviderFee(tokenAmount);
                bool success = token.approve(address(this), serviceProviderFee);
                if (!success) {
                    revert MemberBeatSubscriptionManager__TokenApprovalFailed(address(this), subscription.token);
                }
                token.safeTransferFrom(address(this), address(i_serviceProvider), serviceProviderFee);
            }
        }
    }

    /**
     * @notice Cancels a subscription for a specific account and plan ID.
     * @param _account The account associated with the subscription.
     * @param _planId The plan ID of the subscription to be cancelled.
     */
    function _unsubscribe(address _account, uint256 _planId) private {
        (, uint256 subscriptionIndex) = getUserSubscriptionWithIndex(_account, _planId);

        delete s_userSubscriptionsByPlanId[_account][_planId];
        delete s_subscriptions[subscriptionIndex];

        int256 index = -1;
        uint256[] storage subscriptionIndexes = s_userSubscriptionsIndexes[_account];
        for (uint256 i = 0; i < subscriptionIndexes.length; i++) {
            if (subscriptionIndexes[i] == subscriptionIndex) {
                index = int256(i);
                break;
            }
        }

        if (index > -1) {
            for (uint256 i = uint256(index); i < subscriptionIndexes.length - 1; i++) {
                subscriptionIndexes[i] = subscriptionIndexes[i + 1];
            }
            subscriptionIndexes.pop();
        }

        emit SubscriptionCancelled(_account, _planId);
    }

    /**
     * @notice Retrieves a user's subscription and its index for a specific plan ID.
     * @param _account The account associated with the subscription.
     * @param _planId The plan ID of the subscription.
     * @return subscription The subscription details.
     * @return index The index of the subscription.
     */
    function getUserSubscriptionWithIndex(address _account, uint256 _planId)
        private
        view
        returns (Subscription memory subscription, uint256 index)
    {
        index = s_userSubscriptionsByPlanId[_account][_planId];

        subscription = s_subscriptions[index];
        if (subscription.account != _account) {
            revert MemberBeatSubscriptionManager__NotSubscribed(_account, _planId);
        }
    }
}
