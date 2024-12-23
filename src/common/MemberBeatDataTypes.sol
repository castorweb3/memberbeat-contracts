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

/**
 * @title MemberBeatDataTypes
 * @notice Defines data types and enumerations used in the MemberBeat subscription system.
 * @dev This interface includes enums for periods, pricing types, and subscription statuses, as well as structs for subscriptions, billing plans, and plans.
 */
interface MemberBeatDataTypes {
    /**
     * @notice Defines the billing period types.
     */
    enum Period {
        Day,
        Month,
        Year,
        Lifetime
    }

    /**
     * @notice Defines the pricing types.
     */
    enum PricingType {
        TokenPrice,
        FiatPrice
    }

    /**
     * @notice Defines the subscription statuses.
     */
    enum Status {
        Pending,
        Active,
        Suspended,
        Canceled
    }

    /**
     * @notice Represents a subscription.
     * @param account The address of the subscriber.
     * @param planId The ID of the subscription plan.
     * @param token The address of the token used for the subscription.
     * @param startTimestamp The start timestamp of the subscription.
     * @param nextChargeTimestamp The timestamp of the next scheduled charge.
     * @param status The current status of the subscription.
     * @param billingCycle The current billing cycle of the subscription.
     * @param billingPlan The billing plan details associated with the subscription.
     */
    struct Subscription {
        address account;
        uint256 planId;
        address token;
        uint256 startTimestamp;
        uint256 nextChargeTimestamp;
        Status status;
        uint256 billingCycle;
        BillingPlan billingPlan;
    }

    /**
     * @notice Represents a billing plan.
     * @param period The billing period type.
     * @param periodValue The value of the billing period (e.g., number of days, months, years).
     * @param pricingType The type of pricing (token or fiat).
     * @param tokenAddresses An array of token addresses accepted for the billing plan.
     * @param tokenPrices An array of token prices for the billing plan.
     * @param fiatPrice The fiat price for the billing plan.
     */
    struct BillingPlan {
        Period period;
        uint16 periodValue;
        PricingType pricingType;
        address[] tokenAddresses;
        uint256[] tokenPrices;
        uint256 fiatPrice;
    }

    /**
     * @notice Represents a subscription plan.
     * @param planId The ID of the plan.
     * @param planName The name of the plan.
     * @param billingPlans An array of billing plans associated with the plan.
     */
    struct Plan {
        uint256 planId;
        string planName;
        BillingPlan[] billingPlans;
    }

    /**
     * @notice Represents a token price feed
     * @param tokenAddress address of the token
     * @param priceFeedAddress address of the price feed
     */
    struct TokenPriceFeed {
        address tokenAddress;
        address priceFeedAddress;
    }
}
