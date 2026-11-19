# Market and economy

Numbers and rules for CAP-29 to CAP-38 and CAP-44 to CAP-49. Every value is a starting setting editable from the back-office (CAP-35). Simulated evidence and the full reasoning are in `../forge-market-economy/` and `../forge-market-volume/`.

## Words

| Player-facing | Meaning | In code |
|---|---|---|
| PiCoin | The only currency | PiCoin |
| 100-6-Tron, Réacteur des Briétés | Mints PiCoins and destroys stamps and commissions | Mint, never "bank", which is the capsule reserve |
| Archives de la Confrérie | Keeps entrusted cards | Archives |
| Confier à la Confrérie / Entrust to the Brotherhood | Giving cards for PiCoins. Prefer the verb: "cartes confiées" | entrust |
| *Timbre Fiscal du Gamebler* / Gamebler's Tax Stamp | Listing fee | stamp |
| *Effort de la Confrérie* / Brotherhood Effort | Sale commission | commission |
| Mon maximum / My maximum | A bidder's ceiling. Never "automatic" | maximum |

The Brotherhood announces and justifies each fee in its tone (`brotherhood-tone.md`). Issue #57's examples are tone samples: a contribution on friend trades can never become a mechanic.

## Money

PiCoins are minted only when a card is entrusted. Stamps, commissions and PiCoins spent in the shop (Archive cards, slots) are destroyed. Nothing else creates or destroys them, and the Brotherhood never injects any. Amounts are whole PiCoins, shown compact from 1,000 (12k), never with a euro sign. Every amount was divided by 100 on 2026-11-15, the market already open: balances, ledger, listings, bids and history were converted by a migration.

## Values by rarity

| | Common | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| Entrustment pays | 10 | 20 | 50 | 150 | 1,000 |
| Listing stamp | 1 | 10 | 20 | 50 | 100 |
| Minimum price | 13 | 34 | 78 | 223 | 70,000 |
| Target for a standard player | minutes | minutes | a few hours | 1 to 2 days | about 40 days |

- The rarity is the one minted on the copy, whatever its edition.
- Commission: 10% of the final price, paid by the seller.
- Daily entrustment cap: 12,000 PiCoins per account. Market sales are not capped.
- No sale at a loss: a minimum price is never below `(entrustment + stamp) / (1 - commission)`, rounded up to a whole PiCoin.
- A standard player opens 40 to 50 capsules a day.

## Auction rules

| Rule | Value |
|---|---|
| Durations | 12h, 24h (preselected), 3 days |
| Increment of an amount | 5% of that amount, rounded up to a whole PiCoin |
| Displayed price | Second-highest maximum + its increment, capped at the highest maximum; the starting price with one bidder |
| Computation | Once per validated bid, never in a loop |
| Minimum bid | Current price + its increment; the first bid only reaches the starting price |
| Equal maximums | The earlier one leads, at that maximum |
| Raising one's own maximum while leading | Holds more PiCoins, does not move the price, does not extend the auction |
| Confirmation of an unusual maximum | Asked when a maximum reaches 3 times the current price |
| Soft close | A bid in the last 3 minutes that changes the price or the leader moves the end to 3 minutes from that bid |
| Escrow | The whole maximum is held from the balance, released when outbid; the winner's surplus returns at close |

Worked example, starting at 200: a maximum of 300 leads at 200. A maximum of 250 moves the price to 263 and is released at once. A maximum of 400 takes the lead at 315. At close the winner pays 315 and recovers 85; the seller receives 284 (the commission of 31.5 is rounded down).

## Average price

Per exact edition (game + season). Take the last 5 sales of the last 90 days, drop the highest and lowest, and average the rest. Under 3 sales, the price shows with a "few sales" mention. With no sale in 90 days, the card shows "sans vente" / "no sale". A typical price per rarity may also show as an indication (optional). Both the sale count and the window are settings.

## Buy orders

| Rule | Value |
|---|---|
| Target | A game, any edition; served by a copy whose rarity's minimum price the order's price reaches |
| Copies per order | 1 |
| Duration | 7 days |
| Priority | Best price, then oldest |
| Escrow | The order's price, held from placement, released at cancellation or expiry |
| Cancellation | Free, at any time |
| Direct sale to an order | Instant, no stamp, the usual commission |

## The shop

| Item | Price |
|---|---|
| An Archive card | A multiple of its rarity's entrustment value, to set (5x simulated); it must sit above a player's usual offer |
| A goal beyond 5, a custom set beyond 5, a deck beyond 3 | To set |

## Production evidence (2026-11-19, market open since 2026-11-13)

- Cards changing hands a week: about 50 sold on the market, 1,100 moved by friend trades, 3,000 entrusted.
- 4 bids per sold listing, 9 bidders: supply, not demand, is short. Players entrust about 70 times more cards than they list.
- At the minimum price a sale nets about the entrustment value (Common 11.5 vs 10, Rare 50 vs 50); selling pays only above the floor.
- 50,822 PiCoins sit idle (median wallet 965); before the shop they bought only market cards.
- 56% of trade sides sit at the 4-card limit; 5 of 16 goal holders sit at 5 goals; no player is near 10 custom sets.

## Indicators

| Indicator | Reads | Starting alert |
|---|---|---|
| PiCoins destroyed against created, 30 days | Whether money piles up | Below 40% (a guess; the simulated economy is on target at 56%) |
| PiCoins per active player, 90 days | Whether prices will rise for everyone | None at launch |
| Prices in days of a standard player's income | Whether the targets above hold | None at launch |
| Share of PiCoins held by the top 1% | Whether wealth concentrates | None at launch |

## Charts

| Figure | Rule |
|---|---|
| Destroyed | Stamps, commissions and a deleted account's balance |
| A standard player's daily income | Median earnings (entrusting plus sales, less commissions) of the players who opened a capsule that day and earned something |
| Price in days of capsules | A rarity's typical price divided by that day's income |
| Rarity price | Median of the rarity's edition averages with enough sales |
| Price index | 100 on the rarity's first day with a price |
| Missing figure | Shown as a gap and a dash in the table, never 0 |
| Window | Reactor 30 days; rarity prices and indicators 90 days; edition chart the average-price window. Series end on the last full UTC day. |

A public chart shows once an administrator publishes it; there is no automatic threshold.

## Setting bounds

One change cannot more than double or halve a value, which guards against a typing error; repeating a change goes further. Commission stays between 0% and 25%. A minimum price never goes below the no-loss floor.

## Sales in the feed

Every sale of an Epic or Legendary, and any sale at 10 times its rarity's minimum price or more: from 130 for a Common, 340 for an Uncommon, 780 for a Rare.

## Alt-account signals

Near-maximum capsule opening (about 144 a day is possible, a standard player opens 40 to 50), repeated one-way trades, sales outside market price between the same accounts, repeated minimum-price sales between the same two accounts, bids on a listing from an account tied to its seller, and direct sales to a high order from an account tied to the seller.

## Known limits

- The duel capsule (CAP-42) adds at most one capsule a day per player, 3 cards at the daily bonus odds (about 0.03 Légendaire), as much again as the daily bonus for a player who wins a real duel each day; it was not simulated, and the Légendaire backlog indicator watches it.
- About 1,800 Legendaries may wait for a buyer at a 70,000 minimum with 30% resellers (3 months of sales). Raising the minimum clogs the market further.
- The Legendary price depends on resale: 25 days of income with no minimum and 30% resellers, about 4 days at 60%.
- Epic resellers were not simulated, and the simulation does not test the sale format. It rests on assumed behaviour: prices are orders of magnitude.
- A seller's alt can probe a leader's maximum in small steps; if it wins, the seller loses the commission and stamp.
- Real-money resale of cards or PiCoins outside the game stays possible despite the terms; staff watch for it.
- A beaten maximum can be deduced from the price and increment. Only the leader's maximum is secret, and a price capped at it shows it.
- A direct sale pays no stamp, so an alt's high order moves money for the commission alone.
- The wanted count (CAP-44) reveals other players' goals in aggregate. Accepted, since only a count shows.
- A near-complete set missing a Légendaire flags it as wanted, though nobody has a spare.
- The auction stamp stays charged at listing; charging it at sale (as EVE does) was considered and left unchanged.
- No source measures orders, wanted counts or Archive resale at about 30 players.
- Visible names let anyone follow a player's purchases and let friends avoid bidding against each other. Accepted.

## Rejected

| Rejected | Why |
|---|---|
| Auction only / fixed price only | Forced waits on common cards / seller must guess |
| One duration / free duration | One day for a Legendary / unreadable market |
| Holding only the current bid, or nothing | A maximum silently stops counting / empty accounts inflate auctions |
| Average per game, or per game and rarity; raw average | Mixes rarities / erases edition value; two accounts can inflate it |
| Current-season-only market | Listings lose their goods at each season change |
| Automatic regulator at launch | Overshoots, on thresholds no real data has validated |
| Tight daily cap (150 or below before the x1000 scale, 1,500 today) | Sits at a normal player's income |
| Proportional stamp | Removes most of the money burned |
| Welcome bonus | Barely helps newcomers, alt accounts farm it |
| Seniority gate | Open to every player (author, 2026-11-09) |
| Anonymous bidders | The author prefers visible rivalry |
| The market absorbs all duplicates | 500 Common listings for 480 never bought |
| Implicit demand only, orders later | The seller needs a firm price, not only a count |
| An order sale settles instantly with no choice | Floor-price orders would capture supply below what bidders pay |
| An order sale always opens an auction | The seller loses the instant sale that beats entrusting |
| One order per edition | Goals count any edition, and fewer sellers could serve it |
| An order bids automatically on open listings | Money held twice or moved silently |
| Promoting the market tab first | A shop window in front of empty shelves |
| Capsules bought for PiCoins | A safe price draws no buyers; a distinct capsule competes with duel capsules, resale or the market |
| Cosmetics for PiCoins | The author keeps them earned through achievements |
| Trade capacity for PiCoins | The one limit players hit, but it feeds the market's rival |
