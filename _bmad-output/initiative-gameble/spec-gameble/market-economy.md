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

PiCoins are minted only when a card is entrusted. Stamps, commissions and PiCoins spent on Archive cards and slots are destroyed. Nothing else creates or destroys them, and the Brotherhood never injects any. Amounts are whole PiCoins, shown compact from 1,000 (12k), never with a euro sign. Every amount was divided by 100 on 2026-11-15, the market already open: balances, ledger, listings, bids and history were converted by a migration.

## Values by rarity

| | Common | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| Entrustment pays | 10 | 20 | 50 | 150 | 1,000 |
| Listing stamp | 2 | 20 | 40 | 100 | 50 |
| Minimum price | 15 | 45 | 100 | 280 | 70,000 |
| Archive price | 50 | 100 | 500 | 1,500 | not sold |
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

Per exact edition (game + season); auction sales and direct sales to an order both count. Take the last 5 sales of the last 90 days, drop the highest and lowest, and average the rest. Under 3 sales, the price shows with a "few sales" mention. With no sale in 90 days, the card shows "sans vente" / "no sale". A typical price per rarity may also show as an indication (optional). Both the sale count and the window are settings.

## Buy orders

| Rule | Value |
|---|---|
| Target | A game, any edition; served by a copy whose rarity's minimum price the order's price reaches |
| Copies per order | 1 |
| Duration | 7 days |
| Priority | Best price, then oldest |
| Escrow | The order's price, held from placement, released at cancellation or expiry |
| Per player | One order per game |
| Reachable rarities | Those whose minimum the price reached when the order was placed |
| Best order shown to a buyer | Its price alone; only orders placed more than an hour ago, never a tied account's |
| Banned or deleted owner | Orders withdrawn at once; a banned owner's held PiCoins return, a deleted owner's are destroyed with the balance |
| Cancellation | Free, at any time |
| Direct sale to an order | Common and Uncommon only. Instant, no stamp, the usual commission; serves the best eligible order, never the seller's own; refused when that order changed after the seller's screen was drawn; counts in the average price |
| Order-backed auction | Any rarity. An auction opened at or below eligible orders turns each into a bid with its price as its maximum: the best leads and its held PiCoins move to the auction, the beaten end with their PiCoins returned, and the auction prices them as any bids. An order below the starting price stays open. An order never bids on an auction already open (author, 2026-11-24) |

## The shop

| Item | Price |
|---|---|
| An Archive card | 5x its rarity's entrustment value for Common and Uncommon, 10x for Rare and Epic (Values by rarity); above a player's usual offer and never below the rarity's player minimum price. Légendaire not sold at launch; 140,000 (2x its minimum) if opened later |
| Goals 6 to 10, custom sets 6 to 10 | 500, 1,000, 2,000, 3,000, 5,000; bought in context only, never in the shop |
| Decks 4 and 5 | 1,000, 2,000; bought in context only |

A rarity whose Archive price is not set is absent from the shop. Above Uncommon, a player buys at most a set number of copies of each rarity per period; the starting values are 1 Rare a day and 1 Epic a week, settings an administrator edits. Commons and Uncommons have no limit. Staff keep which account entrusted each Archive copy; players never see it.

## Production evidence (2026-11-19, market open since 2026-11-13)

The settings above are those production ran on 2026-11-19 (author, 2026-11-20). Shop and slot prices come from `../forge-market-volume/shop-pricing.md`.

- Cards changing hands a week: about 50 sold on the market, 1,100 moved by friend trades, 3,000 entrusted.
- 4 bids per sold listing, 9 bidders: supply, not demand, is short. Players entrust about 70 times more cards than they list.
- At the minimum price a sale nets about the entrustment value (Common 11.5 vs 10, Rare 50 vs 50); selling pays only above the floor.
- 50,822 PiCoins sit idle (median wallet 965); before the shop they bought only market cards.
- 56% of trade sides sit at the 4-card limit; 5 of 16 goal holders sit at 5 goals; no player is near 10 custom sets.

## Indicators

| Indicator | Reads | Starting alert |
|---|---|---|
| PiCoins destroyed against created, 30 days | Whether money piles up | Below 40% (a guess; the simulated economy is on target at 56%; production ran near 8% on 2026-11-19, so it fires from the shop's opening and reads as a signal, author 2026-11-20) |
| PiCoins per active player, 90 days | Whether prices will rise for everyone | None at launch |
| Prices in days of a standard player's income | Whether the targets above hold | None at launch |
| Share of PiCoins held by the top 1% | Whether wealth concentrates | None at launch |

## Charts

| Figure | Rule |
|---|---|
| Destroyed | Stamps, commissions, Archive card and slot purchases, and a deleted account's balance (held order money included) |
| A standard player's daily income | Median earnings (entrusting plus sales, less commissions) of the players who opened a capsule that day and earned something |
| Price in days of capsules | A rarity's typical price divided by that day's income |
| Rarity price | Median of the rarity's edition averages with enough sales |
| Price index | 100 on the rarity's first day with a price |
| Missing figure | Shown as a gap and a dash in the table, never 0 |
| Window | Reactor 30 days; rarity prices and indicators 90 days; edition chart the average-price window. Series end on the last full UTC day. |

A public chart shows once an administrator publishes it; there is no automatic threshold.

## Setting bounds

One change cannot more than double or halve a value, which guards against a typing error; repeating a change goes further. Commission stays between 0% and 25%. A minimum price never goes below the no-loss floor. An Archive price never goes below its rarity's player minimum price. An Archive purchase cap is at least 1, over a window of at least 1 day.

## Sales in the feed

Every sale of an Epic or Legendary, and any sale at 10 times its rarity's minimum price or more: from 150 for a Common, 450 for an Uncommon, 1,000 for a Rare. A direct sale to an order follows the same rule; an Archive purchase never makes an entry.

## Alt-account signals

Near-maximum capsule opening (about 144 a day is possible, a standard player opens 40 to 50), repeated one-way trades, sales outside market price between the same accounts, repeated minimum-price sales between the same two accounts, bids on a listing from an account tied to its seller, direct sales to a high order from an account tied to the seller, and an Archive purchase of a copy an account tied to the buyer entrusted.

## Known limits

- The duel capsule (CAP-42) adds at most one capsule a day per player, 3 cards at the daily bonus odds (about 0.03 Légendaire), as much again as the daily bonus for a player who wins a real duel each day; it was not simulated, and the Légendaire backlog indicator watches it.
- About 1,800 Legendaries may wait for a buyer at a 70,000 minimum with 30% resellers (3 months of sales). Raising the minimum clogs the market further.
- The Legendary price depends on resale: 25 days of income with no minimum and 30% resellers, about 4 days at 60%.
- Epic resellers were not simulated, and the simulation does not test the sale format. It rests on assumed behaviour: prices are orders of magnitude.
- A seller's alt can probe a leader's maximum in small steps; if it wins, the seller loses the commission and stamp.
- Real-money resale of cards or PiCoins outside the game stays possible despite the terms; staff watch for it.
- A beaten maximum can be deduced from the price and increment. Only the leader's maximum is secret, and a price capped at it shows it.
- A direct sale pays no stamp, so an alt's high order moves money for the commission alone.
- A seller's alt can back an auction with a high order, forcing real rivals above it; the tied-bids signal reads the converted orders' bids.
- An order converted into a bid is automatic bidding, limited to auctions opened at or below the order's price; it was chosen over holding the money twice and over a second order sniping the last minute (author, 2026-11-24).
- The wanted count (CAP-44) reveals other players' goals in aggregate, custom-set goals and private players included. Accepted, since only a count shows (author, 2026-11-20).
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
| An order sale always opens an auction, for every rarity | A Common seller loses the instant sale that beats entrusting; a Rare and above sells only at auction, which its orders back (author, 2026-11-24) |
| One order per edition | Goals count any edition, and fewer sellers could serve it; an edition order was also weighed again for Common and Uncommon and dropped (author, 2026-11-24) |
| An order bids automatically on listings already open | Money held twice or moved silently; only an auction opened at or below an order turns it into a bid |
| A direct sale for every rarity | Money and one press replace the talk for the cards that matter (author, 2026-11-24) |
| The Archive shop closed above Uncommon | Removes the main PiCoin sink (about 8% destroyed against created on 2026-11-19) |
| The Archive shop unchanged above Uncommon | Money alone then bypasses every other rule; a per-player cap keeps the sink |
| A separate rule for the last card of a set | The rarity rules already cover it, and blocking its order hurts the player who needs it most |
| Promoting the market tab first | A shop window in front of empty shelves |
| Capsules bought for PiCoins | A safe price draws no buyers; a distinct capsule competes with duel capsules, resale or the market |
| Cosmetics for PiCoins | The author keeps them earned through achievements |
| Trade capacity for PiCoins | The one limit players hit, but it feeds the market's rival |
