// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import Solidity libraries
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @title NFT Marketplace
/// @author Team Project
/// @notice A marketplace that allows users to list, buy, and sell ERC721 NFTs.
/// @dev The marketplace charges a platform fee on successful sales and allows the owner to withdraw accumulated fees.
contract NFTMarketplace is Ownable {
   struct Listing {
      address seller;
      uint256 price;
      bool active;
   }

   // Errors
   /// @notice thrown when the caller does not own the NFT they are trying to list
      error NotTokenOwner();
   /// @notice Thrown when a non-seller attempts to cancel a listing
      error NotSeller();
   /// @notice Thrown when the marketplace has not been approved to transfer the NFT
      error NotApproved();
   /// @notice Thrown when attempting to list an NFT that is already actively listed
      error AlreadyListed(); 
   /// @notice Thrown when interacting with an NFT that has no active listing
      error NotListed(); 
   /// @notice Thrown when a listing price of zero is provided
      error PriceMustBeAboveZero(); 
   /// @notice Thrown when the ETH sent does not exactly match the listing price
      error IncorrectPaymentAmount(); 
   /// @notice Thrown when the owner attempts to withdraw fees but none have accumulated
      error NoFeesToWithdraw();
   /// @notice Thrown when an ETH transfer to the seller or owner fails
      error TransferFailed();
   /// @notice Thrown when the proposed platform fee exceeds 10000 basis points (100%)
      error FeeTooHigh();
   /// @notice Thrown when the buyer and seller are the same address
   error SellerCannotBuyOwnNFT();

   // Events
   event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
   event NFTSold(
      address indexed buyer, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price
   );
   event ListingCancelled(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
   event FeesWithdrawn(address indexed owner, uint256 amount);
   event FeeUpdated(uint256 newFee);

   // Variables
   uint256 public platformFeeBps;
   uint256 public platformFeesAccumulated;
   mapping(address => mapping(uint256 => Listing)) public listings;

   /// @notice Creates the marketplace contract.
   /// @param _platformFeeBps Initial platform fee in basis points (250 = 2.5%).
      constructor(uint256 _platformFeeBps) Ownable(msg.sender) {
         platformFeeBps = _platformFeeBps;
      }
   /// @notice Lists an NFT for sale.
   /// @dev Caller must own the NFT and approve the marketplace.
   /// @param nftContract Address of the NFT contract.
   /// @param tokenId ID of the NFT being listed.
   /// @param price Sale price in wei.
   // Function for sellers to list NFT
   function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
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

   /// @notice Cancels an active NFT listing.
   /// @dev Only the seller who listed the NFT can cancel it.
   /// @param nftContract Address of the NFT contract.
   /// @param tokenId ID of the NFT listing.
   // Function for a seller to cancel a listing
   function cancelListing(address nftContract, uint256 tokenId) external {
      Listing memory listing = listings[nftContract][tokenId];
      // Make sure that it is the seller that can call it
      if (msg.sender != listing.seller) {
         revert NotSeller();
      }

      // Make sure that the NFT is listed
      if (listing.active == false) {
         revert NotListed();
      }

      // Mark the NFT as inactive
      listings[nftContract][tokenId].active = false;

      emit ListingCancelled(msg.sender, nftContract, tokenId);
   }

   /// @notice Purchases a listed NFT.
   /// @dev Transfers NFT ownership and distributes payment.
   /// @dev Follows Checks-Effects-Interactions pattern to prevent reentrancy.
   /// @param nftContract Address of the NFT contract.
   /// @param tokenId ID of the NFT being purchased.
   // Function for buyers to buy NFT
   function buyNFT(address nftContract, uint256 tokenId) external payable {
      // Makes sure that the NFT is listed
      Listing memory listing = listings[nftContract][tokenId];
      if (listing.active == false) {
         revert NotListed();
      }

      // Make sure seller is not buying their own NFT
      if (msg.sender == listing.seller) {
         revert SellerCannotBuyOwnNFT();
      }

      // Make sure that the buyer sends the exact price
      if (msg.value != listing.price) {
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
      (bool success,) = listing.seller.call{value: sellerProfit}("");
      if (!success) {
         revert TransferFailed();
      }

      // Emit NFT sold
      emit NFTSold(msg.sender, listing.seller, nftContract, tokenId, listing.price);
   }

   /// @notice Withdraws accumulated marketplace fees.
   /// @dev Only the contract owner can withdraw fees.
   /// @dev Uses CEI pattern, zeroes balance before transferring.
      // Function for the owner of contract to withdraw fee
   function withdrawFees() external onlyOwner {
      // Make sure there is fees to withdraw
      if (platformFeesAccumulated == 0) {
         revert NoFeesToWithdraw();
      }

      uint256 fee = platformFeesAccumulated;
      platformFeesAccumulated = 0;

      address currentOwner = owner(); // Cache owner address once

      // Send fee to owner wallet
      (bool success,) =currentOwner.call{value: fee}("");
      if (!success) {
         revert TransferFailed();
      }

      emit FeesWithdrawn(currentOwner, fee); // Uses same cached address
   }

/// @notice Updates the marketplace fee.
/// @dev Only the owner can update the fee.
/// @dev Fee is capped at 10000 bps (100%) to prevent abuse.
/// @param _updatePlatformFee New fee in basis points.
   // Function to update platform fee
   function updatePlatformFee(uint256 _updatePlatformFee) external onlyOwner {
      // Makes sure that the fee isnt too high
      if (_updatePlatformFee > 10000) {
         revert FeeTooHigh();
      }

      // Update the platform fee
      platformFeeBps = _updatePlatformFee;

      emit FeeUpdated(platformFeeBps);
   }
}
