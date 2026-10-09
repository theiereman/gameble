---
title: 'Feed fallback, filters and empty states'
type: 'feature'
ticket: '2'
created: '2026-10-07'
status: done
baseline_revision: 'e419296bcc721682f3ba0eafef14b228311cacf9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The feed (story 6.1) shows only the TOUS tab with pulls: there are no type filters, no empty-filter line, its entries carry no type to filter on, and the visibility filter reads a single window of 90 rows, so hidden or banned players' newest entries can crowd out public ones and leave the feed empty while visible activity exists (deferred finding of 6.1).

**Approach:** Give each feed entry a `kind` (pull, discovery, trade, repost; existing rows are pulls), add the filter row TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS as links (`?filter=`) under the TOUS tab, make `Game::FeedEntries` take the kind and page through the entries until enough visible ones are found, keep the lower-rarity fallback for TOUT and TIRAGES only, and show "Rien pour l'instant dans ce filtre." when a filter yields nothing.

## Boundaries & Constraints

**Always:** Visibility asked only through `Game::Visibility.visible?` at render (AD-13), nothing stored. GET writes nothing (AD-11); readable signed out. A filter shows only its kind; fillers are pulls, so they appear under TOUT and TIRAGES only. Newest first. French and English copy. Migrations follow the repo's expand / validate / concurrent-index pattern (strong_migrations). The handler stays one insert, now writing `kind: "pull"` explicitly.

**Never:** Producing discovery, trade or repost entries (stories 6.6, 6.7, 6.9); the AMIS tab (6.8); the LIVE ticker or broadcasts (6.4); the friends-only branch of Visibility (5.10); a Brotherhood line on the screen; a SQL copy of the visibility rule.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| TOUT, quiet | 1 public notable pull, 1 public filler | both shown, filler on sunken panel | No error expected |
| TIRAGES | pulls only exist | same entries as TOUT, TIRAGES pressed | No error expected |
| DÉCOUVERTES / ÉCHANGES / REPOSTS | no entries of that kind (or only pulls) | empty-filter line, no fillers | No error expected |
| Kind row present | a `trade` row and a pull | ÉCHANGES shows only the trade row's entry; TIRAGES only the pull | No error expected |
| Hidden crowd | > 90 newest notable rows of a private/banned player, 1 older public pull | the public pull is shown | No error expected |
| Unknown filter | `?filter=bogus` | rendered as TOUT, 200 | Ignored |
| Empty feed, TOUT | no entries | existing "Rien pour l'instant." | No error expected |

</intent-contract>

## Code Map

- `db/migrate/` -- three new migrations after 20261007130400: add `kind` string NOT NULL default `'pull'` + unvalidated check `kind IN ('pull','discovery','trade','repost')` (pattern `20261007110000_add_visibility_to_accounts_players.rb`), validate it (pattern `20261007110100_...`), concurrent index `[kind, notable, occurred_at, id]` (pattern `20261006050000_index_game_packs_opened.rb`). `db/schema.rb` dumped from the lane dev database.
- `packs/game/app/models/game/feed_entry.rb` -- add `KINDS`; `record_pack` rows get `kind: "pull"`.
- `packs/game/app/queries/game/feed_entries.rb` -- `call(viewer, kind: nil)`: notable scope filtered by kind when given; fillers only when kind is nil or `"pull"`; `visible` pages by keyset `(occurred_at, id) <` the last row, WINDOW rows per pass, up to PASSES passes, players fetched per pass (constants tuned in play).
- `app/controllers/feeds_controller.rb` -- `FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost" }`; `@filter` from `params[:filter]` (unknown → nil = TOUT); passes kind.
- `app/views/feeds/show.html.erb` -- TOUS tab and filter row as `.segmented` controls (reuse `app/frontend/styles/settings.css` `.segmented__option`, `aria-current` on the chosen); empty line `.empty` for TOUT, `.empty_filter` for a filter.
- `app/frontend/styles/feed.css` -- filter row wraps on phone; drop now-unused `.feed__tab` rules if replaced.
- `config/locales/{fr,en}.yml` `feeds.show` -- `filters.{all,pulls,discoveries,trades,reposts}`, `filters_label`, `empty_filter`.
- Do not change: `Game::Visibility`, the handler's selection rule, menu/PLUS links.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_kind_to_game_feed_entries.rb`, `*_validate_game_feed_entries_kind_check.rb`, `*_index_game_feed_entries_on_kind.rb`, `db/schema.rb` -- the kind column -- filters need a type.
- [x] `packs/game/app/models/game/feed_entry.rb` -- KINDS, explicit kind on insert.
- [x] `packs/game/app/queries/game/feed_entries.rb` -- kind filter, filler rule, keyset paging.
- [x] `app/controllers/feeds_controller.rb`, `app/views/feeds/show.html.erb`, `app/frontend/styles/feed.css`, `config/locales/{fr,en}.yml` -- filter row and empty-filter line.
- [x] `test/packs/game/feed_test.rb` -- matrix rows: kind filter, fillers absent under other kinds, hidden crowd beyond one window, pull kind written.
- [x] `test/controllers/feeds_controller_test.rb` -- filter row present with TOUT current, each filter link, empty-filter line (fr and en), unknown filter, private and banned player gone under a filter, GET writes nothing with a filter.

**Acceptance Criteria:**
- Given a signed-out visitor on the feed, when the page renders, then the five filters show with TOUT current, and choosing one marks it current and keeps the TOUS tab.
- Given only pulls exist, when a visitor picks DÉCOUVERTES, ÉCHANGES or REPOSTS, then the page shows "Rien pour l'instant dans ce filtre." and no entry.
- Given a player sets their profile to private or is banned, when anyone else opens the feed under any filter, then their entries are gone.
- Given a handful of players with only low-rarity packs, when the feed opens under TOUT or TIRAGES, then fillers show and the feed is not empty.

## Implementation Notes

- Subagents unavailable, done in-session (no Agent tool in this lane).
- strong_migrations refuses a non-unique index of more than three columns: the kind index is `[kind, notable, occurred_at]` (the keyset's `id` tie-break is read from the heap).
- `PASSES = 10` bounds the paging (900 rows, 20 statements at worst); the whole-feed path keeps using the 6.1 index `[notable, occurred_at, id]`.
- The TOUS tab now uses the shared `.segmented__option` look; the old `.feed__tab` rules went. Filters are links (`aria-current`), not `aria-pressed` buttons, as the settings language row does.
- Rows of kinds other than pull still render with the pull sentence; their stories (6.6, 6.7, 6.9) bring their own sentences and tags.
- Checked in Chrome at 1400 and 360 px wide (throwaway screenshot test, not committed): the filters wrap on the phone, no horizontal scroll.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[patch]` `Game::FeedEntry::KINDS` was used nowhere, so the controller's FILTERS values and the database check could drift from it — patched: a controller test asserts `FILTERS.values == Game::FeedEntry::KINDS`.
  - `[low]` `[reject]` The paging stops after PASSES x WINDOW = 900 rows, so more than 900 newest hidden rows would still empty the feed — far from everyday use at this scale; lifting it adds an unbounded loop or a SQL copy of the visibility rule (AD-13).
  - `[low]` `[reject]` A discovery, trade or repost row would render with the pull sentence — no handler writes those kinds yet; their sentences and tags belong to stories 6.6, 6.7, 6.9 by the intent.
  - `[low]` `[reject]` DESIGN.md names `aria-pressed` for filter chips while the filters are links with `aria-current` — links are the right role for URL navigation and match the settings language row; the visual state is identical.

## Design Notes

Links rather than buttons: the filter is navigation state in the URL (`/fr/feed?filter=pulls`), works without JavaScript and reuses the segmented control that the settings language row already renders as links with `aria-current`. The paging loop keeps `Game::Visibility` the only judge (AD-13) while bounding the cost:

```ruby
cursor = nil
PASSES.times do
  rows = scope.newest_first.then { |s| cursor ? s.where("(occurred_at, id) < (?, ?)", *cursor) : s }.limit(WINDOW).to_a
  # keep visible ones; stop when enough or rows.size < WINDOW
end
```

## Verification

**Commands:**
- `bin/rails test test/packs/game/feed_test.rb test/controllers/feeds_controller_test.rb` -- expected: green
- `bin/rails test` (PARALLEL_WORKERS=2) -- expected: green
- `bin/rubocop` on changed Ruby files, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: no offenses

## Auto Run Result

Status: built.

**Summary:** Feed entries gain a `kind` (pull, discovery, trade, repost; existing rows are pulls). The feed shows the TOUS tab and the filters TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS as `?filter=` links; a filter shows only its kind, fillers (the quiet-feed fallback) only under TOUT and TIRAGES, and an empty filter says "Rien pour l'instant dans ce filtre." / "Nothing in this filter yet.". `Game::FeedEntries` pages by keyset (up to 10 windows of 90) so hidden or banned players' entries no longer crowd out older visible ones (closes the 6.1 deferred WINDOW finding).

**Files:**
- `db/migrate/20261007140600_add_kind_to_game_feed_entries.rb`, `..._140601_validate_...`, `..._140602_index_...`, `db/schema.rb` -- kind column, check, index.
- `packs/game/app/models/game/feed_entry.rb` -- KINDS, explicit `kind: "pull"`.
- `packs/game/app/queries/game/feed_entries.rb` -- kind filter, filler rule, keyset paging.
- `app/controllers/feeds_controller.rb` -- FILTERS, `@filter`.
- `app/views/feeds/show.html.erb`, `app/frontend/styles/feed.css` -- filter row, empty-filter line.
- `config/locales/{fr,en}.yml` -- filter labels, empty-filter line.
- `test/packs/game/feed_test.rb`, `test/controllers/feeds_controller_test.rb` -- matrix and AC coverage.

**Review:** 1 patch (low), 0 deferred, 3 rejected (reasons in the triage log). Follow-up review recommended: false (patched: high 0, medium 0, low 1).

**Verification:** feed tests 30 runs green; `bin/rails test` 1439 runs, 0 failures; rubocop, packwerk, i18n-tasks missing/unused clean; `npm run typecheck` and `npx vitest run` (132) green; screenshot check at 1400 and 360 px.

**Residual risks:** the 900-row paging bound; `db/schema.rb` version will conflict with any other lane that adds a migration (resolve by keeping the highest version and both tables' changes).
