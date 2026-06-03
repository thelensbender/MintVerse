// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

    /*//////////////////////////////////////////////////////////////
                        listNFT() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ListNFT_reverts_if_priceIsZero() public {
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.PriceMustBeAboveZero.selector);
        marketplace.listNFT(address(nft), tokenId, 0);
    }

    function test_ListNFT_reverts_if_notTokenOwner() public {
        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotTokenOwner.selector);
        marketplace.listNFT(address(nft), tokenId, price);
    }

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

    function test_BuyNFT_reverts_if_notListed() public {
        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.NotListed.selector);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
    }

    function test_BuyNFT_reverts_if_incorrectETH() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.deal(buyer, price);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.IncorrectPaymentAmount.selector);
        marketplace.buyNFT{value: 0.5 ether}(address(nft), tokenId);
    }

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

    function test_CancelListing_reverts_if_notSeller() public {
        vm.prank(seller);
        marketplace.listNFT(address(nft), tokenId, price);

        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelListing(address(nft), tokenId);
    }

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

    /*//////////////////////////////////////////////////////////////
                    withdrawFees() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawFees_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.withdrawFees();
    }

    function test_WithdrawFees_reverts_if_noFees() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.NoFeesToWithdraw.selector);
        marketplace.withdrawFees();
    }

    /*//////////////////////////////////////////////////////////////
                updatePlatformFee() REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UpdatePlatformFee_reverts_if_notOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        marketplace.updatePlatformFee(500);
    }

    function test_UpdatePlatformFee_reverts_if_feeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(NFTMarketplace.FeeTooHigh.selector);
        marketplace.updatePlatformFee(10001);
    }
}
