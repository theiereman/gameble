# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6.

## Card identity

- One card per Steam app of type `game` that passes the filters.
- **Card text:** a title and a short description, stored in every language the UI supports. Translations come from Steam's own localized store text.
- **Tags:** Steam store tags are imported with each game.

## Inclusion

- **Excluded:** DLC, soundtracks, demos and tools.
- **Kept:** games with at least 500 Steam reviews.
- **Target size:** an estimated 10k–20k cards, to confirm on real data.

## Rarity

- **5 rarity tiers.**
- **Inputs:** Steam review score and review count. Nothing else; Metacritic is not used.
- **Formula:** calibrated on real data (see Open Questions in the spec).
- **Player-facing rule:** a player must be able to guess a card's rarity in one sentence. "The more acclaimed a game is, the rarer its card."
- **Not obscurity:** a little-known game is never rare for being little known.

## Draw

- Pick a rarity tier with fixed per-tier odds, then pick a card uniformly within that tier. Catalog size never dilutes the top tiers.
- **Starting point for odds:** ~70% common, ~20% rare, with the higher tiers sharing the remainder. Odds are tuned in playtests.

## Sets

- Three kinds of set: genre, decade and publisher.
- A game can belong to several sets.
- **Tag-based sets:** sets can later be created from Steam store tags, probably in a second phase. Whether sets ship in the MVP is an open question in the spec.

## Import

- **Source:** the Steam API, read by offline import scripts, never at play time.
- **Storage:** the scripts copy the catalog data into gameble's database, which is the reference at play time. Images are not copied; only their Steam CDN address is stored.
- **Limits measured on 2026-10-02:**
  - Store endpoints (`appdetails`, `appreviews`): about 200 requests per 5 minutes.
  - Steam Web API: 100,000 calls per day per key. `IStoreService/GetAppList` lists the apps.
- **Duration:** applying the 500-review filter needs a review count for every game on Steam, so a full pass may take hours to days. Importing text in each UI language adds requests. Measure early.
- **Terms:** an API key is required and the Steam Web API terms of use apply.
- **Delisted games:** the store API returns little for them. They are not curated in the MVP.
