# Forged idea: market volume

Outcome: hardened, 2026-11-19. Builds on `../forge-market-economy/forge-market-economy.md` and `../research-market-liquidity/research-market-liquidity.md`. Returns the tab question to `../forge-duels-alpha-placement/`.

## Evidence (production, 2026-11-19; market open since 2026-11-13)

- Cards changing hands a week: about 50 sold on the market, about 1,100 moved by friend trades, about 3,000 entrusted to the Archives.
- Demand exists: 4 bids per sold listing, 9 bidders. Supply is the bottleneck: players entrust about 70 times more cards than they list.
- At the minimum price a sale nets about the entrustment value (Common 11.5 vs 10, Rare 50 vs 50). Selling only pays above the floor, so bulk duplicates rightly go to the Archives.
- PiCoins buy only market cards: 50,822 sit idle (median wallet 965).
- 56% of trade sides sit at the 4-card limit; 5 of 16 goal holders sit at 5 goals; no player is near 10 custom sets.

## Decisions

- **Target:** the market serves the cards someone wants, not the flow of duplicates. Unwanted Commons stay with the Archives.
- **Wanted:** a card is wanted when it is missing from another player's goals, or from a set that player lacks only 1 or 2 cards of. All players count, not only friends. One definition serves the buyer's "Voulue" tag and notices and the seller's signal. Sellers see a count, never names.
- **Seller flow:** the entrustment recap sets wanted cards apart ("x players want it"); the rest of the batch is entrusted at once. The notice opens a table, one line per wanted card, showing seekers, best order, average price and entrustment value. Each line is prefilled with the likeliest choice: sell at the order's price, start an auction at a higher price with its duration, or entrust anyway. "Entrust them all anyway" is offered too, and one validation covers the table. The market also has a "your wanted cards" section.
- **Buy orders:** an order targets a game across all its editions and is served only by the editions whose rarity minimum its price clears; the form says which rarities the price reaches. Money is held from placement; best price, then oldest, is served first; one copy per order; 7 days; cancellation is free.
- **Selling to an order:** the holder either sells at the order's price, a direct sale that is instant, pays no stamp and pays 10% commission, or lists higher in an ordinary auction with its stamp, and the order's owner is notified. The order stays open until a direct sale consumes it.
- **Orders and auctions stay separate:** an order never bids on its own. The order form first shows the game's open listings and offers buy-now when a buy-now is at or below the order's price. Every listing form shows the best eligible order.
- **Where orders are placed:** from a missing card in a set or goal, from the market's empty search, and as a suggestion on the goal itself.
- **Archive resale joins this work:** PiCoins buy a specific card from the Archives' stock. Its home is the Brotherhood's shop, where players browse the Archives' stock. Archive offers also appear in market search results next to player listings, and the order form proposes them when the card is neither listed nor covered by an order. They are priced well above a player's usual offer, so they set a ceiling and never undercut sellers; the spec sets the multiple (5x entrustment was simulated).
- **PiCoin utilities:** neutral capacity only, never new cards, a duel advantage or trade capacity. Free up to 5 goals (today's maximum), 5 custom sets (down from 10; the one player holding 6 keeps the sixth for free) and 3 decks (down from 5; decks are not in production yet, so nobody loses one); each slot beyond is bought with PiCoins, in context at the limit ("6th goal: X PiCoins"), and may also be listed in the shop. The spec sets the prices.
- **Navigation:** promoting the tab is not the lever, because the volume comes from entries outside it. The tab question goes back to the duels forge, where option E' stands.
- **Success measure:** the market's weekly share of cards changing hands, sales / (sales + cards moved by friend trades), about 4% today. Read it four weeks after buy orders ship. No threshold was chosen; the author decides on that reading.

## Rejected

| Rejected | Why |
|---|---|
| The market absorbs all duplicates | 500 listings of Commons for 480 never bought |
| Implicit demand only, orders later | The seller needs a firm price, not only a count |
| An order sale settles instantly with no choice | Floor-price orders would capture supply below what bidders pay |
| An order sale always opens an auction | The seller loses the instant sale that beats entrusting |
| One order per edition | Goals count any edition, and fewer sellers could serve it |
| An order bids automatically on open listings | Money held twice or moved silently |
| Promoting the market tab first | It is a shop window in front of empty shelves |
| Capsules bought for PiCoins | A safe price draws no buyers; a distinct capsule competes with duel capsules, resale or the market |
| Cosmetics for PiCoins | The author keeps them earned through achievements |
| Trade capacity for PiCoins | It is the one limit players hit, but it feeds the market's rival |

## Weak points that survived

- **Alt accounts:** a direct sale pays no stamp, so an alt's high order moves money for 10%. Off-market detection must cover direct sales.
- **Goals exposed:** "N players want it" reveals others' goals in aggregate. Accepted because only a count shows.
- **Auction stamp:** the research suggests charging at sale rather than at listing (EVE). It was left unchanged.
- **The "1 or 2 missing cards" share** is a guess; check that it does not flood the table with cards that never sell.
- **Legendaries:** a near-complete set missing a Legendary flags it as wanted, but nobody has a spare.
- **About 30 players:** no source measures any of these mechanisms at this scale.

## Forge separately

- Capsules from past seasons bought with PiCoins (author: a very good idea). They touch `forge-season-carryover`, and the price must exceed the contents' entrustment value.
