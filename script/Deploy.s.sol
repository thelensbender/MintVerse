// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 1. Grab the Foundry smart robot tools
import "forge-std/Script.sol";

// 2. Grab your team's custom contract blueprints
import "../src/MockNFT.sol";
import "../src/NFTMarketplace.sol";

contract DeployScript is Script {
    function run() external {
        // 3. Tell the robot to look inside your computer wallet for authorization
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));

        // 4. Start the official deployment transmission
        vm.startBroadcast(deployerPrivateKey);

        // 5. Build the MockNFT contract first
        MockNFT mockNft = new MockNFT();

        // 6. Build the NFTMarketplace contract, giving it 0 for the platform fee!
        NFTMarketplace marketplace = new NFTMarketplace(0);

        // 7. Stop the transmission safely
        vm.stopBroadcast();
    }
}