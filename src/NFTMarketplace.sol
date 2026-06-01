// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Solidity libraries
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract NFTMarketplace {
   struct Listing {
      address seller;
      uint256 price;
      bool active;
   }

   // Errors
   error NotTokenOwner();
   error NotSeller();
   error NotApproved();
   error AlreadyListed();
   error NotListed();
   error PriceMustBeAboveZero();
   error IncorrectPaymentAmount();
   error NoFeesToWithdraw();
   error TransferFailed();
   error FeeTooHigh();

   // Events
   event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
   event NFTSold(address indexed buyer, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
   event ListingCancelled(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
   event FeesWithdrawn(address indexed owner, uint256 amount);
   event FeeUpdated(uint256 newFee);

   // Variables
   uint256 public platformFeeBps;
   uint256 public platformFeesAccumulated;
   mapping(address => mapping(uint256 => Listing)) public listings;

   constructor(uint256 _platformFeeBps) Ownable(msg.sender) {
      platformFeeBps = _platformFeeBps;
   }

   // Function for sellers to list NFT
   function listNFT(address nftContract, uint256 tokenId, uint256 price) external{
      // Makes sure that price is above 0
      if (price < 1) {
         revert PriceMustBeAboveZero();
      }

      // Makes sure that the caller is the owner of the NFT
      if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) {
         revert NotTokenOwner();
      }

      // Makes sure that the NFT is not already listed
      if (listings[nftContract][tokenId].active) {
         revert AlreadyListed();
      }

      // Makes sure that marketplace has approval for the NFT
      if (IERC721(nftContract).getApproved(tokenId) != address(this)) {
         revert NotApproved();
      }

      listings[nftContract][tokenId].seller = msg.sender;
      listings[nftContract][tokenId].price = price;
      listings[nftContract][tokenId].active = true;

      emit NFTListed(msg.sender, nftContract, tokenId, price);
   }

   // Function for a seller to cancel a listing
   function cancelListing(address nftContract, uint256 tokenId) external {
      Listing memory listing = listings[nftContract][tokenId];
      // Make sure that it is the seller that can call it
      if(msg.sender != listing.seller) {
         revert NotSeller();
      }

      // Make sure that the NFT is listed
      if(listing.active == false) {
         revert NotListed();
      }

      // Mark the NFT as inactive
      listings[nftContract][tokenId].active = false;

      emit ListingCancelled(msg.sender, nftContract, tokenId);
   }


   // Function for buyers to buy NFT
   function buyNFT(address nftContract, uint256 tokenId) external payable {
      // Makes sure that the NFT is listed
      Listing memory listing = listings[nftContract][tokenId];
      if (listing.active == false) {
         revert NotListed();
      }

      // Make sure that the buyer sends the exact price
      if(msg.value != listing.price) {
         revert IncorrectPaymentAmount();
      }


      // Mark the NFT as inactive
      listings[nftContract][tokenId].active = false;

      // Calculate the platform fees
      uint256 fee = (listing.price * platformFeeBps) / 10000;

      // Calculate what seller gets
      uint256 sellerProfit = listing.price - fee;

      // Accumulate the fee inside the contract
      platformFeesAccumulated += fee;

      // Transfer the NFT
      IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

      // Transfer ETH to the seller
      (bool success, ) = listing.seller.call{value: sellerProfit}("");
      if(!success) {
         revert TransferFailed();
      }

      // Emit NFT sold
      emit NFTSold(msg.sender, listing.seller, nftContract, tokenId, listing.price);
   }

   // Function for the owner of contract to withdraw fee
   function withdrawFees() external onlyOwner {
      // Make sure there is fees to withdraw
      if(platformFeesAccumulated == 0) {
         revert NoFeesToWithdraw();
      }

      uint256 fee = platformFeesAccumulated;
      platformFeesAccumulated = 0;

      // Send fee to owner wallet
      (bool success, ) = owner().call{value: fee}("");
      if(!success) {
         revert TransferFailed();
      }

      emit FeesWithdrawn(owner(), fee);
   }

   // Function to update platform fee
   function updatePlatformFee(uint256 _updatePlatformFee) external onlyOwner {
      // Makes sure that the fee isnt too high
      if(_updatePlatformFee > 10000) {
         revert FeeTooHigh();
      }

      // Update the platform fee
     platformFeeBps =  _updatePlatformFee;

     emit FeeUpdated(platformFeeBps);
   }
}