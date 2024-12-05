# MemberBeat Subscription Manager

## Overview

The `MemberBeatSubscriptionManager` contract is designed to manage subscription services, allowing users to subscribe, manage subscriptions, and handle token-based payments. This contract provides a comprehensive and automated solution for subscription management, leveraging Chainlink "Time-Based" and "Log Trigger" Upkeeps to automatically charge subscriptions.

### Key Features

- **Subscription Management**: Users can subscribe to different plans using tokens. The contract handles various subscription statuses, including activating, suspending, and canceling subscriptions.
- **Automated Charging**: Subscriptions are automatically charged using Chainlink Upkeeps. The "Time-Based" Upkeep ensures periodic charges, while the "Log Trigger" Upkeep handles event-based charges.
- **Billing Plan Management**: The owner can create, update, and delete subscription plans, as well as manage billing plans within those plans. This allows for flexible subscription models tailored to different needs.
- **Token Integration**: The contract supports multiple tokens for subscription payments, integrating with the `TokenPriceFeedRegistry` to convert fiat prices to token amounts.

### Owner Capabilities

The owner of the contract has several key capabilities to manage subscription services:

- **Create Subscription Plans**: The owner can create new subscription plans with specific billing plans, defining the period and pricing type (token or fiat).
- **Update Subscription Plans**: Existing subscription plans can be updated by the owner, including modifying billing plans and plan details.
- **Delete Subscription Plans**: The owner can delete subscription plans that are no longer needed, ensuring the service remains up-to-date and relevant.
- **Manage Billing Plans**: Billing plans within subscription plans can be added, updated, or removed by the owner, providing flexibility in subscription offerings.
- **Token Management**: The owner can view and manage the tokens used for subscription payments. After tokens are charged, they can be transferred to the owner's wallet using the `claimTokens` function, which ensures all charged tokens are handled efficiently.

### Integration with External Registries

The contract integrates with the `SubscriptionPlansRegistry` and `TokenPriceFeedRegistry` to manage subscription plans and token price feeds. This integration allows for dynamic and flexible subscription models, supporting a wide range of pricing and billing options.

By automating subscription charges and providing robust management capabilities, the `MemberBeatSubscriptionManager` contract offers a powerful solution for subscription-based services.

## Installation  
    
1. **Install dependencies**:

    ```
    make install
    ```
   
2. **Deploy the contract**:
   
    To deploy to a local anvil chain, run:

    ```
    make deploy   
    ```

    For Sepolia, run
    ```
    make deploy-sepolia
    ```    

    For Arbitrum Sepolia, run
    ```
    make deploy-arbitrum-sepolia
    ```

## Usage

1. **Manage Plans**:
   - Use the `createPlan`, `updatePlan`, and `deletePlan` functions to manage subscription plans.
   - Use the `addBillingPlan`, `updateBillingPlan`, and `removeBillingPlan` functions to manage billing plans within subscription plans.

2. **Handle Subscriptions**:
   - Users can subscribe to plans using the `subscribe` function.
   - Users can unsubscribe from plans using the `unsubscribe` function.
   - The contract handles charging subscriptions and managing billing cycles automatically.

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Demo Arbitrum Sepolia deployment

##### arbitrum-sepolia
✅  [Success]Hash: 0xd1c3282a93d20ab54141d66a3ac6065454caf935bfd20062bb169f1d408aca0f
Contract Address: 0x0D27195dC9c7196A0576F7582C09fA3d2D0B254d
Block: 103421025
Paid: 0.0005981722 ETH (5981722 gas * 0.1 gwei)

✅ Sequence #1 on arbitrum-sepolia | Total Paid: 0.0005981722 ETH (5981722 gas * avg 0.1 gwei)
                                                                                                                                                                                                                                 
==========================

