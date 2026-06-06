// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/MockNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    // Actors
    address owner = address(1);
    address seller = address(2);
    address buyer = address(3);
    address attacker = address(4);

    uint256 tokenId;
    uint256 price = 1 ether;

    function setUp() public {
        // Deploy marketplace as owner
        vm.prank(owner);
        marketplace = new NFTMarketplace(250);

        // Deploy MockNFT
        nft = new MockNFT();

        // Mint token to seller — returns the tokenId
        tokenId = nft.mint(seller);

        // Seller approves marketplace
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
    }

    /// listNFT() REVERT TESTS ///
    // Test to makes sure that a seller cannot list an NFT with a price of 0
    function test_ListNFT_reverts_if_priceIsZero() public {
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.PriceMustBeAboveZero.selector);
        marketplace.listNFT(address(nft), tokenId, 0);
    }

    // Test to make sure that another account cannot list the seller's NFT
    function test_ListNFT_reverts_if_notTokenOwner() public {
        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotTokenOwner.selector);
        marketplace.listNFT(address(nft), tokenId, price);
    }

    // Tests to make sure that a seller cannot list the same NFT more than once
    function test_ListNFT_reverts_if_alreadyListed() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.AlreadyListed.selector);
        marketplace.listNFT(address(nft), tokenId, price);
    }

    // Tests to make sure that the NFT lists correctly
    function test_ListNFT_success() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);
        (address storedSeller, uint256 storedPrice, bool active) = marketplace.listings(address(nft), tokenId);
        assertEq(storedSeller, seller);
        assertEq(storedPrice, price);
        assertEq(active, true);
    }

    /// buyNFT() REVERT TESTS ///
    // Tests to make sure that a buyer cannot buy an NFT that is not listed
    function test_BuyNFT_reverts_if_notListed() public {
        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
    }

    // Tests to make sure that a buyer cannot purchase the NFT with an incorrect ETH price
    function test_BuyNFT_reverts_if_incorrectETH() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.IncorrectPaymentAmount.selector);
        marketplace.buyNFT{value: 0.5 ether}(address(nft), tokenId);
    }

    // Tests to make sure that seller doesn't buy its own NFT
    function test_BuyNFT_reverts_if_sellerBuysOwnNFT() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(seller, price);
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.SellerCannotBuyOwnNFT.selector);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
    }

    //
    function test_BuyNFT_success() public {
        // Seller lists first
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        // Buyer buys
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        // Confirm values after sale
        (address sellerAfter, uint256 priceAfter, bool activeAfter) = marketplace.listings(address(nft), tokenId);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(sellerAfter, seller);
        assertEq(priceAfter, price);
        assertEq(activeAfter, false);
    }

    // Tests to make sure that seller receives the correct ETH
    function test_seller_received_correct_ETH() public {
        // Seller lists first
        uint256 sellerBalanceBefore = seller.balance;
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        // Buyer buys
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        uint256 sellerBalanceAfter = seller.balance;
        uint256 balanceChange = sellerBalanceAfter - sellerBalanceBefore;
        uint256 feeBps = marketplace.platformFeeBps();
        uint256 fee = (price * feeBps) / 10000;
        uint256 expectedPrice = price - fee;

        // Seller balance must be equal to price of NFT minus the fee
        assertEq(balanceChange, expectedPrice);
    }

    /// cancelListing() REVERT TESTS ///
    // Test to make sure that only seller can cancel the listing of an NFT
    function test_CancelListing_reverts_if_notSeller() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelListing(address(nft), tokenId);
    }

    // Test to make sure that a seller cannot cancel an NFT that is not listed.(Note: After a buyer purchases the NFT, it becomes cancelled.)
    function test_CancelListing_reverts_if_notListed() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.cancelListing(address(nft), tokenId);
    }

    //  Tests to make sure that seller can cancel a listed NFT he listed
    function test_seller_cancelled() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(seller);
        marketplace.cancelListing(address(nft), tokenId);

        (,, bool active) = marketplace.listings(address(nft), tokenId);
        assertEq(active, false);
    }

    /// withdrawFees() REVERT TESTS ///
    // Test to make sure that only owner can withdraw the fee
    function test_WithdrawFees_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.withdrawFees();
    }

    // Test to make sure that owner cannot withdraw when no fee exists
    function test_WithdrawFees_reverts_if_noFees() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.NoFeesToWithdraw.selector);
        marketplace.withdrawFees();
    }

    //  Test to make sure that the withdraw works
    function test_WithdrawFees_success() public {
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        uint256 feeBps = marketplace.platformFeeBps();
        uint256 expectedFee = (price * feeBps) / 10000;

        // Confirm platform Fee Accumulated
        vm.prank(owner);
        marketplace.withdrawFees();

        uint256 ownerBalanceAfter = owner.balance;
        uint256 ownerBalanceChange = ownerBalanceAfter - ownerBalanceBefore;

        assertEq(marketplace.platformFeesAccumulated(), 0);
        assertEq(ownerBalanceChange, expectedFee);
    }

    /// updatePlatformFee() REVERT TESTS ///
    //  Tests to make sure that only owner can update the platform fee
    function test_UpdatePlatformFee_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.updatePlatformFee(500);
    }

    // Tests to make sure that the owner doesn't update to a fee that is too high
    function test_UpdatePlatformFee_reverts_if_feeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.FeeTooHigh.selector);
        marketplace.updatePlatformFee(10001);
    }

    // Test to make sure that the owner can successfully update the platform fee
    function test_UpdatePlaformFee_success() public {
        vm.prank(owner);
        marketplace.updatePlatformFee(500);
        assertEq(marketplace.platformFeeBps(), 500);
    }

    // Tests to make sure that the platform fee is changing after each purchase
    function test_PlatformFee_accumulation() public {
        // Seller lists first
        uint256 initialPlatformFee = marketplace.platformFeesAccumulated();
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        // Buyer buys
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        uint256 finalPlatformFee = marketplace.platformFeesAccumulated();
        uint256 feeBps = marketplace.platformFeeBps();
        uint256 fee = (price * feeBps) / 10000;

        assertEq((finalPlatformFee - initialPlatformFee), fee);
    }

    /// Edge case tests ///
    // Buyer tries to buy an NFT that was just cancelled
    function test_Buyer_buys_cancelled_NFT() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, 1 ether);

        vm.prank(seller);
        marketplace.cancelListing(address(nft), tokenId);

        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.buyNFT{value: 1 ether}(address(nft), tokenId);
    }
}
