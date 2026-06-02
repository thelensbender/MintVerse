// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/MockNFT.sol";

contract NFTMarketplaceTest is Test {

    NFTMarketplace marketplace;
    MockNFT nft;

    address owner    = address(1);
    address seller   = address(2);
    address buyer    = address(3);
    address attacker = address(4);

    uint256 tokenId = 1;
    uint256 price   = 1 ether;

    function setUp() public {
        // Deploy marketplace as owner
        vm.prank(owner);
        marketplace = new NFTMarketplace(250);

        // Deploy MockNFT
        nft = new MockNFT();

        // Mint token to seller
        nft.mint(seller, tokenId);

        // Seller approves marketplace
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        listNFT() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    // Price = 0 → PriceMustBeAboveZero fires before ownerOf check
    function test_ListNFT_reverts_if_priceIsZero() public {
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.PriceMustBeAboveZero.selector);
        marketplace.listNFT(address(nft), tokenId, 0);
    }

    // attacker doesn't own the token → NotTokenOwner
    function test_ListNFT_reverts_if_notTokenOwner() public {
        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotTokenOwner.selector);
        marketplace.listNFT(address(nft), tokenId, price);
    }

    // List once successfully, then list again → AlreadyListed
    function test_ListNFT_reverts_if_alreadyListed() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.AlreadyListed.selector);
        marketplace.listNFT(address(nft), tokenId, price);
    }

    /*//////////////////////////////////////////////////////////////
                        buyNFT() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    // Token never listed → NotListed (give buyer ETH so OutOfFunds doesn't fire first)
    function test_BuyNFT_reverts_if_notListed() public {
        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
    }

    // Listed at 1 ether, buyer sends 0.5 ether → IncorrectPaymentAmount
    function test_BuyNFT_reverts_if_incorrectETH() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.IncorrectPaymentAmount.selector);
        marketplace.buyNFT{value: 0.5 ether}(address(nft), tokenId);
    }

    // Seller tries to buy their own listing → IncorrectPaymentAmount
    // (contract doesn't have a SellerCannotBuy error, so we use generic revert)
    function test_BuyNFT_reverts_if_sellerBuysOwnNFT() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(seller, price);
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.SellerCannotBuyOwnNFT.selector);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                    cancelListing() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    // attacker tries to cancel seller's listing → NotSeller
    function test_CancelListing_reverts_if_notSeller() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelListing(address(nft), tokenId);
    }

    // Token was never listed, seller.address stored as address(0) → NotSeller fires
    // We cancel as a random address that is also not the zero-address seller → NotSeller
    // To get NotListed we cancel as address(0)'s "seller" — easiest fix:
    // list then buy to deactivate, then try to cancel → NotListed
    function test_CancelListing_reverts_if_notListed() public {
        // List the NFT
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        // Buy it so listing becomes inactive
        vm.deal(buyer, price);
        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        // Now seller tries to cancel an inactive listing → NotListed
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.cancelListing(address(nft), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                    withdrawFees() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    // attacker calls withdrawFees → OZ Ownable revert
    function test_WithdrawFees_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.withdrawFees();
    }

    // No sales yet → platformFeesAccumulated == 0 → NoFeesToWithdraw
    function test_WithdrawFees_reverts_if_noFees() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.NoFeesToWithdraw.selector);
        marketplace.withdrawFees();
    }

    /*//////////////////////////////////////////////////////////////
                updatePlatformFee() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    // attacker calls updatePlatformFee → OZ Ownable revert
    function test_UpdatePlatformFee_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.updatePlatformFee(500);
    }

    // 10001 bps > 10000 max cap → FeeTooHigh
    function test_UpdatePlatformFee_reverts_if_feeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.FeeTooHigh.selector);
        marketplace.updatePlatformFee(10001);
    }
}
