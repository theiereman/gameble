# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6.

## Card identity

- One card per Steam app of type `game` that passes the filters.
- **Card text:** a title and a short description, stored in every language the UI supports. Translations come from Steam's own localized store text.
- **Release date:** imported with each game. It gives the year shown on the card and the dust on its back.
- **Tags:** Steam store tags are imported with each game.

## Inclusion

- **Excluded:** DLC, soundtracks, demos and tools.
- **Excluded:** games without a vertical Steam library image.
- **Kept:** games with at least 500 Steam reviews.
- **Target size:** an estimated 10k–20k cards, to confirm on real data.

## Rarity

- **5 rarity tiers**, from the most common: steel, emerald, sapphire, amethyst, gold (legendary).
- **Inputs:** Steam review score and review count. Nothing else; Metacritic is not used.
- **Formula:** calibrated on real data (see Open Questions in the spec).
- **Player-facing rule:** a player must be able to guess a card's rarity in one sentence. "The more acclaimed a game is, the rarer its card."
- **Not obscurity:** a little-known game is never rare for being little known.

## Draw

- Pick a rarity tier with fixed per-card odds, then pick a card uniformly within that tier. Catalog size never dilutes the top tiers.
- **Target:** a legendary is exceptional: about one every 400 packs.

| Tier | Per card | On average |
|---|---|---|
| Steel | 76% | — |
| Emerald | 19% | Almost one per pack |
| Sapphire | 4.3% | One every 5 packs |
| Amethyst | 0.65% | One every 30 packs |
| Gold | 0.05% | One every 400 packs |

- **First session:** a new player gets at least one sapphire or better by their 10th pack. If none came by the 9th pack, the 10th contains one. Nothing shows the guarantee.
- Odds are tuned in playtests.

## Sets

A game can belong to several sets. Three kinds ship in the MVP:

- **Publisher sets:** one set per publisher with at least 5 games in the catalog.
- **Tomes:** each Steam store genre is split into volumes of about thirty games, ordered by release date. A game sits in one tome, by its first-listed genre.
- **Best rated of the year:** for each release year, the 10 catalog games with the highest review score.

Sets built from Steam store tags come later.

## Import

- **Source:** the Steam API, read by offline import scripts, never at play time. An administrator starts a run by hand; its progress is visible in the back-office.
- **Storage:** the scripts copy the catalog data into gameble's database, which is the reference at play time. Images are not copied; only their Steam CDN address is stored.
- **Limits measured on 2026-10-02:**
  - Store endpoints (`appdetails`, `appreviews`): about 200 requests per 5 minutes.
  - Steam Web API: 100,000 calls per day per key. `IStoreService/GetAppList` lists the apps.
- **Duration:** applying the 500-review filter needs a review count for every game on Steam, so a full pass may take hours to days. Importing text in each UI language adds requests. Measure early.
- **Terms:** an API key is required and the Steam Web API terms of use apply.
- **Delisted games:** the store API returns little for them. They are not curated in the MVP.
