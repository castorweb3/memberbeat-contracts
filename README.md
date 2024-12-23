# MemberBeat Subscription Manager

## Overview

The `MemberBeatSubscriptionManager` is a decentralized application (dApp) built on blockchain technology using Solidity to manage subscription services. This smart contract enables users to subscribe, manage their subscriptions, and handle token-based payments efficiently. It leverages Chainlink oracles for reliable data feeds and incorporates the new crypto token, MemberBeat Token (MBT), for various subscription-related transactions.

### Key Features

- **Subscription Management**: Users can subscribe to different plans using tokens. The contract handles various subscription statuses, including activating, suspending, and canceling subscriptions.
- **Automated Charging**: Subscriptions are automatically charged using Chainlink Upkeeps. The "Time-Based" Upkeep ensures periodic charges, while the "Log Trigger" Upkeep handles event-based charges.
- **Billing Plan Management**: The owner can create, update, and delete subscription plans, as well as manage billing plans within those plans. This allows for flexible subscription models tailored to different needs.
- **Token Integration**: The contract supports multiple tokens for subscription payments, integrating with the `TokenPriceFeedRegistry` to convert fiat prices to token amounts.
- **Rewards for Subscription**: Each time a user subscribes, they get rewarded with the exact same amount of MemberBeatToken (MBT) proportionally to the amount of tokens spent.
- **Use of MBT Tokens**: MBT tokens can be later used by users within the plans they subscribed to. For example, they can spend MBT tokens for usage of certain services inside a given plan, etc.

### Owner Capabilities

The owner of the contract has several key capabilities to manage subscription services:

- **Create Subscription Plans**: The owner can create new subscription plans with specific billing plans, defining the period and pricing type (token or fiat).
- **Update Subscription Plans**: Existing subscription plans can be updated by the owner, including modifying billing plans and plan details.
- **Delete Subscription Plans**: The owner can delete subscription plans that are no longer needed, ensuring the service remains up-to-date and relevant.
- **Manage Billing Plans**: Billing plans within subscription plans can be added, updated, or removed by the owner, providing flexibility in subscription offerings.
- **Token Management**: The owner can view and manage the tokens used for subscription payments. After tokens are charged, they can be transferred to the owner's wallet using the `claimTokens` function, which ensures all charged tokens are handled efficiently.

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

## Testnet Deployments ##
##### arbitrum-sepolia
✅  [Success]Hash: 0x1a49e384647c5bea0eb0d2bdcdafbccf3d3bc5a24bb7b3f6270cc40b1a37e6b2
Contract Address: 0x226Db0C403FDCaD100089d4bcb255794e96F5ec1
Block: 107548715
Paid: 0.000765067 ETH (7650670 gas * 0.1 gwei)

##### arbitrum-sepolia
✅  [Success]Hash: 0x7636108382501ae92c973b628772ef99aff21c621302801c31fe78d303288840
Block: 107548719
Paid: 0.0000064477 ETH (64477 gas * 0.1 gwei)

✅ Sequence #1 on arbitrum-sepolia | Total Paid: 0.0007715147 ETH (7715147 gas * avg 0.1 gwei)

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

We haven't found any matching bytecode for the following contracts: [0x2d7ff33cbf204f811387e5b85ab4ab4cf222c202, 0x6b2e0e1fa9d74f7abcc0994fcf64abb38222f879].

This may occur when resuming a verification, but the underlying source code or compiler version has changed.
##
Start verification for (1) contracts
Start verifying contract `0x226Db0C403FDCaD100089d4bcb255794e96F5ec1` deployed on arbitrum-sepolia

Submitting verification for [src/MemberBeatSubscriptionManager.sol:MemberBeatSubscriptionManager] 0x226Db0C403FDCaD100089d4bcb255794e96F5ec1.
Submitted contract for verification:
        Response: `OK`
        GUID: `fbfip5qcburjnrpxf567ckctn2jbmz2exqfvdal9rmwv7yj7wl`
        URL: https://sepolia.arbiscan.io/address/0x226db0c403fdcad100089d4bcb255794e96f5ec1
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified
All (1) contracts were verified!
