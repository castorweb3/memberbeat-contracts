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
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract TestingUtils is Test, MemberBeatDataTypes {
    int256 public constant SERVICE_PROVIDER_FEE = 10000000000000000 wei; // 0.1% or 0.001

    uint256 public constant SEPOLIA_CHAIN_ID = 111555111;
    uint256 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint8 public constant DECIMALS = 8;    
    uint256 public constant ETH_FIAT_PRICE = 1734e8;
    uint256 public constant NEW_ETH_FIAT_PRICE = 1629e8;
    uint256 public constant BTC_FIAT_PRICE = 2129e8;    
    int256 public constant INVALID_FIAT_PRICE = -1;

    uint256 public constant ONE_MONTH_FIAT_PRICE = 49 ether;
    uint256 public constant THREE_MONTH_FIAT_PRICE = 129 ether;
    uint256 public constant YEARLY_FIAT_PRICE = 469 ether;

    uint256 public constant ONE_MONTH_FIAT_PRICE_UPDATE = 59 ether;

    address RANDOM_USER = makeAddr("randomUser");
    uint256 INITIAL_RANDOM_USER_BALANCE = 10 ether;
    address POOR_USER = makeAddr("poorUser");

    address RANDOM_TOKEN = makeAddr("randomToken");
    address INVALID_TOKEN = address(0);

    uint256 PLAN_ID = 1;
    uint256 PLAN_ID_2 = 2;
    string PLAN_NAME = "Premium";
    string PLAN_NAME_2 = "Gold";
    string NEW_PLAN_NAME = "Platinum";
    uint256 INVALID_PLAN_ID = 0;

    uint8 FREE_TRIAL_BILLING_PLAN_INDEX = 0;
    uint8 ONE_MONTH_BILLING_PLAN_INDEX = 1;
    uint8 THREE_MONTH_BILLING_PLAN_INDEX = 2;
    uint8 ONE_YEAR_BILLING_PLAN_INDEX = 3;

    uint8 INVALID_BILLING_PLAN_INDEX = 59;
    uint256 RANDOM_PLAN_ID = 7894;
    Period PERIOD = Period.Month;
    Period NEW_PERIOD = Period.Lifetime;
    uint256 SUBSCRIBE_PENDING_DAYS = 1;

    uint16 public INVALID_DAY = 365 + 1;
    uint16 public INVALID_MONTH = 12 + 1;
    uint16 public INVALID_YEAR = 50 + 1;
    uint16 public INVALID_LIFETIME = 1 + 1;

    error TestingConstants__TestRequiresAtLeastTwoTokens();

    function createBillingPlan(
        Period period,
        uint16 periodValue,
        PricingType pricingType,
        address[] memory tokenAddresses,
        uint256[] memory tokenPrices,
        uint256 fiatPrice
    ) internal pure returns (BillingPlan memory) {
        return BillingPlan({
            period: period,
            periodValue: periodValue,
            pricingType: pricingType,
            tokenAddresses: tokenAddresses,
            tokenPrices: tokenPrices,
            fiatPrice: fiatPrice
        });
    }

    function findEvent(Vm.Log[] memory logs, string memory eventSignature)
        internal
        pure
        returns (Vm.Log memory log, bool found)
    {
        bytes32 eventSigHash = keccak256(bytes(eventSignature));
        console.logBytes32(eventSigHash);
        for (uint256 i = 0; i < logs.length; i++) {
            console.log("Processing log ", i);
            console.logBytes32(logs[i].topics[0]);
            if (logs[i].topics[0] == eventSigHash) {
                log = logs[i];
                found = true;
                return (log, found);
            }
        }
        found = false;
    }
}
