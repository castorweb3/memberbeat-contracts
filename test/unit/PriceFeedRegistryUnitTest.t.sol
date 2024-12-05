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
