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

import {Test} from "forge-std/Test.sol";
import {MemberBeatSubscriptionManager, TokenPriceFeedRegistry} from "src/MemberBeatSubscriptionManager.sol";
import {DeploySubscriptionManager} from "script/DeploySubscriptionManager.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TestingUtils} from "test/mocks/TestingUtils.t.sol";

contract PriceFeedRegistryUnitTest is Test, TestingUtils {
    DeploySubscriptionManager deployer;

    MemberBeatSubscriptionManager subscriptionManager;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    TokenPriceFeedRegistry tokenPriceFeedRegistry;

    address TOKEN_ADDRESS = makeAddr("tokenAddress");
    address PRICE_FEED_ADDRESS = makeAddr("priceFeedAddress");

    address TOKEN_ADDRESS_2 = makeAddr("tokenAddress2");
    address PRICE_FEED_ADDRESS_2 = makeAddr("priceFeedAddress2");

    address TOKEN_ADDRESS_3 = makeAddr("tokenAddress3");
    address PRICE_FEED_ADDRESS_3 = makeAddr("priceFeedAddress3");

    address NEW_PRICE_FEED_ADDRESS = makeAddr("newPriceFeedAddress");

    function setUp() public {
        deployer = new DeploySubscriptionManager();
        (subscriptionManager, helperConfig) = deployer.deploySubscriptionManager(SERVICE_PROVIDER_FEE);
        config = helperConfig.getActiveConfig();

        tokenPriceFeedRegistry = new TokenPriceFeedRegistry();
    }

    modifier addedTokenPriceFeed() {
        vm.prank(config.account);
        subscriptionManager.addTokenPriceFeed(TOKEN_ADDRESS, PRICE_FEED_ADDRESS);
        _;
    }

    function testGetTokenPriceFeedRevertsIfTokenNotRegistered() public addedTokenPriceFeed {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, RANDOM_TOKEN
            )
        );
        subscriptionManager.getTokenPriceFeed(RANDOM_TOKEN);
    }

    function testGetTokenPriceFeedReturnsThePriceFeed() public addedTokenPriceFeed {
        vm.prank(config.account);
        address priceFeedAddress = subscriptionManager.getTokenPriceFeed(TOKEN_ADDRESS);
        assertEq(priceFeedAddress, PRICE_FEED_ADDRESS);
    }

    function testAddTokenPriceFeedRevertsIfNotOwner() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.addTokenPriceFeed(address(0), address(0));
    }

    function testAddTokenPriceFeedRevertsIfTokenAlreadyRegistered() public addedTokenPriceFeed {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenAlreadyRegistered.selector, TOKEN_ADDRESS
            )
        );
        subscriptionManager.addTokenPriceFeed(TOKEN_ADDRESS, PRICE_FEED_ADDRESS);
    }

    function testAddTokenPriceRegistersAToken() public {
        vm.prank(config.account);
        subscriptionManager.addTokenPriceFeed(TOKEN_ADDRESS, PRICE_FEED_ADDRESS);

        bool tokenRegistered = subscriptionManager.isTokenRegistered(TOKEN_ADDRESS);
        assertEq(tokenRegistered, true);
    }

    function testUpdateTokenPriceFeedRevertsIfNotOwner() public addedTokenPriceFeed {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.updateTokenPriceFeed(TOKEN_ADDRESS, NEW_PRICE_FEED_ADDRESS);
    }

    function testUpdateTokenPriceFeedRevertsIfTokenNotRegistered() public addedTokenPriceFeed {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, RANDOM_TOKEN
            )
        );
        subscriptionManager.updateTokenPriceFeed(RANDOM_TOKEN, NEW_PRICE_FEED_ADDRESS);
    }

    function testDeleteTokenPriceFeedRevertsIfTokenNotRegistered() public {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, TOKEN_ADDRESS
            )
        );
        subscriptionManager.deleteTokenPriceFeed(TOKEN_ADDRESS);
    }

    function testDeleteTokenPriceDeletesTheToken() public addedTokenPriceFeed {
        vm.prank(config.account);
        subscriptionManager.deleteTokenPriceFeed(TOKEN_ADDRESS);

        bool isRegistered = subscriptionManager.isTokenRegistered(TOKEN_ADDRESS);
        assertEq(isRegistered, false);
    }

    function testSyncTokenPriceFeedsRevertsIfNotOwner() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_USER));
        subscriptionManager.syncTokenPriceFeeds(new TokenPriceFeed[](0));
    }

    function testSyncTokenPriceFeedsSynchronizesTheTokenPriceFeeds() public addedTokenPriceFeed {                        

        TokenPriceFeed[] memory tokens4firstSync = new TokenPriceFeed[](3);
        tokens4firstSync[0] = TokenPriceFeed({tokenAddress: TOKEN_ADDRESS, priceFeedAddress: NEW_PRICE_FEED_ADDRESS});
        tokens4firstSync[1] = TokenPriceFeed({tokenAddress: TOKEN_ADDRESS_2, priceFeedAddress: PRICE_FEED_ADDRESS_2});
        tokens4firstSync[2] = TokenPriceFeed({tokenAddress: TOKEN_ADDRESS_3, priceFeedAddress: PRICE_FEED_ADDRESS_3});

        vm.prank(config.account);
        subscriptionManager.syncTokenPriceFeeds(tokens4firstSync);

        address priceFeedAddress1 = subscriptionManager.getTokenPriceFeed(TOKEN_ADDRESS);
        assertEq(priceFeedAddress1, NEW_PRICE_FEED_ADDRESS);
        address priceFeedAddress2 = subscriptionManager.getTokenPriceFeed(TOKEN_ADDRESS_2);
        assertEq(priceFeedAddress2, PRICE_FEED_ADDRESS_2);
        address priceFeedAddress3 = subscriptionManager.getTokenPriceFeed(TOKEN_ADDRESS_3);
        assertEq(priceFeedAddress3, PRICE_FEED_ADDRESS_3);


        // Plan[] memory plans4secondSync = new Plan[](3);
        // plans4secondSync[0] = Plan({planId: PLAN_ID, planName: NEW_PLAN_NAME, billingPlans: billingPlans});
        // plans4secondSync[1] = Plan({planId: PLAN_ID_2, planName: PLAN_NAME_2, billingPlans: billingPlans});        

        // vm.prank(config.account);
        // subscriptionManager.syncPlans(plans4secondSync);

        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, PLAN_ID_3
        //     )
        // );
        // subscriptionManager.getPlan(PLAN_ID_3);        
    }

    function testGetLatestPriceRevertsIfInvalidToken() public {
        vm.prank(config.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPriceFeedRegistry.TokenPriceFeedRegistry__TokenNotRegistered.selector, TOKEN_ADDRESS
            )
        );
        tokenPriceFeedRegistry.getLatestPrice(TOKEN_ADDRESS);
    }
}
