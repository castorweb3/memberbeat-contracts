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

import {Script} from "forge-std/Script.sol";

contract TransferEth is Script {
    function run() public {
        vm.startBroadcast();
        address receiver = vm.envAddress("ETH_RECEIVER_ADDRESS");
        uint256 amount = vm.envUint("ETH_AMOUNT");

        (bool success,) = payable(receiver).call{value: amount}("");
        require(success, "Transfer failed.");
        vm.stopBroadcast();
    }
}
