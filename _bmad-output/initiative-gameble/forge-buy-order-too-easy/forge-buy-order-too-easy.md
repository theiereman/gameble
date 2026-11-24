# Forged idea: buy orders that keep players talking

Outcome: hardened, 2026-11-24. Amends `../forge-market-volume/forge-market-volume.md` (shipped in 1.4.0-rc.2) and `../spec-gameble/market-economy.md`, Buy orders, The shop, Rejected.

**Amended 2026-11-24 (author, in `../change-market-by-rarity/`):** auctions stay open to every rarity; edition orders are dropped; any auction opened at or below eligible orders turns them into bids, whatever the rarity. The direct sale stays Common and Uncommon only. Where the decisions below disagree, this line wins.

## Problem

Buy orders, one-press direct sales and the Archive shop let PiCoins fill any gap: rich players can buy everything, and an anonymous order filled from the Confier table replaces the trades where players talk.

## Decisions

- **What to protect:** trades that need talk (negotiation), not trade volume.
- **Split by rarity:**
  - Common and Uncommon sell only to orders (or are entrusted), never at auction.
  - Rare and above sell only at auction, never to an order in one press.
- **Common and Uncommon orders** can target one precise edition as well as the game across editions; collectors compete by order price, best first. Still one open order per player and game `[assumption]`.
- **Rare and above orders are signals:** the price is held and shown to sellers, but there is no direct sale. A seller can open an auction backed by the best order. Every order on that game reaching the copy's rarity then becomes a bid with its price as its maximum, and the auction prices them as usual. Money is never held twice. Each owner is told. An order never bids on an auction that was not opened against it.
- **A beaten order ends** and its money returns, like an outbid maximum `[assumption]`.
- **Archive shop:** a per-player cap per period above Uncommon (for example 1 Rare a day, 1 Epic a week), as a back-office setting. Common and Uncommon stay uncapped. The shop stays the PiCoin sink.

## Reversed

- "An order sale always opens an auction" (rejected 2026-11-19, because the seller lost the instant sale) now applies to Rare and above. The seller gets a guaranteed floor at the best order's price, after the auction's duration.
- "An order bids automatically" (rejected) is allowed only on an auction opened against orders. This trade-off was chosen over double holding and last-minute sniping by a second order.

## Rejected

| Rejected | Why |
|---|---|
| Block the order for the last card of a set | The rarity split covers it; blocking it hurts the player who needs that card most |
| Direct sale for every rarity (today) | Money and one press replace the talk for the cards that matter |
| Rare and above: order removed, or only an alert | Buyer has no credible way to show demand |
| Only the best order becomes a bid, the others kept open | Their owners hold money twice, and a second order snipes at the last minute |
| Other orders cancelled when the auction opens | Their owners lose their place and have to bid again |
| Shop closed above Uncommon | Removes the main PiCoin sink (destroyed/created at 8%) |
| Shop unchanged | Money bypasses every other rule |
| No auction and no edition order for Common/Uncommon | Collectors of a season's edition lose every path |

## Weak points that survived

- A seller's alt can back an auction with a high fake order and force rivals above it. Extend the alt signals to order-backed auctions.
- The automatic bidding is limited, but it is still automatic.
- Sought-after Commons lose the auction: edition orders replace it, untested at about 30 players.
- This changes a design already in 1.4.0-rc.2: the Confier wanted table, the best-order banner, Mettre en vente for Common and Uncommon, and `SellToOrder`.

## Forge separately

- Automatic friend trades (4 duplicates for 4) and trade suggestions.
