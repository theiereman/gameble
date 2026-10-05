# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6, CAP-7.

## Card identity

- One card per Steam app of type `game` that passes the filters.
- **Card text:** a title and a short description, stored in every language the UI supports. Translations come from Steam's own localized store text.
- **Release date:** imported with each game. It gives the year shown on the card; it drives nothing else.
- **Genre:** the game's first-listed Steam store genre, kept at import. It shows on the card and places the game in its tome.
- **Tags:** Steam store tags are imported with each game.
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
- **Formula:** calibrated on real data (see Open Questions in the spec).
- **Player-facing rule:** a player must be able to guess a card's rarity in one sentence. "The more acclaimed a game is, the rarer its card."
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
- **Tomes:** each Steam store genre is split into volumes of about thirty games, ordered by release date. A game sits in one tome, by its first-listed genre.
- **Best rated of the year:** for each release year, the 10 catalog games with the highest review score.

Completing a set can unlock a card back (CAP-20). Sets built from Steam store tags come later.

## Images

- Loaded from Steam's CDN at the vertical cover address recorded at import, never copied; only the address is stored.
- How the address is found and refreshed (the hashed vertical-capsule address; the legacy `library_600x900` path fails for recent games) is handed to the architecture: `ux-gameble.md`, For the architecture, item 2.
- Shown through the browser filter: about 32 colours per image, 2 CSS px per image pixel, no dithering, cropped to the card's art box. Steps in `DESIGN.md`, Pixel filter.

## Import

- **Source:** the Steam API, read by offline import scripts, never at play time. An administrator starts a run by hand; its progress is visible in the back-office.
- **Storage:** the scripts copy the catalog data into gameble's database, which is the reference at play time.
- **Limits measured on 2026-10-02:**
  - Store endpoints (`appdetails`, `appreviews`): about 200 requests per 5 minutes.
  - Steam Web API: 100,000 calls per day per key. `IStoreService/GetAppList` lists the apps.
- **Duration:** applying the 500-review filter needs a review count for every game on Steam, so a full pass may take hours to days. Importing text in each UI language adds requests. Measure early.
- **Terms:** an API key is required and the Steam Web API terms of use apply.
- **Delisted games:** the store API returns little for them. They are not curated in the MVP.
