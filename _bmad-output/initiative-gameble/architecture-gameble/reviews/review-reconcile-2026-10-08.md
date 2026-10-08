# Reconcile review — recognizable sets amendment (2026-10-08)

Reviewer: independent subagent, read-only except this file.
Spine: `architecture-gameble.md` (updated 2026-10-08, commit 5c2c0c3), decisions in `.memlog.md` (the nine 2026-10-08 entries).
Inputs checked: `change-recognizable-sets.md` 4.4 and 4.7; `spec-gameble.md` CAP-6, 7, 12, 13, 17, 20, 22, Constraints; `catalog-and-rarity.md` Card identity and Sets; `epic-recognizable-sets.md` and its `tickets.toml`. Grounded against `db/schema.rb` and `packs/` where the spine's wording depends on what is built.

## Verdict

**Landed, with gaps that will bite stories 2 to 5.** Every edit 4.4 asks for is in the spine, several in a stronger form (kinds named, tier shares placed in one `Catalog` constant, the rebuild routed through an event, AD-9's uniqueness rows, CAP-22 in the map). But AD-4 was not touched and now contradicts AD-5 and ticket 3; the rebuild's `Game` handler breaks AD-10's own handler rule; and several things the tickets quietly assume (a frozen main theme, the review count on the card-season, a backfill of identity, the celebration in the opening response, an address for an album) have no home in the spine. Three fixes are needed before story 3; the rest are wording.

## What landed

| 4.4 item | Spine | Status |
| --- | --- | --- |
| AD-5 genre = main theme, none in the UFOs | AD-5 rule 3 | Landed |
| AD-5 rebuild once before launch, completions dropped | AD-5 rule 4 | Landed, stronger (Catalog operation + event + Game handler), but see F2 |
| AD-10 SetTierReached / SetCompleted, unique row per player, set, tier | AD-10 rule 2 | Landed; "tiered" and "(gold for a tiered set)" dropped, see F4 |
| AD-25 back on gold; titles and themes follow the same rules | AD-25 rules 1-2 | Landed, plus "title rendered from a template, never stored" |
| Data model GAME_SET_TIER; CATALOG_SET gains its kind | ER diagram, AD-5 rule 4 | Landed (kind named in AD-5; the ER carries no attributes) |
| CAP map CAP-22 | CAP map | Landed (adds web layer and AD-18) |
| Tier shares, rounded up, one constant (memlog) | AD-5 rule 5 | Landed |
| Theme list in Catalog, in code (memlog) | Paradigm table, Deferred | Partly: AD-4 still says Steam::GenreTags (F1) |
| Spec catch-up CAP-12, CAP-17 (memlog) | Deferred | Landed (goal entries gone except reward delivery) |

## Findings

### F1 — High — AD-4 contradicts the new set rules

AD-4 still says:
- "`Steam` computes the prestige score from the review score and review count only, and a source-neutral rating for 'best rated of the year'." Best of year is retired; the hall of fame now needs the review count as well as the rating (ticket 2 keeps "each card-season's Steam review count for the hall of fame"), and `catalog_card_seasons` has `prestige_score` and `rating` but no count.
- "`Steam` computes a card's genres from its tags: the tags of the curated list in `Steam::GenreTags`, most-voted first." Ticket 3 moves the theme list "into code in place of Steam::GenreTags" in `Catalog`, and AD-5 now derives the genre from the main theme. Two ADs disagree on which pack owns genre.

Also, AD-4's "`Catalog` and `Game` never reference a Steam-specific field" sits uneasily with a `Catalog` theme list "keyed by Steam tag keys" (memlog). Tags are already in `catalog_cards.tags` as source keys, so this holds if the spine says the keys are opaque source tags.

**Fix (replace AD-4 bullets 2 and 3):**
> - `Steam` computes the prestige score from the review score and review count only, and hands `Catalog` a source-neutral rating and the review count per card-season, which the hall of fame sets read.
> - `Steam` hands `Catalog` each game's tags, most-voted first, as opaque keys with their votes, and its developers and franchises as Steam names them. The theme list, its names and the main theme are `Catalog`'s.

And drop `genres` from the identity the import writes (or mark `catalog_cards.genres` for contraction in story 3 / the sweep).

### F2 — High — The rebuild's handler breaks AD-10 and AD-14

AD-5 rule 4: "a `Catalog` operation whose event a `Game` handler answers by dropping that season's set tiers". AD-10 rule 3: a handler "writes only rows of that player or new rows". AD-14: "Every `Game` operation acts for one player… work over many players is a job running that operation once per player, or a `Game::SystemOperation` that writes only rows belonging to no player." Deleting every player's rows for a season in one handler fits none of these. Two smaller mismatches:
- At ticket 4 the table is still `game_set_completions` (ticket 5 introduces tier rows *after* the rebuild); the memlog says "drops that season's set completions", the spine says "set tiers".
- The event is unnamed, unlike every other cross-pack event in the spine.

`game_set_completions.set_id` has no foreign key and feed entries do not reference sets (schema checked), so deleting old sets is safe on the `Catalog` side; nothing else in `Game` points at a set yet.

**Fix (AD-5 rule 4, second sentence):**
> A season published with the retired kinds (`publisher`, `tome`, `best_of_year`) gets its sets rebuilt once, before the public launch, by `Catalog::RebuildSeasonSets`, which publishes `Catalog::SeasonSetsRebuilt`; a `Game` handler answers by deleting that season's set-completion or set-tier rows for every player, the one handler allowed to write other players' rows.

And append to AD-10 rule 3: "…the player's latest activity, except AD-5's one-time rebuild handler."

### F3 — High — Where the main theme is frozen is unspecified

AD-5: genre "is its main theme in that season" and must not drift (its Prevents names genres). The main theme is "the listed theme with the most votes among its 5 most-voted tags" (catalog-and-rarity), i.e. it needs vote order, which theme memberships do not carry. The tags are identity, shared by seasons and refreshed by every import (AD-5 rule 6), so deriving the genre at read time from `catalog_cards.tags` drifts at the next import. Ticket 3 does not say where it is kept.

**Fix (AD-5 rule 3, add):**
> The main theme is decided at publication from the card's tags and kept on the card-season (or as the card-season's primary theme membership); readers never derive it from the card's current tags.

### F4 — Medium — Tier values and the gold event are ambiguous

AD-10: "one `Game::SetTierReached` per tier of a set that player reaches for the first time and one `Game::SetCompleted` per set completed for the first time, each decided by inserting a set-tier row". Read literally, a franchise completion inserts one row and publishes both events, and gold on a theme publishes two events from one row. Change 4.4 said "per tier of a *tiered* set" and "(gold for a tiered set)"; ticket 5 assumes "bronze, silver, gold for tiered sets; complete for the others". The tier values are not named anywhere in the spine. Achievements (CAP-17 "first complete set", "three complete sets") and menu themes (gold on 3, 10, 25 sets) both count on this.

**Fix (AD-5 rule 5, first sentence):**
> A set's kind decides its tiers: `theme` and `hall_of_fame` sets have `bronze`, `silver` and `gold` at fixed shares of the set's distinct cards, rounded up; the other kinds have only `complete`. `gold` and `complete` are completing the set.

**Fix (AD-10 rule 2):**
> An operation that raises a player's quantities then inserts one set-tier row (unique per player, set and tier) with `ON CONFLICT DO NOTHING` for each tier newly reached, and for each row inserted publishes `Game::SetTierReached` for `bronze` or `silver`, and `Game::SetCompleted` for `gold` or `complete`. A tier once reached stays reached when cards leave.

(If the author wants a SetTierReached for gold too, say so; one row, one event is the simpler reading.)

### F5 — Medium — The opening response does not carry the celebration

R6 and ticket 5: "a celebration banner after the reveal that the booster live region announces". The banner lives in the booster island, which receives everything through AD-23's response; AD-23 lists "any card back unlocked by it" and nothing about sets. Without a field, the build either re-queries after the reveal (a GET per opening) or invents its own shape.

**Fix (AD-23 rule 2, append):**
> …and any card back unlocked by it, and the set tiers reached and sets completed by it (each with the set's slug, kind, name and tier).

Add CAP-6 and CAP-13 to AD-23's Binds.

### F6 — Medium — Story 2's backfill sits outside AD-5's write rules

Ticket 2 "keeps them on the card through the draft upsert… and fills them for the cards already imported without a new import", and keeps "each card-season's Steam review count". AD-5 rule 6: identity "is refreshed by the import (`Catalog::UpsertDraftCard`) and by AD-19's image refresh, nothing else"; developers, franchises and tags are not in its identity list. AD-5 rule 3: card-season data never changes after publication; the review count lands on season 1's published card-seasons, and from `steam_apps.details`, which holds the latest run's raw item, not season 1's (so season 1's hall of fame mixes later counts with season 1's ratings).

**Fix (AD-5 rule 6):**
> A card's identity (texts, publisher, developers, franchises, tags, release date, store and image URL) is shared by its seasons and follows Steam: it is refreshed by the import (`Catalog::UpsertDraftCard`), by AD-19's image refresh, and once by the backfill that precedes the set rebuild, nothing else.

**Fix (AD-5 rule 3, add):** "The rebuild may also give a published season's card-seasons their review count, once, from the latest stored Steam item."

### F7 — Medium — Sets have no public address

The album (ticket 8) opens from "EN COURS", the search, the hub and the card detail, on one's own collection and signed out on public profiles; the celebration and feed lines name a set. AD-15 addresses players, cards, packs and invitations, not sets; `catalog_sets` has `kind` + `key` but no slug. Without a rule a build will put `set_id` in the URL.

**Fix (AD-15 rule):** "…cards by a slug, sets by their kind and key within their season, packs and invitations by a token."

### F8 — Medium — Where set and title names live (AD-18)

The theme list is "in code with French and English names" (spec, memlog); hall of fame names (Les Intouchables…) are copy; franchise and studio names are Steam data shown as is; title templates are per kind and tier. AD-18 says all interface copy lives in the locale files; the Deferred entry implies theme names are an AD-18 exception only once they become catalog data, which leaves ambiguous whether "in code" means a Ruby constant with two strings or locale keys. The AGENTS.md pitfall (dynamic keys invisible to i18n-tasks) applies to all three.

**Fix (AD-18 rule 1, append):**
> Theme names, hall of fame names and title templates are locale keys (`catalog.themes.<key>`, `catalog.hall_of_fame.<key>`, `game.titles.<kind>.<tier>`); the theme list in `Catalog` holds keys only. Franchise and studio names are source data, shown as Steam gives them.

### F9 — Low — Title unlock rows duplicate set-tier rows

CAP-22: every franchise, studio or UFO completion and every tier of a tiered set unlocks a title. So a title is exactly a set-tier row, and AD-25's "catalogues in code, unlock rows per player" plus `GAME_TITLE_UNLOCK` in the ER diagram stores the same fact twice (and both must be dropped by a rebuild). Menu themes do fit a code catalogue (3, 10, 25 gold sets).

**Proposed fix (author to confirm, post-launch):**
> A profile title is a set-tier row the player holds; the code catalogue holds only the template per kind and tier, and the active title is a reference to a set-tier row on `game_player_states`.

Remove `GAME_TITLE_UNLOCK` from the ER diagram and "title" from AD-9's unlock rows.

### F10 — Low — A set's back cannot be keyed by a set row

AD-25: "The back catalogue is one constant in `Game`… A set's back unlocks on gold on that set." Sets are season data, rebuilt and recreated each season; a code constant can only name them by kind and key. Whether a theme's back is per season or for all seasons is open.

**Fix (AD-25 rule 1):** "A set's back is keyed by the set's kind and key, and unlocks on gold on that set in any season."

### F11 — Low — Stale lists and binds

- AD-9 Binds: add CAP-6, CAP-20, CAP-22 (it now holds set-tier and unlock rows).
- AD-10 rule 3 handler list: "…an achievement, a card back, title or menu theme unlock, the player's latest activity".
- AD-13 rule 2: "card backs unlocked outside an opening" → "card backs, titles and menu themes unlocked outside an opening" (AD-25 now routes all three there).
- CAP map: CAP-22 row add AD-9; CAP-20 row add "(after the launch)" like CAP-22, matching the spec's Launch scope; CAP-6 row add AD-15 (F7).
- AD-23's `card back` and `back-unlocked` stay valid but are post-launch now; no change needed.

### F12 — Low — "Popular" sets in "À DÉCOUVRIR"

EXPERIENCE 4.5 and R7: a new player sees "popular ones". Popularity across players is a shared figure: under AD-9 and AD-10 it must come from the periodic summing job, or be a rule needing no players (for example the largest themes). Ticket 7 says "adds no migration", so it implicitly takes the second. Suggest one line in AD-10 rule 5: "Totals across players (the gauge, set popularity) are summed by one periodic job", or state in ticket 7 that "popular" means largest.

## Inputs, not the spine (for the owners of those files)

- `spec-gameble.md` CAP-2 success lists genre, tags and sets but not developers and franchises (catalog-and-rarity has them).
- CAP-17 "first complete set" / "three complete sets" and CAP-22 "gold on 3, 10 and 25 sets": with F4's wording, whether a franchise completion counts toward "gold" is for the spec to say.
- `epic-recognizable-sets.md` References name AD-5 and AD-10 only; stories 5, 7, 8 also depend on AD-23 (F5), AD-15 (F7), AD-18 (F8), AD-26 (`last_gained_at`).
- Change log line 269 records 4.1 to 4.6 "still to apply"; the spec and catalog-and-rarity show 4.1 and 4.2 applied, but `EXPERIENCE.md` still says "Compléter le set Roguelite · vol. 1" (line 353) and "Roguelite · vol. 1" (line 454): 4.5 and 4.6 are not applied.
- `game_feed_entries` kind check and its non-null `pack_id` / `card_season_id` will need expand/contract for set entries (ticket 6); no spine change needed.
