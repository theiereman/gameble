# Shop pricing: Archive resale and capacity slots

2026-11-20. Starting values for CAP-48 (Archive price per rarity) and CAP-49 (slot prices), and the effect of buy orders (CAP-46, CAP-47) on money destroyed. Evidence: `simulate_shop.py` (run `python3 simulate_shop.py "" 8`, numpy only) and `simulation-results-shop.txt` (8 seeds per scenario, medians). The script extends `../forge-market-economy/simulate_economy.py` and runs at today's amounts. That simulator worked at a tenth of today's PiCoins: its 1/2/5/15/100 is today's 10/20/50/150/1,000. Its control run reproduces the 56% destroyed/created the economy was tuned to (58% at day 365 over 8 seeds).

## Recommendation

| Archive copy | Common | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| Price | 50 | 100 | 500 | 1,500 | not sold |
| Multiple of entrustment | 5x | 5x | 10x | 10x | — |
| Multiple of minimum (13/34/78/223) | 3.8x | 2.9x | 6.4x | 6.7x | — |
| Days of a standard player's income today (~200) | 0.25 | 0.5 | 2.5 | 7.5 | — |
| Wallets that can pay it today | 98% | 95% | 68% | 38% | 0% |

| Slot | 1st paid | 2nd | 3rd | 4th | 5th |
|---|---:|---:|---:|---:|---:|
| Goals 6 to 10 | 500 | 1,000 | 2,000 | 3,000 | 5,000 |
| Custom sets 6 to 10 | 500 | 1,000 | 2,000 | 3,000 | 5,000 |
| Decks 4 and 5 | 1,000 | 2,000 | | | |

Wallet shares come from a lognormal fit to production (median 965, 50,822 over 20 wallets). A standard player's income today is an estimate: the simulation gives 150 to 180 a day at day 30, and production gives about 400 a day per earning player, mean not median. The back-office indicator will measure it; read it before setting these values.

**The rule behind the Archive price.** Commons and Uncommons sit at 5x entrustment: players hardly sell them, so the Archive is their only shelf and there is nobody to undercut. Rares and Epics sit at 10x: they are what players actually sell, often above the minimum with several bidders, so the Archive must stay a ceiling and not become a competitor. Legendaries stay out of the shop at launch.

**The rule behind slot prices.** The price rises with each slot. The first paid slot costs about half the median wallet, a little over two days of income: a real choice that two thirds of wallets can make. The fifth costs a luxury price. Newcomers are never blocked, because their 5 goals, 5 sets and 3 decks stay free.

## What the numbers say

1. **Production destroys far less than the simulation.** 68,230 PiCoins were minted and 5,251 destroyed (2,257 stamps, 2,994 commission). That is 8% cumulative, about 18% of a week's creation since the market opened. It is already under the 40% alert, which was tuned on a simulated economy where players list half their spare copies. Production entrusts 70 times more than it lists. The script's "thin" variant (3% listed, the rest entrusted) is the closer match: 3% at day 30, 10% at day 90.
2. **No shop price brings production back over 40% on its own.** In the thin economy the recommended shop and slots raise destroyed/created from 3% to 15% at day 30 and from 10% to 26% at day 90. The money that dies is the money that reaches a sale; the ratio is driven by how much supply reaches the market, not by shop prices. The alert will fire from day one whatever is set here. The author should know that before reading it.
3. **Raising the Archive price barely changes how much money is destroyed, but it decides who loses sales.** In the busy economy, every candidate from 3x to 10x entrustment lands at 64 to 68% destroyed/created at day 365 (control 58%) and 36k to 52k destroyed a week per 100 players. What changes is the share of player demand the Archive takes: 35% of Epic purchases at 3x entrustment, 24% at 5x, 12% at 10x.
4. **In a thin market every affordable Archive price undercuts Rare and Epic sellers.** When almost nothing is listed, scarce Rares fetch more than any of these prices in the model, and the Archive serves 45 to 70% of Rare and about 90% of Epic purchases. The thin variant's market prices (a Rare at 20,000) are unrealistic: production's median sale is 104 and its mean 518. Read it as a bound: the higher Rare and Epic price is the protection that remains.
5. **Slots are a small, one-off sink.** They absorb 200 to 600 PiCoins per player who ever joined over a year, against 40,000 to 50,000 held per player at day 365. They matter for the choice they create, not for the ratio.
6. **Buy orders are neutral on the ratio.** Destroyed/created stays at 0.65 to 0.66 at day 365 with or without orders, and within noise at day 90. Direct sales make up 7 to 16% of player sales.

## Archive price per rarity (CAP-48)

Busy economy (the launch simulation's behaviour), medians of 8 seeds. "Diverted" is the share of a rarity's purchases that went to the Archive because it was cheaper than the market: the sales sellers lost. "Above" is the share of player sales priced above the Archive price: where it acts as a ceiling. "Arbitrage" is the share of sales high enough to pay back buying from the Archive and relisting: `(Archive price + stamp) / 0.9`. All are for C/U/R/E, in percent, over the last 90 days of the year.

| Candidate (C/U/R/E, Legendary) | d/c day 90 | d/c day 365 | Archive PiCoins/week/100 players, day 365 | Diverted day 365 | Above | Arbitrage | Money/player day 365 |
|---|---:|---:|---:|---|---|---|---:|
| No shop (control) | 0.37 | 0.58 | 0 | — | — | — | 49.3k |
| 3x entrustment 30/60/150/450 | 0.44 | 0.64 | 36.0k | 4/9/15/35 | 6/14/11/11 | 4/6/5/7 | 42.7k |
| 5x entrustment 50/100/250/750 | 0.37 | 0.67 | 47.8k | 5/7/11/24 | 1/2/2/3 | 1/1/1/3 | 33.8k |
| 5x entrustment with Legendary 5,000 | 0.43 | 0.66 | 45.0k | 3/7/9/22, Legendary 98% at day 90 | 1/3/2/4 | 1/2/1/3 | 41.6k |
| 10x entrustment 100/200/500/1,500 | 0.42 | 0.66 | 52.0k | 3/5/6/12 | 1/1/2/2 | 1/1/2/2 | 40.8k |
| 2x minimum 26/68/156/446 | 0.44 | 0.65 | 34.7k | 5/9/12/37 | 9/9/10/11 | 5/4/5/7 | 46.1k |
| 3x minimum 39/102/234/669 | 0.39 | 0.65 | 41.5k | 4/5/11/25 | 2/3/3/4 | 1/2/2/3 | 46.0k |
| 2x market price, floating | 0.43 | 0.70 | 55.4k | 0 by construction | 6/6/4/3 | 4/3/2/2 | 37.0k |
| 3x market price, floating | 0.43 | 0.67 | 62.0k | 0 by construction | 1/1/2/1 | 1/1/1/1 | 43.9k |
| **Table 50/100/500/1,500** | 0.42 | 0.68 | 48.1k | 3/5/6/12 | 1/3/1/2 | 1/2/1/2 | 40.7k |
| Table + Legendary 140,000 | 0.40 | 0.66 | 68.4k | 4/7/7/17 | 1/3/1/1 | 1/1/1/1 | 38.7k |

Run-to-run noise on destroyed/created is about ±0.05; differences of that size between rows mean nothing. Market fees alone destroy 400k to 550k a week per 100 players at day 365, so the Archive adds roughly a tenth to destruction in this economy.

Thin economy (closer to production):

| Candidate | d/c day 30 | d/c day 90 | Archive PiCoins/week/100, day 90 | Diverted R/E day 90 |
|---|---:|---:|---:|---|
| No shop | 0.03 | 0.10 | 0 | — |
| 5x entrustment | 0.08 | 0.18 | 57.7k | 72/97 |
| 10x entrustment | 0.12 | 0.24 | 107.0k | 71/97 |
| **Table 50/100/500/1,500** | 0.12 | 0.24 | 106.0k | 71/97 |
| Table + slots (recommended) | 0.15 | 0.26 | 102.2k | 71/97 |

Here buyers hold far more PiCoins than they can spend, so a higher Rare and Epic price destroys more, not less: 10x destroys nearly twice what 5x does. Both economies point the same way for Rares and Epics.

**At today's 30 players.** Creation runs at about 34,000 a week. Lifting destroyed/created from 18% to 40% needs about 7,500 more destroyed a week, for example 15 Rares or 5 Epics bought from the Archive. The Archives hold 5,888 copies over 4,020 editions, most of them Commons by the draw odds. A given wanted Rare or Epic is in stock only a minority of the time: about one in five for Rares and under one in ten for Epics, if the stock follows the odds. Until the stock grows, the shop sells mostly what it holds, and that caps what it can destroy more than its price does.

**Days of income.** The fixed prices lose weight as income grows: the simulation's standard income rises from about 150 a day at day 30 to about 500 at day 90 and 1,000 to 1,800 at day 365. A 1,500 Epic falls from about 7 days of income to about 1. Review the table when the "prices in days of income" indicator shows an Archive Epic under 2 days; the setting bounds allow doubling in one change.

**Legendaries.** Leave them out at launch.
- A price at or below the 70,000 minimum competes head-on with the queue of player Legendaries the economy already expects (about 1,800 at 30% resellers). The spec forbids anything under the minimum. At 5,000 (5x entrustment) the Archive took 98% of Legendary demand by day 90.
- Above the minimum, nobody can pay: 140,000 exceeds all of today's idle money (50,822). In the simulation it sold 0.1 copies a week per 100 players by day 365.
- Players rarely entrust a Legendary for 1,000 when its minimum sale is 70,000, so the stock would be a handful of copies.
- Selling one back at 140x what the Brotherhood paid reads as profiteering more than as a ceiling.

Revisit when money per active player nears the minimum. Then 2x the minimum (140,000) sits under about 8% of Legendary sales, with an arbitrage window near 5%.

**Arbitrage.** Buying from the Archive and relisting higher pays only on sales above `(price + stamp) / 0.9`. With the recommended table that is 1 to 2% of player sales per rarity at day 365 in the busy economy. It is larger early, while Epics are scarce and dear, but the Archive then holds almost no Epics to buy. Every pass destroys the Archive price, stamp and commission, and it puts a copy on the market, so the risk is small. The cheaper candidates (3x entrustment, 2x minimum) open a 4 to 7% window. Watch "an Archive copy relisted within 7 days by its buyer"; it costs one query and complements the spec's alt signal on Archive purchases.

## Slot prices (CAP-49)

Assumed demand: 31% of players want a 6th goal, matching 5 of 16 goal holders at 5. Each further goal is wanted with a 60% chance. 5% want a 6th custom set, matching nobody near 10. 25% want a 4th deck: decks are not in production, so this is a guess. A player buys when the price is under their worth for the slot and under their usual spending share of the wallet (40 to 60%). Worth is a lognormal with a median of 3 days of their own income.

| Option | Goal slots owned per 100 players, day 30 | Day 365 | PiCoins absorbed per player who ever joined, year | d/c day 90 |
|---|---:|---:|---:|---:|
| Flat 500 | 19 | 43 | 218 | 0.43 |
| Flat 2,000 | 9 | 32 | 572 | 0.50 |
| **Rising 500/1k/2k/3k/5k, decks 1k/2k** | 14 | 38 | 415 | 0.45 |
| Doubling 500 to 8,000 | 14 | 38 | 438 | 0.45 |
| 3 days of standard income, floating | 19 | 35 | 445 | 0.46 |
| Rising, slots worth 1.5 days | 11 | 33 | 343 | 0.43 |
| Rising, slots worth 6 days | 18 | 42 | 476 | 0.49 |
| Rising, half the demand | 7 | 15 | 176 | 0.40 |

Today, with 5 players at 5 goals, an income of 150 to 300 and slots worth 3 days, the rising schedule sells a 6th goal to 1 or 2 of them and absorbs 800 to 1,300 PiCoins once. That is under 3% of the idle 50,822 and under a week's gap to the alert. Flat 2,000 sells to almost none of them (0.1 to 0.2 of 5). Starting at 250 instead of 500 doubles the 6th-goal buyers (2 to 3 of 5) for about the same total.

The rising schedule keeps the first slot open to the players who hit the limit today. It absorbs nearly twice what flat 500 does, and still prices the 9th and 10th as a luxury when incomes have tripled. Flat 2,000 absorbs the most but halves early uptake: it shuts out the players the limit was opened for. A price in days of income keeps its weight as incomes grow, but it moves under the player from one day to the next; keep it as the review rule rather than the mechanic. Goals are also the cheapest lever on market demand, since every goal feeds the wanted count (CAP-44). Do not price them higher than custom sets, which feed nothing.

## Buy orders (CAP-46, CAP-47)

The simulation can place orders. A captive buyer whose card is not listed places one at 1.2x the typical market price, at least the minimum, with the money held for 7 days. A seller's spare copy matches an open order with probability (open orders / catalog cards of that rarity), and the seller takes it 70% of the time.

| Scenario | d/c day 90 | d/c day 365 | Direct share of player sales | Market share vs friend trades | Epic price in days, day 90 |
|---|---:|---:|---:|---:|---:|
| Recommended, no orders | 0.43 | 0.66 | 0% | 14% | 2.6 |
| Recommended + orders | 0.50 | 0.66 | 7% | 13% | 1.3 |
| Orders, 30% of matching sellers sell | 0.52 | 0.65 | 7% | 13% | 1.3 |
| Orders, 90% sell | 0.44 | 0.65 | 8% | 13% | 1.4 |
| Orders, every unserved buyer orders | 0.42 | 0.65 | 16% | 12% | 1.2 |
| Orders, thin | 0.26 | 0.31 | 3% | 10% | 26.9 (thin prices) |

Orders do not lower destroyed/created. A direct sale loses the stamp, but the copy it moves would otherwise have been entrusted, so it also mints nothing, and the commission is still destroyed. They bring Epic prices toward the 1-to-2-day target by pulling copies that would have gone to the Archives. The model cannot show the volume gain, because its market is anonymous per rarity: an order there replaces a market purchase rather than adding one.

Reasoned instead, at today's scale: 16 goal holders keeping about 5 orders each make 80 orders over some 12,000 games, so about 0.7% of entrusted copies match one. At 3,000 entrusted a week and a 70% take rate, that is about 15 direct sales a week on top of about 50 auction sales. The market's share of cards changing hands moves from about 4% to about 6%. Each such sale moves the ratio by under a point.

## Assumptions added, and how much they matter

| Assumption | Value | Tested | Effect on the recommendation |
|---|---|---|---|
| Buyers whose wanted card has no listing ("captive") | 50% | 20%, 80% | Epic diversion 21% at 20%, 6% at 80%; ratio within noise. Holds. |
| What a captive buyer pays at most, vs the typical market price | Lognormal, median 2x, spread 0.7 | Median 1.5x, 3x | Ratio 0.63 to 0.66; Archive burn 47k to 63k. Holds. |
| A wanted card is in Archive stock | 1 − e^(−stock / cards of the rarity) | — | Caps Rare and Epic sales while stock is thin. Not tested. |
| Share of spare copies listed | 50% busy, 3% thin | Both | The main driver of destroyed/created by far; it brackets production. |
| Single sales spread around the day's price | Lognormal 0.5 | — | Only shifts "above" and "arbitrage". |
| Slot worth | Median 3 days of own income | 1.5, 6 days | Uptake 11 to 18 goal slots/100 at day 30; schedule unchanged. |
| Slot demand | 31% goals, 5% sets, 25% decks | Halved | Absorption halves; still a minor sink. |
| Order take rate and placement | 70%, half of unserved captive buyers | 30%, 90%, all | Ratio unchanged; direct share 7 to 16%. |
| Standard income today | ~200 | 150, 300 | Moves the days figures, not the prices. |

The recommendation is driven by the diversion of Rare and Epic demand, which falls steadily as their price rises in every variant, and by the thin variant, where a higher price destroys more. No tested assumption reverses either.

## Risks

- **The 40% alert fires at once in production**, whatever these prices. Production sits at 8 to 18%, and the shop and slots add about 10 to 15 points in the thin model. A first reading of the alert should not be answered by raising shop prices: that destroys little more and costs sellers.
- **Undercutting in a starved market.** If supply stays at a few listings a week and buyers bid hard, even 500 and 1,500 sit below what some Rares and Epics fetch. Watch Rare and Epic sales priced above the Archive price; raise the price when it passes about 10%.
- **Stock-limited at first.** The Archive will mostly offer Commons and Uncommons until Rare and Epic stock builds, so early destruction is small whatever the price.
- **Price erosion.** Incomes grow several-fold over a year, so the fixed prices weaken. The indicator in days of income is the review trigger.
- **The Archive becomes the default supply.** At these prices, a player who wants a specific Common or Uncommon now will usually buy it from the Archive, not from a player. That is intended: players do not list Commons. It does mean the shop, not the market, carries that volume.

## Rejected

| Rejected | Why |
|---|---|
| One multiple of entrustment for every rarity (5x) | Legendary at 5,000 breaks the minimum and took 98% of Legendary demand. Without Legendaries, 5x still diverts 24% of Epic demand. |
| 3x entrustment, 2x minimum | Divert a third of Epic purchases and open a 4 to 7% arbitrage window, for no more destruction. |
| 3x minimum | Close to 5x entrustment, with the same Epic diversion (25%). |
| A single multiple of the minimum including Legendary (210,000) | Nobody can pay it; it adds nothing at launch. |
| Floating price at 2x or 3x the typical market price | Diverts nothing by construction, but follows a typical price that rests on 2 or 3 sales per edition at 30 players. It would jump with each sale, it can be nudged by two accounts trading between themselves, and it needs code a fixed table does not. Keep it as the review rule: the Archive price stays at or above 3x the rarity's typical price. |
| Legendary at 2x minimum at launch | No buyer can pay it; it sets an anchor and reads as profiteering. Ready for later. |
| Flat slot prices | 500 absorbs half as much and prices the 10th goal like the 6th; 2,000 halves the uptake from the players at the limit today. |
| Slots priced in days of income | Moves daily under the player. Kept as the review rule. |

## What the simulation cannot tell

- **Specific cards.** Demand is per rarity, not per card or edition. Archive coverage, orders and "wanted" are approximations of a card-level market, so the order volume gain is reasoned, not simulated.
- **Thirty players.** The model runs at 450 to 2,000 players. It matches production's wallets at day 30 (about 3,000 per player), but not its thin, competitive bidding (4 bids per sale); the thin variant overshoots its prices.
- **Players' real behaviour at a shop.** How many buy a Common at 50 or an Epic at 1,500, and whether slots feel worth it, are assumptions. No source measures them at this scale.
- **Live settings.** On 2026-11-19, production ran minimums of 15/45/100/280 and stamps of 2/20/40/100/50, not the spec's 13/34/78/223 and 1/10/20/50/100. The recommended prices clear both sets of minimums.
- **The duel capsule, seasons and alt accounts** are not modelled here, as in the earlier simulation.
