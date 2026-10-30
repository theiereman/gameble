---
title: "The rarity legend counts distinct cards against the game's totals and filters the grid"
type: 'feature'
ticket: '1'
created: '2026-10-30'
status: 'built'
baseline_revision: '4ce7ab9e9a7b81425a90f2c8917fcbba7926dd83'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The rarity legend's query aggregates every card-season of every published season on each signed-in page with a top bar, even when the legend is never opened.
    evidence: |-
      Unverified: the catalog totals do not depend on the player and nothing caches them; measuring the query on a production-size catalog (about 16k card-seasons a season, several seasons) would settle whether it needs caching or a lazy frame.
    location: >-
      app/domains/game/app/queries/game/rarity_legend.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The "RARITIES" legend under the top-bar rarity counter repeats the counter's copies per tier, and the collection pages' "Unique cards" counter opens nothing, so a player cannot see how much of each rarity they own against what the game holds, nor jump to those cards.

**Approach:** One `Game` query counts editions per rarity (owned and total, for the published season and over every published season); one shared legend partial shows them as a table with a totals row, each rarity name linking to the card grid filtered on it; the hub's rarity counter and the collection pages' status counter (now a button) both open it, right under the counter.

## Boundaries & Constraints

**Always:**
- Count editions, one card-season each (architecture, CAP-6 rule): the season figures read the published season's card-seasons with a rarity and those the player holds with quantity above zero; the overall figures read the card-seasons of every `published` season at their minted rarity and those held; a draft season counts in neither. The totals row sums the five rows, so it differs from the "Unique cards" game counter by design.
- Read through a `Game` query, one SQL round trip; GETs write nothing; no database id in the HTML.
- Every new string in both `config/locales/en.yml` and `config/locales/fr.yml`.
- The top-bar counter keeps counting copies and keeps its live update during a reveal (`rarity_counter_controller.ts` keeps working on the counter's own count targets).
- On a collection page the legend must not sit inside `.rarity-counter`, which is `display: none` under 720px.

**Never:** no new route, endpoint or Stimulus controller; no live update of the legend's figures during a reveal (they are as of the page render, which precedes any opening); no change to the grid's filters; no migration; no hover-to-open; no edit to planning documents; no `style` attribute.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two published seasons | Player holds an Epic of season 1 and an Epic of season 2 (season 2 published, highest number) | Epic season: 1 / season-2 Epic count; Epic overall: 2 / Epic card-seasons of both seasons | No error expected |
| Copy count | Player holds 3 copies of one edition | Counts 1 owned | No error expected |
| Emptied edition | Holding with quantity 0 | Not owned; still in totals | No error expected |
| Draft season | A draft season with card-seasons | Counts in neither total | No error expected |
| No rarity | A card-season with null rarity | Ignored everywhere | No error expected |
| Another player | Another player's holdings | Never counted | No error expected |
| No published season | No season published | Every figure 0 / 0; legend still renders | No error expected |
| Totals | Any | Totals row = sum of the five rows, season and overall | No error expected |
| Choosing a rarity | Click "Epic" / "Épique" in the legend | Lands on `/:locale/library/cards?rarity[]=epic` with the Epic filter chosen | No error expected |

</intent-contract>

## Code Map

- `app/views/shell/_rarity_counter.html.erb` -- the counter button (`popovertarget="rarity-legend"`) plus today's inline legend section, whose counts carry `data-rarity-counter-target=count`; the legend moves out.
- `app/views/shell/_top_bar.html.erb:55` -- renders the counter only when no `:top_bar_status` is given; no change needed.
- `app/views/library/_status.html.erb` -- the "Unique cards: n / total" status with its progress bar, given to `:top_bar_status` by `library/show`, `library/cards` (signed in only) and `library/set`.
- `app/helpers/shell_helper.rb:104` -- `shell_tier_counts` memoized helper: model for `shell_rarity_legend`.
- `app/domains/game/app/queries/game/tier_counts.rb` -- raw SQL query pattern (`Holding.connection.select_rows`, `sanitize_sql_array`, query name); `catalog_card_seasons.rarity` is an integer 1..5 in SQL, `Catalog::Rarity::TIERS` maps it to `:common`..`:legendary`.
- `app/domains/catalog/app/queries/catalog/published_season.rb` -- the published season is `Season.published` with the highest number.
- `app/controllers/concerns/collection_grid_loading.rb:12` + `app/views/library/_filters.html.erb:35` -- the grid filters on `rarity[]` tier codes; `library_cards_path(rarity: [ "epic" ])` is the target.
- `app/frontend/styles/shell-top-bar.css` (428 lines, cap 500) -- `.shell-popover` (~295), `.rarity-legend*` rules (~318-370), `.rarity-legend__count[data-changed]` (~193).
- `app/frontend/styles/shell-screens.css:152` -- hides `.rarity-counter` on the phone.
- `app/frontend/styles/collection.css:143` and `collection-grid.css:416,438` -- `.collection-status` look, phone rules.
- Tests to update: `test/integration/shell_test.rb:159-170`, `test/controllers/boosters_controller_test.rb:191`, `test/controllers/library_controller_test.rb:101-107,692-693`, `test/system/shell_test.rb:89-91`. Query test pattern: `test/domains/game/held_games_test.rb` (a second published season and `edition` via `insert_all!`), `test/support/holdings.rb` (`hold`).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/rarity_legend.rb` -- new `Game::RarityLegend.call(player)`: one SQL over `catalog_card_seasons` of published seasons, left-joined to the player's holdings with quantity > 0, grouped by rarity with `FILTER` on the published season; returns a value with five rows in tier order (tier code, season owned/total, overall owned/total) and a totals row -- the legend's single read.
- [x] `test/domains/game/rarity_legend_test.rb` -- one test per matrix row except the last, plus one query asserted.
- [x] `app/helpers/shell_helper.rb` -- `shell_rarity_legend`, memoized like `shell_tier_counts`.
- [x] `app/views/shell/_rarity_legend.html.erb` -- the `#rarity-legend` popover section: title, a table (column headers rarity, this season, all seasons), one row per rarity whose header is a link (icon + name) to the filtered grid, figures "owned / total" (`aria-hidden`) with a visually hidden "owned of total", a totals row in `tfoot`.
- [x] `app/views/shell/_rarity_counter.html.erb` -- render the legend partial; the counter keeps its count targets.
- [x] `app/views/library/_status.html.erb` -- the status becomes `<button type="button" class="collection-status" popovertarget="rarity-legend">` with the same content, followed by the legend partial as its sibling.
- [x] `app/frontend/styles/shell-rarity-legend.css` (new, imported right after `shell-top-bar.css` in `app/frontend/entrypoints/application.css`; list it in `shell.css`'s header comment) -- the legend rules moved out of `shell-top-bar.css`, the table layout, link hover and focus, and, under `@supports (position-area: block-end)`, an anchor (`anchor-name` on `.rarity-counter__button` and `.collection-status`) placing the legend right under the counter, aligned to its end edge; within the viewport on a 360px phone.
- [x] `app/frontend/styles/collection.css` -- `.collection-status` as a button: no native border, background or padding, pointer, the rarity counter's hover and `:focus-visible` treatment.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `shell.rarity` keys for the column headers, the totals label and the figure's spoken form.
- [x] Tests listed in the Code Map -- updated to the new legend; the integration test asserts English and French figures and hrefs on the hub and a collection page; the booster test asserts the legend carries no count target.
- [x] `test/system/shell_test.rb` -- desktop: the hub counter opens the legend with figures and totals, under the counter; choosing Epic lands on the grid with Epic chosen; a collection page's status opens the same legend; in French, choosing "Épique" does the same. Retrying matchers only.

**Acceptance Criteria:**
- Given a signed-in player on the hub or a collection page, in English or French, when they activate the top-bar counter, then the legend opens right under it with owned / total per rarity for this season and all seasons, and the totals row.
- Given the legend is open, when Esc is pressed, then it closes (unchanged native popover).
- Given a pack reveal on the booster screen, when a card turns, then the counter's count still updates.

## Implementation Notes

- The published season is resolved inside the same SQL (a `current_season` CTE, highest published number), keeping the read at one round trip.
- The legend adds one query to every page with the rarity counter or the collection status; the query-count tests of the hub, card, library, set album and public profile pages were raised by one each.
- Figures render as `owned` and `/ total` in two no-wrap spans so a cell can break between them on a phone; checked at 360px in French with five-digit figures (legend 5..325px in a 345px viewport).

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 0, false 1, maybe-false 1
- findings:
  - `[medium]` `[patch]` The legend's spoken figure ignored grammatical number in French ("1 sur 1 possédées"), unlike `library.status.progress` — `shell.rarity.figure` pluralized on `count: figure.owned` (fr zero/one/other, en one/other), the partial passes `count:`, the integration test asserts "1 sur 1 possédée", "0 sur 1 possédée" and "2 sur 5 possédées".
  - `[medium]` `[patch]` On a phone the collection status, the only way to open the legend there, was about 25px tall and the legend's links 34px, under the 44px every other phone control gets — both join the phone `min-height: var(--space-chip-height-touch)` rule in `shell-screens.css`.
  - `[false]` `[reject]` The "no rarity" query test cannot fail if `rarity IS NOT NULL` is dropped — a null-rarity group maps to tier 0, which `Catalog::Rarity::TIERS` never reads, so no figure the player sees can count it; the bad outcome does not happen either way.
  - `[maybe-false]` `[defer]` The legend's query aggregates every card-season of every published season on each signed-in page with a top bar, and its cost grows with each season — measuring the query on a production-size catalog (16k card-seasons a season, several seasons) would settle it; medium if true.

## Design Notes

A table, not a list, so each figure is read with its rarity and column header. The `.rarity-legend__row--<tier>` name colours stay. Sketch of the query:

```sql
SELECT cs.rarity,
       COUNT(*) FILTER (WHERE cs.season_id = :season_id),
       COUNT(h.id) FILTER (WHERE cs.season_id = :season_id),
       COUNT(*), COUNT(h.id)
  FROM catalog_card_seasons cs
  JOIN catalog_seasons s ON s.id = cs.season_id AND s.status = 'published'
  LEFT JOIN game_holdings h ON h.card_season_id = cs.id AND h.player_id = :player_id AND h.quantity > 0
 WHERE cs.rarity IS NOT NULL
 GROUP BY cs.rarity
```

## Verification

Every command runs in the worktree with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w281` and `CHROME_BIN=/usr/bin/chromium` exported; never use `gameble_test` or `gameble_development`.

**Commands:**
- `bin/rails test test/domains/game/rarity_legend_test.rb test/integration/shell_test.rb test/controllers/boosters_controller_test.rb test/controllers/library_controller_test.rb` -- expected: pass
- `bin/rails test test/system/shell_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bin/rubocop` -- expected: pass
- `script/check_planning_references && script/check_file_sizes` -- expected: pass

## Auto Run Result

**Summary:** The rarity legend now shows, per rarity, the editions owned against the game's, for this season and all published seasons, with a totals row; each rarity name links to the card grid filtered on it. The hub's rarity counter and the collection pages' "Unique cards" status (now a button) open the same legend, anchored right under the opener.

**Files changed:**
- `app/domains/game/app/queries/game/rarity_legend.rb` -- new one-query read of the legend's figures.
- `app/helpers/shell_helper.rb` -- memoized `shell_rarity_legend`.
- `app/views/shell/_rarity_legend.html.erb`, `_rarity_legend_figures.html.erb` -- the legend table and its figure cells.
- `app/views/shell/_rarity_counter.html.erb` -- renders the shared legend; the counter keeps its live count targets.
- `app/views/library/_status.html.erb` -- the status becomes the legend's opener.
- `app/frontend/styles/shell-rarity-legend.css` (new), `shell-top-bar.css`, `shell.css`, `collection.css`, `shell-screens.css`, `app/frontend/entrypoints/application.css` -- legend layout and anchoring, the status as a button, 44px touch size on the phone.
- `config/locales/en.yml`, `config/locales/fr.yml` -- column headers, totals, the pluralized spoken figure.
- Tests: `test/domains/game/rarity_legend_test.rb` (new), `test/integration/shell_test.rb`, `test/system/shell_test.rb`, `test/controllers/{boosters,library,cards,pages,public_profiles}_controller_test.rb`, `test/controllers/library_set_test.rb` (query counts raised by one for the legend's read).

**Review:** one quick pass; 2 patches applied (both medium: French plural of the spoken figure, phone touch size), 1 deferred (the per-page cost of the legend's query, unverified), 1 rejected as false (the null-rarity test: no visible figure can count a null rarity either way).

**Follow-up review recommended:** false -- two medium patches, both small and covered by the re-run tests; no named unverified risk beyond the deferred cost.

**Verification:** `bin/rails test` 3686 runs, 0 failures; `test/system/shell_test.rb` 24 runs, 0 failures; `npm run test:js` 756 passed; `format:check`, `lint:css`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing`, `rubocop`, `check_planning_references`, `check_file_sizes` all pass.

**Residual risks:** the legend's figures are as of the page render (the booster screen keeps pre-opening figures until the next visit); browsers without CSS anchor positioning show the legend at the old top-right spot; the phone status button at 44px was not screenshot-checked after the patch; DESIGN.md and EXPERIENCE.md still describe the legend as copies per tier.
