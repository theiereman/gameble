# Addendum: gameble product brief

Depth that belongs downstream (PRD, architecture) or does not fit the brief.

## Comparables

- **WikiMasters** (https://www.wiki-masters.com): the user's inspiration for the loop, a French site where players collect Wikipedia cards. The user finds it fun, but unstable and poorly built ("vibe-coded"), and it sells in-game purchases without a visible legal framework. Its public page is only a login wall (email/password), so the mechanics are known only from the user's own play.
- **Wikigacha** (solo dev "harusugi", Japan): a browser TCG/gacha built on Wikipedia articles.
  - 5-card packs; packs regenerate 1 per minute, capped at 10, with more from daily missions or ads.
  - 7 rarity tiers mapped to Wikipedia article-quality ratings; ATK/DEF are derived from pageviews and content length.
  - Sources: [automaton-media](https://automaton-media.com/en/news/bizarre-browser-based-gacha-game-from-japan-turns-wikipedia-articles-into-actual-trading-cards-which-you-can-pull-from-booster-packs/), [nerdist](https://nerdist.com/article/wikigacha-game-turns-wikipedia-pages-into-collectible-pokemon-cards/)
- **Steam Trading Cards** (Valve): per-game cards dropped by playtime, badges crafted from sets, Steam Community Market with real money. The brief states the differentiation.

## Architecture hints (for the architecture phase)

- **Forkability is a product goal.**
  - Keep the game engine (boosters, rarity tiers, collection, trades, community goals, feed) independent of the catalog source.
  - Steam is one catalog adapter: source, prestige score, image and sets.
  - A fork should be able to plug in another catalog (Wikipedia, another store, etc.) without touching the engine.
- **Scaling rule:** start simple and modular. Each infrastructure component (queues, caches, streaming, e.g. Kafka) is introduced only when measured load justifies it, never ahead of it.
- **Stack:** Ruby on Rails, chosen on 2026-10-02. The author knows it well, and it has built-in pieces for translation, background jobs, live updates and deployment. Highly interactive parts, such as the pack opening, can be React components embedded in Rails pages, to keep that code readable instead of one large JavaScript file. Rust and TypeScript were considered earlier for their strict types and dropped. Details belong to the spec and architecture.
- **Content in a back-office:** themed sets and community content are managed through a back-office, not code changes.
- **Card copy model:** each copy stores its minted rarity and season from day one, so V2/V3 need no painful migration.

## Economy and naming carried over from the forge session (V2/V3)

From `forge-steam-tcg`:
- **Currency:** one in-game currency, earned only by destroying cards to the system for a tiny fixed amount per rarity, and spent bidding on rarer cards at auction.
- **Sinks:** a listing fee and a ~10% sale commission, both destroyed and shown to the player before listing. They are the only currency sinks.
- **Season goal:** fees advance the parody battle pass. Each tier rewards contributors with boosters, never currency, so the sink holds.
- **Names** (both UI languages):

  | Item | French | English |
  |---|---|---|
  | Listing fee | *Timbre Fiscal du Gambler* | *Gambler's Tax Stamp* |
  | Sale commission | *Effort de la Confrérie* | *Brotherhood Effort* |
  | Season pass | *Pass de la Confrérie* | *Brotherhood Pass* |

- **Tone:** mock-solemn, Helldivers-2-style patriotism aimed at a community of gamblers, not a nation. No real company names and no Helldivers trademarks.
- **Market gate:** access is gated by gameble-side seniority (account age or boosters opened); the threshold is TBD.

## Rejected alternatives

- **French Wikipedia catalog:** it meant competing head-on with WikiMasters and Wikigacha on execution alone, which they can catch up on. Steam games are more fun for gamers and are what the author wants to play.
- **Discord and Google sign-in:** dropped for Steam-only sign-in, which later library bonuses need and which is harder to farm.
- **French-only UI:** English speakers must be able to play at launch.
- **Library as collection:** there is nothing to obtain in-app, so rarity is meaningless.
- **Obscurity-based rarity:** famous games would be common and shovelware legendary.
- **Live rarity recomputation:** it destabilizes the value of owned cards and, later, the market.
- **Generated-only card art:** less desirable to collect.
- **Two-milestone MVP** (solo pack opening first, social second): rejected; the user prefers one complete release.

## UX intent (moved from the brief)

- **Pack opening:**
  - 5 cards land face down. Each glow is always visible and coloured by rarity, which works on mobile.
  - On desktop, hovering intensifies the glow with a slight 3D tilt.
  - Clicking a card flips it. Animation length scales with rarity: commons flip in a blink, a legendary gets an over-the-top reveal.
  - "Flip all" never skips a legendary's reveal.
- **Card frame:**
  - A gameble-designed frame (rarity effect, Brotherhood style) carries the identity.
  - The game's official Steam art is inset, with the publisher and copyright shown.
- **Sets:** genre, decade and publisher. A game can belong to several sets.
- **Art direction:** the 16-bit pixel-art style is kept. Interface art will be AI-generated, and realistic AI images quickly look like slop, while pixel art holds up. To settle in the UX work: how untouched, full-colour Steam art sits inside that style. Images are loaded as-is from Steam's CDN, so any treatment that transforms them at import (such as sepia dithering) is no longer possible.

## Catalog import (moved from the brief)

- **Card identity:** one card per Steam app of type `game`.
- **Card text:** a title and a short description, shown in every language the app supports. Steam store tags are imported too; sets may later be created from them, probably in a second phase.
- **Exclusions:** DLC, soundtracks, demos and tools.
- **Inclusion:** at least 500 Steam reviews. The estimate is 10k–20k cards, to confirm on real data.
- **Rarity:**
  - Prestige, computed from Steam review score and review volume only. Metacritic is not used. The exact formula is calibrated on real data.
  - A player must be able to guess a card's rarity in one sentence.
- **Stability:** each card copy keeps the rarity and season it was minted with. The catalog and rarities are recomputed once per season (V3), and new games enter only at season start.
- **Draw:** pick the rarity tier first (fixed odds), then a card within it, so catalog size never dilutes legendaries. Example starting odds: ~70% common, ~20% rare, with higher tiers taking the remainder. To be tuned during design.
- **Data source:** the Steam API, read by offline import scripts, never at play time.
  - The scripts copy the data into gameble's own database, which is the reference at play time. A card keeps its data even if Steam later changes or removes the game.
  - Images are never copied, because storing them would cost too much. They are always loaded from Steam's CDN, so a card may lose its image if Steam removes the game.
  - Store endpoints (`appdetails`, `appreviews`): about 200 requests per 5 minutes (web check, 2026-10-02).
  - Steam Web API: 100,000 calls per day per key; `IStoreService/GetAppList` lists the apps.
  - Finding which games pass the 500-review filter needs a review count for every game in the catalog, so a full pass may take hours to days. Measure early.
- **Delisted games:** the store API returns little for them; they would need manual curation, later.

## Compliance and lower risks (moved from the brief)

- **Game art:** it belongs to the publishers. Images are served from Steam's CDN, with the publisher and copyright shown on the card. The site terms state there is no affiliation with Steam or Valve. No Valve policy allowing or forbidding third-party display of store images was found (web check, 2026-10-02). The takedown risk is accepted with no fallback, because gameble is free and makes no money.
- **Steam Web API terms:** an API key is required and the terms of use apply; read them before launch.
- **Player library data (later):** reading a player's library may depend on their Steam profile privacy settings. Verify before designing library bonuses.
- **App stores:** review may object to third-party art and to random rewards. iOS sign-in rules may also apply. Reassess all three at the store phase.
- **Bot protection:** edge protection (e.g. Cloudflare) in front of the app, with the pack limit enforced server-side.
