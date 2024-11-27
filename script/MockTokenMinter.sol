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
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MemberBeatSubscriptionManager} from "src/MemberBeatSubscriptionManager.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.t.sol";

contract MockTokenMinter is Script {
    function run() public {
        address receiver = vm.envAddress('TOKEN_RECEIVER_ADDRESS');
        uint256 amount = vm.envUint('TOKEN_AMOUNT');        
        mintTokens(receiver, amount);
    }

    function mintTokens(address receiver, uint256 amount) public {
        address contractAddress = DevOpsTools.get_most_recent_deployment("MemberBeatSubscriptionManager", block.chainid);
        MemberBeatSubscriptionManager subscriptionManager = MemberBeatSubscriptionManager(contractAddress);
        address[] memory tokens = subscriptionManager.getRegisteredTokens();

        vm.startBroadcast();
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Mock mock = ERC20Mock(tokens[i]);            
            mock.mint(receiver, amount);            
        }
        vm.stopBroadcast();
    }
}
