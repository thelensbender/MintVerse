// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 1. Grab the Foundry smart robot tools
import "forge-std/Script.sol";

// 2. Grab your team's custom contract blueprints
import "../src/MockNFT.sol";
import "../src/NFTMarketplace.sol";

contract DeployScript is Script {
    function run() external {
        // 3. Tell the robot to look inside your computer wallet for authorization
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 4. Start the official deployment transmission
        vm.startBroadcast(deployerPrivateKey);

        // 5. Build the MockNFT contract first
        MockNFT mockNft = new MockNFT();
        console.log("MockNFT:", address(mockNft));

        // 6. Build the NFTMarketplace contract, giving it 0 for the platform fee!
        NFTMarketplace marketplace = new NFTMarketplace(0);
        console.log("Marketplace:", address(marketplace));

        // 7. Stop the transmission safely
        vm.stopBroadcast();
    }
}
