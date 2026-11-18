# Hackathon Submission — AgentStamp

*Ready-to-paste materials for the Binance Wallet × BNB Chain "Agent ID Hackathon"
(developer track). Replace every `<PLACEHOLDER>` after deployment.*

---

## Project name

AgentStamp

## One-line description

Daily check-in dApp exclusively for Binance Agent ID holders — check in once a day, build a streak, and earn soulbound badges at 3 / 7 / 14 / 21 / 30 check-ins.

## Agent ID usage description

AgentStamp's core function is gated entirely by Binance Agent ID. The AgentStamp
smart contract (BNB Chain) stores the official Agent ID contract address
(0x60b9262456de011f7d15a54cdd8c48baaa8b022f) as an immutable set at deployment,
and every call to `checkIn()` begins by reading `balanceOf(msg.sender)` on the
Agent ID ERC-721 contract: if the caller does not hold an Agent ID, the
transaction reverts and nothing is recorded. Holders can check in once per UTC
day; the contract tracks each identity's total check-ins and current streak and
automatically mints a soulbound (non-transferable) ERC-721 badge when the total
reaches 3, 7, 14, 21 or 30. Badge metadata is generated fully on-chain.

Because Agent ID is itself non-transferable, a streak cannot be bought, borrowed,
or faked by moving tokens between wallets — a 30-day badge is verifiable proof
that one specific agent identity was active on 30 different days. In short:
Agent ID is not a login decoration for AgentStamp, it is the eligibility rule,
the identity anchor, and the anti-sybil mechanism for the whole product. The
frontend mirrors this: it reads the connected wallet's Agent ID balance first,
shows holder status prominently, and only enables the check-in button for
holders.

The contract has no owner or admin functions and never custodies or transfers
user assets; the Agent ID address can never be changed after deployment.

## Links & addresses

| Field | Value |
|---|---|
| Website / dApp | `<PLACEHOLDER — hosted frontend URL, e.g. GitHub Pages>` |
| Smart contract (BNB Chain) | `<PLACEHOLDER — deployed AgentStamp address>` |
| Verified source (BscScan) | `<PLACEHOLDER — https://bscscan.com/address/<address>#code>` |
| Source code repository | `<PLACEHOLDER — repository URL>` |
| Agent ID used | `dizzy1998.ai` (holder wallet, for demo check-ins) |
| Agent ID contract (official) | `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` |

## Demo notes for judges

- Connect any wallet holding an Agent ID on BNB Chain → the page shows holder
  status, total check-ins, streak and badges, and enables **Check In Today**.
- Connect a wallet *without* an Agent ID → check-in stays disabled and the
  contract itself reverts any direct `checkIn()` call.
- One check-in per UTC day is enforced on-chain; milestone badges (3/7/14/21/30)
  mint automatically inside the same transaction as the qualifying check-in.

---

## Community Promotion Award — draft X posts

### Post 1 (English)

> 🛂 Introducing AgentStamp — a daily check-in dApp built only for Binance Agent ID holders.
>
> Hold an Agent ID (yourname.ai)? Check in once a day on BNB Chain, keep your streak alive, and earn soulbound badges at 3 / 7 / 14 / 21 / 30 check-ins. No Agent ID, no check-in — the contract checks your ID balance before anything else.
>
> Badges are non-transferable proof you showed up. They carry no promised value — just on-chain bragging rights for consistent agents. The contract has no admin keys and never touches user funds.
>
> Try it: <PLACEHOLDER — dApp URL>
>
> #BinanceWalletHackathon #AgenticWallet

### Post 2 (Chinese)

> 🛂 我给币安 Agent ID 做了一个专属签到应用：AgentStamp。
>
> 只要你的钱包持有 Agent ID（就是那个 xxx.ai 身份），就能在 BNB 链上每天签到一次，攒连续打卡天数，在累计 3 / 7 / 14 / 21 / 30 次时自动领到一枚灵魂绑定徽章 NFT。没有 Agent ID 就签不了——合约在签到前会先查你的 ID 持有状态，徽章也不能转让，杜绝买号刷量。
>
> 说清楚：徽章只是链上打卡证明，不承诺任何价值；签到每笔只花几分钱 gas。合约没有管理员权限，也绝不经手用户资产，代码已在 BscScan 开源验证。
>
> 体验地址：<PLACEHOLDER — dApp URL>
>
> #BinanceWalletHackathon #AgenticWallet
