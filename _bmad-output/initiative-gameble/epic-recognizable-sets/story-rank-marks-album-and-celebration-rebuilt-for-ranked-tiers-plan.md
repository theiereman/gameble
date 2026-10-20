---
title: 'Rank marks, album and celebration rebuilt for ranked tiers'
type: 'feature'
ticket: '23'
created: '2026-10-19'
status: done
baseline_revision: '47dfa417570a430382b24a089feea3cf59e660ba'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/rank-marks.html']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Entry 22 gave new seasons ranked tiers (`novice` … `master`), but they render as names only: no rank mark, no ticks on set rows, album or celebration gauge (ticks sit at fixed 10/25/50 % for metals only), and the folded line shows a fixed bronze/silver/gold row.

**Approach:** Build entry 21's approved design (`ux-gameble/DESIGN.md` Set celebration, Collection › Set progress row, Tier marks, Set album, Feed entry; `EXPERIENCE.md` Copy deck, Motion, Accessibility; `mockups/rank-marks.html`, the spines win on conflict): five exported rank-mark pixel icons; one tick per tier before completion placed at `required / total` of the set, for every set (metal or ranked), with its mark under it; the album adds each tier's threshold figure; the celebration's ribbon is led by the rank mark, its gauge ticks come from the set's own thresholds, its folded line shows the marks of its results' tiers; the hint is the pixel arrow alone; the feed and ticker tag carries the rank mark. Metals keep their notches.

## Boundaries & Constraints

**Always:**
- Rank marks, exact pixels from the mockup's `SH`/`MARK` (1 = filled): chevron `....X....|...XXX...|..XX.XX..|.XX...XX.|XX.....XX`; novice 1, apprentice 2, adept 3 chevrons stacked every 3 rows (9×5, 9×8, 9×11); expert star9 `....X....|...XXX...|...XXX...|XXXXXXXXX|.XXXXXXX.|..XXXXX..|..XXXXX..|.XXX.XXX.|.XX...XX.`; master two star7 `...X...|..XXX..|XXXXXXX|.XXXXX.|..XXX..|.XX.XX.|.X...X.` 2 columns apart (16×7). Exported by `script/pixel_art/export.mjs` as `rank-<key>.svg` in `currentColor` with a DESCRIPTIONS line; never hand-edit `app/frontend/images/pixel/`.
- Mark scale: 1 CSS px per art pixel in set rows, under ticks (rows, album, celebration gauge) and in the feed/ticker; 2 px per art pixel in ribbons and the folded line. Every rank is `--color-text-bright` when reached; a rank mark not reached is solid `--color-line-deep` (never hollow or dithered).
- Tick positions are `required / total`, set as a custom property by a Stimulus controller from a data attribute (server HTML carries no `style` attribute); a tick not yet positioned is not shown. In the React island, positions come through `cssVars` as today.
- Ticks for metal sets use the same path (positions from their rows, close to 10/25/50 %), keeping their 1–3 notches, hollow until reached; earlier seasons' marks are otherwise unchanged.
- Reached tick: solid in tier colour, raised 4px; not reached: dashed `--color-line-deep`. Mark starts 4px under the bar either way. Set row keeps 28px bottom padding when tiered; a 3- or 4-card set and a complete set have no ticks.
- Set row: a reached rank shows the pixel ✓, its mark (1px/px) and its name beside the count; the row's accessible sentence is unchanged.
- Album: tick, mark, then the threshold in cards (11px bold, 19px under the bar, centred on its tick, `--color-text-bright` reached / `--color-muted` not); header bottom padding 44px when tiered; complete set lime bar without ticks; the bar's `aria-valuetext` unchanged; ticks, marks and figures `aria-hidden`.
- Celebration: the opening answer's each set-tier row gains its set's thresholds before completion (`[{ tier, required }]`, by required); `gaugeTicks` draws one tick per threshold (metal or rank), crossed/solid/pending as today, light timings from `fillReaches(required/total)`; desktop ticks show the mark (rank mark 1px/px or metal notches); phone ticks no marks. Ribbon lead: rank mark at 2px/px in the ribbon text colour (metal notches, complete ✓ unchanged). Folded line: one mark per distinct tier among its results, from the lowest result to the highest, each lit in turn (80ms + 90ms apart), rank marks at 2px/px, complete as the stamp frame. Hint: the pixel arrow "▸" alone on desktop (top-right, 10px/9px) and on the phone in place of the album icon; "Voir le set" stays in the link name; the folded line keeps "EN COURS ▸". Juice by rank stays as entry 22 set it.
- Feed and ticker tag (`feed_tier_tag`): a rank shows its mark at 1px/px in `--color-text-bright` before its name.
- Rank icons reach the island as server-rendered HTML through `booster_props` (like `celebrationIcons`).
- AGENTS.md rules: English repo text, no planning ids, both locales for any new string, `node script/pixel_art/export.mjs --check` green.

**Never:**
- No change to tier data, ordering, events, feed SQL, locale tier names or the help page (entry 22).
- No colour-only distinction between ranks; no Greek letters; no new tier colours.
- No inline `style` attribute in ERB/helpers; no ordering of tiers by name.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Row ticks by size | ranked sets of 3, 7, 40, 250 cards | 0, 1, 3, 5 ticks, each with `rank-*` mark and its fraction data attribute (e.g. 40 cards: 10/40, 20/40, 30/40) | No error expected |
| Metal row | earlier theme 62 cards, bronze 7 silver 16 gold 31, holds 16 | 3 ticks, bronze and silver reached with notches, gold not | No error expected |
| Reached rank in row | 40-card set, holds 22 | ✓ + expert mark + "Expert" beside the count | No error expected |
| Album figures | 40-card set, holds 22 | figures 10, 20, 30; the first two reached | No error expected |
| Celebration rank | opening crosses adept of a 40-card set | ribbon "PALIER ADEPTE" led by adept mark; 3 ticks, adept crossed, expert/master pending | No error expected |
| Folded | 4 results: master, expert, adept, novice | marks novice, adept, expert, master lit in that order | No error expected |
| Feed rank tag | set entry tier `expert` | tag holds the expert mark and "Expert" | No error expected |
| Answer validation | set-tier row without thresholds | answer rejected like any malformed answer | existing refusal path |

</intent-contract>

## Code Map

- `script/pixel_art/export.mjs` -- add the five `rank-*` grids to `ICONS` (single-colour `c` grids) and DESCRIPTIONS; run without `--check` to write `app/frontend/images/pixel/rank-*.svg`.
- `app/helpers/set_rows_helper.rb` -- `set_tier_ticks(standing)`: one tick per `standing.thresholds` entry except complete, `data` fraction attribute for the controller, `is-reached`, mark under it (`pixel_icon("rank-…")` or `set_notches`); album figures (new helper or flag); `set_tier_mark` with ✓ + rank mark; drop the metal-only gate entry 22 added (`metal_tiers?`).
- `app/views/library/_set_progress_row.html.erb`, `app/views/library/_album.html.erb` -- attach the tick-positioning controller; album figures.
- new `app/frontend/controllers/<name>_controller.ts` (+ registration as the other controllers are) -- sets `--at` (or similar) on each tick/figure from its data attribute.
- `app/frontend/styles/hub.css` (`.set-row__tick*`, `.set-row--tiered`, `.set-tier`), `app/frontend/styles/collection.css` (`.set-album__*` ~800–830) -- `left: calc(var(--at) * 100%)`, hidden until set; rank mark sizing at 1px/px; figures; paddings; remove fixed `--bronze/--silver/--gold` lefts.
- `app/helpers/feed_helper.rb`, `app/frontend/styles/feed.css` -- rank mark in the tag.
- `packs/game/app/queries/game/pack_set_tiers.rb` -- each Row also carries the set's thresholds before completion ordered by required (one extra query or aggregate; no N+1 per row).
- `app/helpers/packs_helper.rb` (`pack_set_tiers`) -- `thresholds: [{ tier:, required: }]` in camelCase JSON as the rest.
- `app/helpers/boosters_helper.rb` -- `celebrationIcons` gains the five rank marks.
- `app/frontend/lib/opening.ts` -- `OpeningSetTier.thresholds`, validated.
- `app/frontend/lib/celebration.ts` -- `CelebrationResult` keeps the set's thresholds; `gaugeTicks` from them (drop `TICK_TIERS`/`TICK_AT` fixed positions); `foldedMarks` per the rule above; `CelebrationIcons` type.
- `app/frontend/components/BoosterCelebration.tsx` -- ribbon lead and tick marks by family, tick `--at` via `cssVars`, folded marks, arrow-only hint.
- `app/frontend/styles/booster.css` (~1080–1470) -- tick left from `--at`, rank mark colours (line-deep / text-bright), ribbon mark colour, hint.
- Tests: `test/helpers` or `test/controllers/library_*_test.rb` (rows/album ticks, marks, figures, metal row), `test/controllers/feeds_controller_test.rb` or live feed (rank mark in tag), `test/controllers/packs_controller_test.rb` (thresholds in answer), `app/frontend/lib/celebration.test.ts`, `opening.test.ts`, controller vitest, `test/lib/pixel_art_export_test.rb` if it lists icons.

## Tasks & Acceptance

**Execution:**
- [ ] `script/pixel_art/export.mjs` + exported SVGs -- rank marks.
- [ ] `set_rows_helper.rb`, `_set_progress_row.html.erb`, `_album.html.erb`, tick controller, `hub.css`, `collection.css` -- rows and album.
- [ ] `feed_helper.rb`, `feed.css` -- feed and ticker.
- [ ] `pack_set_tiers.rb`, `packs_helper.rb`, `boosters_helper.rb`, `opening.ts`, `celebration.ts`, `BoosterCelebration.tsx`, `booster.css` -- celebration.
- [ ] Tests for every matrix row; update metal celebration tests only where tick positions now come from thresholds.

**Acceptance Criteria:**
- Given ranked sets of 7, 40 and 250 cards, when their rows and albums render, then they show 1, 3 and 5 ticks with distinct rank marks, and no `style` attribute appears in the HTML.
- Given an earlier season's metal set, when its row, album, feed entry and celebration render, then its notches and names appear as before, its ticks at its own thresholds.
- Given an opening that reaches novice, a back tier and completion, when the celebration plays, then each result's ribbon, ticks and juice follow its tier.
- Given the page in greyscale, when the marks are compared, then every rank is told apart by shape.

## Implementation Notes

- Environment (orchestrator): work only in this worktree; Postgres runs on 5433 (do not start one). Use `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1322` (created and loaded); `npm install` done (revert any `package-lock.json` change). Use `/usr/bin/git` if `git` is refused. No migration expected. Do not commit; the orchestrator commits. No system tests.
- Tick positions: `data-tier-at` (required/total, 4 decimals) read by `tier_ticks_controller.ts` (logic in `lib/tier_ticks.ts`), which sets `--at` and `is-placed`; re-applied on `turbo:morph-element` (hub morph refresh). Unplaced ticks stay hidden.
- `Catalog::TierTable::SMALLEST_TIERED` (5, derived from its rows) gates ticks in rows/album and empties `thresholds` in the opening answer, so an earlier season's 3- or 4-card theme (bronze 1, silver 1, gold 2) draws no stacked ticks.
- Removed as dead: `setHint` (type, `boosters.island.set_hint` en/fr), the `album` pixel icon, `Game::SetStanding#tiered?`.
- Orchestrator: the result hint and phone link arrow use `arrow-right` (4×7, 8×14 CSS px as DESIGN.md asks) through a new `celebrationIcons.arrow`; `next` (`arrow-small-right`) stays for the phone's next button and the folded "EN COURS ▸".

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` An earlier season's 3- or 4-card theme (bronze 1, silver 1, gold 2) drew stacked ticks and figures on rows, album and celebration gauge — fixed with `Catalog::TierTable::SMALLEST_TIERED`: no ticks below it, empty `thresholds` in the answer; tests on a 3-card metal theme.
  - `[low]` `[patch]` Metal row tick positions not asserted — `library_controller_test` asserts each `data-tier-at` (0.1129, 0.2581, 0.5).
  - `[low]` `[patch]` `foldedMarks` placed a repeated tier by its lowest result — now by each tier's highest result; test added.
  - `[low]` `[patch]` `setHint` shipped and never shown — removed from type, locales and test.
  - `[low]` `[patch]` `album` icon no longer referenced — removed from the export script and its file.
  - `[low]` `[patch]` `SetStanding#tiered?` without caller — removed with its assertions.

## Design Notes

One tick path for both families keeps a single renderer: metal ticks move from fixed 10/25/50 % to their rows' exact `required/total` (e.g. 7/62 = 11.3 %), which is where the fill reaches them anyway. Folded marks follow results (already ranked by share), so no tier-name order is needed.

## Verification

**Commands:** (with the DATABASE_URL above)
- `bin/rails test` -- green
- `npm run test:js`, `npm run typecheck` -- green
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci` -- green
- `grep -rn 'style=' app/views app/helpers app/components | grep -v '^.*#'` -- no new style attribute

**Manual checks:**
- Desktop and phone: rows, album, celebration (rank, back tier, complete, folded) against `mockups/rank-marks.html`; greyscale tells marks apart.

## Auto Run Result

- **Summary:** five exported rank-mark icons; one tick per tier before completion at `required/total` for every set (metal or ranked), placed by a Stimulus controller, with its mark under it (rank 1px/px or notches); album threshold figures; reached rank shows ✓ + mark + name in rows; feed and ticker tags carry the rank mark; the opening answer carries each set's thresholds; the celebration gauge ticks come from them, the ribbon is led by the rank mark, the folded line shows its results' marks, the hint is the arrow alone.
- **Files:** `script/pixel_art/export.mjs` + `app/frontend/images/pixel/rank-*.svg` (album.svg removed); `app/helpers` (set_rows, feed, packs, boosters); `app/views/library/_set_progress_row`, `_album`; `app/frontend` (tier_ticks lib + controller, celebration, opening, BoosterCelebration, hub/collection/feed/shell/booster css); `packs/catalog/.../tier_table.rb` (SMALLEST_TIERED); `packs/game/.../pack_set_tiers.rb`, `set_standing.rb`; locales (set_hint removed); tests.
- **Review:** quick lens, 6 findings (1 medium, 5 low), all patched; none deferred or rejected. The orchestrator also swapped the hint arrow to the 8×14 icon DESIGN.md asks for.
- **Follow-up review recommended:** false (one medium patched, no high).
- **Verification:** `bin/rails test` 2826 runs, 0 failures; `npm run test:js` 467 passed; `npm run typecheck`, `export.mjs --check` (102 files), `zeitwerk:check`, `packwerk check`, rubocop clean; no `style` attribute in views or helpers.
- **Residual risks:** no visual check was possible here: the author checks rows, album, celebration (desktop and phone) and greyscale against `mockups/rank-marks.html` on staging after the next season is published. Metal ticks moved from fixed 10/25/50 % to their rows' exact thresholds.
