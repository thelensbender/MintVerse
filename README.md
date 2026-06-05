# Mintverse — NFT Marketplace

**Group 16** | Solidity · Foundry · OpenZeppelin

---

## What is Mintverse?

Mintverse is a decentralized NFT marketplace built on Ethereum. Users can mint NFTs, list them for sale, buy them with ETH, and cancel their listings. The contract owner earns a platform fee on every sale and can withdraw it at any time.

---

## Contracts

### `MockNFT.sol`
A simple ERC-721 token used for testing.

| Function | Who can call | What it does |
|---|---|---|
| `mint(address to)` | Anyone | Mints an NFT and sends it to `to`. Returns the token ID. |
| `mintTo(address to)` | Owner only | Same as `mint`, but restricted to the contract owner. |
| `nextTokenId()` | Anyone | Returns the next token ID to be minted (also = total supply). |

Token IDs start at `0` and increment by `1` with each mint.

---

### `NFTMarketplace.sol`
The core marketplace contract. Inherits `Ownable` from OpenZeppelin.

#### Key State Variables

| Variable | Type | Description |
|---|---|---|
| `platformFeeBps` | `uint256` | Platform fee in basis points (e.g. `250` = 2.5%) |
| `platformFeesAccumulated` | `uint256` | Total fees held in the contract, ready to withdraw |
| `listings` | `mapping(address => mapping(uint256 => Listing))` | Stores all listings by NFT contract address and token ID |

Each `Listing` stores: `seller`, `price`, and `active` (bool).

#### Functions

| Function | Who can call | What it does |
|---|---|---|
| `listNFT(nftContract, tokenId, price)` | Token owner | Lists an NFT for sale at a set price in ETH |
| `buyNFT(nftContract, tokenId)` | Anyone (not the seller) | Purchases a listed NFT by sending the exact ETH price |
| `cancelListing(nftContract, tokenId)` | Seller | Removes an active listing |
| `withdrawFees()` | Owner only | Sends all accumulated platform fees to the owner wallet |
| `updatePlatformFee(newFee)` | Owner only | Updates the platform fee (max `10000` bps = 100%) |

#### How fees work
When a sale goes through, the contract takes `price × platformFeeBps / 10000` as a fee. The remainder goes directly to the seller. Fees sit in the contract until the owner calls `withdrawFees()`.

#### Events

| Event | Emitted when |
|---|---|
| `NFTListed` | An NFT is listed |
| `NFTSold` | An NFT is sold |
| `ListingCancelled` | A listing is cancelled |
| `FeesWithdrawn` | Owner withdraws fees |
| `FeeUpdated` | Platform fee is updated |

#### Errors (reverts)

| Error | Trigger |
|---|---|
| `PriceMustBeAboveZero` | Listing price is `0` |
| `NotTokenOwner` | Caller doesn't own the NFT they're trying to list |
| `AlreadyListed` | NFT is already listed |
| `NotApproved` | Marketplace doesn't have approval to transfer the NFT |
| `NotListed` | Trying to buy or cancel a listing that doesn't exist or is inactive |
| `NotSeller` | Caller tries to cancel a listing they didn't create |
| `SellerCannotBuyOwnNFT` | Seller tries to buy their own listed NFT |
| `IncorrectPaymentAmount` | Buyer sends the wrong ETH amount |
| `NoFeesToWithdraw` | Owner calls `withdrawFees()` when balance is `0` |
| `FeeTooHigh` | New platform fee exceeds `10000` bps |
| `TransferFailed` | ETH transfer to seller or owner fails |

---

## Deployment (`DeployScript.sol`)

The deploy script uses Foundry's `Script` module.

```bash
forge script script/DeployScript.sol --broadcast --rpc-url <RPC_URL>
```

By default, it uses the Anvil test private key. For a real deployment, set your own:

```bash
PRIVATE_KEY=0xYourKey forge script script/DeployScript.sol --broadcast --rpc-url <RPC_URL>
```

The script deploys `MockNFT` first, then `NFTMarketplace` with a platform fee of `0` bps. Update the fee after deployment with `updatePlatformFee()` if needed.

---

## Running Tests

```bash
forge test
```

To see detailed output:

```bash
forge test -vvv
```

### Test Coverage

**`MockNFTTest`**
- Minting to self and to another address
- Token ID incrementing correctly
- `nextTokenId()` tracking
- `mintTo()` restricted to owner
- Transfers and approvals

**`NFTMarketplaceTest`**
- `listNFT`: success, zero price, non-owner, duplicate listing
- `buyNFT`: success, not listed, wrong ETH, seller buying own NFT
- `cancelListing`: success, non-seller, already inactive
- `withdrawFees`: success, not owner, no fees
- `updatePlatformFee`: success, not owner, fee too high
- Fee accumulation and seller payout calculations
- Edge case: buying a cancelled listing
- Event emission for `NFTListed`, `NFTSold`, `ListingCancelled`

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

Install dependencies:

```bash
forge install
```
