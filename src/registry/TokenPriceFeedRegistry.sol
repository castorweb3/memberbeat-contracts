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
import {MemberBeatDataTypes} from "src/common/MemberBeatDataTypes.sol";

/**
 * @title TokenPriceFeedRegistry
 * @notice Manages price feed addresses for various tokens and provides utility functions for price conversion.
 * @dev This contract allows adding, updating, and retrieving price feed addresses for tokens, as well as converting fiat amounts to token amounts.
 */
contract TokenPriceFeedRegistry is MemberBeatDataTypes {
    
    mapping(address => TokenPriceFeed) private s_tokenPriceFeeds;
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
        s_tokenPriceFeeds[_tokenAddress] = TokenPriceFeed({tokenAddress: _tokenAddress, priceFeedAddress: _priceFeedAddress});
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
     * @notice Removes the price feed address for a token.
     * @param _tokenAddress The address of the token.
     * @dev Reverts if the token is not registered.
     */
    function deleteTokenPriceFeed(address _tokenAddress) public {
        if (!s_validTokens[_tokenAddress]) {
            revert TokenPriceFeedRegistry__TokenNotRegistered(_tokenAddress);
        }

        delete s_tokenPriceFeeds[_tokenAddress];

        s_validTokens[_tokenAddress] = false;
        for (uint256 i = 0; i < s_tokens.length; i++) {
            if (s_tokens[i] == _tokenAddress) {
                s_tokens[i] = s_tokens[s_tokens.length - 1];
                s_tokens.pop();
                break;
            }
        }
    }

    /**
     * @notice Synchronizes provided token price feeds with the existing ones.
     * @dev If the existing token price feed was not found in the _tokenPriceFeeds array, it will be removed
     * @param _tokenPriceFeeds The array of token price feeds to be synced
     */
    function syncTokenPriceFeeds(TokenPriceFeed[] memory _tokenPriceFeeds) public {
        uint256 totalTokens = s_tokens.length;

        if (totalTokens > 0) {
            for (uint256 i = totalTokens; i > 0; i--) {
                address existingToken = s_tokens[i - 1];
                bool found = false;

                for (uint256 j = 0; j < _tokenPriceFeeds.length; j++) {
                    if (_tokenPriceFeeds[j].tokenAddress == existingToken) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    deleteTokenPriceFeed(existingToken);
                }
            }
        }
        
        for (uint256 i = 0; i < _tokenPriceFeeds.length; i++) {
            TokenPriceFeed memory tokenPriceFeed = _tokenPriceFeeds[i];
            if (tokenPriceFeed.tokenAddress == address(0) || tokenPriceFeed.priceFeedAddress == address(0)) {
                continue;
            }

            TokenPriceFeed storage existingTokenPriceFeed = s_tokenPriceFeeds[tokenPriceFeed.tokenAddress];
            if (existingTokenPriceFeed.tokenAddress == address(0)) {
                addTokenPriceFeed(tokenPriceFeed.tokenAddress, tokenPriceFeed.priceFeedAddress);
            } else {
                updateTokenPriceFeed(tokenPriceFeed.tokenAddress, tokenPriceFeed.priceFeedAddress);
            }
        }
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
}
