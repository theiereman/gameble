# Notes for the V2 market: a WikiMasters veteran's AMA

- **Source:** r/WikiMasters, "Je suis un OG, posez vos questions" (u/mandatory_french_guy, about 2026-10), read on 2026-11-04 from a saved copy.
- **Why it matters:** WikiMasters is a card-collecting web game (one card per Wikipedia page) with an auction market. It grew from about 500 cards on the market to more than 50,000. It is the closest live example of the V2 auction house planned in `spec-gameble/later-roadmap.md`.
- **Status:** ideas only, not decisions. Each one points to the roadmap item it informs.

## What the thread says about their economy

| Observation | Who | Lesson for gameble |
|---|---|---|
| With 100× more listings, popular cards **deflate**: "you miss the auction, no matter, another one is on the market in 2 days". Niche cards **inflate**: a card two people wanted now draws twelve, and a minor Brel song went to 300 while some legendaries "no longer rise". | OP, Mucharo, Karadoc_59 | Value follows **demand for the specific card**, not its rarity. This supports pricing per card, not per rarity (roadmap: average sale price). |
| "Nobody dares bid big up front; everyone waits for the bargain." With the crowd and the lag, everyone plays sniper, which pulls averages down. | OP | Last-second sniping plus lag rewards the fastest connection, not the most interested buyer. |
| The 10-second anti-snipe extension is too short. It should be about a minute. | OP | Add a real anti-snipe window, and use server time as the only clock. |
| Asked-for filter: show only the market listings for cards on my wishlist. | OP | A saturated market needs filtering by **my active goals and sets** from day one. |
| A card on many wishlists sells higher: the "this card is listed" notification is "the best guarantee" of several bidders. | OP | Wishlist notifications **create liquidity**. They are also the strongest lever on prices, so tune them deliberately. |
| Selling tip: "list at 1 for 24h and let interest build". | OP | Start price and duration shape outcomes. Allow a low start without letting it become a dumping exploit. |
| Commons gain value over time, but are worth more **in trades** than on the market. "I don't hesitate to give a rare for a common I want", and more friends means more people looking for THAT common. Destroying everything is not worth it. | OP | Our currency comes **only from destroying cards**. Players may grind away commons that a friend's goal needs. |
| No way to see what a card is worth without entering the auction flow. The lag makes that slow, and the paid "pro" option was the answer; a free Chrome extension ("price average") filled the gap. | Illustrious-Goat6453, Cookersinher | Price discovery is a basic need. If we don't show it, third parties will. Our free average price in the collection is right; never put it behind a paywall or rank. |
| A paying "pro" account bids at the average price and is "rarely outbid". | OP | Paid tiers that touch the market feel unfair. Our "no real money" rule holds. |
| Guilds help mostly "to find trades or hard-to-find cards". | OP | The social graph is a market tool: friends and the Brotherhood are where niche cards circulate. |
| A minted card keeps its rarity forever; its text and image follow the source page. | OP | We made the same choice (copies keep the rarity and season they were minted with). Confirmed in the wild. |
| Black "shiny" legendaries: 1% of legendaries, recently added. | OP | Rare visual variants become their own price tier. This bears on the open question of averaging per game, per minted rarity or per edition. |
| A third showcase unlocks at 10,000 cards held and vanishes when the count drops below it. | Kokillage, OP | Thresholds on "cards held" collide with destroying cards for currency. |
| Racist or provocative collections and profiles, weak moderation, waves of new accounts from far-right forums. | OP | Brand-new accounts flood the social and market spaces. Our seniority gate on the market also defends against this. |

## Ideas to carry into the V2 design

### Auctions
1. **Anti-snipe extension of about a minute**, decided by server time. A bid in the last minute pushes the end back. Players with slow connections no longer lose to snipers.
2. **Optional buy-now price** next to the auction, so a buyer ready to pay the going rate can settle it. That is what the "pro" player was doing anyway.
3. **Minimum starting price per rarity**, or a listing fee that rises as the start price falls. "List at 1" stays a fair tactic without enabling near-free transfers between a player's own accounts.
4. **Market performance is a feature.** Their lag shaped prices. Live updates on a listing's current bid should go through our existing streams, and load-test before launch.

### Finding and pricing
5. **Market filters from launch**: cards that advance my active goals or sets, cards I don't own, rarity, edition and season, ending soon.
6. **"A card you want is listed" notification**, routed through the bell. Throttle it, for example one digest per goal rather than one alert per listing, so it stays useful.
7. **Show demand, not only price.** Card detail could show "wanted by N players" (counted from active goals). This is open: it drives the niche inflation they describe, which can be good (a reason to keep commons) or bad (a pile-on).
8. **Free average price everywhere**: in the collection (already planned), on the listing form ("recent sales: …") and before destroying a card. It must never be paid or rank-gated.

### Destruction, the only source of currency
9. **Before destroying, warn when a friend's goal wants the card**: "2 friends are looking for this card", with a shortcut to offer it. This protects the trade economy that, according to the OP, makes commons valuable. It belongs in the "to process" screen of quick sorting.
10. **Destroy value vs. market value side by side** on the "to process" screen, so a player sees when a card is worth more sold than destroyed.
11. **No reward that disappears when the count drops.** If a perk depends on cards held, either keep it once earned or warn before a destruction crosses the threshold.

### Variants and editions
12. **Average sale price per variant**: an iridescent or exotic copy and an edition from an earlier season each get their own price line. Otherwise rare variants pull the average away from what a plain copy is worth. This is an input to the open question in the roadmap.

### Abuse and access
13. **Keep the seniority gate.** It also blocks waves of new accounts used for alt-account farming, wash trading or trolling. *Superseded (author, 2026-11-09): the market has no seniority gate; alt accounts are handled by back-office detection and a daily entrustment cap (`spec-gameble/market-economy.md`).*
14. **Watch for transfers between a player's own accounts**: repeated sales at the minimum price between the same two accounts. The back office should be able to list them.

## Not relevant here
- Their AI-generated quiz battles (half the questions answer themselves or are wrong): combat stays a non-goal for us.
- Battles making cards stronger: no card stats in gameble.
