# Contributing to MintVerse

**Group 16** — Solidity · Foundry · OpenZeppelin

---

## Team Members & Contributions

### Development Team

| Name | Contribution |
|------|-------------|
| **thelensbender** | Wrote the full `NFTMarketplace.sol` contract logic and handled testing |
| **Zento** | Wrote `MockNFT.sol` and the deployment script `Deploy.s.sol` |
| **Solomon** | Wrote ~90% of the test suite — `NFTMarketplace.t.sol` and `MockNFT.t.sol` |

### Documentation Team

| Name | Contribution |
|------|-------------|
| **Soffy** | Wrote the NatSpec documentation across the contracts |
| **CJ** | Handled code commenting and wrote Contributing.md |
| **Japheth** | Wrote the README |

---

## How to Contribute

1. Clone the repository
2. Create a new branch for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes and ensure all tests pass:
   ```bash
   forge test
   ```
4. Commit with a clear message:
   ```bash
   git commit -m "feat: describe your change"
   ```
5. Open a pull request against the `main` branch

---

## Code Standards

- Follow the existing NatSpec documentation style
- All new functions must have corresponding tests
- Run `forge coverage` and aim to maintain above 90% line coverage
- Use custom errors over `require` strings
- Follow the Checks-Effects-Interactions pattern for any state-changing functions

