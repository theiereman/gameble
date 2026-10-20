---
title: "Set tiers cut by the set's size"
type: 'feature'
ticket: '22'
created: '2026-10-19'
status: done
baseline_revision: 'df8eca55ef6eb1e24c377ae1645c4ebdee8f2514'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Only theme and hall of fame sets have tiers (bronze 10 %, silver 25 %, gold 50 %), whatever their size; franchise, studio and UFO sets are complete or not. Tier order is read from a fixed list of names, so any new tier name breaks ordering, the feed, the opening answer and the celebration.

**Approach:** One tier table by set size in `Catalog` cuts every set of every kind at publication into zero to five ranks counted from the top (`novice`, `apprentice`, `adept`, `expert`, `master`, the last always `master`), then `complete`, each share rounded up. Both tier families (metals for published seasons, ranks from now on) are accepted by the models and the three database checks (widened expand/contract). Every reader orders a set's tiers by required count and ranks results across sets by the share of the set a tier stands for, complete highest. Rank names land in both locales and the help page states the table.

| Distinct cards | Tiers before completion |
|---|---|
| 3–4 | none |
| 5–9 | master ½ |
| 10–19 | expert ⅓, master ⅔ |
| 20–59 | adept ¼, expert ½, master ¾ |
| 60–199 | apprentice 10 %, adept 25 %, expert 50 %, master 75 % |
| 200+ | novice 10 %, apprentice 25 %, adept 50 %, expert 75 %, master 90 % |

## Boundaries & Constraints

**Always:**
- Published seasons' `bronze`/`silver`/`gold`/`complete` rows are never rewritten; they keep reading, celebrating and showing in the feed exactly as today (existing tests that insert metal tiers stay green unchanged, except for assertions about newly published seasons).
- A set's tiers are ordered by `required`; equal counts (possible only in earlier seasons, e.g. a 3-card theme's bronze 1 and silver 1) break ties by the tier's position in `Catalog::SetTier::TIERS` (metals, then ranks, then `complete`). Results across sets rank by `required / complete required`, `complete` above any other tier, then that tie-break, then set id (feed) or name (celebration).
- Required counts are exact: rational shares, rounded up (⅓ of 10 is 4).
- Check constraints: each of `catalog_set_tiers_tier_check`, `game_set_tiers_tier_check`, `game_feed_entries_tier_check` is removed and re-added under the same name with both families, `validate: false`, in one migration; a second migration validates the three (the convention of `20261015130001`/`…02`). Write lists as `tier = '…' OR …` equalities (schema round-trip), keep `game_feed_entries_tier_check`'s `tier IS NULL OR` and `set_count` clauses.
- Every tier except `complete` publishes `Game::SetTierReached` (already true in `Game::Operation`; keep it, fix comments).
- AGENTS.md rules: no planning ids in code, English repo text, French only in `fr.yml`, both locales for every string, no `style` attribute, packwerk dependencies.

**Never:**
- No code orders or compares tiers by their name's rank or by a fixed name list as the primary key (`array_position(…)` on names, `RANK[...]` maps, `NOTCHES.key?` gates for "is a tier before completion").
- No rank marks, rank ticks on bars, album tick layout, juice redesign or folded-line rank marks: entry 23 builds those. Here rank tiers only render their names safely (no crash, no fixed metal ticks on a ranked set).
- No card back, title or menu theme code (not built yet).
- No rename of published rows; no change to `catalog_sets` kinds.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tier table | 3, 7, 12, 40, 100, 250 cards | `{complete:3}`; `{master:4, complete:7}`; `{expert:4, master:8, complete:12}`; `{adept:10, expert:20, master:30, complete:40}`; `{apprentice:10, adept:25, expert:50, master:75, complete:100}`; `{novice:25, apprentice:63, adept:125, expert:188, master:225, complete:250}` | No error expected |
| Boundaries | 4, 5, 9, 10, 19, 20, 59, 60, 199, 200 cards | 0, 1, 1, 2, 2, 3, 3, 4, 4, 5 tiers before complete | No error expected |
| Every kind | franchise/studio/UFO of 7 cards | `{master:4, complete:7}` like a theme | No error expected |
| Earlier season | 3-card theme with bronze 1, silver 1, gold 2, complete 3; opening gets 1 card | rows bronze then silver; feed, PackSetTiers and celebration show silver, as today | No error expected |
| Feed across sets | one opening: Roguelike (62) adept 16 and Dark Souls (10) expert 4 | feed entry names Dark Souls expert (4/10 > 16/62), count 2 | No error expected |
| Old checks | insert `tier: 'adept'` before migrations | refused; after migrations accepted; `'platinum'` still refused everywhere | CheckViolation |

</intent-contract>

## Code Map

- `packs/catalog/app/models/catalog/themes.rb` -- remove `TIER_PERCENTS`, `COMPLETE`, `self.tiers` and the tier part of the header comment; keep themes only.
- new `packs/catalog/app/models/catalog/tier_table.rb` (name free) -- `RANKS`, rows by minimum size with Rational shares, `self.tiers(card_count)` → `{ rank => required, …, "complete" => card_count }`, ranks taken from the top (`RANKS.last(shares.size)`).
- `packs/catalog/app/models/catalog/set_builder.rb` -- themes, hall of fame, franchises, studios, UFOs all take the table (`complete_only` goes); header comment.
- `packs/catalog/app/models/catalog/set_tier.rb` -- `TIERS` = both families + `complete` (order: bronze silver gold novice apprentice adept expert master complete), `COMPLETE`, comment explaining order is a tie-break only.
- `packs/game/app/models/game/set_tier.rb` -- `TIERS` reuse Catalog's; `RECORD_SQL` orders inserts by set, `required`, tie-break; `record` returns pairs in that order (data-modifying CTE joining `catalog_set_tiers` for `required`, or equivalent) — no `TIERS.index` sort.
- `packs/game/app/models/game/set_standing.rb` -- `thresholds` from the `tiers` hash (`complete` defaults to `total`), positive only, sorted by required then tie-break; `tiered?` = any tier other than complete.
- `packs/game/app/models/game/feed_entry.rb` -- `RECORD_SETS_SQL` `rank` → join `catalog_set_tiers` for the tier's and the set's complete `required`; order `complete` first, share desc, tie-break desc, set id; update comment.
- `packs/game/app/queries/game/pack_set_tiers.rb` -- order by set id, `reached.required`, tie-break.
- `packs/game/app/events/game/set_tier_reached.rb` -- comment: any tier but complete.
- `packs/game/lib/open_pack_benchmark.rb` -- theme seeds from the table instead of `THEME_TIER_SHARES`.
- `app/helpers/set_rows_helper.rb` -- "a tier before completion" is `tier && tier != complete`, not `NOTCHES.key?`; rank tiers render their name in sentences, value text and the reached mark (mark without notches); `set_tier_ticks` draws the fixed metal ticks only for a set whose tiers are metals (ranked sets: none until entry 23).
- `app/helpers/feed_helper.rb` -- `feed_tier_tag` for a rank: name with an empty mark (no `fetch` crash).
- `app/helpers/how_it_works_helper.rb`, `app/views/pages/how_it_works.html.erb` -- drop `set_tier_percents`; the tier sentence is the EXPERIENCE.md "Comment ça marche, tiers" copy.
- `app/frontend/lib/opening.ts` -- `SET_TIERS` both families + complete (the answer validator rejects unknown tiers today).
- `app/frontend/lib/celebration.ts` -- results ranked by share (`required/total`), complete highest, tie-break by `SET_TIERS` index; `resultOf` highest by the same; `crossed` sorted by required then tie-break; `notchCount` metals 1–3, others 0; `gaugeTicks` returns `[]` for a non-metal result; `foldedMarks` keeps the metal row + complete; `JUICE` gains rank entries per DESIGN.md "Juice by rank" (novice none; apprentice +6 tick sparks; adept +1 gloss; expert +8 ribbon-end sparks; master + glints).
- `app/frontend/styles/booster.css` -- `[data-tier]` rule for the five ranks: tier `--color-text-bright`, on `--color-outline`, light/dark #ffffff / #8f98a0.
- `config/locales/en.yml`, `fr.yml` -- rank keys in `library.set_progress.tiers` (Novice, Apprentice, Adept, Expert, Master / Novice, Apprenti, Adepte, Expert, Maître), `library.album.celebration.tiers` (caps, `MAÎTRE`), `…spoken_tiers` (lowercase), `feeds.show.tiers`, `feeds.show.set_reached.<rank>_html` ("Léa atteint le palier Novice du set Roguelike." / "Léa reaches the Novice tier in the Roguelike set."), `pages.how_it_works.sets.tiers` (EXPERIENCE.md copy, fr and en, no interpolation).
- `db/migrate/` two new migrations (widen, validate); `db/schema.rb` regenerated per AGENTS.md on scratch DB `gameble_schema_w1322`.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/catalog/…/tier_table.rb`, `themes.rb`, `set_builder.rb`, `set_tier.rb` -- table, both families, every kind -- the rule.
- [ ] `db/migrate/*_widen_tier_checks_to_ranks.rb`, `*_validate_tier_checks_with_ranks.rb`, `db/schema.rb` -- expand/contract.
- [ ] `packs/game/…/set_tier.rb`, `set_standing.rb`, `feed_entry.rb`, `pack_set_tiers.rb`, `set_tier_reached.rb`, `lib/open_pack_benchmark.rb` -- order by required/share.
- [ ] `app/helpers/set_rows_helper.rb`, `feed_helper.rb`, `how_it_works_helper.rb`, `app/views/pages/how_it_works.html.erb`, locales -- names and help sentence.
- [ ] `app/frontend/lib/opening.ts`, `celebration.ts`, `styles/booster.css` -- accept and rank rank tiers.
- [ ] Tests: `test/packs/catalog/set_builder_test.rb` (table rows, boundaries, every kind; replace `Themes.tiers` cases), `test/packs/catalog/publish_season_test.rb` (a published season with a 3-, 7-, 12-, 40-, 100-, 250-card set gets exactly the matrix's tiers; update the existing expected hashes to ranks), `test/packs/catalog/schema_test.rb` + `test/packs/game/set_tier_test.rb` (both families accepted, unknown refused), `test/packs/game/set_tier_test.rb` (an opening crossing adept and expert of a ranked set records both in required order, publishes `SetTierReached` for each and `SetCompleted` for complete), `test/packs/game/feed_test.rb` (cross-set ranking by share), `test/packs/game/set_standing_test.rb` (ranked thresholds, tiered? for a 7-card set, untiered 3-card set), `test/controllers/how_it_works_test.rb` (sentence in both languages; each row boundary agrees with the table), `test/controllers/library_set_test.rb` or `library_controller_test.rb` (album value text "31 cards out of 62, expert tier"), feed controller/live feed (a rank entry renders its name), `app/frontend/lib/celebration.test.ts` + `opening.test.ts` (rank tiers accepted, ranking by share, no metal ticks on a rank result). Existing metal tests stay unchanged.

**Acceptance Criteria:**
- Given a draft season with sets of 3, 7, 12, 40, 100 and 250 cards, when it is published, then their `catalog_set_tiers` rows are exactly the matrix's.
- Given a published earlier season with metal tiers, when a player opens packs, then rows, events, feed entry, opening answer and celebration are as before this change.
- Given the code, when searched, then no reader orders tiers by `array_position` of names or a name→rank map as primary key.
- Given the help page in fr and en, when read, then it states the table in the EXPERIENCE.md wording.

## Implementation Notes

- Environment (orchestrator): work only in this worktree; Postgres is already running on 5433 (do not start one). `gameble_test_w1322` is created and loaded; `npm install` is done (revert any `package-lock.json` change). Use `/usr/bin/git` if `git` is refused. After adding migrations, reload the test DB (`RAILS_ENV=test DATABASE_URL=… bin/rails db:schema:load`) after regenerating `db/schema.rb` on `gameble_schema_w1322`, then drop `gameble_schema_w1322`. Do not commit; the orchestrator commits.
- `Catalog::TierTable` holds the table as `Rational` shares; `Catalog::SetTier::TIERS` lists metals, ranks, complete (tie-break only); `Game::SetTier::TIER_ORDER_SQL` (`unnest … WITH ORDINALITY`) replaces `array_position` as a secondary key. The insert of the tier pass is a data-modifying CTE so its answer is ordered by `required`.
- The celebration's locale keys live under `boosters.island.celebration` (the plan named `library.album.celebration`); the code was followed.
- The feed's share falls back to the set's member count when a set has no complete row (test fixtures insert such sets).
- The benchmark seeds studios through the table as well as themes, as in play.
- Ranking results across sets by share changes which of two earlier-season sets at the same metal is named first (Roguelike bronze 7/62 now before Cosy bronze 6/54; the feed likewise); between different metals the order is unchanged. One celebration test was rewritten for it. This follows the ticket's rule ("rank results by the share of its set").
- Test helper `insert_ranked_theme` added beside `insert_theme` (metals kept).

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Two earlier-season sets at the same metal now rank by share, not by set id/name, in the feed and celebration — real but follows the ticket's explicit rule (results ranked by the share of their set); keeping the old order would add a family branch to both rankers. Recorded in Implementation Notes for the author.
  - `[low]` `[patch]` The album's metal ticks lost their only positive test — added "an earlier season's metal theme shows its three ticks…" in `test/controllers/library_set_test.rb`.
  - `[low]` `[patch]` The help sentence is literal copy with nothing tying its shares to the table — `test/controllers/how_it_works_test.rb` now asserts `Catalog::TierTable::ROWS` equals the rows the sentence states.
  - `[low]` `[patch]` Three set builder test names still said "complete only" — renamed to "complete at its size, too small for a rank".
  - `[low]` `[reject]` Ranked sets get `--tiered` padding with no ticks drawn — interim only: no ranked set exists on staging until the next season, which waits for entry 23, which draws the rank ticks there.

## Design Notes

The name list is a tie-break only because earlier seasons can hold equal counts (a 3-card theme: bronze 1, silver 1); without it, "silver above bronze" would become arbitrary and change published behaviour. Ranked tiers never tie (the table's smallest gaps are ≥ 1 card from 5 cards up). Entry 23 replaces the interim rank rendering (name only, no ticks) with the designed marks.

## Verification

**Commands:** (all with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1322`)
- `bin/rails test` -- green (no system tests)
- `npm run test:js`, `npm run typecheck` -- green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci` -- green
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb DATABASE_URL=…/gameble_schema_w1322 bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- schema diff only the three checks
- `grep -rn "array_position" packs` -- no tier-name ordering left

## Auto Run Result

- **Summary:** every set of a newly published season is tiered by `Catalog::TierTable` (zero to five ranks counted from the top, then complete, shares rounded up), whatever its kind; the models and the three tier checks (widened expand/contract, two migrations) accept both families; the tier pass, `SetStanding`, `PackSetTiers`, the feed and the celebration order a set's tiers by required count and rank results across sets by share, complete highest; rank names in en/fr; the help page states the table.
- **Files:** `packs/catalog` (tier_table new, themes, set_builder, set_tier), `packs/game` (set_tier, set_standing, feed_entry, pack_set_tiers, set_tier_reached, lib/open_pack_benchmark), `app/helpers` (set_rows, feed, how_it_works), `app/views/pages/how_it_works.html.erb`, `app/frontend/lib` (opening, celebration), `app/frontend/styles/booster.css`, locales, two migrations, `db/schema.rb`, tests.
- **Review:** quick lens, 5 findings, all low: 3 patched (tests only), 2 rejected (same-metal cross-set order follows the ticket's share rule; tick padding on ranked sets is interim until entry 23). Nothing deferred.
- **Follow-up review recommended:** false (no high, no medium patched).
- **Verification:** `bin/rails test` 2813 runs, 0 failures; `npm run test:js` 449 passed; `npm run typecheck`, `zeitwerk:check`, `packwerk check` clean; schema regenerated from migrations on a scratch database (only the three checks differ); no `array_position` left in `packs`/`app`.
- **Residual risks:** rank tiers render names only (no marks, no ticks) until entry 23; the next season must not be published on staging before entry 23.
