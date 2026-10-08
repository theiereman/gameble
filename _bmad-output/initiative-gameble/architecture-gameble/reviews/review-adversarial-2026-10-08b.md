# Adversarial review: the 2026-10-08 amendment (recognizable sets)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-08): AD-4 as left untouched, AD-5 (set kinds, one-time rebuild, tiers), AD-9, AD-10 (`SetTierReached` / `SetCompleted`, set-tier rows), AD-13, AD-23, AD-25 (backs on gold, titles, menu themes) and the data model.

Units one level down: `epic-recognizable-sets/tickets.toml` (entries 1 to 10), `epic-season-preparation/tickets.toml` story 2 (theme list curation), `epic-card-backs/epic-card-backs.md` (Cosmetics), plus the code these units build on: `Catalog::SetBuilder`, `Catalog::Set`, `Catalog::CardViews`, `Steam::GenreTags`, `Steam::CardMapping`, `Game::SetCompletion`, `Game::HubSets`, `Game::Handlers::PackOpenedFeed`, and the schema (`catalog_cards`, `catalog_sets`, `game_set_completions`, `game_feed_entries`).

Method: for each amended area I built two units that each follow every AD word for word, and still build incompatibly. Each hole names the clash and gives rule text that closes it.

**Verdict: not ready to build stories 3 to 8 as written.** The amendment says where sets, tiers and the theme list live, but it doesn't say who stores the derived values (main theme, tier thresholds). It also leaves the event that gold publishes ambiguous, and gives nothing a set can be recognized by across seasons, which backs and titles need. AD-4 was not amended and still contradicts AD-5. I found 8 holes: 1 critical, 3 high, 3 medium, 1 low. Each closes by adding a sentence or two to an existing AD. None needs a new AD.

Severity: **critical** means a published season visibly changes, or two units corrupt each other's data. **High** means two units ship incompatible schemas or behaviour that a later story has to unpick. **Medium/low** means a visible inconsistency or rework.

---

## Critical

### H1. Nothing stores the main theme, so two readers compute it from inputs that change after publication (AD-4, AD-5)

- **Unit A, story 3 "new set kinds" (Catalog):** follows AD-5 ("a card's genre in a season is its main theme in that season"). The set builder computes themes at publication from `catalog_cards.tags` (heaviest first) and the theme list in code, and writes memberships. These are frozen, as AD-5 requires. The face needs one genre per card, but a card sits in several theme sets, and a membership doesn't record which theme is the main one. Today `Catalog::CardViews` reads the genre from the card's *one* tome. That trick no longer works. So the face computes `main_theme(card.tags, THEMES)` live.
- **Unit B, Season preparation story 2 (back-office) and the season 2 import (Steam):** follows AD-5's identity rule ("a card's identity is shared by its seasons and follows Steam: refreshed by the import"). The next import's `UpsertDraftCard` rewrites `catalog_cards.tags`, and the administrator reclassifies tags (a merge, a rename, Roguelite added).
- **Also, AD-4 bullet 3 is unchanged:** "`Steam` computes a card's genres from its tags: the tags of the curated list in `Steam::GenreTags`". A third unit that follows AD-4 keeps writing `catalog_cards.genres` from `Steam::GenreTags`. Story 3 says it replaces `Steam::GenreTags`, which contradicts AD-4. AD-4 bullet 2 still names "best rated of the year", a retired set kind.
- **Clash:** once the season 2 draft import or a reclassification happens, a season-1 card shows the genre "Roguelite", a theme that has no set in season 1. Or it shows "Souls-like" while its album lists it only under Metroidvania. AD-5's "set memberships never change" holds, but the genre, which AD-5 also places "in that season", drifts. Three owners of "genre" exist (Steam's `genres` column, the builder, the live face computation), and no AD picks one.
- **Rule (AD-5, replacing "A card's genre in a season is its main theme in that season"):**
  > `PublishSeason` records each card-season's main theme once, as a reference to one of its `theme` sets (null for a card in the UFOs); the face, the detail, the filters and the feed read only that. Nothing computes a theme from `catalog_cards.tags` after publication. The draft preview and `PublishSeason` call the same builder.
- **Rule (AD-4, replacing bullets 2 and 3):**
  > `Steam` computes the prestige score from the review score and review count only, and hands `Catalog` source-neutral fields: a rating, a review count, developers, franchises and tags in vote order. `Steam` computes no genre and no theme; themes are `Catalog`'s (AD-5).

---

## High

### H2. Tier thresholds are computed in two places from a constant that is going to change (AD-5, AD-10)

- **Unit A, story 5 "tiers at opening" (Game):** follows AD-5 ("the shares are one constant in `Catalog`, read by `Game`'s operations"). It extends `Game::SetCompletion`'s SQL to `COUNT(held) >= CEIL(:share * total)`, with numeric arithmetic in Postgres.
- **Unit B, stories 7 and 8 "EN COURS" and the album (queries):** follow the same sentence ("and by the collection's queries"). They compute `(total * share).ceil` in Ruby to draw the tier marks and the "closeness to next tier".
- **Clash:**
  1. **Rounding.** With a share tuned to 0.3 (the spec says "percentages tuned in playtests"), Ruby's `(10 * 0.3).ceil` is 4 while Postgres's `CEIL(0.3 * 10)` is 3. A player crosses bronze, gets the row and the celebration, and the album draws the bronze mark one card further on.
  2. **Drift.** When playtests change the constant, every published set's thresholds move. Rows already written stay. New players need a different count for the same published set, and the album's marks move under existing rows. AD-5 freezes memberships but not thresholds.
  3. **Reached by rows or by counts.** AD-10 says "a tier once reached stays reached when cards leave". `Game::HubSets` sorts by current counts. A player at silver who trades down to 30 % has silver as their "next tier" by counts, and gold by rows. The hub, "EN COURS" and the album can each pick a different one.
  4. **Tiny sets.** In a 2-card theme, bronze and silver both need 1 card. One card writes two rows and shows two celebrations.
- **Rule (AD-5, replacing "The shares are one constant … collection's queries"):**
  > `PublishSeason` writes each set's tiers as rows (set, tier, required distinct cards), computed once from the shares constant, which nothing else reads. A tier whose count equals a lower tier's is not created. `Game`'s tier test and every query read those rows, never the constant. A tier is reached when the player's set-tier row exists; screens draw reached marks from rows only. The next tier is the lowest tier without a row, and closeness is its required count minus the distinct cards the player holds with `quantity > 0`.

### H3. What gold and "complete" publish is ambiguous, and the opening's response cannot carry the result (AD-10, AD-23, AD-13)

- **Unit A, story 5 (Game):** follows AD-10 ("one `SetTierReached` per tier … and one `SetCompleted` per set completed for the first time"). Gold is a tier and also completes a theme, so gold publishes both events. A franchise publishes `SetCompleted`, and maybe `SetTierReached(complete)` too, since story 5 writes a `complete` row.
- **Unit B, Cosmetics (titles, backs, menu themes) and story 6 (feed):** follow AD-25 and CAP-22 ("each tier of a tiered set unlocks a title"; "completing a franchise … unlocks a title"). The title handler listens to both events. A theme at gold then grants "Maître · Roguelike" and "Complétiste · Roguelike", and the feed writes two lines for one moment. A menu-theme counter of "sets at gold" counts gold rows and misses franchises in one build, and counts `SetCompleted` and includes them in another.
- **Also, the response:** AD-23's success response is a closed list ("… and any card back unlocked by it"). Story 5's celebration banner needs the tiers that the opening reached. One build widens the JSON. Another adds them to the private stream (AD-13's list is closed too), or fetches them after the reveal. A trade can also reach a tier, but `game_feed_entries` requires `pack_id` and `card_season_id` (NOT NULL), and AD-13 puts "the choice of what enters the feed in one handler", which listens only to `PackOpened`.
- **Rule (AD-10, replacing the second bullet):**
  > Each new set-tier row publishes exactly one event. A `bronze` or `silver` row publishes `Game::SetTierReached`. A `gold` or `complete` row publishes `Game::SetCompleted` and no `SetTierReached`. Both carry `{player_id, set_id, tier}`, and are published after the operation's own event in ascending set id, then tier. One opening may publish several. "A set at gold" counts `gold` and `complete` rows.
- **Rule (AD-23, added to Success):**
  > … and the set tiers it reached, in the order of their events, each with its set's public key, kind, name and tier.
- **Rule (AD-13, amended):**
  > Feed entries reference a pack, a card-season or a set tier, by kind. The single feed handler listens to `PackOpened`, `TradeAccepted`, `SetTierReached` and `SetCompleted`.

### H4. The theme list has three owners in turn, and nothing identifies a set across seasons for backs and titles (AD-5, AD-18, AD-25)

- **Unit A, story 3 (Catalog, code):** keeps the theme list in a Ruby constant "with French and English names", keyed by tag key. Under AD-18, the names could instead live in `catalog.themes.*` locale keys. The story says "in code", so a second home for copy appears.
- **Unit B, Season preparation story 2 (back-office data):** "replaces the theme list in code", allows merges ("fusionner vers un genre") and renames, and lets a tag go back to "not a theme". The Deferred section hands its design to a later update.
- **Unit C, Cosmetics (code):** follows AD-25 ("the back catalogue is one constant in `Game` … a set's back unlocks on gold on that set"; "a title is rendered from a template per set kind and the set's name, never stored as text").
- **Clash:**
  1. A back in a code constant can't name a set by database id, and sets are regenerated for every season. Cosmetics keys backs by theme key. Season preparation creates a theme in the back-office whose key has no back, or renames the key a back points to.
  2. A title rendered live from "the set's name" changes on a season-1 profile when the administrator renames the theme for season 2. Season preparation's Done when 4 says a published season's sets never change.
  3. "Roguelike" exists in season 1 and in season 2 as two sets. A title unlock row "per player and title" keyed by set id gives duplicate titles in the picker, while one keyed by theme key gives one. The menu theme for "gold on 10 sets" counts each one differently.
- **Rule (AD-5, added):**
  > A set's identity across seasons is its kind and key; a theme's key never changes once a season uses it, even after a rename or a merge. A set stores its display names (per locale for themes) in its params at publication, and screens, titles and the feed read them from there. Until the theme list moves to the back-office, one `Catalog` object is its only reader.
- **Rule (AD-25, replacing "A set's back unlocks on gold on that set"):**
  > A back may name a set kind and key; it unlocks on the first gold or completion of any season's set with that kind and key. A set without such a back unlocks no back. Title unlocks are keyed by set kind, key and tier, so a later season's same set grants nothing new. The menu-theme counts are counts of distinct kind and key.

---

## Medium

### H5. The one-time rebuild and live set-tier rows have no order (AD-5)

- **Unit A, story 4 (Catalog operation):** reuses `PublishSeason`'s builder, deletes the season's old `catalog_sets` and memberships (bypassing the guard `Catalog::Set#refuse_destroy_once_published`), inserts the new ones, then publishes `SeasonSetsRebuilt(season_id)`.
- **Unit B, the Game handler (story 4) and `OpenPack` (story 5):** the handler drops "that season's set tiers" by joining `catalog_sets` on `season_id`. By then the old sets are gone, so it finds only new sets. `game_set_completions` has no foreign key to `catalog_sets`, so the old rows stay behind, orphaned, with nothing to report it. An opening running at the same moment inserts a completion for an old set id after the handler's delete has run. Feed entries (story 6) and achievements that name old sets render with a missing name. Players who already hold 40 % of a new theme have no row. Their first opening that touches it writes bronze and silver together, perhaps weeks later, and a theme they never touch again stays without a row while its count says silver.
- **Rule (AD-5, replacing the rebuild sentence):**
  > The rebuild runs with openings and trades stopped (or under a season lock they take shared). Its event carries the retired set ids and is published before the old sets are deleted, so the `Game` handler drops tier rows, feed entries and unlocks naming those ids. Tiers of the new sets are written only by later quantity raises, which insert every tier the counts already meet.

### H6. Story 2's backfill is a third writer of card identity, and the identity list is closed (AD-5, AD-4)

- **Unit A, story 2:** "fills them for the cards already imported without a new import". It runs a task that reads `steam_apps.details` and writes developers and franchises onto `catalog_cards`, and a review count onto card-seasons.
- **Unit B, any later reviewer, following AD-5:** the identity list "(texts, publisher, release date, store and image URL)" is refreshed "by the import (`Catalog::UpsertDraftCard`) and by AD-19's image refresh, nothing else". Developers, franchises and tags are not on the list. The backfill is a forbidden third writer, and the review count is a Steam field in `Catalog`.
- **Rule (AD-5, amended):**
  > A card's identity (texts, publisher, developers, franchises, tags, release date, store and image URL) … is refreshed by `Catalog::UpsertDraftCard`, by AD-19's image refresh, and once by a backfill that calls `UpsertDraftCard` from the stored raw items.
  > A card-season's review count is a source-neutral field that the import writes beside its rating.

### H7. The UFOs' share and "unclassified tag" guards live in two places (AD-1, AD-5)

- **Unit A, Season preparation story 2:** the back-office controller and its preview compute the UFOs' share, and grey out PUBLIER.
- **Unit B, `Catalog::PublishSeason`:** it knows nothing of this guard, so the console's `PublishSeason` or a stale tab publishes anyway. Or it computes the share again with its own rounding.
- **Rule (AD-5, added):**
  > `PublishSeason` refuses with `unclassified_tag` or `ufo_share_exceeded` from the same builder output the preview shows; the share limit is one `Catalog` constant.

---

## Low

### H8. Several sets reached in one opening against the 200 ms budget (AD-7)

A 5-card opening can touch about 5 themes, a franchise, a studio and a hall of fame set per card. That means several tier tests, events and handler writes (feed, later titles and backs) per opening, and no unit is asked to measure them. AD-7 measures `POST /packs` before launch, but story 5 lands after the benchmark that `pending-approvals.md` asks for.

- **Rule (AD-7, added):**
  > The tier test is one statement per opening, whatever the sets; the benchmark is re-run after set tiers ship.

---

## Not holes

- Trades lowering counts: AD-10's "stays reached" together with H2's "reached = row exists" settles it.
- Two raises racing for the same player: AD-10's lock order already serializes them through the player's advisory lock.
- The kind check widened by story 3 and contracted by story 4 follows AD-21's expand/contract.
