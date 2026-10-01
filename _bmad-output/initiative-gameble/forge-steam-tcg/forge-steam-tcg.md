# Forged idea: gameble — Steam catalog TCG

Outcome: **HARDENED** (2026-10-01)

Web TCG where every card is a Steam game. Players open free boosters, collect sets, and trade through an auction market. 100% free-to-play.

## Locked decisions

- **Card source:** the whole Steam catalog via boosters. Cards are not derived from the player's own library.
- **Catalog:** `type = game` only (no DLC/soundtrack/demo/tool), with >= 500 Steam reviews (est. 10k–20k cards, to confirm). Cards are grouped into sets (genre, decade, publisher); a game can belong to several sets.
- **Rarity = prestige:** based on review score, Metacritic and review volume. A player must be able to guess a card's rarity in one sentence.
- **Stability:** each card copy keeps the rarity and season it was minted with, forever. The catalog and rarities are recomputed once per season (e.g. quarterly), and new games enter only at season start (1st-edition effect).
- **Core loop:** 1 free booster per 10 min per player. Players destroy cards to the system for a tiny fixed amount per rarity, accumulate a single in-game currency, and bid on rarer cards at auction.
- **Money:** no real money anywhere — no purchase, no cash-out.
- **Currency sinks:**
  - A listing fee (*Gambler's Tax Stamp* / *Timbre Fiscal du Gambler*).
  - A ~10% sale commission (*Brotherhood Effort* / *Effort de la Confrérie*).
  - Both are destroyed and shown before listing.
- **Season goal:** fees advance a collective parody battle pass (*Brotherhood Pass* / *Pass de la Confrérie*). Each tier gives contributors a rarer booster. Rewards are boosters only, never currency.
- **Tone:** players belong to *The Grand Gamblers' Brotherhood* (*La Grande Confrérie des Gamblers*). Mock-solemn, Helldivers-2-like patriotism aimed at a gambler community, not a nation. Satire lives in the copy only. No real companies are named, and no Helldivers trademarks are used.
- **UI:** bilingual, French and English.
- **Card art:** official Steam images hotlinked from Steam's CDN, with the publisher and copyright shown on the card. The site terms state there is no affiliation with Steam/Valve.
- **Accounts:** login via Steam OpenID only. Market access is gated by gameble-side seniority (e.g. account age or boosters opened); before that, players can collect but not trade. The exact threshold is TBD.

## Rejected (and why)

- **Library-as-collection:** there is nothing to obtain in-app, so rarity is meaningless.
- **Obscurity-based rarity:** famous games would be common and shovelware legendary.
- **Live rarity recomputation:** it destabilizes the market and the value of owned cards.
- **Any real money:** it creates loot-box/gambling regulatory exposure.
- **Battle mode:** not wanted.
- **Email/password or generic OAuth login:** trivially farmable.
- **Generated-only card art:** less desirable to collect.
- **"Players are shareholders" theme:** too heavy.

## Deferred

- **Exotic editions:** delisted games, old classics, etc. Delisted games likely need manual curation, since the store API returns little for them.
- **Personal library layer:** badges on owned cards from the player's achievements and playtime (uses the SteamID from login).
- **Extra mechanics:** daily bonus, premium boosters, crafting.

## Surviving risks

- **No takedown fallback:** nothing is planned if a publisher asks to remove its art.
- **Steam API rate limits:** they still need to be measured against seasonal recomputation of 10k–20k games.
- **Bot farming:** it remains possible for collection and leaderboards; only the market is gated.
