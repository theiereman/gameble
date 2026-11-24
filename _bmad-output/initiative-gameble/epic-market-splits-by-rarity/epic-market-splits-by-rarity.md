---
tracker_id: ""
key: ""
type: epic
title: "The market splits by rarity"
parent: initiative-gameble
covers: ["CAP-30", "CAP-45", "CAP-46", "CAP-47", "CAP-48"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# The market splits by rarity

## Description

Money and one press must not fill every gap in a collection, and an anonymous order must not replace the trades where players talk. A direct sale to a buy order stays for Common and Uncommon only. An auction opened at or below eligible orders, whatever the rarity, turns those orders into bids: the best leads with its PiCoins held once, the beaten end and are refunded. The Archive shop caps what one player buys above Uncommon. The change proposal `change-market-by-rarity` and the forge `forge-buy-order-too-easy` hold the reasoning; the spec, `market-economy.md`, AD-42, AD-44, AD-45, AD-58, AD-59 and AD-60 hold the amended rules, and EXPERIENCE.md the screens. This epic builds them on top of market volume, before release 1.4.0.

## Outcome

For the author: rich players can no longer buy every card they miss, and a Rare and above is contested by named rivals even when an order backs it. The market's weekly share of cards changing hands (`spec-gameble.md`, market volume measure) is read four weeks after release, as the market volume epic set.

## Requirements

- R1 — The settings version holds, for each rarity above Uncommon, an Archive purchase cap and its window in days (at least 1; defaults 1 Rare a day, 1 Epic a week), bounded by `ChangeSettings` and edited in the back-office; `game_market_orders` takes the statuses `bid` and `beaten` and `game_market_notices` the kinds `order_leads` and `order_beaten`; an index on Archive withdrawals by player and time. (CAP-48, CAP-46; AD-42, AD-44, AD-58, AD-60; `market-economy.md`, The shop, Setting bounds)
- R2 — `ListCard` converts, in the one transaction that opens the auction, the eligible orders whose price is at or above the starting price: the best becomes the leader with its held PiCoins moved to the listing (never held twice), the others become `beaten` with their PiCoins released, one bid row per converted order, the price from `AuctionMath`; an order below the start stays open with its `listed_above_order` notice; `PlaceBid` and `CloseAuction` never read orders. (CAP-30, CAP-46, CAP-47; AD-44, AD-58; `market-economy.md`, Buy orders)
- R3 — The converted orders' owners are told (`order_leads`, `order_beaten`, with the push), their wanted rows refresh, MES ORDRES reads EN ENCHÈRE, GAGNÉE and DÉPASSÉE, and the bid history names the converted bidders as any bidders. (CAP-46; AD-44, AD-45; EXPERIENCE.md, MES ORDRES row)
- R4 — Mettre en vente shows, whatever the rarity, the eligible orders above the auction form and prefills the start at the lowest eligible order's price, with the line saying what the auction starts at and which orders it leaves open; a refusal for a changed order follows the existing rule. (CAP-30, CAP-47; EXPERIENCE.md, Mettre en vente, Orders behind an auction)
- R5 — `SellToOrder` serves a Common or Uncommon only (`:direct_sale_not_for_rarity`); the best-order banner and VENDRE MAINTENANT show for a Common or Uncommon copy only. (CAP-47; AD-59; EXPERIENCE.md, Best-order banner and direct sale)
- R6 — The Confier wanted table offers a Common or Uncommon line its three choices and a Rare and above line two (ENCHÈRES, CONFIER), with the prefill of its rarity; `ApplyWantedChoices` refuses an `order` line above Uncommon (`:invalid_choices`) and its auction step is `ListCard`'s with the conversion. (CAP-45; AD-59; EXPERIENCE.md, Confier wanted table)
- R7 — `BuyFromArchives` refuses a purchase past the rarity's cap in its window (`:archive_cap_reached`); the shop, the market grid's offers, the order form's offers and the confirmation show what is left of the cap and refuse past it, with nothing charged; Commons and Uncommons are uncapped. (CAP-48; AD-60; EXPERIENCE.md, Shop screen, Archive purchase confirmation)
- R8 — The order form says that an order becomes an auction when a player lists at or below its price; the back-office alt signals read converted orders through the tied-bids signal. (CAP-46; AD-63; EXPERIENCE.md, Order form)

## Done when

1. A holder opens an auction at or below two eligible orders: the best order leads at the price `AuctionMath` gives, its PiCoins are held once and now belong to the auction, the second order is beaten and refunded in the same transaction, both owners are told, and MES ORDRES shows EN ENCHÈRE and DÉPASSÉE.
2. A Rare, an Epic or a Légendaire cannot be sold to an order in one press: the operation refuses it and no screen offers it, in Mettre en vente and in the Confier wanted table; a Common or Uncommon still sells in one press.
3. An order below the auction's start stays open and its owner is told, as before.
4. A player cannot buy more Archive copies of a rarity above Uncommon than its cap allows in its window, from the shop, the market grid or the order form, and the refusal charges nothing; an administrator edits the caps.
5. The nightly reconciliation balances with converted orders, and the tied-bids signal flags an auction led by an order from an account tied to its seller.
6. Release 1.4.0 ships with this rule.

## Boundaries

The market's order and auction money paths, the Archive shop's purchase and the screens that draw them. Not in this epic: edition-targeted orders (weighed and dropped, 2026-11-24); automatic friend trades and trade suggestions (forged separately); selling Légendaires to the Archives; the later economy charts.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, spec capabilities CAP-30, CAP-45 to CAP-48
- change — _bmad-output/initiative-gameble/change-market-by-rarity/change-market-by-rarity.md
- forge — _bmad-output/initiative-gameble/forge-buy-order-too-easy/forge-buy-order-too-easy.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-30, CAP-45 to CAP-48
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md, Buy orders, The shop, Setting bounds, Known limits, Rejected
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-42, AD-44, AD-45, AD-58, AD-59, AD-60 (the "Amended 2026-11-24" lines)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Mettre en vente (Orders behind an auction), Best-order banner and direct sale, Confier wanted table (Rarity), MES ORDRES row (Conversion), Order form (Conversion), Shop screen and Archive purchase confirmation (Purchase cap), Flow 13

## Notes

- Decision (2026-11-24, author): release 1.4.0 is held until this epic is on `develop`; no player ever sees the old rule, and no order exists in production, so nothing is migrated.
- Decision (2026-11-24, author): an auction opened at or below eligible orders converts them, whatever the rarity; the direct sale stays for Common and Uncommon only; edition orders are dropped.
- Decision (2026-11-24, author): a beaten order ends and its PiCoins return; it does not reopen.
- Decision (2026-11-24): entry 1 is the contract every lane opens on; the conversion (2) is the one new money path and comes before the screens that read it (3); the shop cap (4) runs beside 2 and 3, since it touches `BuyFromArchives`, the settings and the shop only.
- Assumption: the shop cap values (1 Rare a day, 1 Epic a week) are starting values the author sets in the back-office.
- Assumption: the copy marked "to approve" in EXPERIENCE.md is approved by the author in the pull request.
- Open question: the converted leader is named on the Annonce as any bidder is, so a seller learns who placed the order that led; the banner row's "the seller never learns who placed the order" holds for the direct sale only.
- Unknown: whether the ledger's unique indexes on a listing's holds accept the conversion's `hold` on the listing right after an order's `release`; entry 2 checks it first.
- Waits on epic 46 because: the orders table, `EligibleOrders`, `SellToOrder`, `ApplyWantedChoices`, the Archive shop and its settings, MES ORDRES and the order notices are what it amends.
