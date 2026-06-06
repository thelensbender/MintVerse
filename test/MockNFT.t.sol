// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MockNFT.sol";

contract MockNFTTest is Test {
    MockNFT nft;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address attacker = address(4);

    function setUp() public {
        // Deploy MockNFT as owner
        vm.prank(owner);
        nft = new MockNFT();
    }

    /// mint() TESTS ///
    // Anyone can mint — user1 mints and receives the NFT
    function test_Mint_success() public {
        vm.prank(user1);
        uint256 tokenId = nft.mint(user1);

        assertEq(nft.ownerOf(tokenId), user1);
    }

    // After mint, balance of user1 should be 1
    function test_Mint_balanceIncreasesAfterMint() public {
        vm.prank(user1);
        nft.mint(user1);

        assertEq(nft.balanceOf(user1), 1);
    }

    // TokenId starts from 0 and increments by 1 each mint
    function test_Mint_tokenIdIncrementsCorrectly() public {
        uint256 firstId = nft.mint(user1);
        uint256 secondId = nft.mint(user1);
        uint256 thirdId = nft.mint(user2);

        assertEq(firstId, 0);
        assertEq(secondId, 1);
        assertEq(thirdId, 2);
    }

    // nextTokenId() should reflect how many tokens have been minted
    function test_Mint_nextTokenIdUpdatesAfterMint() public {
        assertEq(nft.nextTokenId(), 0); // nothing minted yet

        nft.mint(user1);
        assertEq(nft.nextTokenId(), 1);

        nft.mint(user2);
        assertEq(nft.nextTokenId(), 2);
    }

    // Mint to a different address — token belongs to recipient not caller
    function test_Mint_toAnotherAddress() public {
        vm.prank(user1);
        uint256 tokenId = nft.mint(user2); // user1 mints but sends to user2

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.balanceOf(user1), 0);
    }

    /// mintTo() REVERT TESTS ///

    // Only owner can call mintTo — attacker should be reverted
    function test_MintTo_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        nft.mintTo(attacker);
    }

    // Owner can call mintTo successfully
    function test_MintTo_success_ifOwner() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintTo(user1);

        assertEq(nft.ownerOf(tokenId), user1);
    }

    /// transfer() TESTS ///

    // User can transfer their NFT to another address
    function test_Transfer_success() public {
        uint256 tokenId = nft.mint(user1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    // Non-owner cannot transfer someone else's NFT
    function test_Transfer_reverts_if_notOwner() public {
        uint256 tokenId = nft.mint(user1);

        vm.prank(attacker);
        vm.expectRevert();
        nft.transferFrom(user1, attacker, tokenId);
    }

    /// approve() TESTS ///

    // Owner can approve another address to transfer their NFT
    function test_Approve_success() public {
        uint256 tokenId = nft.mint(user1);

        vm.prank(user1);
        nft.approve(user2, tokenId);

        assertEq(nft.getApproved(tokenId), user2);
    }

    // Approved address can transfer the NFT
    function test_Approve_allowsTransfer() public {
        uint256 tokenId = nft.mint(user1);

        vm.prank(user1);
        nft.approve(user2, tokenId);

        vm.prank(user2);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
    }

    // Non-owner cannot approve someone else's NFT
    function test_Approve_reverts_if_notOwner() public {
        uint256 tokenId = nft.mint(user1);

        vm.prank(attacker);
        vm.expectRevert();
        nft.approve(attacker, tokenId);
    }
}
