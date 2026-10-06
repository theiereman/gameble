---
tracker_id: ""
key: ""
type: epic
title: "Steam catalog"
parent: initiative-gameble
covers: [CAP-2, CAP-3]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Steam catalog

## Description

The card catalog is built from Steam: an administrator starts an import, watches it, and publishes a season whose cards have a rarity and belong to sets.

## Outcome

For players: a catalog of established Steam games to draw from, whose rarity anyone can explain. For the administrator: an import that can be watched and resumed.

## Requirements

- R1 (CAP-2; architecture AD-19): an administrator starts an import run by hand from the back-office; each run has a record with its step, counts and errors, shown in the back-office while it runs.
- R2 (architecture AD-19, AD-21; `catalog-and-rarity.md`, Import): import jobs run on their own queue, in the import worker process, with one throttled worker that stays under Steam's limits (store endpoints about 200 requests per 5 minutes; Web API 100,000 calls per day per key); a run resumes after an interruption from where it stopped, and every write is idempotent.
- R3 (CAP-2; `catalog-and-rarity.md`, Inclusion): one card per Steam app of type `game`; DLC, soundtracks, demos and tools are excluded; a game without a vertical Steam library image is excluded; a game with fewer than 500 Steam reviews is excluded.
- R4 (CAP-2; `catalog-and-rarity.md`, Card identity; architecture AD-18; spec CAP-7): each card has a title and a short description in French and English taken from Steam's localized store text, a release date, its store tags, its publisher (shown with a generic notice that the game and its image belong to their owners; no per-game copyright since story 10), its image address on Steam's CDN (the image is never copied) and a link to its store page.
- R5 (CAP-3; architecture AD-4): `Steam` keeps the raw Steam responses in its own tables and computes each game's prestige score from its review score and review count only; Metacritic is not used. `Catalog` and `Game` never reference a Steam-specific field.
- R6 (CAP-3; architecture AD-5; DESIGN.md, Dust): an import fills a draft season. `Catalog::PublishSeason` turns prestige scores into the five tiers (integers 1 to 5, steel, emerald, sapphire, amethyst, gold, defined once in `Catalog`), sets each card-season's dust tier from the game's age, and makes the season visible at once; rarity and dust tier never change after publication; draws read only the published season.
- R7 (CAP-2; `catalog-and-rarity.md`, Sets): publishing builds the sets of the season: one publisher set per publisher with at least 5 games; tomes, each genre of a curated list of Steam genre tags split into volumes of about thirty games by release date, a game sitting in one tome by its most-voted listed genre tag (story 10; before it, its first-listed store genre); and for each release year the 10 games with the highest review score.

## Done when

1. An administrator starts an import from the back-office and sees its step, counts and errors while it runs.
2. An interrupted import resumes without restarting and without duplicate cards.
3. Publishing season 1 makes its cards visible at once, each with a rarity tier, a release date, a title and description in French and English, and its sets.
4. No game is in the catalog with fewer than 500 Steam reviews or without a vertical Steam image.
5. The published season contains publisher sets, tomes and "best rated of the year" sets.

## Boundaries

The `Steam` and `Catalog` packs and the import pages of the back-office. Not the display of cards or sets to players (epic-packs-and-reveal, epic-collection-and-sharing).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-4, AD-5, AD-19
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md

## Notes

- Open question: prestige formula and tier thresholds; calibrated on the first real import. Resolved: tier shares kept at calibration (2026-10-06), formula chosen by the author in story 2.12 (2026-10-06).
- Unknown: the duration of a full import pass under Steam's rate limit; measured on the first run.
- Retrospective (2026-10-03): not accepted until season 1 is published from a real import; see `epic-steam-catalog-retrospective.md`. Follow-ups: story 10 (no store API), story 11 (import hardening), then the author's real import, calibration and publication, then a new retrospective.
- Degraded local import (2026-10-03, development): 1,000 listed games, 502 kept by the review filter, 498 cards written into draft season 2; all steps but genres took 14 s, genres (store API) about 17 min.
- Unknown: which Steam endpoint gives review counts, tags and the vertical image cheapest; `IStoreBrowseService/GetItems` may batch them, `appdetails` and `appreviews` are one app per call. The review pass and the store-details entries settle it before they write code.
- Finding (2026-10-02, probed with the real key): `IStoreBrowseService/GetItems` (Web API quota, not the store limit) takes 100 appids per call (500 is refused with 400, URL length) and returns, per app, `reviews.summary_filtered.review_count` and `percent_positive`, `tagids` with weights, `assets.library_capsule` (the vertical 600x900 image, absent when the game has none) with `asset_url_format`, `release.steam_release_date`, `basic_info.publishers` and the `short_description` in the `context.language` asked. It returns no genres. `IStoreService/GetTagList?language=` names the tags per language. `appdetails` (store limit, one app per call) is the only source found for `genres` and `legal_notice`. The full list was 190,050 games on 2026-10-02, so the review pass is about 1,900 GetItems calls.
- Finding (2026-10-02, second probe): `GetItems` does not localize game names (`french` and `english` give the same `name`), only `short_description`; `basic_info.publishers` is a list of `{ name, creator_clan_account_id }`; `release` may carry `original_release_date` or `original_steam_release_date` besides `steam_release_date`; `assets.library_capsule` may be a hashed path (`<hash>/library_capsule.jpg`), and the image is served at `https://shared.akamai.steamstatic.com/store_item_assets/` + `asset_url_format`. `appdetails?appids=<id>&cc=us&l=english&filters=basic,genres` returns `type`, `genres` (`{ id, description }`) and `legal_notice`; an unknown appid answers `{"<id>":{"success":false}}`; `filters=basic,genres` does not accept several appids.
- Risk for story 2.8 (2026-10-02): `appdetails` lists non-genres such as `Indie`, `Free To Play` and `Early Access` among `genres`; when one comes first, a game's tome follows it, and the `indie` tomes could run to hundreds of volumes. Check the first-genre distribution on the real import before publishing season 1.
- Decision (2026-10-02): set names and genre labels (`catalog.sets.*`, `catalog.genres.*`) are rendered by the collection epic; story 2.7 stores what they need in `catalog_sets.params`.
- Decision (2026-10-02): the prestige score starts as the Wilson lower bound of the positive share (95 %) plus `0.01 × log10(review_count)`, so acclaim dominates and the count only nudges (story 2.5's plan review showed `× log10(count)` let a "Mostly Negative" blockbuster outrank an "Overwhelmingly Positive" smaller game). Story 2.8 calibrates the weight.
- Decision (2026-10-02): breakdown of nine stories drafted by the facilitator at the author's request ("découpe l'épic 2 en stories"), pending the author's approval.
- Decision (2026-10-02): tracer bullet is story 1: an administrator starts a run from the back-office, a job on the import queue lists Steam's games, and the run's step and counts update on the page.
- Decision (2026-10-02): stories 1 and 2 run side by side (back-office and `Steam` against `Catalog`); everything after story 2 is one lane, because each step feeds the next.
- Decision (2026-10-02): resumability is built into story 1 (a run's step and cursor) and every later step honours it; it is not a story of its own.
- Assumption: tiers are cut by prestige-score percentile with thresholds held in one place in `Catalog`; story 6 sets starting values and story 8 calibrates them on real data.
- Decision (2026-10-02): hitl on story 1 (a Steam Web API key in the credentials) and story 8 (the author runs the full import and approves the calibration).
- Decision (2026-10-02): a closing refactor sweep (story 9) follows every other story.
- Assumption: the set check was run by the facilitator in this conversation, not by independent agents.
- Measurement (2026-10-06, staging gameble.dotsncircles.com, author): the first full real import ran 13:53:57–14:49:19 UTC (55 min): 190,718 apps listed and reviewed, 12,326 kept (500 reviews or more), 178,392 set aside, 446 tags named, 12,326 store pages copied, 19 set aside there, 12,307 cards written, 0 refused, 0 struck from the draft.
- Measurement (2026-10-06, staging): season 1 published at 15:02:33 UTC with 12,307 cards: Commune 7,384 (60 %), Peu commune 3,076 (25 %), Rare 1,231 (10 %), Épique 492 (4 %), Légendaire 124 (1 %); 380 publisher sets, 406 tomes, 37 best-of-year sets. Calibration kept the starting values (COUNT_WEIGHT, the tier shares, TOME_SIZE); season 1 is frozen, a change applies from season 2.
- Decision (2026-10-06, author, story 2.12): the prestige score becomes `log10(review_count) + 4 × Wilson lower bound` (z = 1.96), popularity first, after a simulation on the 12,326 games of the staging import (the 124 Légendaires would be games with about 93k reviews or more and at least 76 % positive, e.g. Counter-Strike 2, Dota 2, Elden Ring, Skyrim, Red Dead Redemption 2, Cyberpunk 2077). It supersedes the 2026-10-02 starting formula and `COUNT_WEIGHT`; season 1 on staging is not republished, the formula applies from the next publication or rescore.
