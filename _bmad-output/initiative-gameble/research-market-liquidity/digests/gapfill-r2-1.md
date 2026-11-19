# Gap-fill round 2, digest 1

Accessed 2026-11-19 for every row. "Read" = page text retrieved this run; "snippet" = search-result text only.

## Claims

| # | Claim | Source URL | Publisher | pub_date | Confidence | Class | Read? |
|---|---|---|---|---|---|---|---|
| a1 | Valve defines a buy order on commodity items: "you specify the price you want to pay, and when an item comes available at that price the purchase completes. If there isn't an item available immediately at that price, then that request to purchase stays active until an item listed at the right price comes along." The price is a maximum; buyer pays the lower price if a cheaper item appears. | https://help.steampowered.com/en/faqs/view/61F0-72B7-9A18-C70B | Valve (Steam Support, Community Market FAQ) | undated | high | mechanism | read (raw HTML; the page renders via JS, so WebFetch saw only chrome) |
| a2 | Buy orders apply to "commodity" items: "all the items are identical, and can be traded interchangeably". | same | Valve | undated | high | mechanism | read |
| a3 | Up to 10x wallet balance can sit in active buy orders, "so you can place low-priced buy orders on a lot of items that you're interested in"; an order is auto-cancelled if the wallet cannot fund it. | same | Valve | undated | high | mechanism | read |
| a4 | Valve states buy orders help sellers: "you can see what other users are willing to pay for an item, and you can choose if you want to do a lower price to sell immediately; or go for a higher price and wait." | same | Valve | undated | high | dev-statement | read |
| a5 | Matching: a new buy order takes the cheapest listings, oldest listing first. When several buy orders could fill a new listing, "the oldest matching buy order will be selected" (changed March and July 2017 from highest-after-currency-conversion, for fairness across currencies). | same | Valve | undated (references 2017 changes) | high | mechanism | read |
| a6 | Fees: "Steam Transaction Fee ... is currently 5% (with a minimum fee of $0.01)", paid by the buyer, shown on the confirmation page. Game-specific fee "determined and collected by the game publisher", currently 10% for TF2, Dota 2 and CS2. | same | Valve | undated | high | mechanism | read |
| a7 | Buy orders on Steam Market date from a 2014 announcement (forum repost). | https://www.valvetime.co.uk/threads/new-steam-community-market-features-credit-card-verification-and-buy-orders.245291 | ValveTime (fan forum) | undated | medium | mechanism | snippet |
| b1 | GGG's announcement "Introducing the Currency Exchange Market" (Community_Team) was posted 2024-07-22 for the 2024-07-26 Settlers of Kalguur launch; the mechanics were explained in an embedded video, not in text. Players in the thread regret it is not in Standard/SSF. | https://www.pathofexile.com/forum/view-thread/3532348 | Grinding Gear Games | 2024-07 | high (for existence/date); mechanics not in text | dev-statement / player-sentiment | read |
| b2 | 3.25.0c added "a warning ... when your chosen trade ratio is more generous than the market requires"; 3.25.0d: holding Alt over the Market Ratio "now displays information about competing trades on the market"; 3.25.0b fixed players "unable to retrieve partial orders" and added an "Owned" tab to "I Have". Shows partial fills exist and GGG kept adding order-book visibility. | https://pathofexile.com/forum/view-thread/3541691 ; /3546212 ; /3537823 | Grinding Gear Games | 2024-07/08 | medium-high (official notes, but quoted from snippets) | mechanism | snippet |
| b3 | Maxroll: "The moment your exchange listing is placed, it is available to be filled"; "Exchanges can be partially filled and canceled at any time"; up to 10 exchanges at a time; gold cost scales with quantity and is not refunded on cancel; completed exchanges are collected from Faustus, with a hideout icon if you missed the notice. | https://maxroll.gg/poe/currency/currency-exchange-market | Maxroll.gg (CoffeeBns) | 2024-07 (updated 2025-06) | medium-high | mechanism | read |
| b4 | Orders "are fulfilled asynchronously in real-time, meaning you don't need to be online for trades to complete" (third-party guides). Not found in GGG text this run. | (search summary of poe-vault / mmogah / poedb guides) | third parties | 2024 | medium | mechanism | snippet |
| b5 | Mark Roberts (GGG) said in the preview video they were "excited" to see whether the market performs in Settlers and whether it has a place in future leagues; trade menu shows the 12 highest-volume currencies. | https://gamingbolt.com/?p=594101 | GamingBolt | 2024-07 | medium | dev-statement (reported) | snippet |
| c1 | Pokémon TCG Pocket trading overhaul shipped 2025-07-29 (with Wisdom of Sea and Sky); trade tokens removed; new wishlist lets players pick cards they want to receive. | https://comicbook.com/gaming/news/pokemon-tcg-pocket-big-changes-to-trading-start-date | ComicBook.com | 2025-07 | medium-high | mechanism | snippet |
| c2 | Wishlist: up to 20 cards via My Cards; 3 featured on the profile; visible to traders when viewing your profile, on friends lists and when making trades. Article reports no notifications/matching and no trade-volume data; reaction is the writer's opinion. | https://www.pocketgamer.com/pokemon-trading-card-game-pocket/wishlist-feature-changes | Pocket Gamer | 2025-07 | medium-high | mechanism | read |
| c3 | Motive cited by coverage: with no in-game communication it was hard to convey what you wanted in exchange. | https://www.lodj.ma/Pokemon-TCG-Pocket-introduces-Wishlists-to-fix-trading-challenges_a139825.html | L'ODJ Média | 2025-07 | medium | mechanism / player-sentiment | snippet |
| d1 | Gods Unchained Shine Fusing burns 5 copies (+ $GODS + Flux) for one higher-shine card; devs call it the game's first burn mechanism, reducing circulating lower-shine supply, and argue it could stabilise card value. | https://portal.godsunchained.com/blog/shine-fusing-feature | Immutable (GU) | undated | medium (official, but 403 on fetch) | mechanism / dev-statement | snippet |
| d2 | GU later posted "CURRENT STATUS: FUSING AND THE FORGE IS DEACTIVATED" (date and reason not retrieved). | https://portal.godsunchained.com/blog/fusing-cards-temporarily-on-hold | Immutable (GU) | undated | low-medium | dev-statement | snippet (403) |
| d3 | Splinterlands: non-soulbound cards carry a fixed DEC burn value; when market price falls below it, buying and burning is profitable, so burn value acts as a system price floor / buyback for any card. | https://hiveblocks.com/@gadrian/splinterlands-from-too-many-to-not-enough-in-no-time (and publish0x posts in search) | community (Hive / publish0x) | 2024 | medium | mechanism / player-sentiment | snippet |
| e1 | No source measured a trade-volume effect of wishlists or want lists (Pokémon TCG Pocket, Discogs, MTG Arena/MTGO, MythicHub). Discogs acquired Wantlister in 2024 to integrate it; users complain of missed/duplicate wantlist alerts. | https://radiox.cms.socastsrm.com/2024/06/05/discogs-knows-your-wantlist-needs-uncluttering-acquires-wantlister/ | Radio X | 2024-06 | medium | dev-statement (reported) | snippet |

## Takeaways for a ~30-player market (inference, not evidence)

- Steam and PoE both solve thin markets with standing orders that fill without the counterparty present (a1, a5, b3/b4). Valve also states buy orders inform sellers of the instant-sell price (a4).
- Both cap and price orders (Steam: 10x wallet; PoE: 10 orders, non-refundable gold), so standing orders stay cheap but bounded.
- A system floor (Splinterlands burn value, d3) gives every card a guaranteed exit; GU's sink was later switched off (d2), reason unknown.
- No quantitative evidence that wishlist matching raises trade volume was found; the case rests on mechanism and design intent.

## Leads

- Steam FAQ raw HTML holds more: "How long do buy orders stay active?" (system-cancellation reasons), the 200-item sale limit. Same URL as a1.
- PoE 3.25.0 main patch notes thread https://www.pathofexile.com/forum/view-thread/3531661 (~245k chars); first 200k read, no Currency Exchange lines; the last 45k (offset 200000) was not read.
- GGG "Currency Exchange UX Improvements" feedback thread: https://pathofexile.com/forum/view-thread/3537965
- poe.ninja / community data on exchange volume per league (not searched).
- GU portal blog (403 to fetcher): "the tales told by secondary markets", "nuts and bolts of the marketplace week 1".
- Pokémon TCG Pocket official news page (the press-release URL returned 404).

## Looked for, not found

- GGG text stating orders fill while offline (only third-party guides say so).
- Any GGG or community figure on trade volume before and after the Currency Exchange.
- Official Pokémon Company text for the wishlist; any later (2025-11 to 2026) trading change.
- Primary GU/Splinterlands statement that commons are unsellable or order books thin.
- Any measured trade-volume lift from wishlists or want-list notifications (Cardmarket, TCGplayer, Steam trade matcher, Monopoly GO, Pokémon GO, Discogs).
