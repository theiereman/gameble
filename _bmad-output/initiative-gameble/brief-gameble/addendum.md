# Addendum: gameble product brief

Depth that belongs downstream (PRD, architecture) or does not fit the brief.

## Comparables

- **WikiMasters** (https://www.wiki-masters.com): the user's direct inspiration, a French site where players collect Wikipedia cards. The user finds it fun, but unstable and poorly built ("vibe-coded"), and it sells in-game purchases without a visible legal framework. Its public page is only a login wall (email/password), so the mechanics are known only from the user's own play.
- **Wikigacha** (solo dev "harusugi", Japan): a browser TCG/gacha built on Wikipedia articles.
  - 5-card packs; packs regenerate 1 per minute, capped at 10, with more from daily missions or ads.
  - 7 rarity tiers mapped to Wikipedia article-quality ratings; ATK/DEF are derived from pageviews and content length.
  - Sources: [automaton-media](https://automaton-media.com/en/news/bizarre-browser-based-gacha-game-from-japan-turns-wikipedia-articles-into-actual-trading-cards-which-you-can-pull-from-booster-packs/), [nerdist](https://nerdist.com/article/wikigacha-game-turns-wikipedia-pages-into-collectible-pokemon-cards/)
- **Steam Trading Cards** (Valve): per-game cards dropped by playtime, badges crafted from sets, Steam Community Market with real money. Differentiation is still to be stated in the brief.

## Architecture hints (for the architecture phase)

- **Forkability is a product goal.**
  - Keep the game engine (boosters, rarity tiers, collection, trades, community goals, feed) independent of the catalog source.
  - Wikipedia FR is one catalog adapter: source, notoriety score, image and family.
  - A fork should be able to plug in another catalog (another Wikipedia language, Steam, etc.) without touching the engine.
- **Scaling rule:** start simple and modular. Each infrastructure component (queues, caches, streaming, e.g. Kafka) is introduced only when measured load justifies it, never ahead of it.
- **Stack:** Rust is considered because of AI-assisted development (strict compiler and types). The final choice belongs to architecture.
- **Content in a back-office:** themed sets and community content are managed through a back-office, not code changes.
- **Card copy model:** each copy stores its minted rarity and season from day one, so V2/V3 need no painful migration.

## Economy and naming carried over from the forge session (V2/V3)

From `forge-steam-tcg`, still valid after the Wikipedia pivot:
- **Currency:** one in-game currency, earned only by destroying cards to the system for a tiny fixed amount per rarity, and spent bidding on rarer cards at auction.
- **Sinks:** a listing fee and a ~10% sale commission, both destroyed and shown to the player before listing. They are the only currency sinks.
- **Season goal:** fees advance the parody battle pass. Each tier rewards contributors with boosters, never currency, so the sink holds.
- **Names** (French UI first):

  | Item | French | English |
  |---|---|---|
  | Listing fee | *Timbre Fiscal du Gambler* | *Gambler's Tax Stamp* |
  | Sale commission | *Effort de la Confrérie* | *Brotherhood Effort* |
  | Season pass | *Pass de la Confrérie* | *Brotherhood Pass* |

- **Tone:** mock-solemn, Helldivers-2-style patriotism aimed at a community of gamblers, not a nation. No real company names and no Helldivers trademarks.
- **Market gate:** access is gated by gameble-side seniority (account age or boosters opened); the threshold is TBD.

## Booster odds (to calibrate)

Odds are fixed per rarity tier, and a card is then picked within the tier. Example starting point: ~70% common, ~20% rare, with higher tiers taking the remainder. To be tuned during design.

## Rejected alternatives (brief session)

- **Steam catalog:** dropped for Wikipedia. Steam was judged too niche for the target audience; the user chose to compete head-on with WikiMasters and Wikigacha.
- **EN ∪ FR Wikipedia catalog and bilingual UI:** dropped for French-only, which is simpler and gives a clear French positioning.
- **Article-quality tiers as rarity:** this is what Wikigacha does, and it is not prestige.
- **Raw pageviews as rarity:** they track fads, not prestige.
- **Two-milestone MVP** (solo pack opening first, social second): rejected; the user prefers one complete release.

## UX intent (moved from the brief)

- **Pack opening:**
  - 5 cards land face down. Each glow is always visible and coloured by rarity, which works on mobile.
  - On desktop, hovering intensifies the glow with a slight 3D tilt.
  - Clicking a card flips it. Animation length scales with rarity: commons flip in a blink, a legendary gets an over-the-top reveal.
  - "Flip all" never skips a legendary's reveal.
- **Card frame:**
  - A gameble-designed frame (family colour, rarity effect, Brotherhood style) carries the identity.
  - The Wikimedia Commons photo is inset.
  - Each family has designed fallback art for articles without a photo.
- **Families:** People, Places & monuments, Film & TV, Literature, Music, Video games, Animals, Nature, History & events, Science, Sport, Brands & objects. Each has its own colour and pictogram.

## Catalog import (moved from the brief)

- **Card identity:** one card per Wikidata entity, sourced from French Wikipedia.
- **Exclusions:** non-topic pages (disambiguation, lists, years, timelines, portals).
- **Inclusion:** a subject is kept if ≥ 10 Wikipedia language editions cover it OR it gets ≥ 1,000 monthly French pageviews. The target is ~100k–300k cards, with thresholds tuned on real data.
- **Rarity:**
  - Base tier = number of Wikipedia editions (Wikidata sitelinks).
  - +1 tier for high French pageviews.
  - Foil variant (V3) for "Article de qualité" and "Bon article".
- **Draw:** pick the rarity tier first (fixed odds), then a card within it, so catalog size never dilutes legendaries.
- **Data source:** build from Wikimedia dumps, not live APIs.

## Compliance and lower risks (moved from the brief)

- **Image licences:** CC BY-SA requires attribution. Show the author and licence in each card's detail view. French Wikipedia allows no fair-use images, so all card images are freely licensed.
- **App stores:** review may object to random rewards. Sign in with Apple becomes mandatory on iOS when other social logins are offered. Reassess at the store phase.
- **Bot protection:** edge protection (e.g. Cloudflare) in front of the app, with the pack limit enforced server-side.
