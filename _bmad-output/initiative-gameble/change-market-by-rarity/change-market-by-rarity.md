---
type: change-proposal
title: "The market splits by rarity"
date: 2026-11-24
trigger: _bmad-output/initiative-gameble/forge-buy-order-too-easy/forge-buy-order-too-easy.md
mode: batch
scope: major
status: approved
approved: 2026-11-24, by the author, after one revision (auctions kept for every rarity, edition orders dropped)
---

# Sprint Change Proposal: the market splits by rarity

## 1. Issue summary

**Problem.** In the market-volume design, PiCoins and one press fill any gap in a collection.
- A buy order is served in one press by any player entrusting a copy, since the Confier wanted table prefills the sale.
- The Archive shop sells Rares and Epics at once with no limit.

A rich player can buy every card they miss, and an anonymous order replaces the trades where players talk, which is the interaction the author wants to keep.

**Type.** A strategic correction from the product owner, before release.

**How it was found.** The author questioned the buy order and the instant sale on 2026-11-24. The source of the decisions below is the forge session `forge-buy-order-too-easy`, hardened the same day and amended in this proposal (see the log).

**Evidence.**
- Confier sets wanted copies apart. The wanted table prefills À L'ORDRE when the order is at 90% of the average price or more, and one press validates. The seller never learns who ordered (EXPERIENCE.md, Confier wanted table, Prefill).
- `BuyFromArchives` has no limit. CAP-48 says "There is no daily purchase limit".
- Production on 2026-11-19 had 50,822 idle PiCoins and a median wallet of 965.
- The epic is built and tagged in 1.4.0-rc.2. Production runs v1.3.7, so no player has used orders yet.

## 2. Impact analysis

### Checklist

| Item | Status | Finding |
|---|---|---|
| 1.1 Trigger | [x] | Forge `forge-buy-order-too-easy`; it amends `epic-market-volume`, whose entries are all built. |
| 1.2 Problem | [x] | Strategic correction: money and one press replace player interaction for the cards that matter. |
| 1.3 Evidence | [x] | Above. |
| 2.1 Current epic | [x] | Market volume is built. It does not ship as designed: 1.4.0 is held (author, 2026-11-24). |
| 2.2 Epic changes | [!] | One new epic amends market volume. Market volume's text stays as the record of what was built. |
| 2.3 Other epics | [x] | `epic-duels-alpha` ships in the same 1.4.0 and waits with it. `epic-economy-charts` reads sales and the destroyed figure, whose sources are unchanged. `epic-trade-suggestions` is untouched (forge it separately). |
| 2.4 Obsolete or new epics | [!] | None obsolete; one new epic. |
| 2.5 Order | [!] | The new epic comes before the 1.4.0 cut. |
| 3.1 Spec | [!] | CAP-30, CAP-45, CAP-46, CAP-47, CAP-48 and `market-economy.md` are amended; two Rejected rows are reversed. |
| 3.2 Architecture | [!] | AD-42, AD-44, AD-45, AD-58, AD-59 and AD-60 are amended. AD-58's "an order never touches a listing or a bid" is reversed for auctions opened at or below orders. |
| 3.3 UX | [!] | Mettre en vente, the best-order banner, the Confier wanted table, the order form, MES ORDRES, the shop and the purchase confirmation change; so do Flow 13 and the copy deck. |
| 3.4 Other | [x] | No order exists in production, so there is nothing to migrate. Auctions are unchanged for every rarity. |
| 4.1 Direct adjustment | Viable | A new epic on top of what is built. Effort: medium. Risk: medium (one new money path). |
| 4.2 Rollback | Not viable | The change reuses orders, the wanted table and the shop. Only their rules change. |
| 4.3 MVP review | N/A | Post-launch; the market-volume outcome stays. |
| 4.4 Path | [x] | Direct adjustment, with 1.4.0 held. |

### Epic impact

- **Market volume** (built, in 1.4.0-rc.2): its direct sale, wanted table, Mettre en vente and shop are amended by the new epic.
- **Duels alpha** (1.4.0): no code change; its release waits.
- **New epic "The market splits by rarity"**: five entries (4.6).

### Technical impact

- **Direct sale for Common and Uncommon only.** `SellToOrder` refuses a Rare and above (`:direct_sale_not_for_rarity`). `ApplyWantedChoices` refuses an `order` line above Uncommon.
- **Order-backed auction, every rarity.** When `ListCard` opens an auction, every order in `EligibleOrders` for the copy whose price is at or above the starting price becomes a bid:
  - The best leads, and its hold moves to the listing (never held twice).
  - The second sets the price through `AuctionMath`.
  - The other converted orders are beaten at once: their PiCoins return, and they end.
  - An eligible order below the start is not converted. It stays open with its `listed_above_order` notice, as today.
  - This fits AD-44 (only the leader's maximum is held). It adds the order statuses `bid` and `beaten`, bid rows owned by the order owners, and two notice kinds.
  - `PlaceBid` and `CloseAuction` stay unaware of orders.
- **Shop cap.** The settings version gains a per-rarity purchase cap with a window. `BuyFromArchives` counts the player's withdrawals of that rarity in the window (`:archive_cap_reached`). An index on withdrawals by player and time, built concurrently.
- **Alt signals.** `tied_bids` reads bid rows, so it covers converted orders. `order_sales_to_tied_buyer` now sees only Commons and Uncommons.
- **Migrations.** Expand/contract: the order status check widened, the settings columns, the withdrawals index.

## 3. Recommended approach

**Direct adjustment, with 1.4.0 held** (author, 2026-11-24). The new epic is built on `develop` before the release cut, so no player ever sees the old rule and no order needs migrating. Auctions do not change.

- **Effort:** medium, five entries; one new money path (the conversion in `ListCard`).
- **Risk:** medium. The conversion reuses `AuctionMath`, the bid rows and the ledger's hold and release.
- **Timeline:** duels alpha's 1.4.0 waits for this epic.
- **Rejected:** ship 1.4 as is and change it in 1.5 (orders to migrate, a rule taken back from players); a guard in 1.4 and the rest in 1.5 (two migrations of the same rules).

## 4. Detailed change proposals

### 4.1 Spec: `spec-gameble/spec-gameble.md`

**CAP-30**

OLD: The listing form shows the best eligible buy order (CAP-47).

NEW: The listing form shows the eligible buy orders. An auction whose starting price is at or below eligible orders turns each of them into a bid with its price as its maximum. The best order leads, the auction prices them as any bids, and the beaten orders end with their PiCoins returned; their owners are told.

Rationale: an order gives the seller a floor, and the card still goes through a contest between named rivals.

**CAP-45**

OLD: Each line is prefilled with the likeliest choice: sell at the order's price, start an auction at a higher price with its duration, or entrust anyway.

NEW: Each line offers the choices its rarity allows. For a Common or Uncommon: sell at the order's price, start an auction, or entrust. For a Rare and above: start an auction (which turns the eligible orders into bids, CAP-30), or entrust. Each line is prefilled with the likeliest one.

**CAP-46**

OLD: An order never bids on an auction.

NEW: An order never bids on an auction already open. It becomes a bid only on an auction opened at or below its price (CAP-30).

**CAP-47**

OLD:
- A direct sale to an order is instant, pays no stamp and pays the commission …
- Listing higher opens an ordinary auction with its stamp (CAP-30), and the order's owner is notified; the order stays open until a direct sale consumes it.

NEW:
- A direct sale to an order is for a Common or Uncommon only: instant, no stamp, the commission paid …
- A holder of a Rare and above sells it at auction. Opening the auction at or below the eligible orders turns them into bids (CAP-30). Opening it above an order leaves that order open, and its owner is notified.

**CAP-48**

OLD: There is no daily purchase limit.

NEW: A player buys at most a set number of copies of each rarity above Uncommon per period (a setting, for example 1 Rare a day, 1 Epic a week); Commons and Uncommons have no limit.

### 4.2 Spec: `spec-gameble/market-economy.md`

- **Buy orders:**
  - The direct-sale row becomes "Common and Uncommon only …".
  - New row, **Order-backed auction**: "An auction opened at or below eligible orders turns each into a bid at its price; the best leads; the beaten end, their PiCoins returned; an order below the start stays open".
- **The shop:** "There is no daily purchase limit" becomes "Above Uncommon, a per-player cap per period (starting values: 1 Rare a day, 1 Epic a week); Commons and Uncommons uncapped".
- **Rejected:**
  - Remove "An order sale always opens an auction". For a Rare and above, the sale goes through an auction, which the orders back.
  - Narrow "An order bids automatically on open listings" to "on a listing already open".
  - Add the forge's rejected options: blocking the last card of a set, the direct sale for every rarity, the shop closed above Uncommon, the shop unchanged, and edition orders (no longer needed once auctions stay open to every rarity).
- **Known limits:** add "A seller's alt can back an auction with a high order, forcing rivals above it (covered by the tied-bids signal)".
- **Setting bounds:** the shop caps, at least 1, with their window in days.

### 4.3 Architecture: `architecture-gameble/architecture-gameble.md`

Each AD below gets an "Amended 2026-11-24" line.

- **AD-42.** The settings version gains `archive_cap_<rarity>` and `archive_cap_window_days_<rarity>` for each rarity above Uncommon; `ChangeSettings` bounds them.
- **AD-44.**
  - `ListCard` takes the seller's bank lock, then the bank locks of every converted order's owner in ascending player id, then the order rows. It converts the eligible orders at or above the starting price.
  - Their `release` and the leader's `hold` go in one `Ledger.post`, with one `game_market_bids` row per converted order, outcome `leader` or `beaten`.
  - The best converted order becomes `bid`, the others `beaten`. An eligible order below the start keeps its `listed_above_order` notice.
  - `CardListed` carries the converted orders.
  - New notice kinds: `order_leads` and `order_beaten`.
  - `PlaceBid` and `CloseAuction` still never read orders.
- **AD-45.** `CardListed` is also heard by the order notices and their push, and by the wanted refresh of every converted order's owner. `WantedChoicesApplied` does the same for its listings.
- **AD-58.**
  - Statuses add `bid` and `beaten`.
  - "An order never touches a listing or a bid" becomes "only `ListCard`'s conversion moves an order into a bid".
  - A `bid` order's PiCoins are the listing leader's hold. Outbid, they return as any maximum does, and the order stays `bid`, the bid row telling the outcome.
- **AD-59.** `SellToOrder` refuses a Rare and above (`:direct_sale_not_for_rarity`). `ApplyWantedChoices` refuses an `order` line above Uncommon (`:invalid_choices`), and its auction step is `ListCard`'s step with the conversion.
- **AD-60.** `BuyFromArchives` refuses a purchase past its rarity's cap within the window (`:archive_cap_reached`). An index on withdrawals by player and `created_at`. The shop reads what is left for the player.

### 4.4 UX: `ux-gameble/EXPERIENCE.md`

- **Mettre en vente.**
  - For a Common or Uncommon, the best-order banner and VENDRE MAINTENANT stay above the auction form, as today.
  - For a Rare and above, there is no banner. The form shows "<n> ordres d'achat, le meilleur à <amount>" and prefills the start at the lowest eligible order's price, so every order converts (with one order, its price, which secures it as the floor).
  - A line under the start says "Avec ces ordres, l'enchère part à <price>, menée par un ordre". A start above an order leaves that order open, and the line says so.
- **Best-order banner and direct sale.** For Common and Uncommon only.
- **Confier wanted table.**
  - Common or Uncommon lines keep their three choices. Rare and above lines get two: ENCHÈRES or CONFIER.
  - Prefill for a Rare and above: ENCHÈRES when orders exist, starting at the lowest eligible order's price; else the rule as today without À L'ORDRE.
- **Order form.** For a price reaching a Rare and above, the sentence "Pour une Rare et plus, votre ordre devient une enchère quand un joueur la met en vente."
- **MES ORDRES row.** New status chips: EN ENCHÈRE (the auction linked; after it ends, GAGNÉE or DÉPASSÉE with "PiCoins rendus").
- **Shop screen and Archive purchase confirmation.** Each rarity above Uncommon shows what is left ("1 Épique par semaine · prochaine le <date>"). The confirmation refuses past the cap.
- **Flow 13.** The example's Pyre becomes an Uncommon. A Rare variant shows the auction opening with Inès's order leading.
- **Copy deck.** The new lines in French and English, marked "to approve".

### 4.5 UX: `ux-gameble/DESIGN.md`

The new MES ORDRES chips use the existing status chip styles. No new component.

### 4.6 Epics and stories

**New epic "The market splits by rarity"**, before the 1.4.0 cut. It waits on market volume (built) and covers CAP-30 and CAP-45 to CAP-48.

| # | Entry | Depends on |
|---|---|---|
| 1 | Contract: order statuses `bid` and `beaten`, notice kinds, the shop cap settings with their back-office fields, the withdrawals index, event keys for converted orders | none |
| 2 | Order-backed auction: `ListCard` converts eligible orders, notices and their push, MES ORDRES statuses, the bid history naming the converted bidders, Mettre en vente's orders line and prefilled start | 1 |
| 3 | Direct sale for Common and Uncommon only: `SellToOrder` refuses a Rare and above; the banner for Common and Uncommon only; the Confier wanted table's choices and Prefill per rarity; `ApplyWantedChoices`' gate and its auction line converting orders | 2 |
| 4 | The Archive shop cap: `BuyFromArchives`, the shop, the confirmation, the order form and the market grid's offers | 1 |
| 5 | Refactor sweep | all |

Also:
- Market volume's Notes get "Amended before release by change-market-by-rarity (2026-11-24)", and its entries stay `built`.
- The initiative lists the new epic before 1.4.0.

## 5. Implementation handoff

**Scope: major.** AD-58's invariant is reversed and a new money path opens; four capabilities change rule; the release is held.

| Who | Does what |
|---|---|
| Author (product owner) | Approves this proposal and the copy marked "to approve"; sets the shop cap values; cuts 1.4.0 after the epic. |
| `bmad-spec` | Applies 4.1 and 4.2, with the forge as input. |
| `bmad-architecture` | Applies 4.3. |
| `bmad-ux` | Applies 4.4 and 4.5. |
| `bmad-ticket` | Applies 4.6. |
| `bmad-build` | Builds entries 1 to 5. |

**Success criteria**
1. A Rare and above is never sold to an order in one press. The operations refuse it, and no screen offers it.
2. An auction opened at or below orders starts with the best order leading, at the price `AuctionMath` gives. Each order's PiCoins are held at most once, and the beaten orders' PiCoins return in the same transaction.
3. A player cannot buy more Archive copies of a rarity above Uncommon than its cap allows in its window.
4. The nightly reconciliation balances with converted orders.
5. 1.4.0 ships with the new rule.

## Approval and handoff log

- 2026-11-24: drafted in batch mode. Author choices: 1.4.0 held for this change; a beaten order ends, its PiCoins returned.
- 2026-11-24: revised before approval (author). Auctions stay open to every rarity, which reverses the forge's "Common and Uncommon never at auction". Edition orders are dropped, since their reason went with it. The order-backed auction applies to every rarity. The new epic shrinks from seven entries to five.
- 2026-11-24: approved by the author. Scope: major; routed to the product manager and the architect: sections 4.1 and 4.2 through `bmad-spec`, 4.3 through `bmad-architecture`, 4.4 and 4.5 through `bmad-ux`, then 4.6 through `bmad-ticket`. Nothing applied yet.
- 2026-11-24: sections 4.1 and 4.2 applied to the spec and `market-economy.md` (CAP-30, 45, 46, 47, 48; Buy orders, The shop, Setting bounds, Known limits, Rejected); section 4.3 applied to AD-42, AD-44, AD-45, AD-58, AD-59 and AD-60; sections 4.4 and 4.5 applied to EXPERIENCE.md (Mettre en vente, banner, Confier wanted table, MES ORDRES, Order form, Shop, purchase confirmation, Flow 13; DESIGN.md needs no change); section 4.6 applied through `bmad-ticket`: epic 48 `epic-market-splits-by-rarity` (release 1.4.0, after epic 46) with five entries, notes added to epics 46 and 45. Applied directly, without the skills' interactive reviews. Nothing built.
- 2026-11-24: Flow 13's example card changed from a Rare to a Peu commune (order 60, average 56, entrusted 20, received 54), since a Rare no longer sells to an order in one press; a Rare variant was added.
