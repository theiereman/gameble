---
title: 'Select research: Archives shop sink models'
type: 'competitive + domain (select shape)'
topic: 'Archives shop: which shop / currency-sink model fits PiCoins'
decision: 'Which model the Archives shop uses to sell entrusted cards: what it lists, at what price, to whom, at what rhythm'
source: 'native run, 3 parallel web researchers + lead spot-checks; run folder ../research-archive-shop-sink-models/'
status: complete
preset: 'standard'
validation: 'normal'
created: '2026-11-24'
updated: '2026-11-24'
claims: 'verified 3, unverified 15, overturned 0 (memlog tally)'
---

# Archives shop: sink models compared

**Decision this research serves:** how the Archives shop should list, price and allocate entrusted cards so that it destroys PiCoins without making sets easy, without a reset-time rush, and without looking empty or allowing rebuy loops, for a community of tens to low hundreds of players.

## Executive summary

**Do this:** keep the budget-sized weekly shared list with per-rarity caps and a 20-edition floor. Price each edition at a fixed price for the whole week, taken from a robust median of auction sales times a rarity premium. Drop the nightly descent. Sell the few scarce slots (the Legendary, the Epics) by a sealed bid that stays open for at least two days, with that fixed price as the reserve. This is model 1 below.

**Why:**
- A rush comes from pricing below what buyers will pay, not from the reset time itself. A shop that sells under the clearing price produces a race whatever the code does [7]. Shared first-come stock in Neopets ended in millisecond races and bots that bans did not stop [20]. A fixed premium price removes the race on plentiful tiers. Only the one-copy slots stay contested, and a sealed bid makes clock time irrelevant for them.
- A descending price adds a waiting game. Players wait for others to move, the early buyers pay far more than the late ones, and buying bunches up at the end [7]. With one drop a night, each drop becomes a small reset moment: this is an inference, since no source tested day-long steps.
- The closest live precedent works. Old School RuneScape funds a coffer from a trade tax and uses it to buy and delete a short list of luxury items under per-item daily quotas [1]. A causal study found it raised luxury prices without cutting trade volume [2]. Jagex started small and watched the flows [1]. That is the "budget from the previous period" idea, run carefully.

**Biggest caveat:** no developer publishes a sink-to-faucet target or a sizing rule [6][24]. Sizing the budget at 50 % of last week's mint is a reasonable opening value, not an evidence-based one: tune it from the metrics below. No source studied economies with fewer than a few hundred players.

## Requirements frame

The goals come from the brief, not from the research. The hard gates are G4, G5 and G6; the others are weighted.

| Goal | Weight |
|---|---|
| G1 Destroys PiCoins (rebalances supply) | 3 |
| G2 Prices high enough that sets stay hard to complete | 2 |
| G3 Shared talking point (same list for everyone) | 2 |
| G4 No Monday-midnight rush (gate) | 3 |
| G5 Never looks empty (gate) | 2 |
| G6 No rebuy loop (gate) | 3 |

## Evidence by mechanism

### Rotating and limited shops

- **Destroy-for-currency with fixed rates.** Warframe mints Ducats when a player destroys Prime parts, at a fixed rate per rarity (15 / 45 / 100), and Ducats cannot be traded [11]. Hearthstone disenchanting returns only 1/8 to 1/4 of a card's crafting cost [13]. The wide gap between what destroying pays and what buying costs is what stops loops. NPC arbitrage loops did appear wherever the buy and sell prices sat close together, as in Ultima Online's 188/199 vendor bug, and the standard fix was a wider gap [23].
- **Rare visits, announced ahead.** Baro Ki'Teer comes every two weeks and stays up to 48 hours, with a countdown shown in advance [12]. A long window that players can see coming spreads out the visits. Fortnite removed its shop refresh countdown and drew complaints that refresh times changed without warning. It was reported to be adding a timer on each item showing when it leaves; this run did not confirm that the timer shipped [17]. Epic promises only that items "have a good chance" of returning [16].
- **Personal shops remove the rush but also the shared list.** Marvel Snap moved its Series 3 cards to a choose-one-per-month picker that each player uses alone [14]. Its 2025 Card Shop shows personal daily cards on a timer [15]. Path of Exile 2 vendors refresh when the player levels up, so there is no shared reset moment [19]. Genshin's Paimon's Bargains resets monthly with per-player limits [18]. All of these avoid a rush by giving up G3.
- **Shared first-come stock fails.** In Neopets restocks, "milliseconds matter", and autobuyers stayed "rampant" despite bans [20].

### Pricing and allocation

- **Descending (Dutch) sales.** When each buyer pays the price at the moment they buy, waiting lowers what they pay. The sale turns into a game of chicken, early supporters pay several times the final price, and buying rushes in near the end [7]. The fix is a clearing price: everyone pays the last price, and higher payers get the difference back [7]. Yuga Labs dropped a planned Dutch auction for a fixed price, and an access race followed [9]. In the lab, a fast Dutch clock earned less than a sealed bid and a slow one earned more [8]. Those clocks ticked in seconds, not nights.
- **Pricing from a thin market.** TradeSkillMaster for World of Warcraft keeps the lowest 30 % of listings, cuts everything after a jump of 20 % or more, drops outliers beyond 1.5 standard deviations and blends 14 days of data with a half-life of about 2 days [10]. RuneScape builds its guide price from trades, caps how far each update can move it, and admits low-volume items can be priced wrong [4]. Both resist manipulation by cleaning outliers and capping moves.
- **Per-player limits.** RuneScape's buy limits apply per account over a fixed 4-hour window. The wiki says they exist to stop manipulation and bulk resale [5]; no Jagex statement was found.

### Faucets, sinks and NPC resale

- **Coffer-funded sink.** In Old School RuneScape, 1 % of each sale (2 % since May 2025) feeds a coffer. The coffer buys 20 listed luxury items up to per-item daily quotas, sized from each item's estimated daily entry into the game, and deletes them. It does nothing once the coffer is empty [1][3]. Prices rose and trade volume held [2]. Raising the tax rate drew an organised protest [3]: changes that look like taxes are felt.
- **Measure, don't target.** CCP publishes its faucets and sinks by category, plus how fast ISK changes hands, and states no inflation target [6]. The ratio rules of thumb found online (faucets at 1.1 to 1.3 times sinks; sinks at 90 to 110 % of faucets) are unsourced and contradict each other [24].
- **An NPC that only buys.** Albion's Black Market buys player gear and puts it back into the game as loot, and players can never buy from it, so no loop exists [21]. NPC prices act as a fixed floor and ceiling for player prices [22].

## Candidate fit

Each goal is scored 0 to 2 and multiplied by its weight; the maximum is 30. Scores are the lead's judgment from the evidence above; re-weight freely.

| Model | G1 ×3 | G2 ×2 | G3 ×2 | G4 ×3 | G5 ×2 | G6 ×3 | Total |
|---|---|---|---|---|---|---|---|
| A. Fixed back-office price per rarity, all stock | 1 | 1 | 1 | 1 | 2 | 2 | 20 |
| B. Weekly showcase of N rarest | 1 | 2 | 2 | 0 | 1 | 1 | 16 |
| C. Budget list, 6× median falling 10 % a night, once per player per edition | 2 | 2 | 2 | 1 | 1 | 2 | 25 |
| D. C plus per-rarity caps and a 20-edition floor | 2 | 2 | 2 | 1 | 2 | 2 | 27 |
| **1. D's stock, fixed pegged price, sealed lot for scarce slots** | 2 | 2 | 2 | 2 | 2 | 2 | **30** |

Notes on the scores:
- C and D never fall below the median: after six nights the price is still 2.4 times the median. So the price itself does not reward a race [7]. The descent still adds the waiting game and a micro-rush at each nightly drop.
- A drifts: a back-office price either undercuts the market, which brings sniping on each new arrival, or overshoots it, so nothing sells and nothing is destroyed. Neither outcome stays visible without the market peg.
- B's few one-copy rarities at one reset are the Neopets pattern [20].

## Cross-dimension insights

- **A rush follows from the price, not the clock.** Every rush in the evidence comes from stock priced below what buyers will pay, sold first come first served [7][20]. Staggering or moving the reset only moves the rush. Pricing at or above the market, plus an allocation that ignores time for one-copy items, removes it.
- **Gameble already has the pieces of the coffer model.** Its mint is known each week (the faucet), its auctions record sale prices (the index), and the shop only takes in destroyed cards. That is the OSRS design with the cash flowing the other way [1]. The OSRS lesson carries over: start with a small sink, quotas per tier, and watch the flows.
- **The size of the gap decides loops more than any limit.** The once-per-week limit stops one player from buying the same edition twice. Only a wide gap between what entrusting mints and the shop price stops the entrust-and-rebuy loop at the economy level [13][23].

## Recommendations (ranked)

### 1. Pegged weekly list with sealed lots (recommended)

Confidence: medium. The mechanism parts are well evidenced [1][2][7][20]; the parameter values are not.

- **Stock.** Keep D's rules: the budget is a share of last week's mint, with at most 1 Legendary, 5 Epics and 10 Rares a week, Commons and Uncommons filling the rest, and at least 20 editions. Publish the list in advance with a countdown [12].
- **Price.** Fixed for the week. Each edition costs its robust median times a rarity premium. The median is a trimmed median of auction sales over several weeks, with each weekly move capped [4][10]. Fall back to the rarity median when an edition has too few sales. The price must never fall below the median, and must stay far above what entrusting that card mints [13][23].
- **Allocation.**
  - Commons to Rares: buy now, once per player per edition per week.
  - Epic and Legendary: a sealed bid open at least 48 hours, with the fixed price as the reserve and the winner chosen at close. A slot with no bid falls to buy-now at the reserve.
  - The highest bid is destroyed, so a contested Legendary sinks more PiCoins, not fewer.
- **Talking point.** The list is the same for everyone, and the sealed lots give players something to debate all week without anyone needing to be online at a set time.

### 2. Descending list without the rush (runner-up)

Choose this instead if the author values the drama of a falling price above timing fairness. Keep model D, then:
- Make the price fall continuously or at a fixed time far from midnight, not as one drop per night, so no drop becomes an event.
- Keep a floor of at least about 2× the median.
- For editions with several copies, use a clearing price: every buyer pays the lowest price reached and is refunded the difference at week's end. This removes the reason to wait [7], but the refunds shrink the sink.

Strongest argument against it: one-copy slots still play the game of chicken [7].

### 3. Pegged fixed price, continuous shop (fallback)

Model A, with its price pegged to the robust median times a premium, the whole archive listed, and the per-player limit kept. It is the cheapest to build and never looks empty. It is weakest on G3 and gives the least control over the sink. Use it if the build budget for this feature is small.

**Cheapest hedge for any choice:** keep the premium multipliers, the budget share and the caps as data, not code, so the weekly numbers can be retuned without a release. That is how OSRS adjusts its sink list [1].

## How to judge the model (weekly metrics)

- **Sink ratio:** PiCoins destroyed by the shop ÷ PiCoins minted. Compare it with the budget share; the realised ratio will run below the budget.
- **Money supply and inflation:** total PiCoins held by players, and the rarity medians of auction sales [6].
- **Sell-through by rarity:** the share of listed editions sold, and the number of editions shown at the lowest point of the week. That number must stay at or above 20.
- **Rush:** the share of the week's purchases made in the first hour after the list opens, or after each price drop under model 2, and the largest number of purchases by a single player.
- **Fairness:** the number of distinct buyers each week and how concentrated purchases are among them.
- **Set pace:** sets completed per week, and the median time to complete a set (for G2).
- **Loop check:** editions a player entrusted and then bought back from the shop within a few weeks. This should be close to zero.

## Parameters to tune from data

| Parameter | Starting value |
|---|---|
| Budget share | 50 % of last week's mint |
| Rarity premium multipliers | High: model C's floor of 2.4× is a defensible start |
| Median window, trim and weekly move cap | 4 weeks, cleaned as in [10], ±20 % per week |
| Minimum sales before the rarity median is used instead | No starting value proposed |
| Per-rarity caps | 1 Legendary, 5 Epics, 10 Rares |
| Minimum editions listed | 20 |
| Sealed-lot window and reserve | 48 h; reserve = the fixed price |
| Descent start, step and floor (model 2 only) | 6× the median, 10 % a step, floor of about 2× |

## Open questions

- **Small-community evidence.** No source covered economies with fewer than a few hundred players. A 4 to 8 week pilot with the metrics above is the only way to answer it.
- **Lotteries.** No game using a lottery to allocate scarce shop stock was found this run. That absence is why model 1 uses a sealed bid instead.
- **Descending prices over days.** No evidence covers price steps a day long, or Dutch sales with very few bidders [8]. A Deepen run on auction theory with few bidders could answer it.
- **Unconfirmed details.** Whether Baro's stock is shared and limited, and how often Marvel Snap's shop rotates, could not be confirmed: the wikis were blocked.

## Sources

| # | Supports | Publisher | Pub date | Accessed | Confidence |
|---|---|---|---|---|---|
| [1] | OSRS item sink mechanism, daily quotas, start small | [OSRS Wiki (Jagex update mirror)](https://oldschool.runescape.wiki/w/Update:Grand_Exchange_Tax_%26_Item_Sink) | 2021-12 | 2026-11-24 | high (verified) |
| [2] | Sink raised luxury prices, volume held | [arXiv, Hogan-Hennessy, Xenopoulos, Silva](https://arxiv.org/abs/2210.07970) | 2022-10 | 2026-11-24 | high (verified, abstract only) |
| [3] | Tax raise to 2 %, protest | [PC Gamer](https://www.pcgamer.com/games/mmo/american-old-school-runescape-players-are-recreating-the-boston-tea-party-after-jagex-hiked-taxes-they-took-a-page-from-the-british-empire-rather-poetic-from-a-british-game) | 2025-05 | 2026-11-24 | medium |
| [4] | Guide price from trades, capped moves | [OSRS Wiki, Grand Exchange](https://oldschool.runescape.wiki/w/Grand_Exchange) | n.d. | 2026-11-24 | medium |
| [5] | Per-account 4 h buy limits | [OSRS Wiki, Buying limits](https://oldschool.runescape.wiki/w/Grand_Exchange/Buying_limits) | n.d. | 2026-11-24 | medium |
| [6] | EVE measures faucets and sinks, no target | [CCP Games](https://www.eveonline.com/news/view/eve-economy-update-eve-vegas-2015-report) | 2015-11 | 2026-11-24 | medium (stale) |
| [7] | Descending sales: waiting game, overpay, end rush; clearing-price fix; underpricing races | [a16z crypto, Kominers & Roughgarden](https://a16zfrontier.com/nft-sales-market-clearing-gas-wars-auction-mechanism-design-for-builders/) | 2022-09 | 2026-11-24 | high (verified) |
| [8] | Clock speed vs sealed-bid revenue | [Experimental Economics, Katok & Kwasnica](https://ideas.repec.org/a/kap/expeco/v11y2008i4p344-357.html) | 2008 | 2026-11-24 | medium |
| [9] | Otherside: Dutch auction dropped, access race | [CoinGape](https://coingape.com/just-in-yuga-labs-cancels-otherside-auction-apecoin-rallies-past-26/) | 2022-04 | 2026-11-24 | medium |
| [10] | Robust market value from thin listings | [TradeSkillMaster docs](https://support.tradeskillmaster.com/tsm-addon-documentation/auctiondb-market-value) | n.d. | 2026-11-24 | medium |
| [11] | Ducats from destroyed parts, fixed rates | [Warframe Wiki, Orokin Ducats](https://wiki.warframe.com/w/Orokin_Ducats) | n.d. | 2026-11-24 | medium |
| [12] | Baro: biweekly, 48 h, announced | [Warframe Wiki, Baro Ki'Teer](https://wiki.warframe.com/w/Baro_Ki%27Teer) | n.d. | 2026-11-24 | medium |
| [13] | Disenchant returns 1/8 to 1/4 of craft cost | [Blizzard Support](https://support.blizzard.com/en/article/20456) | n.d. | 2026-11-24 | medium |
| [14] | Personal monthly card picker | [Marvel Snap (Second Dinner)](https://marvelsnap.com/?p=90212) | 2023-03 | 2026-11-24 | medium |
| [15] | Card Shop with personal daily cards | [Marvel Snap (Second Dinner)](https://marvelsnap.com/?p=91009) | 2025-04 | 2026-11-24 | medium |
| [16] | Items return with "a good chance" | [Epic Games Help](https://www.epicgames.com/help/c-34254770/c-33726977/when-will-items-return-to-the-fortnite-shop-a20534496) | n.d. | 2026-11-24 | medium |
| [17] | Countdown removal complaints, per-item timer reported | [VideoGamer](https://www.videogamer.com/news/fortnite-seems-set-to-make-the-biggest-change-to-the-item-shop-yet) | n.d. | 2026-11-24 | low |
| [18] | Paimon's Bargains monthly, per-player limits | [GameWith](https://gamewith.net/genshin-impact/article/show/22383) | n.d. | 2026-11-24 | low (secondary) |
| [19] | PoE2 vendors refresh per player on level-up | [PoE2 Wiki](https://poe2wiki.net/wiki/Vendor) | n.d. | 2026-11-24 | medium |
| [20] | Neopets restock races and autobuyers | [Alex Irpan (blog)](https://www.alexirpan.com/2018/11/10/neopets-economy.html) | 2018-11 | 2026-11-24 | medium |
| [21] | Albion buy-only Black Market | [Albion Database guide](https://www.albiondatabase.com/guides/black-market) | n.d. | 2026-11-24 | medium (fan guide) |
| [22] | NPC prices as floor and ceiling | [Game Developer, Simon Ludgate](https://gamedeveloper.com/design/the-f-words-of-mmos-faucets) | 2011-07 | 2026-11-24 | medium |
| [23] | NPC arbitrage loops from narrow spreads | [Stratics forum](https://community.stratics.com/threads/jeremy-npc-vendors-price-bug.57552/) | n.d. | 2026-11-24 | low (forum) |
| [24] | Ratio rules of thumb disagree, unsourced | [StraySpark blog](https://www.strayspark.studio/blog/game-economy-balancing-spreadsheets) | n.d. | 2026-11-24 | low |

## Staleness map

- **First to re-check (before acting):** the shop rules of live games [11][12][14][15][16][18][19]. The pricing and features bar is 3 months, and most of these pages are undated live pages.
- **Mechanism and theory sources** [1][2][7][8]: these describe how things work and age slowly. Re-check [1] for changes to the sink list.
- **The report as a whole:** re-check it before 2027-05 (two quarters), per the selection rule.
