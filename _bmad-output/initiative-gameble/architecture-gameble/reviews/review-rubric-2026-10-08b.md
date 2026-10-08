# Review — good-spine rubric, update run of 2026-10-08 (independent reviewer, second pass)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-08: AD-5, AD-9, AD-10, AD-25, the data model, the CAP map with CAP-22, Deferred), its `.memlog.md` (entries of 2026-10-08), `change-recognizable-sets.md` section 4.4, the three level-below units (`epic-recognizable-sets/tickets.toml` entries 1-10, `epic-season-preparation` stories 1-2, `epic-card-backs` "Cosmetics" done-when 1-6), and the brownfield code: `packs/catalog/app/models/catalog/set_builder.rb`, `packs/game/app/models/game/set_completion.rb`, `packs/game/app/operations/game/operation.rb`, `packs/game/app/operations/game/release_player.rb`, `packs/steam/app/models/steam/card_mapping.rb`, `packs/steam/app/models/steam/genre_tags.rb`, `db/schema.rb` (`catalog_sets`, `catalog_set_memberships`, `catalog_cards`, `catalog_card_seasons`, `game_set_completions`).

**Verdict:** the amendment adds the right ideas (five kinds, kind-decided tiers, one shares constant, row-decided tier events, cosmetics under AD-25), but it is **not yet safe to slice from**. Three divergence points that the stories will meet are left open: how a set is identified and addressed across seasons, rebuilds and code catalogues; exactly which tier values exist and which events each one publishes; and how the one-off rebuild's handler fits AD-10 and AD-14. AD-4 and AD-23 were not amended although the change touches them. Every fix is one or two sentences.

## What the spot-check ratified (no change needed)

- AD-10's row-decided event: `Game::SetCompletion::RECORD_SQL` already inserts with `ON CONFLICT (player_id, set_id) DO NOTHING ... RETURNING set_id`, and `Game::Operation#publish_completions` publishes one `Game::SetCompleted` per returned id after the operation's own event. A row per player, set *and tier* is a direct extension of it.
- "A tier once reached stays reached": the existing row is never deleted when cards leave (only `Game::ReleasePlayer` deletes it, on account deletion).
- AD-5's set storage: `catalog_sets (season_id, kind, key, params)` unique on `(season_id, kind, key)`, `catalog_set_memberships` with a `position` and `attr_readonly` columns. Album order ("cards in set order") has one source, the builder's `position`.
- AD-5's rebuild-once: has a precedent (numbers given once to an older season). `game_set_completions` has no foreign key to `catalog_sets`, so deleting the retired sets does not depend on the order of the Game handler.
- Expand/contract of the kind check: `catalog_sets_kind_check` lists the three retired kinds; entry 3 widens it, entry 4 contracts it. This matches AGENTS.md and AD-21.
- `catalog_cards.tags` already holds source-neutral tag keys in vote order (`Steam::CardMapping.tag_keys`). The theme list can be keyed on them without a Steam field crossing into `Catalog`.
- Pack direction: a `Game` handler that reacts to a `Catalog` event follows the allowed arrow (AD-2, AD-10 last bullet).

## Critical

None.

## High

### H1 — A set has no stable identity or public address, but four units need one
- **Location:** AD-5 (set kinds), AD-15, AD-25 ("a set's back unlocks on gold on that set"; titles "rendered from a template per set kind and the set's name"); the data model (`GAME_TITLE_UNLOCK`).
- **Problem:** A set row is per season, and its id changes when a season is rebuilt (entry 4) and again in season 2. Several units must still point at "the same set":
  - The back catalogue is "one constant in code", so a theme's back must name its set by something other than an id.
  - Title unlocks are "rows per player". Cosmetics done-when 5 gives one title per (set, tier), and nothing says whether the row holds a `set_id`, a `(kind, key)` or a duplicate of the set-tier row.
  - The album (entry 8) needs a URL. It is opened from "EN COURS", the search, the hub, the card detail, the celebration banner (entry 5) and feed lines (entry 6). AD-15 addresses players, cards, packs and invitations, but not sets.
  - Season preparation story 2 turns themes into data. If the admin renames or merges tags, a theme's key must not follow the Steam tag.
  
  The brownfield key rule for publishers (`SetBuilder.publishers`: parameterized name, then `-2`, `-3` suffixes allotted in byte order) is unstable across seasons. A franchise or studio builder that copies it gives the same franchise different keys in different seasons. Each unit will invent its own reference.
- **Fix:** Add to AD-5: "A set is identified by its kind and key, stable across seasons and rebuilds: a theme by its theme key (fixed when the theme is created, never derived from a tag name), a franchise or studio by its parameterized source name, a hall-of-fame set by a fixed key per set in the builder, the UFOs by `ufos`; `catalog_sets.id` is never referenced outside a season. Code catalogues (backs, titles, menu themes) and unlock rows name a set by `(kind, key)`." Add to AD-15: "Sets are addressed by season number, kind and key (`/:locale/sets/:season/:kind/:key`)." Add to AD-25: "A title is unlocked by its set-tier row; a title unlock row holds `(kind, key, tier)` and survives the set's season."

### H2 — The tier vocabulary and the events of a gold tier are ambiguous
- **Location:** AD-10, second bullet; AD-25 ("a set's back unlocks on gold"); entries 5 and 6; Cosmetics done-when 2, 5 and 6.
- **Problem:** The spine says "one `SetTierReached` per tier of a set ... and one `SetCompleted` per set completed for the first time, each decided by inserting a set-tier row". Three readings are open:
  - Is `complete` a tier value? Entry 5 says yes ("complete for the others").
  - Does a franchise's completion also publish `SetTierReached(complete)`?
  - Does a theme's gold, which "is complete", also publish `SetCompleted`?
  
  The change proposal said "(gold for a tiered set)", and that clause was dropped in the spine. The units that consume these events are the celebration (5), the feed and ticker lines (6), the back handler (gold), the title handler (each tier, plus complete) and the menu-theme count (gold on 3/10/25 sets). They will double-post or miss depending on the reading each one picks.
- **Fix:** Replace AD-10's second bullet with: "Tier values are `bronze`, `silver`, `gold` (kinds `theme`, `hall_of_fame`) and `complete` (the other kinds). An operation that raises a player's quantities inserts one `game_set_tiers` row per tier first reached (`ON CONFLICT DO NOTHING`) and publishes one `Game::SetTierReached { player_id, set_id, tier }` per inserted row; `gold` and `complete` rows also publish `Game::SetCompleted { player_id, set_id }`, after it. A consumer of a completion subscribes to `SetCompleted`; a consumer of a tier, to `SetTierReached`; the feed handler writes one entry per `SetTierReached` and none per `SetCompleted`."

### H3 — The rebuild's handler breaks AD-10's handler rule and AD-14
- **Location:** AD-5, fourth bullet ("a `Game` handler answers by dropping that season's set tiers"); AD-10, third bullet; AD-14, third bullet; entry 4.
- **Problem:** AD-10 lets a handler write "only rows of that player or new rows". AD-14 says work over many players is a job that runs a per-player operation, or a `Game::SystemOperation` that writes no player's rows. The rebuild handler deletes every player's rows in the `Catalog` operation's transaction, which is exactly what both rules forbid. The developer of entry 4 must break one AD or invent a job, and a reviewer can reject either choice.
- **Fix:** Name the exception in AD-10's third bullet: "One exception: the handler of `Catalog::SeasonSetsRebuilt` deletes every `game_set_tiers` row whose set belongs to that season, in one statement, in the rebuild's transaction; it runs once, before the public launch, and leaves feed entries, unlocks and achievements in place."

## Medium

### M1 — AD-4 still describes the retired genre and "best of year" path; the main theme is not frozen per season
- **Location:** AD-4, second and third bullets; AD-5, third bullet ("a card's genre in a season is its main theme in that season"), sixth bullet (card identity follows Steam); entry 3 ("gives each card its main theme as genre"); `catalog_cards.genres`/`tags` in `db/schema.rb`.
- **Problem:**
  - AD-4 still says Steam computes genres through `Steam::GenreTags` and a rating "for best rated of the year". Entry 3 deletes `GenreTags`, and best-of-year is retired. AD-4 also does not list what Steam now hands to Catalog: developers, franchises and a per-card-season review count (entry 2).
  - `tags` and `genres` are card identity, shared by seasons and rewritten by every import (AD-5 sixth bullet). A main theme computed from `catalog_cards.tags`, or written to `catalog_cards.genres` as entry 3's wording suggests, drifts under the published season at the next import. The 2026-10-05 review found the same drift for tomes (H3). That case was closed because a card sat in exactly one tome. A card can sit in several themes, so the membership alone no longer names the main one.
- **Fix:** Rewrite AD-4's second and third bullets: "Steam hands Catalog source-neutral values only: tag keys most-voted first, developers, franchises, a rating and a review count per card-season; it computes the prestige score from the last two. Steam holds no theme or genre list." Add to AD-5's third bullet: "`PublishSeason` stores each card-season's main theme key (`catalog_card_seasons.theme_key`, null in the UFOs); readers never recompute it from the card's tags."

### M2 — AD-23's opening response cannot carry the celebration
- **Location:** AD-23, second bullet; entry 5 ("a celebration banner after the reveal").
- **Problem:** The response lists cards, bank, server time, back, per-tier counts and backs unlocked, but no set tier reached. Entry 5 would extend the response, make a second request or add a DOM event, and each choice affects the island, the controller and AD-16's event list differently.
- **Fix:** Add to AD-23's success list: "the set tiers reached by the opening, each with the set's address (H1), kind, localized name and tier, in the order of `SetTierReached`."

### M3 — Season preparation story 1 has no entry in the spine
- **Location:** Deferred; AD-5, first bullet ("An import fills a draft season"); AD-19; `index_catalog_seasons_one_draft`; memlog direction 2026-10-05 ("to design in an update run before the backlog story is built").
- **Problem:** Story 1 (an import builds beside the draft and is promoted or discarded) contradicts AD-5's single draft and the one-draft unique index. Unlike the theme list, it is neither decided, deferred nor an open question in the spine.
- **Fix:** Add to Deferred: "**Import staging and promotion:** an import run builds a staging draft beside the current one and replaces it only on promotion; changes AD-5 (one draft) and AD-19; designed in an update run before Season preparation story 1."

## Low

### L1 — Tier thresholds are read live and "held" is undefined
- **Location:** AD-5, fifth bullet; Layer table ("sets and their tiers"); `Game::SetCompletion::RECORD_SQL`, `Game::HubSets` (`quantity > 0`).
- **Problem:**
  - If the shares constant is tuned after launch ("percentages tuned in playtests"), the collection's "next tier" and the album's marks move while existing tier rows stay.
  - The Layer table says Catalog holds the tiers, but AD-5 holds only a constant.
  - Whether a reserved copy counts toward a tier is unstated. The code counts `quantity > 0`, but entry 7's "closeness" query could pick `quantity - reserved`.
- **Fix:** Add to AD-5: "`PublishSeason` stores each tiered set's bronze and silver card counts on `catalog_sets`; later changes to the constant affect only later seasons. A card counts toward a set while its holding's `quantity` is above zero, reserved copies included."

### L2 — Deferred says AD-5 fixes where the set numbers live; it does not
- **Location:** Deferred ("Set numbers on real data"); AD-5.
- **Problem:** AD-5 places only the tier shares. The theme list, the franchise and studio minimum, the hall-of-fame thresholds and the UFOs' share limit have no stated home. Season preparation story 2 must read that limit at publication.
- **Fix:** Add to AD-5: "The theme list (`Catalog::Themes`), the franchise and studio minimum, the hall-of-fame thresholds and the UFOs' share limit are constants in `Catalog`, read by the builder, the draft preview and `PublishSeason`."

### L3 — Bookkeeping
- AD-9's Binds lack CAP-6, CAP-20 and CAP-22, although its rule now names set-tier and unlock rows.
- AD-14's deletion list omits set-tier and unlock rows. `Game::ReleasePlayer` already deletes `SetCompletion`; say "and its set tiers and unlocks".
- Neither the spine nor entry 5 says how `game_set_completions` becomes `game_set_tiers`. Add to AD-28-style rework, or to AD-10: "rows of `game_set_completions` are copied as `complete`/`gold`, then the table is dropped (contract)". Without that, completions recorded between entries 4 and 5 are lost.
- Observation outside the spine: the brownfield comments carry planning ids (`CAP-6, AD-5`, `story 6.7`), which AGENTS.md forbids. Entry 10's sweep or the readable-codebase epic should remove them from the files it touches.
