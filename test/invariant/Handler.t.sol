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
import {MemberBeatSubscriptionManager, IMemberBeatSubscriptionManager, MemberBeatDataTypes, DateTime} from "src/MemberBeatSubscriptionManager.sol";

contract Handler is Test, MemberBeatDataTypes {
    MemberBeatSubscriptionManager subscriptionManager;
    address[] users;
    address[] tokens;
    uint256 minPlanId;
    uint256 maxPlanId;
    uint8 minBillingPlanIndex;
    uint8 maxBillingPlanIndex;
    uint256 maxTestingMonths;
    uint256 testEndTimestamp;

    address currentUser;
    address currentToken;

    uint256 public totalSubscribes;
    uint256 public totalUnsubscribes;
    uint256 public totalWarps;

    mapping(address => uint256) totalTokenAmountsSpent;
    mapping(address => mapping(address => uint256)) userTokenAmountsSpent;
    mapping(address => uint256) subscriptionManagerTokenAmountsCharged;
    mapping(address => uint256) serviceProviderTokenFeesCharged;

    modifier useUser(uint256 _userIndexSeed) {
        currentUser = users[bound(_userIndexSeed, 0, users.length - 1)];
        vm.startPrank(currentUser);
        _;
        vm.stopPrank();
    }

    modifier useToken(uint256 _tokenIndexSeed) {
        currentToken = tokens[bound(_tokenIndexSeed, 0, tokens.length - 1)];
        _;
    }

    constructor(
        MemberBeatSubscriptionManager _subscriptionManager,
        address[] memory _users,
        address[] memory _tokens,
        uint256 _minPlanId,
        uint256 _maxPlanId,
        uint8 _minBillingPlanIndex,
        uint8 _maxBillingPlanIndex,
        uint256 _maxTestingMonths
    ) {
        subscriptionManager = _subscriptionManager;
        users = _users;
        tokens = _tokens;
        minPlanId = _minPlanId;
        maxPlanId = _maxPlanId;
        minBillingPlanIndex = _minBillingPlanIndex;
        maxBillingPlanIndex = _maxBillingPlanIndex;
        maxTestingMonths = _maxTestingMonths;

        testEndTimestamp = DateTime.addMonths(block.timestamp, maxTestingMonths);
    }

    function subscribeScheduled(
        uint256 _planId,
        uint8 _billingPlanIndex,
        uint256 _startTimestamp,
        uint256 _tokenIndexSeed,
        uint256 _userIndexSeed
    ) public useToken(_tokenIndexSeed) useUser(_userIndexSeed) {
        /*TODO*/
    }

    function subscribeNow(uint256 _planId, uint8 _billingPlanIndex, uint256 _tokenIndexSeed, uint256 _userIndexSeed)
        public
        useToken(_tokenIndexSeed)
        useUser(_userIndexSeed)
    {
        if (block.timestamp > testEndTimestamp) {
            return;
        }

        _planId = bound(_planId, minPlanId, maxPlanId);
        _billingPlanIndex = uint8(bound(_billingPlanIndex, minBillingPlanIndex, maxBillingPlanIndex));

        try subscriptionManager.subscribe(_planId, _billingPlanIndex, currentToken, block.timestamp) returns (
            Subscription memory subscription, uint256 tokenAmount
        ) {
            totalSubscribes++;

            totalTokenAmountsSpent[subscription.token] += tokenAmount;
            userTokenAmountsSpent[subscription.account][subscription.token] += tokenAmount;
            uint256 serviceProviderFee = subscriptionManager.calculateServiceProviderFee(tokenAmount);
            subscriptionManagerTokenAmountsCharged[subscription.token] += tokenAmount - serviceProviderFee;
            serviceProviderTokenFeesCharged[subscription.token] += serviceProviderFee;
        } catch (bytes memory lowLevelData) {
            bytes4 errorSignature = bytes4(lowLevelData);
            if (
                errorSignature
                    != IMemberBeatSubscriptionManager.MemberBeatSubscriptionManager__AlreadySubscribed.selector
            ) {
                assembly {
                    revert(add(lowLevelData, 0x20), mload(lowLevelData))
                }
            }
        }
    }

    function warp() public {
        if (block.timestamp > testEndTimestamp) {
            return;
        }

        vm.warp(DateTime.addDays(block.timestamp, 1));

        totalWarps++;
    }

    function unsubscribe(uint256 _planId, uint256 _userIndexSeed) public useUser(_userIndexSeed) {
        _planId = bound(_planId, minPlanId, maxPlanId);
        try subscriptionManager.unsubscribe(_planId) {
            totalUnsubscribes++;
        } catch (bytes memory lowLevelData) {
            bytes4 errorSignature = bytes4(lowLevelData);
            if (errorSignature != IMemberBeatSubscriptionManager.MemberBeatSubscriptionManager__NotSubscribed.selector) {
                assembly {
                    revert(add(lowLevelData, 0x20), mload(lowLevelData))
                }
            }
        }
    }

    function getTotalTokenAmountSpent(address token) public view returns (uint256) {
        return totalTokenAmountsSpent[token];
    }

    function getUserTokenAmountSpent(address user, address token) public view returns (uint256) {
        return userTokenAmountsSpent[user][token];
    }

    function getSubscriptionManagerTokenAmountCharged(address token) public view returns (uint256) {
        return subscriptionManagerTokenAmountsCharged[token];
    }

    function getServiceProviderTokenFeeCharged(address token) public view returns (uint256) {
        return serviceProviderTokenFeesCharged[token];
    }
}
