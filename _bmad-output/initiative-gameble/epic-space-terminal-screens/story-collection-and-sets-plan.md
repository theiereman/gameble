---
title: 'Collection and sets'
type: 'feature'
ticket: '1'
created: '2026-10-06'
status: 'built'
baseline_revision: 'a26b1d7f8bba85fb953601df45311edab245d20f'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The collection is still the first direction's library (a shelf of tomes, an open tome beside it), and nothing tells a player which cards are new: AD-26's NOUVEAU watermark does not exist.

**Approach:** Rebuild `/library` and `/library/:kind/:key` (URLs kept) as DESIGN.md's Collection screen — set rows with progress, genre chips, RAPPORT, a paginated grid of owned faces with "x3" badges and missing slots naming the game — and add AD-26: `game_holdings.last_gained_at` set only when a quantity rises, a `collection_seen_up_to` watermark on `game_player_states`, and a POST from the player's own rendered collection page to an operation keeping the greater value.

## Boundaries & Constraints

**Always:**
- AD-26: a holding is new when `quantity > 0` and `last_gained_at` is after the watermark (a NULL watermark: every non-NULL `last_gained_at` is after it). Existing holdings get `last_gained_at` NULL = never new (no backfill); the watermark column is nullable, no backfill. Expand-only migration, version `20261006141010`, passing strong_migrations.
- Only `Game::OpenPack`'s credit raises quantities today: it sets `last_gained_at = now` on insert and on conflict. Nothing that touches `reserved` may touch `last_gained_at`.
- AD-11: the GET writes nothing. The page, once rendered (not a Turbo preview), POSTs the largest `last_gained_at` among the new cards it showed, only when it showed one, only for the signed-in player on the library pages (never the public profile).
- `Game::MarkCollectionSeen` (AD-3, AD-14): `call(player:, up_to:)`; one statement `INSERT … ON CONFLICT (player_id) DO UPDATE SET collection_seen_up_to = GREATEST(…)`, value clamped to `Time.current`; publishes no event (AD-10 housekeeping); touches only the `game_player_states` row (locked last, AD-10). Full microsecond precision end to end (`iso8601(6)`).
- AD-15: no id in HTML/URLs; sets by kind and key, cards by slug. AD-16/27: server-rendered, the single `CardComponent`, plain CSS on `tokens.css` tokens, no `style` attribute, a named Stimulus controller. AD-18: every string in `config/locales/{en,fr}.yml` in natural case (CSS uppercases), French copy from EXPERIENCE.md, "vous"; numbers with `number_with_delimiter`.
- A visitor (or banned player) sees every slot missing and no NOUVEAU (CAP-18); the top bar keeps the Steam sign-in image.

**Never:** the card detail page or its in-screen 340px panel (story 10.2; grid slots only link to `card_season_path`); the public profile's look (story 10.3: `library/_shelf`, `library/_tome`, `ShelvesHelper#profile_shelf_links` and their `library.css` rules stay working, unchanged in behaviour); a per-card "seen" write; fluid 120–170px card resizing with filter re-runs (fixed `card-m`; record it in `deferred-work.md`); new gems.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Opening credits | player opens a pack (new and existing holdings) | every credited holding's `last_gained_at` = the opening time | — |
| New card shown | holding gained after the watermark, on the page | slot shows "NOUVEAU"; page carries the max shown `last_gained_at` for the POST | — |
| Next visit | watermark moved by the POST | same slot no longer NOUVEAU | — |
| Older holding | `last_gained_at` NULL (pre-migration) or reserved raised only | never NOUVEAU | — |
| No new card shown | nothing new on this page | no POST controller rendered | — |
| POST lower value | `up_to` below the watermark | watermark unchanged | 204 |
| POST future value | `up_to` after now | stored as now | 204 |
| POST no state row | player lacks `game_player_states` | row created with the value | 204 |
| POST bad input | missing / unparsable `up_to` | nothing written | 422 JSON `invalid_time` |
| POST visitor | signed out | nothing written | 401 JSON `sign_in_required` |
| Visitor GET | signed out | every slot missing, no NOUVEAU, no holdings query | — |
| Big scope | > 60 slots (season or set) | 60 per page, Pagy nav (`page`) | page past the end: empty-grid line |
| Genre filter | `genre` among the scope's genres | only that genre's cards; unknown genre ignored | — |
| No season | none published | the existing "no season" panel | — |

</intent-contract>

## Code Map

Work only in the worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-a15fc9eed950236a9`; never touch `/home/teyermann/projets/gameble` itself.

- `packs/game/app/operations/game/open_pack.rb` `#credit` -- `upsert_all` with `on_duplicate` SQL: add `last_gained_at` to rows and to the update.
- `packs/game/app/models/game/holding.rb`, `player_state.rb` -- update the doc comments (new columns, AD-26).
- `packs/game/app/operations/game/create_player_state.rb` -- pattern for an upsert on `player_states`; `operation.rb` -- `require_player`, `Game::Operation` contract.
- `packs/game/app/queries/game/quantities.rb` -- pattern for the new slot query (stays for the public profile).
- `packs/game/app/queries/game/collection_summary.rb` `.distinct_cards`, `tier_counts.rb`, `packs/catalog/app/queries/catalog/card_count.rb` -- top bar "Cartes uniques", "Toute la saison" row, RAPPORT (copies per tier, total = sum, duplicates = total − unique).
- `packs/catalog/app/queries/catalog/set_slots.rb`, `season_shelf.rb`, `card_views.rb` (its `GENRE` subquery: a card's genre is its tome's `params->>'genre'`), `set_totals.rb`.
- `app/controllers/library_controller.rb`, `concerns/shelf_loading.rb` (`load_shelf` reads `params[:page]`: give it a page argument so the library pages the set list with `shelf` while the public profile keeps `page`), `concerns/public_read.rb`.
- `app/controllers/daily_bonuses_controller.rb` + `app/policies/daily_bonus_policy.rb` -- pattern for a POST, its policy and `rate_limit`; `application_controller.rb#refuse_with` gives JSON errors.
- `app/views/library/{show,set}.html.erb` -- replace; `_shelf`/`_tome` stay for `app/views/public_profiles/*`.
- `app/views/pages/_set_progress.html.erb` + `hub.css` `.set-row*` -- the set progress row to reuse (DESIGN.md: same component on hub and collection).
- `app/views/shell/_top_bar.html.erb` -- add an optional `content_for :top_bar_status` slot; when given, a player's rarity counter and packs chip give way to it (DESIGN.md Top bar table).
- `app/helpers/card_details_helper.rb#link_to_card_detail` -- slot links.
- `script/pixel_art/export.mjs` -- add a `lock` icon right after `picture` (the mock's padlock, 10×12) and run `node script/pixel_art/export.mjs`; `test/lib/pixel_art_export_test.rb` checks it.
- `app/frontend/controllers/*.ts`, `app/frontend/lib/` -- Stimulus conventions; registered by glob.
- Tests to rewrite: `test/controllers/library_controller_test.rb`, `library_set_test.rb`, `test/system/library_test.rb`, `tome_test.rb`; helpers `test/support/library_requests.rb`, `catalog_seeds.rb` (`publish_sets_draft`: tomes action-1..3 of 25, rpg-1 of 44, publishers P, best of year).
- Design refs: `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` lines 515–545 (layout, grid), 700–712 (top bar), 783–790 (Collection components); `EXPERIENCE.md` lines 86, 152, 168–176, 254–259, 393–399.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261006141010_add_collection_watermark_to_game.rb` -- nullable `game_holdings.last_gained_at`, `game_player_states.collection_seen_up_to` (datetime); regenerate `db/schema.rb` -- AD-26, AD-21.
- [x] `packs/game/app/operations/game/open_pack.rb` -- set `last_gained_at` on credit -- AD-26.
- [x] `packs/game/app/queries/game/collection_slots.rb` -- `Game::CollectionSlots.call(player, ids)` → `{ id => Slot(copies:, new:, gained_at:) }` for held cards, one query joining the player's state; `{}` without query for nil -- NOUVEAU read.
- [x] `packs/game/app/operations/game/mark_collection_seen.rb` -- as in Boundaries; failures `:player_required`, `:invalid_time` (non-Time) -- AD-26.
- [x] `packs/catalog/app/queries/catalog/collection_grid.rb` -- the ordered card-season relation of a scope (season: rarity not NULL, by number then id; a set found by kind and key: by membership position then id), filtered by genre via the tome subquery; the scope's genre keys; the set (nil if absent) -- grid paging in SQL.
- [x] `app/controllers/library_controller.rb` + `shelf_loading.rb` -- `show` = "Toute la saison", `set` = one set (404 as today); both load: set-list kind (`kind`, tomes default) and its shelf page (`shelf`), grid page of 60 (`page`, Pagy), `genre` chip, slot views and `CollectionSlots`, summary figures, `@seen_up_to` (max `gained_at` of new shown slots, player only).
- [x] `app/controllers/collection_seen_controller.rb`, `app/policies/collection_seen_policy.rb`, route `post "library/seen"` (`as: :library_seen`) -- 204 / 422 / 401 JSON; `rate_limit` 30 per minute.
- [x] `app/views/library/show.html.erb`, `set.html.erb`, new partials (`_collection`, `_set_list`, `_report`, `_grid`, `_slot`) -- screen title "Collection"; top bar status "Cartes uniques : n / N" + bar (label hidden under 900px, value in the accessible name); aside: kicker "Sets", kind chips, "Toute la saison" row then the shelf's set rows (current: `aria-current`, 5px accent bar), shelf Pagy nav; RAPPORT (≥1180px panel; <720px a `<details>` folded to "n cartes · n doublons", open adds "Cartes uniques"); genre chips ("Tous" + genres, only with ≥2 genres); grid `<ol>` of slots: owned = face `card-m` link + "x3" badge (top-right, from x1, accessible "3 copies") + "Nouveau" lime tag (top-left) when new; missing = hatched slot, `lock` icon, title, year, linking to the card; empty line "Aucune carte de ce genre dans ce set pour l'instant."; Pagy nav; the `collection-seen` controller element only when `@seen_up_to`.
- [x] `app/frontend/controllers/collection_seen_controller.ts` -- on connect, unless `html[data-turbo-preview]`, POST `{ up_to }` JSON with the CSRF meta token, once; failures ignored.
- [x] `app/frontend/styles/collection.css` (import in `application.css`) -- layout: ≥1180 aside 220px + grid; 720–1179 sets as a horizontal strip of 184px rows above the grid, RAPPORT hidden; <720 one column, set chips 132×48 strip, 2-column grid, touch targets ≥44px; grid `repeat(auto-fill, card-m width)` with the DESIGN grid gaps; `content-visibility: auto` on slots; no horizontal page scroll. Update `library.css`'s header: public profile only, until 10.3.
- [x] `app/views/shell/_top_bar.html.erb` -- the status slot.
- [x] `config/locales/{en,fr}.yml` -- new `library.*` keys; keep keys `_shelf`/`_tome` use.
- [x] Tests: migration-free model of AD-26 in `test/packs/game/collection_slots_test.rb`, `mark_collection_seen_test.rb` (every matrix POST row + failures), `open_pack_test.rb` (`last_gained_at` set, unchanged by a `reserved` update), `test/packs/catalog/collection_grid_test.rb`, `test/policies/collection_seen_policy_test.rb`, request tests (rewritten library tests, POST endpoint, query counts, visitor), system tests (desktop and 390×844: progress, slots, NOUVEAU shown then gone on the next visit, no sideways scroll, hub menu 02 and the tab lead here).
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- fluid grid sizing; in-screen detail panel left to 10.2; old `_shelf`/`_tome` left to 10.3.

**Acceptance Criteria:**
- Given a signed-in player with cards in a tome, when they open menu 02 or the COLLECTION tab and pick the tome, then they see each set row's owned/total, the grid with faces, "x2" badges and missing slots naming game and year, on desktop and at 390×844 without sideways scroll.
- Given a player who just opened a pack, when they open the collection on a page holding those cards, then those cards show "Nouveau"; when they reload, they no longer do.
- Given a scope of more than 60 cards, when the page renders, then 60 slots show with links to the next pages.

## Implementation Notes

- `Catalog::CollectionGrid.call(season:, kind:, key:, genre:)` answers nil for an absent set (the controller 404s), else `Grid(set, genres, genre, card_seasons)`; an unknown genre comes back as `genre: nil`.
- The grid's page links are a small own nav (`library/_grid`, `CollectionHelper#collection_pages`, Pagy's `page_url`), not `series_nav`: Pagy's dictionary names its links after shelves ("The next shelf"), which the set list (`shelf`) keeps.
- Query counts pinned: whole season 13 for a player, 8 for a visitor (the grid's count and `Catalog::CardCount` are the same SQL, served once from the query cache); one set 15 / 10.
- The set page's title and h1 are `SetLabel.for` (no year range): only the grid's page of cards is loaded.
- The set progress row is one partial, `library/_set_row`, rendered by the hub too; its sentence moved from `pages.home.sets.progress` to `library.set_row.progress` (same copy). `library.show.heading` and `library.show.public_profile` are gone with the old library page; the player chip's menu keeps the way to the public profile (its system test now uses it).
- Phone top bar: with the status, the player chip is hidden (as mocked in mobile.html) and a visitor's status (always 0) gives way to the Steam image; otherwise 390px scrolled sideways. `.top-bar--status .top-bar__end` does not shrink, so the title ellipsizes.
- Grid slots carry `content-visibility: auto`; each slot reaches 12px past its card (negative margin, padding) so the badges, outline, tilt and focus ring stay inside its paint containment. Under 372px the column gap tightens to 8px so two `card-m` fit a 360px phone.
- The sets strip is `position: relative`: the rows' visually hidden sentences (absolute) otherwise widened the page.
- Tests moved off the library for the packs chip and rarity counter (`pages_controller_test`, `integration/shell_test`, `system/countdown_test` now use a card page).

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The new `deferred-work.md` entry told story 10.3 to remove the `library.show.*` keys, which the collection's `_set_list` and `show` still use (`tabs.*`, `empty.*`, `past_the_end`, `no_season`) — fixed: the entry names only the profile-only keys and says the shared ones stay or move.
  - `[low]` `[patch]` `ShelvesHelper#library_shelf_links` had no caller left and still built `?page=` set links that now page the grid; the `.library__profile` rule and the `ShelfLoading` header were stale too — fixed: helper and selector deleted, header names its real users.
  - `[medium]` `[patch]` An old set link from shelf page N (`/library/tome/x?page=2`) now lands past the grid's last page and read "No card of this genre in this set yet." with no genre set — fixed: a distinct `library.grid.past_the_end` line (en, fr) when the scope has cards, with the page nav; request tests cover `?page=2` on a 44-card tome.
  - `[low]` `[patch]` `scrollbar-width: none` hid the sets strip's scrollbar at 720–1179px, where mouse users need it — fixed: the rule removed.
  - `[low]` `[patch]` The top bar's progress bar was 90px at 720–1179px, a width DESIGN.md does not give (180px; 48px on the phone) — fixed: the override removed; checked no sideways scroll at 720, 900 and 1179px for a player and a visitor.
- Verification fix after the pass: `test/system/public_profile_test.rb` clicked the player chip before the Collection visit finished (stale element in one full run) — it now waits for the collection's path first.

## Design Notes

The watermark is global: posting the largest `last_gained_at` shown also clears older new cards on other pages (AD-26 accepts it; no per-card write). `?page` on `/library/:kind/:key` used to mean the shelf page; it now pages the grid and `shelf` pages the set list — the URLs stay valid.

## Verification

Run from the worktree root with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w101 CHROME_BIN=/usr/bin/chromium` (database created and schema loaded). After writing the migration: `RAILS_ENV=test bin/rails db:migrate db:schema:dump` regenerates `db/schema.rb` (check its diff holds only the two columns and the version). Never use gameble_test or gameble_development.

**Commands:**
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test` -- 0 failures, 0 errors
- `bin/rails test:system` -- 0 failures, 0 errors

## Auto Run Result

Status: built.

- **Summary:** the first direction's library is rebuilt as the Collection screen at the same URLs (`/library` = the whole season, `/library/:kind/:key` = one set): a set list (kind chips, "Toute la saison" row, set progress rows paged by `shelf`), a RAPPORT panel (folded on the phone), genre chips, a grid of 60 slots per page (`card-m` faces with "x3" badges and a lime "Nouveau" tag, hatched missing slots with a padlock naming game and year), and the top bar's "Cartes uniques" status. AD-26 is in place: `game_holdings.last_gained_at` (set by `Game::OpenPack` on every credit), `game_player_states.collection_seen_up_to`, `Game::CollectionSlots` reading what is new, and `Game::MarkCollectionSeen` behind `POST /:locale/library/seen`, posted once by the `collection-seen` Stimulus controller from the player's own rendered page.
- **Migration:** `db/migrate/20261006141010_add_collection_watermark_to_game.rb` (expand only, two nullable columns, no backfill: holdings gained before read as never new); `db/schema.rb` regenerated.
- **Files:** `packs/game` (open_pack, collection_slots, mark_collection_seen, holding/player_state docs), `packs/catalog` (collection_grid), `app/controllers` (library, collection_seen, shelf_loading), `app/policies/collection_seen_policy.rb`, `app/helpers` (collection_helper; shelves_helper trimmed), `app/views/library/*` (new partials `_collection`, `_set_list`, `_set_row`, `_report`, `_grid`, `_status`), `app/views/pages/_set_progress.html.erb` (shares `_set_row`), `app/views/shell/_top_bar.html.erb` (`top_bar_status` slot), `app/frontend` (collection_seen_controller.ts, collection.css, library.css header, `lock` icon), `script/pixel_art/export.mjs`, `config/routes.rb`, locales, tests (new and rewritten), `deferred-work.md`.
- **Review:** quick lens, 5 findings, all patched (1 medium, 4 low); none deferred, none rejected.
- **Follow-up review recommended:** false (patched: 0 high, 1 medium, 4 low).
- **Verification:** rubocop clean; packwerk validate and check clean; i18n-tasks missing none; typecheck clean; test:js 126 passed; `bin/rails test` 1182 runs, 0 failures; `bin/rails test:system` 76 runs, 0 failures, 0 errors on the final run. Earlier full system runs each showed one different intermittent error (`shell_test` phone toasts, `pack_reveal_test` sign-in, `public_profile_test` stale element, the last fixed); the first two passed on reruns and are not touched by this story.
- **Residual risks:** the watermark is global, so a page showing a new card also clears older new cards shown elsewhere (AD-26 as written); a Turbo snapshot taken before leaving still shows "Nouveau" on a Back restore; the grid uses fixed `card-m` sizes (deferred); `export.mjs` gains a `lock` icon while story 8.8 also edits that script (a merge may need a hand).
