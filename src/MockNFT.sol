// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockNFT is ERC721, Ownable {
   uint256 public _nextTokenId;
   mapping(uint256 => string) private _tokenURIs;

   constructor() ERC721("Mock NFT", "MNFT") Ownable(msg.sender) {}

   function mint(address to, string memory uri) external returns (uint256) {
      uint256 tokenId = _nextTokenId;
      _safeMint(to, tokenId);
      _tokenURIs[tokenId] = uri;
      _nextTokenId++;
      return tokenId;
   }

   function tokenURI(uint256 tokenId) public view override returns (string memory) {
      return _tokenURIs[tokenId];
   }
}