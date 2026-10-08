# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6, CAP-7.

## Card identity

- One card per Steam app of type `game` that passes the filters.
- **Card text:** a title and a short description. The title is Steam's single store name, the same in every language (Steam does not localize game names); the short description is stored in every language the UI supports, from Steam's own localized store text.
- **Release date:** imported with each game. It gives the year shown on the card; it drives nothing else.
- **Genre:** the name of the game's main theme (see Sets): the listed theme with the most votes among its 5 most-voted tags. A game in the UFOs shows no genre.
- **Tags:** Steam store tags are imported with each game, with their vote weights, as English keys. Only theme names are shown, in French and English (see Sets).
- **Developers and franchises:** imported with each game from GetItems' basic info, as Steam names them.
- **Card number:** each card has a number within its season, shown without a total ("S1 · #4 215"; digits grouped with a no-break space).
- **Card face:** title, publisher, cover, genre, release year, rarity (shape and name) and card number. No stats, cost or effect text. Layout in `DESIGN.md`, Card face.

## Inclusion

- **Excluded:** DLC, soundtracks, demos and tools.
- **Excluded:** games without a vertical Steam library image.
- **Kept:** games with at least 500 Steam reviews.
- **Target size:** an estimated 10k–20k cards, to confirm on real data.

## Rarity

- **5 rarity tiers.** Each has a name, a colour and a shape; colour never stands alone. Colours and icon sizes are in `DESIGN.md`, Rarity.

| Tier | Name | Shape |
|---|---|---|
| 1 | Commune | Circle |
| 2 | Peu commune | Double circle |
| 3 | Rare | Diamond |
| 4 | Épique | Triangle |
| 5 | Légendaire | Star |

- The names steel, emerald, sapphire, amethyst and gold are retired. English names are not written yet.
- **Inputs:** Steam review score and review count. Nothing else; Metacritic is not used.
- **Formula:** combines review count and review score, popularity first: the base-10 logarithm of the review count plus 4 × the lower bound of the positive share (Wilson, 95 %). A tenfold count is worth one point and the score at most four, so the best-known games lead and, among games known alike, the better liked one ranks higher (author, 2026-10-06, after a simulation on the 12,326 games of the first real import). Tiers are cut by percentile of this score.
- **Player-facing rule:** a player must be able to guess a card's rarity in one sentence. "The better known and the better liked a game is, the rarer its card."
- **Not obscurity:** a little-known game is never rare for being little known.

## Draw

- Pick a rarity tier with fixed per-card odds, then pick a card uniformly within that tier. Catalog size never dilutes the top tiers.
- **Target:** a Légendaire is exceptional: about one every 400 packs.

| Tier | Per card | On average |
|---|---|---|
| Commune | 76% | — |
| Peu commune | 19% | Almost one per pack |
| Rare | 4.3% | One every 5 packs |
| Épique | 0.65% | One every 30 packs |
| Légendaire | 0.05% | One every 400 packs |

- **No promise per pack:** no pack shows or guarantees a rarity.
- **First session:** a new player gets at least one Rare or better by their 10th pack. If none came by the 9th pack, the 10th contains one. Nothing shows the guarantee.
- Odds are tuned in playtests.

## Sets

Every card belongs to at least one set; a card can belong to several. A set exists only if a player recognizes it from its name. Five kinds:

- **Themes:** a curated list of about thirty Steam tags kept in code with French and English names (e.g. Souls-like, Metroidvania, Roguelike, Deckbuilder, Cosy, Horror, Zombies, Pirates, Space, Cyberpunk). A game joins every listed theme among its 5 most-voted tags. Broad tags (Action, Adventure, Casual, Indie) are never themes. Tiered.
- **Franchises:** one set per Steam franchise with at least N games in the catalog (N set on real data, 2 or 3).
- **Studios:** one set per developer with at least N games in the catalog.
- **Hall of fame:** sets drawn from review stats, thresholds set on real data: Les Intouchables (very high score, very many reviews), Les Pépites (very high score, few reviews), Les Mal-aimés (mixed score, very many reviews), Les Phénomènes (the most reviewed). Tiered.
- **The UFOs (Les OVNI):** every game with no listed theme among its 5 most-voted tags. Kept under about 5 % of the catalog by tuning the theme list, never by changing the rule.

**Tiers.** Theme and hall of fame sets have bronze (25 %), silver (50 %) and gold (100 %) of their distinct cards; percentages tuned in playtests. Franchise, studio and UFO sets are complete or not.

**Rewards.** Bronze and silver: a celebration at opening and a feed line. Gold: that set's card back. Complete (franchise, studio, UFOs): a "complete" stamp on the album and a feed line. Profile titles and menu themes: CAP-22 of the spec.

Tomes, publisher sets and "best rated of the year" sets are retired.

## Images

- Loaded from Steam's CDN at the vertical cover address recorded at import, never copied; only the address is stored.
- How the address is found and refreshed (the hashed vertical-capsule address; the legacy `library_600x900` path fails for recent games) is handed to the architecture: `ux-gameble.md`, For the architecture, item 2.
- Shown through the browser filter: about 32 colours per image, 2 CSS px per image pixel, no dithering, cropped to the card's art box. Steps in `DESIGN.md`, Pixel filter.

## Import

- **Source:** the Steam Web API, read by offline import scripts, never at play time. An administrator starts a run by hand; its progress is visible in the back-office.
- **Storage:** the scripts copy the catalog data into gameble's database, which is the reference at play time. Images are not copied; only their Steam CDN address is stored.
- **Endpoints:** only the Steam Web API: `IStoreService/GetAppList` lists the apps, `IStoreService/GetTagList` names the tags, `IStoreBrowseService/GetItems` (100 apps a call) gives reviews, text, publishers, release date, weighted tags and assets. The keyless store API (`appdetails`, about 200 requests per 5 minutes) is not used: it alone made a full import last hours.
- **Limit:** 100,000 Web API calls per day per key; a full import needs a few thousand.
- **Duration:** every season re-imports every game, so rarity reflects current reviews; there is no incremental import. Measure the full run.
- **Terms:** an API key is required and the Steam Web API terms of use apply.
- **Delisted games:** Steam returns little for them. They are not curated in the MVP.
