# AgentStamp 🛂

**Daily check-in for Binance Agent ID holders — earn soulbound streak badges.**

AgentStamp is a tiny, fully on-chain dApp built for the **Binance Wallet × BNB Chain
Agent ID Hackathon**. If your wallet holds a Binance **Agent ID** (the `yourname.ai`
identity), you can check in once per UTC day, build a streak, and mint non-transferable
ERC-721 badges at 3, 7, 14, 21 and 30 total check-ins.

- Contract: `contracts/AgentStamp.sol` — one self-contained Solidity file, no dependencies
- Frontend: `frontend/index.html` — one self-contained page, no build step
- Tests: `test/AgentStamp.test.js` — Hardhat, 10 tests, all passing locally

---

## How Agent ID is integrated (the core flow)

Agent ID is not decoration here — it is the **only key that opens the dApp**:

1. Agent ID is an ERC-721 on BNB Chain at
   `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`. An address holds one iff
   `balanceOf(address) > 0` on that contract.
2. `AgentStamp.checkIn()` starts with exactly one gate:
   `require(agentId.balanceOf(msg.sender) > 0)`. No Agent ID → the call reverts,
   no stats are recorded, nothing can be earned.
3. Because Agent ID itself is non-transferable, check-in history and badges are
   anchored to a real, persistent agent identity — you cannot buy, borrow, or
   transfer your way into a streak. Badges inherit the same property: they are
   soulbound, so a 30-day badge genuinely means *that identity showed up 30 times*.

This gives Agent ID a recurring, everyday use: a public, verifiable "proof of
liveness" for agent identities.

## Contract behaviour

| Function | Behaviour |
|---|---|
| `checkIn()` | Holders only, once per UTC day (`block.timestamp / 86400`). Updates total + streak, emits `CheckIn`, mints a badge if a milestone (3/7/14/21/30 total check-ins) is hit. |
| `getStats(user)` | Returns `(totalCheckins, currentStreak, lastCheckinDay, badgesMask)`. `currentStreak` is the *effective* streak — it reads 0 once a full day has been missed. |
| `hasBadge(user, i)` / `badgeTokenId(user, i)` | Badge ownership queries. Token ids are deterministic: user address in the high bytes, milestone index + 1 in the lowest byte. |
| `balanceOf` / `ownerOf` / `tokenURI` | Standard ERC-721 reads for the badge collection. `tokenURI` builds the JSON metadata fully on-chain (Base64 `data:` URI naming the milestone) — no IPFS or server needed. |
| `transferFrom` / `safeTransferFrom` / `approve` / `setApprovalForAll` | **Always revert.** Badges are soulbound. |

Events: `CheckIn(user, day, totalCheckins, currentStreak)`,
`BadgeMinted(user, milestone, tokenId)`, and the standard ERC-721
`Transfer(address(0), user, tokenId)` on badge mint.

## Permissions & safety disclosure

- **No owner, no admin keys, no upgrade path.** There is no `owner()` and no
  function that can pause the contract, change the Agent ID address, mint badges
  manually, or edit anyone's stats. The Agent ID contract address is an
  `immutable` set once in the constructor.
- **The contract never touches user assets.** It has no payable functions, no
  `receive`/`fallback`, and contains no ERC-20/ERC-721 transfer calls on user
  funds. Sending BNB or tokens to it simply reverts / does nothing. The only
  tokens it creates are its own badges, minted directly to the earner.
- **Cost to users:** one small BSC gas fee per check-in (typically a few cents).
  Badges have **no promised value** and can never be sold or transferred.
- Runtime bytecode is ~5.7 KB — small enough to read end-to-end before trusting it.

## Architecture

```
┌────────────────────┐   balanceOf()    ┌──────────────────────────┐
│                    │ ───────────────► │  Binance Agent ID (ERC-721)│
│  AgentStamp.sol    │   gate check     │  0x60b9…022f · BNB Chain   │
│  · check-in stats  │                  └──────────────────────────┘
│  · streaks         │
│  · soulbound       │   getStats() / checkIn()
│    badge ERC-721   │ ◄─────────────── ┌──────────────────────────┐
└────────────────────┘                  │  frontend/index.html       │
                                        │  ethers v6 · window.ethereum│
                                        │  (MetaMask / Binance Wallet)│
                                        └──────────────────────────┘
```

Everything lives on-chain; the frontend is a static page with no backend, no
database, and no analytics. `contracts/MockAgentID.sol` is a **test-only**
stand-in for the real Agent ID contract — never deploy it live.

## Local build & test

Requires Node.js 20+.

```bash
npm install
npx hardhat compile
npx hardhat test
```

Expected: `Compiled 2 Solidity files successfully` and `10 passing`.
The tests deploy `MockAgentID` + `AgentStamp` on the in-process Hardhat network
and verify: non-holders are rejected; one check-in per day; streak increments and
resets across simulated days (Hardhat time helpers); badges mint exactly at
totals 3 and 7; badge transfers/approvals revert; `tokenURI` JSON is correct.

To preview the frontend locally, open `frontend/index.html` in a browser
(it will report "preview mode" until a real contract address is configured).

---

## Deployment checklist (no coding — Remix + wallet)

> You deploy with **your own wallet, on your own machine**. Never share your
> seed phrase or private key with anyone, including in chat. Deployment costs
> a small one-time amount of BNB for gas (keep ~0.01 BNB spare in the wallet).

1. **Prepare the wallet.** Install MetaMask (or use Binance Wallet's browser
   extension), add the **BNB Smart Chain** network (chainId 56), and fund it
   with a little BNB.
2. **Open Remix** at <https://remix.ethereum.org>. Create a file named
   `AgentStamp.sol` and paste in the full contents of `contracts/AgentStamp.sol`.
3. **Compile.** In Remix's Solidity Compiler tab, select compiler **0.8.20**
   (or any 0.8.20+), enable the optimizer (200 runs) if offered, and click
   *Compile AgentStamp.sol*. You should see a green checkmark.
4. **Deploy.** In the *Deploy & Run* tab:
   - Environment: **Injected Provider** (connects your wallet).
   - Contract: **AgentStamp**.
   - In the constructor field, enter the Agent ID contract address:
     `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
   - Click **Deploy** and confirm in your wallet. Wait for the transaction.
5. **Copy the contract address** shown under "Deployed Contracts" in Remix.
   This is your AgentStamp address — it goes in the submission form and the
   frontend.
6. **Verify the source on BscScan.** Open
   `https://bscscan.com/address/<YOUR_ADDRESS>#code`, click *Verify and Publish*,
   choose single-file, compiler 0.8.20, MIT license, and paste the same source.
   (If you enabled the optimizer in Remix, set it here too.) A green
   "Contract Source Code Verified" badge should appear.
7. **Configure the frontend.** Open `frontend/index.html`, find the `CONFIG`
   block at the top of the script (marked `TO FILL AFTER DEPLOYMENT`), and
   replace the zero address in `AGENT_STAMP_ADDRESS` with your deployed address.
8. **Host the page.** Easiest free option: push this repo to GitHub and enable
   **GitHub Pages** (Settings → Pages → deploy from branch, folder `/` or as
   configured) — or any static host. Share that URL.
9. **Test it yourself.** Open the hosted page in your wallet's browser, connect,
   and do one check-in. Confirm your stats show `1` and come back tomorrow for
   day 2. (You need to hold an Agent ID in that wallet for the check-in to work.)
10. **Submit** to the hackathon with the contract address and page URL
    (see `SUBMISSION.md` for ready-to-paste text).

## License

MIT
