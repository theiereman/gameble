# Market and economy

Numbers and rules for CAP-29 to CAP-38. Every value is a starting setting editable from the back-office (CAP-35). Simulated evidence and the full reasoning are in `../forge-market-economy/`.

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

PiCoins are minted only when a card is entrusted. Stamps and commissions are destroyed. Nothing else creates or destroys them, and the Brotherhood never injects any. Amounts are integers, shown compact (1.2M), never with a euro sign.

## Values by rarity

| | Common | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| Entrustment pays | 1,000 | 2,000 | 5,000 | 15,000 | 100,000 |
| Listing stamp | 100 | 1,000 | 2,000 | 5,000 | 10,000 |
| Minimum price | 1,300 | 3,400 | 7,800 | 22,300 | 7,000,000 |
| Target for a standard player | minutes | minutes | a few hours | 1 to 2 days | about 40 days |

- The rarity is the one minted on the copy, whatever its edition.
- Commission: 10% of the final price, paid by the seller.
- Daily entrustment cap: 1,200,000 PiCoins per account. Market sales are not capped.
- No sale at a loss: a minimum price is never below `(entrustment + stamp) / (1 - commission)`, rounded up to the next hundred.
- A standard player opens 40 to 50 capsules a day.

## Auction rules

| Rule | Value |
|---|---|
| Durations | 12h, 24h (preselected), 3 days |
| Increment of an amount | 5% of that amount, rounded up to the next hundred |
| Displayed price | Second-highest maximum + its increment, capped at the highest maximum; the starting price with one bidder |
| Computation | Once per validated bid, never in a loop |
| Minimum bid | Current price + its increment; the first bid only reaches the starting price |
| Equal maximums | The earlier one leads, at that maximum |
| Raising one's own maximum while leading | Holds more PiCoins, does not move the price, does not extend the auction |
| Confirmation of an unusual maximum | Asked when a maximum reaches 3 times the current price |
| Soft close | A bid in the last 3 minutes that changes the price or the leader moves the end to 3 minutes from that bid |
| Escrow | The whole maximum is held from the balance, released when outbid; the winner's surplus returns at close |

Worked example, starting at 20,000: a maximum of 30,000 leads at 20,000. A maximum of 25,000 moves the price to 26,300 and is released at once. A maximum of 40,000 takes the lead at 31,500. At close the winner pays 31,500 and recovers 8,500; the seller receives 28,350.

## Average price

Per exact edition (game + season). Take the last 5 sales of the last 90 days, drop the highest and lowest, and average the rest. Under 3 sales, the price shows with a "few sales" mention. With no sale in 90 days, the card shows "sans vente" / "no sale". A typical price per rarity may also show as an indication (optional). Both the sale count and the window are settings.

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

Every sale of an Epic or Legendary, and any sale at 10 times its rarity's minimum price or more: from 13,000 for a Common, 34,000 for an Uncommon, 78,000 for a Rare.

## Alt-account signals

Near-maximum capsule opening (about 144 a day is possible, a standard player opens 40 to 50), repeated one-way trades, sales outside market price between the same accounts, repeated minimum-price sales between the same two accounts, and bids on a listing from an account tied to its seller.

## Known limits

- About 1,800 Legendaries may wait for a buyer at a 7M minimum with 30% resellers (3 months of sales). Raising the minimum clogs the market further.
- The Legendary price depends on resale: 25 days of income with no minimum and 30% resellers, about 4 days at 60%.
- Epic resellers were not simulated, and the simulation does not test the sale format. It rests on assumed behaviour: prices are orders of magnitude.
- A seller's alt can probe a leader's maximum in small steps; if it wins, the seller loses the commission and stamp.
- Real-money resale of cards or PiCoins outside the game stays possible despite the terms; staff watch for it.
- A beaten maximum can be deduced from the price and increment. Only the leader's maximum is secret, and a price capped at it shows it.
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
| Tight daily cap (150 or below, before the x1000 scale) | Sits at a normal player's income |
| Proportional stamp | Removes most of the money burned |
| Welcome bonus | Barely helps newcomers, alt accounts farm it |
| Seniority gate | Open to every player (author, 2026-11-09) |
| Anonymous bidders | The author prefers visible rivalry |
