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

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title TokenPriceFeedRegistry
 * @notice Manages price feed addresses for various tokens and provides utility functions for price conversion.
 * @dev This contract allows adding, updating, and retrieving price feed addresses for tokens, as well as converting fiat amounts to token amounts.
 */
contract TokenPriceFeedRegistry {
    struct PriceFeed {
        address tokenAddress;
        address priceFeedAddress;
    }

    mapping(address => PriceFeed) private s_tokenPriceFeeds;
    mapping(address => bool) private s_validTokens;
    address[] private s_tokens;

    error TokenPriceFeedRegistry__TokenAlreadyRegistered(address tokenAddress);
    error TokenPriceFeedRegistry__TokenNotRegistered(address tokenAddress);

    /**
     * @notice Adds a price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _priceFeedAddress The address of the price feed.
     * @dev Reverts if the token is already registered.
     */
    function addTokenPriceFeed(address _tokenAddress, address _priceFeedAddress) public {
        if (s_validTokens[_tokenAddress]) {
            revert TokenPriceFeedRegistry__TokenAlreadyRegistered(_tokenAddress);
        }
        s_tokenPriceFeeds[_tokenAddress] = PriceFeed({tokenAddress: _tokenAddress, priceFeedAddress: _priceFeedAddress});
        s_validTokens[_tokenAddress] = true;
        s_tokens.push(_tokenAddress);
    }

    /**
     * @notice Updates the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @param _newPriceFeedAddress The new address of the price feed.
     * @dev Reverts if the token is not registered.
     */
    function updateTokenPriceFeed(address _tokenAddress, address _newPriceFeedAddress) public {
        if (!s_validTokens[_tokenAddress]) {
            revert TokenPriceFeedRegistry__TokenNotRegistered(_tokenAddress);
        }
        s_tokenPriceFeeds[_tokenAddress].priceFeedAddress = _newPriceFeedAddress;
    }

    /**
     * @notice Retrieves the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @return The address of the price feed.
     * @dev Reverts if the token is not registered.
     */
    function getTokenPriceFeed(address _tokenAddress) public view returns (address) {
        if (!s_validTokens[_tokenAddress]) {
            revert TokenPriceFeedRegistry__TokenNotRegistered(_tokenAddress);
        }
        return s_tokenPriceFeeds[_tokenAddress].priceFeedAddress;
    }

    /**
     * @notice Checks if a token is registered.
     * @param _tokenAddress The address of the token.
     * @return True if the token is registered, false otherwise.
     */
    function isTokenRegistered(address _tokenAddress) public view returns (bool) {
        return s_validTokens[_tokenAddress] == true;
    }

    /**
     * @notice Retrieves all registered token addresses.
     * @return An array of registered token addresses.
     */
    function getRegisteredTokens() public view returns (address[] memory) {
        return s_tokens;
    }

    /**
     * @notice Retrieves the latest price for a token.
     * @param _tokenAddress The address of the token.
     * @return The latest price of the token.
     * @dev Reverts if the token is not registered.
     */
    function getLatestPrice(address _tokenAddress) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(getTokenPriceFeed(_tokenAddress));
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price * 1e10);
    }

    /**
     * @notice Converts a fiat amount to a token amount based on the latest price.
     * @param _tokenAddress The address of the token.
     * @param _fiatAmount The fiat amount to be converted.
     * @return The equivalent token amount.
     */
    function convertFiatToTokenAmount(address _tokenAddress, uint256 _fiatAmount) public view returns (uint256) {
        uint256 price = getLatestPrice(_tokenAddress);
        if (price == 0) {
            return 0;
        }
        return _fiatAmount * 1e18 / price;
    }
}