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

import {MemberBeatDataTypes} from "src/common/MemberBeatDataTypes.sol";

/**
 * @title IMemberBeatSubscriptionManager Interface
 * @notice Interface for managing MemberBeat subscriptions and plans.
 */
interface IMemberBeatSubscriptionManager is MemberBeatDataTypes {
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
    error MemberBeatSubscriptionManager__TokenBalanceZero(address token);

    event SubscriptionCreated(
        address indexed account, address indexed token, uint256 indexed planId, BillingPlan billingPlan
    );
    event SubscriptionCharged(
        address indexed account, uint256 indexed billingCycle, address indexed token, uint256 tokenAmount
    );
    event SubscriptionCancelled(address indexed account, uint256 indexed planId);
    event SubscriptionDueForCharge(uint256 indexed subscriptionIndex);
    event TokenBalanceClaimed(address indexed token, uint256 indexed balance);

    /**
     * @notice Subscribes a user to a plan.
     * @param _planId The ID of the plan to subscribe to.
     * @param _billingPlanIndex The index of the billing plan within the selected plan.
     * @param _token The address of the token to be used for the subscription.
     * @param _startTimestamp The start timestamp for the subscription.
     * @return Returns the subscription details and the spent token amount.
     */
    function subscribe(uint256 _planId, uint8 _billingPlanIndex, address _token, uint256 _startTimestamp)
        external
        returns (Subscription memory, uint256);

    /**
     * @notice Unsubscribes a user from a plan.
     * @param _planId The ID of the plan to unsubscribe from.
     */
    function unsubscribe(uint256 _planId) external;

    /**
     * @notice Creates a new plan.
     * @param _planId The ID of the new plan.
     * @param _planName The name of the new plan.
     * @param _billingPlans The billing plans associated with the new plan.
     */
    function createPlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans) external;

    /**
     * @notice Updates an existing plan.
     * @param _planId The ID of the plan to update.
     * @param _planName The updated name of the plan.
     * @param _billingPlans The updated billing plans associated with the plan.
     */
    function updatePlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans) external;

    /**
     * @notice Deletes an existing plan.
     * @param _planId The ID of the plan to delete.
     */
    function deletePlan(uint256 _planId) external;

    /**
     * @notice Retrieves a plan by its ID.
     * @param _planId The ID of the plan to retrieve.
     * @return Returns the plan details.
     */
    function getPlan(uint256 _planId) external view returns (Plan memory);

    /**
     * @notice Retrieves all plans.
     * @return Returns an array of all plans.
     */
    function getPlans() external view returns (Plan[] memory);

    /**
     * @notice Adds a billing plan to an existing plan.
     * @param _planId The ID of the plan to add the billing plan to.
     * @param _billingPlan The billing plan to add.
     */
    function addBillingPlan(uint256 _planId, BillingPlan memory _billingPlan) external;

    /**
     * @notice Updates a billing plan within an existing plan.
     * @param _planId The ID of the plan containing the billing plan to update.
     * @param _billingPlanIndex The index of the billing plan within the plan.
     * @param _billingPlan The updated billing plan details.
     */
    function updateBillingPlan(uint256 _planId, uint8 _billingPlanIndex, BillingPlan memory _billingPlan) external;

    /**
     * @notice Removes a billing plan from an existing plan.
     * @param _planId The ID of the plan containing the billing plan to remove.
     * @param _billingPlanIndex The index of the billing plan within the plan.
     */
    function removeBillingPlan(uint256 _planId, uint8 _billingPlanIndex) external;

    /**
     * @notice Retrieves the addresses of the tokens that are currently being charged.
     * @dev This function can be called externally to fetch the token addresses.
     * @return A list of addresses of the tokens that are being charged.
     */
    function getChargedTokenAddresses() external returns (address[] memory);

    /**
     * @notice Transfers the balance of the specified token from the contract to the owner's wallet.
     * @param _token The address of the token to be transferred and removed from the charged token addresses list.
     */
    function claimTokenBalance(address _token) external;

    /**
     * @notice Adds a price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _priceFeedAddress The address of the price feed.
     */
    function addTokenPriceFeed(address _tokenAddress, address _priceFeedAddress) external;

    /**
     * @notice Updates the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _newPriceFeedAddress The new address of the price feed.
     */
    function updateTokenPriceFeed(address _tokenAddress, address _newPriceFeedAddress) external;

    /**
     * @notice Removes the price feed address for a token.
     * @param _tokenAddress The address of the token.
     */
    function deleteTokenPriceFeed(address _tokenAddress) external;

    /**
     * @notice Checks if a token is registered.
     * @param _tokenAddress The address of the token.
     * @return Returns true if the token is registered, otherwise false.
     */
    function isTokenRegistered(address _tokenAddress) external view returns (bool);

    /**
     * @notice Retrieves all registered tokens.
     * @return Returns an array of addresses of all registered tokens.
     */
    function getRegisteredTokens() external view returns (address[] memory);

    /**
     * @notice Retrieves all subscriptions.
     * @return Returns an array of all subscriptions.
     */
    function getSubscriptions() external view returns (Subscription[] memory);

    /**
     * @notice Retrieves a user's subscription for a specific plan.
     * @param _account The address of the user.
     * @param _planId The ID of the plan.
     * @return Returns the user's subscription details for the specified plan.
     */
    function getUserSubscription(address _account, uint256 _planId) external view returns (Subscription memory);

    /**
     * @notice Checks if the caller is the owner of the contract.
     * @return Returns true if the caller is the owner, otherwise false.
     */
    function isOwner() external view returns (bool);
}
