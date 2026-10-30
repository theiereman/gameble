---
title: 'The rarity legend counts distinct games in its overall figures'
type: 'feature'
ticket: ''
created: '2026-10-30'
status: 'built'
baseline_revision: '34295feb856778c2606ad48fa4be5bc033e5e1eb'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The rarity legend (follow-up to 28.1, plan `epic-aim-at-the-cards-you-want/story-the-rarity-legend-counts-distinct-cards-against-the-game-s-t-plan.md`) counts editions in its "All seasons" column, so a game held in two seasons counts twice and the totals row disagrees with the collection's "Unique cards" counter. The author decided on 2026-10-30 that the overall figures count distinct games.

**Approach:** `Game::RarityLegend` keeps its single SQL round trip and its season figures (one card per game per season), and changes the overall figures: per rarity, owned = distinct games the player holds (quantity > 0) in at least one edition of that rarity in a published season, total = distinct games with an edition of that rarity in any published season. The totals row comes from the same SQL (a `GROUPING SETS` grand total) and counts each game once: owned = distinct games held, total = distinct games in published seasons, so it can be less than the sum of the rows and agrees with `Game::HeldGames.count`. The season totals stay the sum of the season rows (equal to distinct games, one edition per game per season). Views keep reading `legend.rows` and `legend.totals`; the spec line of CAP-6 in `spec-gameble/spec-gameble.md` describing the legend says the overall figures count distinct games (author, 2026-10-30). Tests: `test/domains/game/rarity_legend_test.rb` (same game in two seasons counts once per rarity; same game in two rarities counts in each row and once in the totals, which are less than the sum; overall owned total agrees with `HeldGames.count`; still one query), `test/integration/shell_test.rb` (the legend's overall totals equal the collection status on the collection page). Everything else of 28.1 stays: draft seasons, null rarity, emptied holdings and other players' holdings count nowhere; no migration, no new route or string.

</intent-contract>

## Implementation Notes

Oneshot: one query, its unit test, one integration assertion and one spec line, well under 100 lines.

- The query groups the published editions with `GROUP BY ROLLUP (rarity)`; null rarities are filtered out first, so the grand-total row is the only one with a null tier (`EVERY_RARITY`). Every figure is `COUNT(DISTINCT card_id)`; the season figures are unchanged, since `(card_id, season_id)` is unique. `Legend` now carries `totals` as data instead of summing the rows; `Figures#+` and `NONE` went.
- The spec line keeps the 28.1 citation and adds the distinct-games rule; it says the owned total matches the unique cards counter, since the counter's denominator is the published season's card count, not the overall total.
- Test titles in `test/integration/shell_test.rb` and `test/system/shell_test.rb` say "owned cards" instead of "owned editions". No view change was needed.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The integration assertion compared the whole "owned / total" strings of the collection status and the legend's overall totals; the denominators measure different things (published season's card count against distinct games over every published season) and agree only while one season is published — the assertion now compares the owned figure only (`.rarity-legend__owned` in the last tfoot cell against the status's unique count).
  - `[low]` `[reject]` `HeldGames.count` counts held editions whatever their season's status or rarity, while the legend's owned total keeps published, rated editions only, so they could differ — no production path holds a draft-season or unrated edition (rarity is written only on publish, and no season goes back to draft); aligning the two queries would add filters to a query this change does not touch.

## Verification

Every command runs with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w281b` and `CHROME_BIN=/usr/bin/chromium` exported.

**Commands:**
- `bin/rails test test/domains/game/rarity_legend_test.rb test/integration/shell_test.rb test/controllers/boosters_controller_test.rb test/controllers/library_controller_test.rb` -- expected: pass
- `bin/rails test test/system/shell_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check && bin/rubocop && script/check_planning_references && script/check_file_sizes` -- expected: pass

## Auto Run Result

**Summary:** The rarity legend's "All seasons" column and its totals row count distinct games instead of editions: a game counts once in a rarity whatever its editions of that rarity, and once in the totals whatever its rarities, so the totals' owned figure matches the collection's unique cards counter and the totals can be less than the sum of the rows. The season column is unchanged. CAP-6's legend line in the spec says so (author, 2026-10-30).

**Files changed:**
- `app/domains/game/app/queries/game/rarity_legend.rb` -- distinct-game counts and a `ROLLUP` grand-total row, still one query.
- `test/domains/game/rarity_legend_test.rb` -- a game over two seasons counts once; a game in two rarities counts in each and once in the totals, agreeing with `HeldGames.count`; totals updated.
- `test/integration/shell_test.rb` -- the legend's overall owned total equals the collection status's unique count; title wording.
- `test/system/shell_test.rb` -- title wording.
- `_bmad-output/initiative-gameble/spec-gameble/spec-gameble.md` -- the CAP-6 legend line.

**Review:** one quick pass; 1 low patch applied (the integration assertion compared denominators that only agree with one season), 1 low rejected (`HeldGames.count` and the legend count different holdings only for draft or unrated editions, which no production path creates). Nothing deferred.

**Follow-up review recommended:** false -- one low patch, test-only.

**Verification:** `bin/rails test` 3742 runs, 0 failures (after the patch); touched tests 122 runs, 0 failures; `test/system/shell_test.rb` 24 runs, 0 failures; `packwerk check`, `zeitwerk:check`, `rubocop` on the touched Ruby files, `check_planning_references`, `check_file_sizes` pass.

**Residual risks:** the legend's overall total (distinct games over every published season) and the collection status's total (the published season's cards) differ once a game leaves the catalog in a later season; DESIGN.md and EXPERIENCE.md still describe the legend as copies per tier (carried from 28.1).
