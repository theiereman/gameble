# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6, CAP-7.

## Card identity

- One card per Steam app of type `game` that passes the filters.
- **Card text:** a title and a short description. The title is Steam's single store name, the same in every language (Steam does not localize game names); the short description is stored in every language the UI supports, from Steam's own localized store text.
- **Release date:** imported with each game. It gives the year shown on the card; it drives nothing else.
- **Genre:** the genre of the game's tome (see Sets), shown on the card. The Web API gives no store genres, so the genre comes from the tags. A game in no tome shows no genre.
- **Tags:** Steam store tags are imported with each game, with their vote weights, as English keys. Whether French labels are needed is open (see the spec).
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

A game can belong to several sets. Three kinds ship in the MVP:

- **Publisher sets:** one set per publisher with at least 5 games in the catalog.
- **Tomes:** each genre is split into volumes of about thirty games, ordered by release date. The genres are a curated list of about twenty-five Steam genre tags kept in code (e.g. FPS, third-person shooter, platformer, puzzle, horror, roguelike, souls-like, stealth, rhythm, arcade, racing, strategy, RPG, survival). Broad tags (Action, Adventure, Casual, Indie) are not genres. A game sits in one tome, that of its most-voted tag in the list; a game with none of them sits in no tome.
- **Best rated of the year:** for each release year, the 10 catalog games with the highest review score.

Completing a set can unlock a card back (CAP-20). Sets built from Steam store tags come later.

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
