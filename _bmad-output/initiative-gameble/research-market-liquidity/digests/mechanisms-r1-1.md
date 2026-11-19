# Digest — market mechanisms (round 1, agent 1)

Scope: buy orders / order books, system market makers and floors, auction vs posted price, fees and volume.
All claims retrieved 2026-11-19. Pages read: EVE devblog 2021, OSRS wiki GE, IDEAS (Einav et al. 2018 abstract), Game Developer (D3), GamingOnLinux (Albion 2017), PoE forum + poe-vault (both empty of mechanics). The rest comes from search-result snippets and is marked as such.

## Claims

Format: claim | source URL | publisher | pub_date | accessed | confidence | class

### c. Auction vs posted price

1. eBay moved from auctions to posted prices because buyers' demand for auctions fell and auction sale probabilities fell. Sellers' incentives changed; sellers and items did not. The authors model the choice as competitive price discovery against convenience, and survey evidence supports this. | https://ideas.repec.org/a/ucp/jpolec/doi10.1086-695529.html | Journal of Political Economy 126(1):178-215 (Einav, Farronato, Levin, Sundaresan), via RePEc/IDEAS | 2018-02 | 2026-11-19 | high (abstract read; full text not read) | academic
2. In matched eBay listings, auction prices vary widely and usually come in below equivalent posted prices. | https://web.stanford.edu/~leinav/pubs/AEJmicro2015.pdf (fetch failed; search snippet only) | AEJ: Microeconomics 2015 (Einav, Kuchler, Levin, Sundaresan) | 2015 | 2026-11-19 | medium | academic
3. eBay auctions sell at a discount but more often than comparable posted-price listings. Fixed-price listings get the highest price and the lowest sale rate, with buy-it-now in between. | search snippets citing Levin & Smith and an eBay format study (e.g. https://www.andrew.cmu.edu/user/alm3/papers/buyitnow.pdf, https://web.stanford.edu/~jdlevin/Papers/AFP.pdf) | various academic | undated | 2026-11-19 | low (snippets, papers not read) | academic
4. With few bidders, one extra bidder moves the final price much more. The thin-auction outcome depends mostly on whether a second bidder exists at all. | search snippet, eBay auction literature (source paper not identified) | academic | undated | 2026-11-19 | low | academic

### a. Buy orders / order books

5. In the OSRS Grand Exchange, a trade runs when a buy offer is at or above a sell offer, and the earlier offer sets the price. A buy offer that arrives first fills at the lowest existing sell price and the buyer gets the difference back; a sell offer that arrives first fills at the highest buy price. Older offers win ties, loosely. | https://oldschool.runescape.wiki/w/Grand_Exchange | OSRS Wiki (community, cites Jagex) | undated (changelog to 2026-09) | 2026-11-19 | high | mechanism
6. The OSRS GE caps how many units of each item a player can buy every 4 hours. Selling has no cap. The wiki gives no official purpose for the cap. | same | OSRS Wiki | undated | 2026-11-19 | high | mechanism
7. OSRS GE "guide price": new offers start pre-filled at a system price computed from trade history. Jagex can set it by hand to counter manipulation. Since 2026-09-30 it updates every 3h with up to ±20% per update; it used to be 24h and ±5%. | same | OSRS Wiki | 2026-09 (changelog) | 2026-11-19 | high | mechanism
8. PoE Currency Exchange (3.25 Settlers of Kalguur, live 2024-07-26): players pay gold to list currency with an NPC (Faustus). Orders fill while the player is offline. It was league-only at launch and GGG said it would review it. It was PoE's first in-game currency market; before it, about 30 currency items were traded player to player through whispers. | https://maxroll.gg/poe/currency/currency-exchange-market ; https://gamingbolt.com/path-of-exiles-currency-exchange-market-is-not-available-in-standard-leagues (search snippets) | Maxroll / GamingBolt | 2024-07 | 2026-11-19 | medium (official post read: it links to a video and does not describe the mechanics) | mechanism
9. Steam Community Market buy orders fill automatically when a listing at or below the order price appears. Sellers can "quick sell" straight into the highest buy order. | search snippets from third-party guides (steamanalyst.com, steam-navigator) | third-party | undated | 2026-11-19 | low (Valve FAQ redirect chain not followed to the end) | mechanism

### b. System market makers / floors / sinks

10. The OSRS GE tax went from 1% (2021-12-09) to 2% (2025-05-29), capped at 5M coins per item. Sales under 50 coins pay none because the tax rounds down. Most of the tax is deleted as a gold sink. Part of it funds an "item sink": Jagex buys listed high-value uniques from players and deletes them to "better control market supply". Jagex says well over half of the taxed coins are deleted rather than spent on the sink. | https://oldschool.runescape.wiki/w/Grand_Exchange | OSRS Wiki citing Jagex | 2025-05 | 2026-11-19 | high | mechanism / dev-statement
11. Albion Online Black Market (2017): an NPC that only buys. "Whenever a mob is killed, there is a chance a buy order is generated for the Black Market"; once enough orders build up for an item, the NPC raises its price. Items sold to it become the PvE loot pool, and mobs drop less silver. Crafters can sell to it directly or post sell orders, which it fills when its price reaches them. | https://gamingonlinux.com/2017/06/albion-onlines-new-black-market-feature-is-sounding-really-interesting | GamingOnLinux quoting Game Director Robin Henkys | 2017-06 | 2026-11-19 | high (as quoted) | dev-statement / mechanism
12. Third-party guides say Albion Black Market buy prices rise when supply is low and fall when supply is high, and that players "flip" items from the player market to the Black Market. Its order depth is not published. | https://www.albiondatabase.com/guides/black-market ; https://albionfreemarket.com/flipper (snippets) | community | undated | 2026-11-19 | low | player-sentiment / mechanism

### d. Fees / taxes

13. EVE moved the cost from listing to selling. On 2021-10-19 the base sales tax went 2.5%→8% (5% before the temporary relief) and the base broker fee (charged when an order is placed) 2.5%→3% (5% before), "permanently reducing the cost-pressure associated with listing orders". Base total: 11%, up from 10%. The devblog has no volume data. | https://eveonline.com/news/view/restructuring-taxes-after-relief | CCP (official) | 2021-10 | 2026-11-19 | high | dev-statement
14. EVE's 2019 devblog doubled the maximum total market tax from 5% to 10%. Players in the forum thread said the cost fell mostly on new or unskilled traders. | https://www.eveonline.com/news/view/updates-to-sales-taxes-and-brokers-fees ; forum https://forums.eveonline.com/t/devblog-updates-to-sales-taxes-brokers-fees/178876 | CCP / forum | 2019-07 | 2026-11-19 | medium (search summary, not read) | dev-statement / player-sentiment
15. Steam Market fee is 15% total (5% Steam plus a game fee, 10% for CS2), deducted from the seller; buyers pay no fee. | https://steamdb.com/en/markets/steam ; https://www.gamespot.com/news/valve-launches-steam-market-6401485 (snippets) | third-party | undated / 2013-12 | 2026-11-19 | medium (widely repeated; Valve page not read) | quantitative
16. Diablo III: Blizzard closed both the gold and real-money auction houses on 2014-03-18. John Hight: "the driving goal was to provide a convenient and secure system for trade" but "it ultimately undermines Diablo's core game play". The closure was tied to the Loot 2.0 rework. | https://gamedeveloper.com/business/blizzard-to-shut-down-i-diablo-3-i-auction-house | Game Developer quoting Blizzard | 2013-09 | 2026-11-19 | high | dev-statement

## Leads

- Einav et al. 2018 JPE full text (NBER w19021, "Sales Mechanisms in Online Markets"): sale-probability figures for auctions vs posted prices, and the role of buyer time cost.
- Einav et al. 2015 AEJ Micro (Stanford PDF, TLS failed): exact auction discount and dispersion.
- Valve Steam Market FAQ: https://help.steampowered.com/redirects/kb_article.php?ref=6088-UDXM-7214 (redirect not followed; budget).
- GGG Currency Exchange video / 3.25 patch notes / later Q&A on keeping the exchange in leagues (PoE2 also has one): official rationale for order books vs whisper trade.
- GGG "trade manifesto" (Chris Wilson): friction kept on purpose. A counterpoint on whether a game should make trade easier.
- Hearthstone / Legends of Runeterra dust-disenchant floors: a fixed-value system floor with no player market (not searched).
- CCP Quarterly Economic Reports / MER: volume before and after the 2019 and 2021 tax changes.
- Neopets shops / restock economy: NPC fixed-price sellers acting as a price ceiling (not searched).

## Looked for, not found

- Any dev statement or data showing that buy orders / order books raise liquidity or volume compared with a listing-only market. Only the mechanics were found; the PoE Exchange's reported success is press framing, not data.
- Volume data before and after any game fee change (EVE devblogs give rates, no volume).
- The OSRS official reason for buy limits (the wiki states none).
- Game-specific evidence on auctions failing with very few bidders. All evidence found is eBay/academic, at a population scale far larger than ~30 players.
- Official Albion statement that the Black Market is meant as a price floor or a guaranteed buyer. That reading is inferred from the mechanics, not stated.
