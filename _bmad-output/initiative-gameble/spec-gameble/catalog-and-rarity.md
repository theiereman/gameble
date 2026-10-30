# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4, CAP-6, CAP-7, CAP-23.

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
- **Formula:** the review count alone ranks the games; the positive percent, as Steam gives it (a whole number), only orders games with exactly the same count, with no rating floor. The score is the review count plus that percent in thousandths (5,000 reviews at 98 % score 5000.098), so a game with one more review always ranks higher, whatever the ratings (author, 2026-10-13, after a simulation on staging season 4, 12,345 cards, with the published tier sizes: Légendaire from about 174,000 reviews, Épique from about 36,000, Rare from about 9,500, and about 24 % of cards changing tier; supersedes log10(count) + 4 × Wilson lower bound of 2026-10-06). Tiers are cut by percentile of this score.
- **One formula per season:** a season's cards are all scored by one formula; a draft that mixes them is not published until rescored.
- **Player-facing rule:** a player must be able to guess a card's rarity in one sentence. "The more reviews a game has on Steam, the rarer its card."
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

- **Themes:** a curated list of about forty themes kept in code with French and English names (e.g. Souls-like, Metroidvania, Roguelike, Deckbuilder, Cosy, Horror, Zombies, Pirates, Space, Cyberpunk, Simulation, Open world, Adult); a theme groups one or more Steam tags (Roguelike: Roguelike, Roguelite, Action Roguelike, Traditional Roguelike). A game joins every theme with one of its tags among its 5 most-voted tags. Broad tags (Action, Adventure, Casual, Indie, Singleplayer, Multiplayer, Free to Play) are never themes.
- **Franchises:** one set per Steam franchise with at least 3 games in the catalog. Steam's franchise field also holds publisher pages and cross-promotions, so a franchise named like a developer or publisher of the catalog is dropped, and so is one where no more than half of its games' titles share a whole word of its name. The name is shown without Steam's suffixes ("Franchise", "Series", "- Official").
- **Studios:** one set per developer with at least 3 games in the catalog, counting each game under its first developer (porting houses come second), names normalized (legal suffixes, platform in brackets and case), and only when the studio's most-reviewed game has at least 20,000 reviews.
- **Hall of fame:** sets drawn from the review score and count frozen at publication: Les Intouchables (at least 97 % positive and 20,000 reviews), Les Pépites (at least 98 % positive and under 1,000 reviews), Les Mal-aimés (40 to 69 % positive and at least 20,000 reviews), Les Phénomènes (at least 200,000 reviews). About 90 to 100 cards each on season 2's catalog.
- **The UFOs (Les OVNI):** every game with no listed theme among its 5 most-voted tags. Kept under about 5 % of the catalog by tuning the theme list, never by changing the rule.

**Tiers.** Every set is tiered by its number of distinct cards when the season is published (author, 2026-10-18; supersedes bronze 10 %, silver 25 %, gold 50 % for themes and hall of fame only):

| Distinct cards | Tiers before completion | Then |
|---|---|---|
| 3–4 | none | complete (100 %) |
| 5–9 | Master 50 % | complete |
| 10–19 | Expert ⅓, Master ⅔ | complete |
| 20–59 | Adept 25 %, Expert 50 %, Master 75 % | complete |
| 60–199 | Apprentice 10 %, Adept 25 %, Expert 50 %, Master 75 % | complete |
| 200 and more | Novice 10 %, Apprentice 25 %, Adept 50 %, Expert 75 %, Master 90 % | complete |

The tiers before completion are named by rank, Novice, Apprentice, Adept, Expert, Master (French: Novice, Apprenti, Adepte, Expert, Maître; author, 2026-10-19), counted from the top: the last tier before completion is always Master, and a set with fewer tiers drops ranks from Novice up (author, 2026-10-19). Each tier needs that share of the set's distinct cards, rounded up. A tier's name gives its rank, not a share: Master is 50 % of a 7-card set and 90 % of a 250-card one. At the published odds, completing a large set needs every Légendaire of it, which packs alone never give. Seasons published before 2026-10-18 keep their bronze, silver, gold and complete tiers.

**Rewards.** Every tier: a celebration at opening and a feed line. A theme or hall of fame set's first tier at or above 50 % of its cards (its back tier: Adept from 200 cards, Expert from 20 to 199, Master from 5 to 19, completion below; gold in earlier seasons) also unlocks that set's card back. Complete: also a "complete" stamp on the album. The tiers and completions one opening reaches make one feed line, naming the highest, ranked by the share of its set the tier stands for. Profile titles and menu themes: CAP-22 of the spec.

**Custom sets (CAP-27).** A player's own set of 3 to 50 games shows the tiers of the table above for its size, with no reward.

Tomes, publisher sets and "best rated of the year" sets are retired.

## Seasons

- **A season is a reprint.** Each publication re-imports every game, recomputes rarities, numbers the cards and rebuilds the sets; games enter or leave the catalog. Nothing a player owns is removed or changed.
- **Editions.** A copy keeps the rarity and season it was minted with. The same game can be held in several editions of different rarities.
- **Sets across seasons.** A set keeps its kind and key from one season to the next; its members follow each season's rules. Any edition of a member game counts for it. Tiers are cut on the published season's set and earned there only.
- **Earned stays earned.** A tier reached in a season keeps that season's mark forever. A tier the player still meets when a new season is published is received again with the new season's mark at the seasonal allocation; one below its threshold is won back by play.

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
