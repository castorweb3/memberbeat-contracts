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
 * @title SubscriptionPlansRegistry
 * @notice Manages subscription plans and their associated billing plans.
 * @dev This contract allows for the creation, updating, and deletion of subscription plans and billing plans.
 */
contract SubscriptionPlansRegistry is MemberBeatDataTypes {
    mapping(uint256 => Plan) public s_plans;
    uint256[] public s_planIds;

    uint16 public constant MAX_DAYS = 365;
    uint16 public constant MAX_WEEKS = 53;
    uint16 public constant MAX_MONTHS = 12;
    uint16 public constant MAX_YEARS = 50;
    uint16 public constant LIFETIME = 1;

    event PlanCreated(uint256 indexed planId, string indexed planName);
    event PlanUpdated(uint256 indexed planId, string indexed planName);
    event PlanDeleted(uint256 indexed planId);
    event BillingPlanAdded(uint256 indexed planId, uint8 indexed billingPlanIndex);
    event BillingPlanUpdated(uint256 indexed planId, uint8 indexed billingPlanIndex);
    event BillingPlanRemoved(uint256 indexed planId, uint8 indexed billingPlanIndex);

    error SubscriptionPlansRegistry__PlanNotFound(uint256 planId);
    error SubscriptionPlansRegistry__PlanAlreadyRegistered(uint256 planId);
    error SubscriptionPlansRegistry__BillingPlanNotFound(uint256 planId, uint8 billingPlanIndex);

    error SubscriptionPlansRegistry__TokenPricesNotProvided(uint256 _planId);
    error SubscriptionPlansRegistry__TokenAddressesNotProvided(uint256 _planId);
    error SubscriptionPlansRegistry__TokenAddressesDontMatchTokenPrices(uint256 _planId);
    error SubscriptionPlansRegistry__PlanWithInvalidTokenAddress(uint256 planId, address token);
    error SubscriptionPlansRegistry__PlanWithInvalidTokenPrice(uint256 planId, address token);
    error SubscriptionPlansRegistry__PlanWithInvalidFiatPrice(uint256 planId, uint256 fiatPrice);
    error SubscriptionPlansRegistry__PlanWithInvalidPeriod(uint256 planId, Period period, uint16 periodValue);

    modifier validBillingPlan(uint256 _planId, BillingPlan memory _billingPlan) {
        if (_billingPlan.tokenAddresses.length == 0) {
            revert SubscriptionPlansRegistry__TokenAddressesNotProvided(_planId);
        }

        if (_billingPlan.pricingType == PricingType.TokenPrice) {
            if (_billingPlan.tokenPrices.length == 0) {
                revert SubscriptionPlansRegistry__TokenPricesNotProvided(_planId);
            } else if (_billingPlan.tokenAddresses.length != _billingPlan.tokenPrices.length) {
                revert SubscriptionPlansRegistry__TokenAddressesDontMatchTokenPrices(_planId);
            }

            for (uint256 i = 0; i < _billingPlan.tokenAddresses.length; i++) {
                if (_billingPlan.tokenAddresses[i] == address(0)) {
                    revert SubscriptionPlansRegistry__PlanWithInvalidTokenAddress(
                        _planId, _billingPlan.tokenAddresses[i]
                    );
                }
            }
        }

        if (
            _billingPlan.periodValue <= 0 || (_billingPlan.period == Period.Day && _billingPlan.periodValue > MAX_DAYS)
                || (_billingPlan.period == Period.Month && _billingPlan.periodValue > MAX_MONTHS)
                || (_billingPlan.period == Period.Year && _billingPlan.periodValue > MAX_YEARS)
                || (_billingPlan.period == Period.Lifetime && _billingPlan.periodValue > LIFETIME)
        ) {
            revert SubscriptionPlansRegistry__PlanWithInvalidPeriod(
                _planId, _billingPlan.period, _billingPlan.periodValue
            );
        }
        _;
    }

    /**
     * @notice Creates a new subscription plan.
     * @param _planId The ID of the plan to be created.
     * @param _planName The name of the plan to be created.
     * @param _billingPlans The billing plans associated with the plan.
     * @dev Reverts if the plan ID is already registered.
     */
    function createPlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans) public {
        if (s_plans[_planId].planId != 0) {
            revert SubscriptionPlansRegistry__PlanAlreadyRegistered(_planId);
        }

        Plan storage plan = s_plans[_planId];
        plan.planId = _planId;
        plan.planName = _planName;
        s_planIds.push(_planId);

        emit PlanCreated(_planId, _planName);

        for (uint256 i = 0; i < _billingPlans.length; i++) {
            addBillingPlan(_planId, _billingPlans[i]);
        }
    }

    /**
     * @notice Updates an existing subscription plan.
     * @param _planId The ID of the plan to be updated.
     * @param _planName The new name of the plan.
     * @param _billingPlans The new billing plans associated with the plan.
     * @dev Reverts if the plan ID is not found.
     */
    function updatePlan(uint256 _planId, string memory _planName, BillingPlan[] memory _billingPlans) public {
        if (s_plans[_planId].planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        Plan storage plan = s_plans[_planId];
        plan.planName = _planName;

        emit PlanUpdated(_planId, _planName);

        if (_billingPlans.length > 0) {
            delete plan.billingPlans;

            for (uint256 i = 0; i < _billingPlans.length; i++) {
                addBillingPlan(_planId, _billingPlans[i]);
            }
        }
    }

    /**
     * @notice Deletes an existing subscription plan.
     * @param _planId The ID of the plan to be deleted.
     * @dev Reverts if the plan ID is not found.
     */
    function deletePlan(uint256 _planId) public {
        if (s_plans[_planId].planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        delete s_plans[_planId];

        int256 index = -1;
        uint256 plansLength = s_planIds.length;
        for (uint256 i = 0; i < plansLength; i++) {
            if (s_planIds[i] == _planId) {
                index = int256(i);
                break;
            }
        }

        if (index > -1) {
            for (uint256 i = uint256(index); i < plansLength - 1; i++) {
                s_planIds[i] = s_planIds[i + 1];
            }
            s_planIds.pop();
        }

        emit PlanDeleted(_planId);
    }

    /**
     * @notice Retrieves a subscription plan by its ID.
     * @param _planId The ID of the plan to retrieve.
     * @return The subscription plan details.
     * @dev Reverts if the plan ID is not found.
     */
    function getPlan(uint256 _planId) public view returns (Plan memory) {
        if (s_plans[_planId].planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        return s_plans[_planId];
    }

    /**
     * @notice Retrieves all subscription plans.
     * @return An array of all subscription plans.
     */
    function getPlans() public view returns (Plan[] memory) {
        uint256 totalPlans = s_planIds.length;
        Plan[] memory result = new Plan[](totalPlans);
        for (uint256 i = 0; i < totalPlans; i++) {
            result[i] = s_plans[s_planIds[i]];
        }
        return result;
    }

    /**
     * @notice Adds a billing plan to a subscription plan.
     * @param _planId The ID of the plan to add the billing plan to.
     * @param _billingPlan The billing plan to add.
     * @dev Reverts if the plan ID is not found.
     */
    function addBillingPlan(uint256 _planId, BillingPlan memory _billingPlan)
        public
        validBillingPlan(_planId, _billingPlan)
    {
        Plan storage plan = s_plans[_planId];
        if (plan.planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        plan.billingPlans.push(_billingPlan);

        emit BillingPlanAdded(_planId, uint8(plan.billingPlans.length - 1));
    }

    /**
     * @notice Updates a billing plan for a subscription plan.
     * @param _planId The ID of the plan to update the billing plan for.
     * @param _billingPlanIndex The index of the billing plan to update.
     * @param _billingPlan The new billing plan details.
     * @dev Reverts if the plan ID or billing plan index is not found.
     */
    function updateBillingPlan(uint256 _planId, uint8 _billingPlanIndex, BillingPlan memory _billingPlan)
        public
        validBillingPlan(_planId, _billingPlan)
    {
        Plan storage plan = s_plans[_planId];
        if (plan.planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        if (_billingPlanIndex >= plan.billingPlans.length) {
            revert SubscriptionPlansRegistry__BillingPlanNotFound(_planId, _billingPlanIndex);
        }

        plan.billingPlans[_billingPlanIndex] = _billingPlan;

        emit BillingPlanUpdated(_planId, _billingPlanIndex);
    }

    /**
     * @notice Removes a billing plan from a subscription plan.
     * @param _planId The ID of the plan to remove the billing plan from.
     * @param _billingPlanIndex The index of the billing plan to remove.
     * @dev Reverts if the plan ID or billing plan index is not found.
     */
    function removeBillingPlan(uint256 _planId, uint8 _billingPlanIndex) public {
        Plan storage plan = s_plans[_planId];
        if (plan.planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        if (_billingPlanIndex >= plan.billingPlans.length) {
            revert SubscriptionPlansRegistry__BillingPlanNotFound(_planId, _billingPlanIndex);
        }

        for (uint256 i = _billingPlanIndex; i < plan.billingPlans.length - 1; i++) {
            plan.billingPlans[i] = plan.billingPlans[i + 1];
        }

        plan.billingPlans.pop();

        emit BillingPlanRemoved(_planId, _billingPlanIndex);
    }

    /**
     * @notice Retrieves a billing plan from a subscription plan.
     * @param _planId The ID of the plan to retrieve the billing plan from.
     * @param _billingPlanIndex The index of the billing plan to retrieve.
     * @return The billing plan details.
     * @dev Reverts if the plan ID or billing plan index is not found.
     */
    function getBillingPlan(uint256 _planId, uint8 _billingPlanIndex) public view returns (BillingPlan memory) {
        Plan storage plan = s_plans[_planId];
        if (plan.planId == 0) {
            revert SubscriptionPlansRegistry__PlanNotFound(_planId);
        }

        if (_billingPlanIndex >= plan.billingPlans.length) {
            revert SubscriptionPlansRegistry__BillingPlanNotFound(_planId, _billingPlanIndex);
        }

        return plan.billingPlans[_billingPlanIndex];
    }
}
