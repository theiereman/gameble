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
- **Stack:** Ruby on Rails, chosen on 2026-10-02. The author knows it well, and it has built-in pieces for translation, background jobs, live updates and deployment. React components, in TypeScript, are embedded for the pack reveal and the trade board. Rust, a full TypeScript stack and Hanami were considered and set aside. The binding decisions are in `../architecture-gameble/architecture-gameble.md`.
- **Content in a back-office:** themed sets and community content are managed through a back-office, not code changes.
- **Card copy model:** copies are counted per card and season, so each keeps the rarity and season it was minted with and V2/V3 need no painful migration.

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

The UX work of 2026-10-02 replaced the intent first noted here. The binding documents are `../ux-gameble/DESIGN.md` and `../ux-gameble/EXPERIENCE.md`. In short:

- **Style:** 16-bit pixel art on a light parchment theme, one pixel size everywhere, text in a modern sans-serif. Interface art is AI-generated in pixel style.
- **Card art:** the vertical Steam image, pixelated and reduced to 16 colours in the browser. Images are never copied.
- **Reveal:** dust by the age of the game, a rarity seal under the dust, then the flip. This replaces the rarity glow.
- **Sets:** publisher sets, tomes per genre, and the ten best-rated games of each year. This replaces sets by genre, decade and publisher.
- **Navigation:** the furniture of a room, furnished as the chapter hall of a Brotherhood.

## Catalog import (moved from the brief)

- **Card identity:** one card per Steam app of type `game`.
- **Card text:** a title and a short description, shown in every language the app supports. Steam store tags are imported too; sets may later be created from them, probably in a second phase.
- **Exclusions:** DLC, soundtracks, demos and tools.
- **Inclusion:** at least 500 Steam reviews and a vertical Steam library image. The estimate is 10k–20k cards, to confirm on real data.
- **Rarity:**
  - Prestige, computed from Steam review score and review volume only. Metacritic is not used. The exact formula is calibrated on real data.
  - A player must be able to guess a card's rarity in one sentence.
- **Stability:** each card copy keeps the rarity and season it was minted with. The catalog and rarities are recomputed once per season (V3), and new games enter only at season start.
- **Draw:** pick the rarity tier first (fixed odds), then a card within it, so catalog size never dilutes legendaries. Target: about one legendary every 400 packs. Starting odds per card: 76% common, 19% emerald, 4.3% sapphire, 0.65% amethyst, 0.05% legendary, tuned in playtests.
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

## Parked idea: knowledge battles (future version)

Proposed by a friend of the author on 2026-10-02, to make the game more interactive. Not in the MVP, and not scheduled. It reopens "Combat", which the brief lists as out.

- **Match:** three rounds, each with a theme drawn from Steam data. Examples: the game released closest to 2014, a game in the RPG category, the game with the best Steam rating.
- **Hand:** 20 cards are drawn at random from the player's collection. The player picks 3 of them within one minute.
- **Play:** the player places one card per round.
- **Power:** cards get attack and defence values, probably from their rarity, with power multipliers from their seals.
- **Format:** live, fast matches of 5 minutes at most.
- **Principle:** battles reward knowledge of Steam games, not collection size or time played.
- **Reward:** battles are optional and give credits for the market.
- **Challenge market:** an alternative market page where a player opens a challenge by staking a card, for example an epic Portal 2. An opponent accepts by staking a card of the same rarity. The winner takes both cards.

Points to settle before this is planned:

- The forge session rejected a battle mode, and the brief rejects trivia-style combat whose answers can be looked up online.
- Battle credits would be a second source of currency. The V2 economy earns currency only by destroying cards.
- Live matches need both players connected at once; the MVP has no live play.

