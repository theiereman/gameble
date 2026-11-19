---
title: 'Competitive and user-voice research: player market liquidity vs free suggested peer trades'
type: 'competitive+user-voice+academic-lit'
topic: 'What makes a player market attractive and liquid in a game with a tiny population, compared with free, suggested peer trades'
decision: 'Whether and how to promote the player market to a main navigation tab (demoting trades) in a free card game with about 30 active players who use suggested friend trades and ignore the market'
source: 'native run (4 researcher digests, 2 rounds)'
status: complete
preset: 'standard'
validation: 'normal'
created: '2026-11-19'
updated: '2026-11-19'
claims_verified: 8
claims_unverified: 12
---

# Player market liquidity vs free suggested peer trades

**Decision this research serves:** whether and how to promote the player market to a main navigation tab and demote trades, in a free card game with about 30 active players. Those players use the trades the app suggests and ignore the market.

## Executive summary

**Do not expect a more visible tab to create market volume.** The evidence points the same way from three directions:

1. **Market design.** A marketplace works only if it is thick (it draws enough of the potential participants) and safe and simple enough that people prefer it to trading outside it [1]. With about 30 players the market cannot be thick. The suggested free trade is a simpler outside option, so it wins. In search models, money arises because it cuts the search for a "double coincidence of wants" that barter needs [2]. A trade suggester already performs that search, which takes away the market's main advantage. *(Applying both sources to gameble is inference.)*
2. **The games that address thin trading do not rely on auctions.** They use **standing buy orders** that wait for a seller (Steam [5], OSRS [6], Path of Exile [11][12]), **a system buyer of last resort** (Albion's Black Market [7], OSRS's item sink [6], Splinterlands' burn value [8]), and **posted prices**. eBay itself drifted away from auctions as buyers' demand for them and their sale rates fell [3]. No source shows that these mechanisms raise volume.
3. **Where direct trade is convenient, the auction format loses.** On Neopets, expensive items were haggled on the Trading Post and the Auction House only closed those deals [19] *(single essay)*. Pokémon TCG Pocket responded to complaints about its trading with a wishlist and a shinedust cost, not with a market [14][15]. Players still find its trading underwhelming. On low-population servers, players describe empty auction houses, prices inflated by scarcity and a handful of dominant traders, and they defend direct trade as the social option [23][24][25].

**What the evidence supports:** make the market the *fallback for the trade that has no swap*, where you want a friend's card but they want nothing of yours. That is the one case barter cannot serve and money can. It means standing bids generated from set goals, fixed or buy-now prices instead of long auctions, the Archives treated as a buyer of last resort, and no fee charged before a sale happens. Whether it earns a main tab should follow from measured volume after those changes, not come before them.

**Biggest caveat:** no source measured the effect of buy orders, wishlists or fee changes on trade volume, and none studied a population of tens of players. The mechanisms are documented. Their effect at gameble's scale is inference.

## 1. Mechanisms that create liquidity in thin markets

**Standing buy orders turn demand into something a seller can hit at once.** On the Steam Community Market, a buy order "stays active until an item listed at the right price comes along". Valve says buy orders let a seller "see what other users are willing to pay for an item" and choose to sell immediately [5] *(verified: Valve FAQ plus third-party guides)*. Buy orders work only on interchangeable items ("all the items are identical"), and a player can commit up to 10 times their wallet balance across orders [5]. The OSRS Grand Exchange is a full order book: a trade runs when a buy offer meets or beats a sell offer, and the earlier offer sets the price [6]. Path of Exile added a Currency Exchange in July 2024, which matches standing orders with partial fills [11][12]. Secondary reporting says it was the game's first in-game currency market, and that before it players traded about 30 currency items by whispering to each other *(medium, snippets)*. Third-party guides say its orders fill while the player is offline; this run found no GGG text saying so *(medium, snippets)*. GGG kept adding visibility to the exchange after launch: patches added a warning when a ratio is more generous than the market, then a view of competing orders [27].

**A system buyer gives every item a guaranteed exit.** Albion Online's Black Market is an NPC that only buys. "Whenever a mob is killed, there is a chance a buy order is generated", and its price rises as orders pile up [7] *(verified: dev quote plus community guide)*. OSRS spends part of its 2% sales tax on an "item sink" in which Jagex buys high-value items and deletes them to "better control market supply" [6]. In Splinterlands, a card's fixed burn value acts as a price floor: when the market price falls below it, buying and burning the card is profitable [8] *(medium, community source)*. No source states that any of these was designed as a liquidity floor; that reading is inference.

**Posted prices have displaced auctions on eBay.** eBay moved from auctions to posted prices because buyers wanted auctions less and auction sale probabilities fell. The authors model the choice as competitive price discovery against convenience [3] *(verified: JPE abstract plus an independent summary)*. In matched listings, auction prices are more dispersed and usually lower than posted prices [4] *(medium, snippet)*. *Inference:* price discovery needs competing bidders, so with about 30 players a 24-hour or 3-day auction mostly adds waiting time. The thin-bidder point rests on a low-confidence snippet and on eBay's scale.

**Charge on the sale, not on the listing.** In 2021 EVE moved the cost from placing an order (broker fee 3%) to completing a sale (sales tax 8%), explicitly "permanently reducing the cost-pressure associated with listing orders" [9]. CCP published no volume data [9]. Steam charges nothing until a sale: a 5% transaction fee paid by the buyer, plus a game-specific fee of 10% in Valve's own games [5]. *(An earlier snippet said the seller pays; Valve's FAQ is primary and wins.)* *Inference:* a listing stamp charged up front taxes exactly the speculative listings a thin market most needs.

**A convenient market can also hurt the game.** Blizzard closed both Diablo III auction houses in 2014. In John Hight's words, a "convenient and secure system for trade [...] ultimately undermines Diablo's core game play" [10].

## 2. How games position direct trades, markets and crafting

| Game | Direct trade | Market | Sink / crafting | Stated reason |
|---|---|---|---|---|
| Pokémon TCG Pocket | yes, restricted | no | shinedust (from duplicates) pays for trades | prevent "abuse from bots [...] multiple accounts" and preserve "the fun of collecting" [13] |
| Hearthstone | no | no | disenchant to dust, craft by rarity | "When you have trading, that brings in a bunch of other stuff with it" [16] *(secondary, citing IGN)* |
| Marvel Snap | no | no | copies are free to make | "gave everyone a photocopier [...] breaks the 'trading' market" [17] *(unverified, secondary)* |
| Steam trading cards | yes | yes, with buy orders | craft a set into a badge | all three outlets sit side by side; the badge page shows which friends own the cards you miss [18] |
| Neopets | Trading Post (haggled) | user shops and an Auction House | none relevant | Auction House used "only [...] to close already agreed-upon deals" [19] *(single essay)* |
| Gods Unchained | no | yes (on-chain) | Shine Fusing burned 5 copies; a later post says it is deactivated *(low, snippet)* | presented as removing supply to stabilise value [26] *(snippet)* |

**Push demand to the owner of the card.** Pokémon TCG Pocket's answer to unpopular trading (July 2025) was to remove trade tokens, charge trades in shinedust and add a public wishlist of up to 20 cards, 3 of them shown on the profile, "to make trades need less back-and-forth" [14][15] *(verified: three outlets)*. No source reports notifications or automatic matching in that wishlist [15]. Steam's badge page already shows which friends hold the cards you need [18]. On Steam, a self-reported matching bot shows about 174,000 trades against about 600 market transactions [21] *(low: self-reported)*. That is weak evidence that automatic 1:1 matching moves more duplicates than the market.

**A sink feeds a market only when items are scarce and priced.** When CS2 let five Covert skins be traded up into a knife (October 2025), the input skins rose up to about 10x within hours and knives fell 30 to 60% [20] *(medium, market-tracker estimates)*. *Inference:* in closed economies, a sink paid in the game's own currency (Hearthstone dust, MTG Arena wildcards, Pocket's shinedust) replaces a market rather than feeding one [14][16].

## 3. What players say about empty markets

The same pattern appears in three communities whose threads were read (WoW, FFXI, Pantheon) and a fourth seen only in a snippet (Fallout 76) *(medium)*:

- Nothing to buy: "there really isn't anything for sale", because of "lack of supply, and lack of demand, both due to a low population" [23]. Cheap useful items "aren't even listed" [24].
- Prices inflated by scarcity: "Most items worth anything cost more on the less populated servers already just due to scarcity" [24]. One player adds, "I also wonder how much people quit because it's a pain to get their hands on stuff" [24].
- A few traders dominate: on low-population realms a few experienced traders control the auction house [23], and players fear "each server dominated by the same handful of people" [25].
- Trade moves to social channels: players defend direct trade because it is social, and consignment because direct selling "takes a lot of time sitting around not playing" [25]. Splitting venues means "only one market will be favored" [25].
- The fix games shipped was **consolidation**: in 2022 WoW pooled commodity listings across every realm of a region and kept unique gear per realm [22] *(verified: Blizzard notes plus press)*.

## Cross-dimension insights

- **The suggester and the market do the same job.** Both exist to find a counterpart [2]. The suggester already does it for free, so the market can only win the trades the suggester cannot make: a one-way want, a stranger who is not a friend, or a card nobody holds as a duplicate. *(Inference from [1][2][19].)*
- **Players expect liquidity to pool in one venue** [25], and WoW consolidated its commodity markets [22] without publishing a reason or volume data. With two tabs competing for 30 players, the one with more activity drains the other. A tab swap leaves that dynamic in place. Linking the venues (a suggestion that falls back to a bid) changes it.
- **Interchangeable items are what order books need** [5][22]. Copies of the same card in the same edition are interchangeable, which makes them good candidates for standing bids. Unique or variant items fit posted prices.

## Recommendations

Each recommendation is an inference from the evidence cited, applied to about 30 players. Confidence is noted per line.

1. **Make the market the second step of a trade, not a rival tab.** When a set goal matches a friend's duplicate but no swap exists, offer "bid X PiCoin" or "buy now". *Medium:* rests on [1][2][19]. No source measured the effect.
2. **Add standing bids generated from set goals and wishlists**, so a player who owns a duplicate sees "someone will pay X now" and can sell in one tap. *Medium-high on the mechanism* [5][6][12], *low on the volume effect* (not measured anywhere).
3. **Default to fixed price or buy-now with a short window; keep auctions only for top rarities.** *Medium-high* [3][4]. The thin-bidder argument is directional, from eBay data far larger than 30 players.
4. **Treat the Archives as the buyer of last resort and show its price beside each listing,** so a seller always knows the floor. *Medium* [6][7][8]. Check how this interacts with the closed PiCoin supply: every Archives purchase mints coins.
5. **Remove the listing stamp or refund it on sale, and keep the 10% commission on completed sales.** *Medium* [9][5]. No volume data exists for fee changes.
6. **Do not split liquidity:** one market across all players, with no per-friend-group or per-region venues. *Medium* [22][25].
7. **Let measured volume decide whether the market deserves a main tab.** Watch, for example, the share of listings that sell within 24 hours and the bids filled per week after items 1 to 5 ship. *Medium.*

Feeds: the duel and navigation plan (which tab the market gets), and any market epic (buy orders, Archives floor, fee change).

**What to avoid:** long auctions as the default format in a thin market [3][4]; fees charged before a sale [9]; hidden or negotiated-only prices, which hurt price discovery [19]; splitting the market into several venues [22][25]; and a market convenient enough to replace the core loop. Diablo III closed its auction houses for that reason [10].

## Open questions

- **Measured volume effect** of buy orders, wishlists, "someone wants your duplicate" prompts or fee changes. No source found one [12][15]. Only gameble's own metrics can answer this.
- **Behaviour at tens of players.** No academic or game source covers populations this small.
- **Gods Unchained's fusing deactivation** (reason not retrieved; the blog blocks fetchers) and Path of Exile's exchange volume (poe.ninja, not searched).
- **Primary texts of the secondary quotes:** the Polygon interview for Marvel Snap [17] and the IGN interview for Hearthstone [16].

## Source appendix

| # | Supports | Publisher | Pub date | Accessed | Confidence |
|---|---|---|---|---|---|
| [1] | Thickness, congestion, safety and simplicity; the market must beat outside trading | [NBER w13530, Roth "What Have We Learned from Market Design?"](https://www.nber.org/papers/w13530) | 2007-10 | 2026-11-19 | high (verified via EconPapers record and summaries) |
| [2] | Money removes the double-coincidence search of barter | [Kiyotaki–Wright model summary (Wikipedia)](https://en.wikipedia.org/wiki/Kiyotaki%E2%80%93Wright_model_of_money) | undated | 2026-11-19 | medium |
| [3] | eBay drifted from auctions to posted prices; price discovery vs convenience | [Journal of Political Economy 126(1), Einav, Farronato, Levin, Sundaresan](https://ideas.repec.org/a/ucp/jpolec/doi10.1086-695529.html) | 2018-02 | 2026-11-19 | high (verified via EconPapers and NBER w19021 listings) |
| [4] | Auction prices more dispersed and usually below posted prices | [AEJ: Microeconomics, Einav, Kuchler, Levin, Sundaresan](https://web.stanford.edu/~leinav/pubs/AEJmicro2015.pdf) | 2015 | 2026-11-19 | medium (snippet) |
| [5] | Steam buy orders, matching, 10x wallet, fees | [Valve, Steam Community Market FAQ](https://help.steampowered.com/en/faqs/view/61F0-72B7-9A18-C70B) | undated | 2026-11-19 | high |
| [6] | OSRS Grand Exchange order book, buy limits, guide price, 2% tax, item sink | [OSRS Wiki, Grand Exchange](https://oldschool.runescape.wiki/w/Grand_Exchange) | 2026-09 (changelog) | 2026-11-19 | high (single source, cites Jagex) |
| [7] | Albion Black Market NPC buyer | [GamingOnLinux quoting Robin Henkys](https://gamingonlinux.com/2017/06/albion-onlines-new-black-market-feature-is-sounding-really-interesting) | 2017-06 | 2026-11-19 | high (verified with albiondatabase.com guide) |
| [8] | Splinterlands burn value as price floor | [Hive community post](https://hiveblocks.com/@gadrian/splinterlands-from-too-many-to-not-enough-in-no-time) | 2024 | 2026-11-19 | medium |
| [9] | EVE moved cost from listing to sale | [CCP, "Restructuring taxes after relief"](https://eveonline.com/news/view/restructuring-taxes-after-relief) | 2021-10 | 2026-11-19 | high |
| [10] | Diablo III auction houses closed; undermined core gameplay | [Game Developer](https://gamedeveloper.com/business/blizzard-to-shut-down-i-diablo-3-i-auction-house) | 2013-09 | 2026-11-19 | high |
| [11] | PoE Currency Exchange announced for Settlers of Kalguur | [Grinding Gear Games forum](https://www.pathofexile.com/forum/view-thread/3532348) | 2024-07 | 2026-11-19 | high |
| [12] | PoE exchange mechanics: partial fills, 10 orders, gold cost; earlier whisper trade | [Maxroll.gg guide](https://maxroll.gg/poe/currency/currency-exchange-market) | 2024-07 (upd. 2025-06) | 2026-11-19 | medium-high |
| [13] | Pokémon TCG Pocket trade restrictions and stated reasons | [The Pokémon Company, dev team update](http://www.pokemon.com/uk/pokemon-news/update-from-the-pokemon-trading-card-game-pocket-development-team) | 2025-01 | 2026-11-19 | high |
| [14] | Trade tokens removed, shinedust cost, wishlist planned | [VGC](https://www.videogameschronicle.com/news/pokemon-tcg-pocket-is-changing-its-most-controversial-feature/) | 2025-03 | 2026-11-19 | high |
| [15] | Wishlist shipped 2025-07: 20 cards, 3 on profile, no matching reported | [Pocket Gamer](https://www.pocketgamer.com/pokemon-trading-card-game-pocket/wishlist-feature-changes) | 2025-07 | 2026-11-19 | high (verified with ComicBook.com and Nintendo Life) |
| [16] | Hearthstone chose crafting over trading | [Shacknews citing IGN](https://shacknews.com/article/80856/hearthstone-future-could-include-tournaments-and-expansions-but-no-card) | 2013-08 | 2026-11-19 | medium (secondary) |
| [17] | Marvel Snap: free copies break a trading market | [GINX citing Polygon](https://www.ginx.tv/en/marvel-snap/trading) | 2023-01 | 2026-11-19 | medium (secondary) |
| [18] | Steam cards: trade, market and badge crafting; friends holding missing cards | [Valve, Trading Cards FAQ](https://steamcommunity.com/tradingcards/faq) | undated | 2026-11-19 | high |
| [19] | Neopets: shops carry common goods, the Auction House only closes negotiated deals, prices hidden | [Alex Irpan, "The Neopets Economy"](https://www.alexirpan.com/2018/11/10/neopets-economy.html) | 2018-11 | 2026-11-19 | medium (single essay) |
| [20] | CS2 trade-up change repriced inputs up to ~10x, knives down 30–60% | [Refrag](https://refrag.gg/blog/cs2-skins-update-trade-ups) | 2025-10 | 2026-11-19 | medium |
| [21] | Matching bot: ~174k trades vs ~600 market transactions | [Steam Community profile](https://steamcommunity.com/id/fatalerrorgoat) | undated | 2026-11-19 | low (self-reported) |
| [22] | WoW pooled commodity listings region-wide, gear stayed per realm | [Blizzard, patch 9.2.7 notes](https://worldofwarcraft.blizzard.com/en-us/news/23833174) | 2022-08 | 2026-11-19 | high (verified with PC Gamer) |
| [23] | Low-population WoW realms: nothing for sale, a few traders dominate | [Engadget / WoW Insider](https://www.engadget.com/2013-02-15-do-we-need-a-cross-realm-auction-house.html) | 2013-02 | 2026-11-19 | high |
| [24] | FFXI: cheap items not listed, scarcity prices, players quitting | [FFXIAH forum](https://www.ffxiah.com/forum/topic/54195/cross-server-auction-house) | 2019-11 | 2026-11-19 | high |
| [25] | Pantheon: dominance fears, social direct trade, one market favored | [Pantheon official forums](https://seforums.pantheonmmo.com/content/forums/topic/8405/classic-trade-vs-ah-compromise) | undated | 2026-11-19 | medium |
| [26] | Gods Unchained Shine Fusing burned copies, later deactivated | [Immutable, Gods Unchained blog](https://portal.godsunchained.com/blog/shine-fusing-feature) | undated | 2026-11-19 | medium (snippet, page blocks fetchers) |
| [27] | PoE exchange: generous-ratio warning (3.25.0c), competing-order view (3.25.0d, thread 3546212) | [Grinding Gear Games, 3.25.0c patch notes](https://pathofexile.com/forum/view-thread/3541691) | 2024-07/08 | 2026-11-19 | medium-high (snippet) |

## Staleness map

Computed with `recon_kit.py staleness`, using these windows: mechanism 3 months, dev statement 6, quantitative 12, player sentiment 18, academic 120.

| Claim | Pub | Re-check | Stale now |
|---|---|---|---|
| [5] Steam buy orders and fees | undated (read 2026-11) | 2027-02-01 | no |
| [6] OSRS GE tax, guide price, item sink | 2026-09 | 2026-12-01 | no |
| [12] PoE Currency Exchange mechanics | 2024-07 | 2024-10-01 | yes |
| [15] Pokémon TCG Pocket wishlist and trade cost | 2025-07 | 2025-10-01 | yes |
| [9] EVE listing vs sales tax | 2021-10 | 2022-04-01 | yes |
| [20] CS2 trade-up repricing | 2025-10 | 2026-10-01 | yes |
| [23][24][25] Low-population market complaints | 2013-02 to 2019-11 (newest used) | 2021-05-01 | yes |
| [1][3] Market design, auction vs posted price | 2018-02 | 2028-02-01 | no |

Five of eight claims are past their window, and the earliest re-check date is 2021-05-01. Here these are design precedents: the decision rests on *why* a mechanism worked when it shipped, not on whether it still works that way today. A Refresh matters only if one of these games has since reversed a mechanism; Pocket's trading and the PoE exchange are the likeliest to have changed.
