---
title: "The set album's header simplified and its cards across the full width"
type: 'bugfix'
ticket: '19'
created: '2026-10-19'
status: done
baseline_revision: 'ebeaea4045b3e8df40f59b104c0bae3bf91340fe'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the author's staging check of the set album, its cards sat narrower than its header (six `card-m` columns at most, about 170 px short at 1280 px) and the header said too much: the set's kind, a facts row, and a BRONZE · ARGENT · OR gauge list under the bar.

**Approach:** The album's grid becomes the collection's fill grid (columns from 140 px, cards up to 170 px, the grid face), spanning the header panel's full width, aligned on both edges. The header keeps the set's name and its owned/total count on one line (the COMPLET stamp beside the count when complete) and the progress bar right below with its tier ticks, lit when reached; the kind and the gauge list go; the bar's spoken text names the count and the tier reached. EXPERIENCE.md's set album row and DESIGN.md's Set album and COMPLET stamp lines follow, reconciled with the ranked tiers just applied (ticks on the bar instead of a per-tier gauge), noting that entry 21's design starts from this header.

## Boundaries & Constraints

**Always:**
- Header, in reading order: the h1 (set name, unchanged: id, tabindex, Stimulus target, public profile's "Horror · Gabe the Brave"), then the stamp when complete, then the count `<b>held</b>/total` (still `aria-hidden`), on one flex line: the name takes the room, the stamp and count sit at the line's end; when the name is too long for the line, stamp and count wrap under it, still at the end. Then the bar and ticks right below (smaller gap than today).
- The bar keeps its name (`aria-labelledby` the h1) and its value text as before: the count, and the tier reached when one is: "5 cards out of 16, silver tier"; "0 cards out of 8"; "8 cartes sur 16, palier or"; complete: "3 cartes sur 3, complet"; an untiered set not complete: the count alone. No visually hidden per-tier sentence remains.
- Ticks unchanged (`set_tier_ticks`, notches under them, reached ticks lit).
- Grid: the same fill grid and grid face as "Toutes les cartes" (`collection-grid--fill`, `CardComponent` size `:grid`), its width the album's (= the header panel's), no six-column cap. Each slot is centred in its column, so the first and last cards sit within half a column's spare width (about 1 px; at most 5 px where the 170 px cap bites) of the panel's edges. Phones keep two 160 px cards.
- No `style` attribute, no planning ids in code or tests, no explanatory comments beyond file headers. Strings in both `en.yml` and `fr.yml`.
- Docs: do not edit `ux-gameble/.working/`.

**Never:**
- No change to the set row, the hub panel, the celebration, the card grid of "Toutes les cartes", paging, queries or routes.
- No new tier list or per-tier text anywhere in the header.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Theme at silver | 5 of 16 held | h1 "Horror", count "5/16", no kind, no list; 3 ticks, 2 lit; value "5 cards out of 16, silver tier" | — |
| Theme with none | visitor, 0 of 8 | "0 cards out of 8" ("0 carte sur 8") | — |
| At gold | 8 of 16 | "8 cartes sur 16, palier or" | — |
| Complete franchise | 3 of 3 | stamp "Complet" on the name's line before "3/3"; no ticks; "3 cartes sur 3, complet" | — |
| Desktop 1440 | album 1216 px wide | 7 × 160, grid edges = header edges | — |
| Phone 390 | — | 2 × 160, name over or beside the count, no sideways scroll | — |

</intent-contract>

## Code Map

- `app/views/library/_album.html.erb` -- rewrite the header: a `div.set-album__title` holding the h1, the stamp (`span.set-album__stamp`, when `standing.complete?`) and the count; drop `p.set-album__facts`, `span.set-album__kind` and the whole `ol.set-album__gauge`. Keep `.set-album__track` (bar + ticks) and `set-album__header--tiered`. Grid: `ol.collection-grid.collection-grid--fill.set-album__grid` (same aria-label and grid-keys), `CardComponent.new(card: slot.card, size: :grid)`. Same for the public profile (it renders this partial).
- `app/helpers/set_rows_helper.rb` -- `set_album_value_text` unchanged (count, then `complete` or the reached tier). Delete `AlbumTier`, `set_album_tiers`, `set_album_tier_sentence`. Keep `set_kind_name` (rows use it), `set_tier_ticks`, `set_notches`, `NOTCHES`.
- `config/locales/en.yml` / `fr.yml` -- delete `library.album.tiers` and `library.album.tier.*` (both files); `bundle exec i18n-tasks unused` must not list new keys.
- `app/frontend/styles/collection.css`:
  - Delete `.set-album__facts`, `.set-album__kind`, `.set-album__gauge`, `.set-album__tier*`, `.set-album__check`, and their phone (`max-width: 719px`) and `max-width: 359px` rules.
  - New `.set-album__title`: flex, `flex-wrap: wrap`, `align-items: center`, column/row gaps; h1 `flex: 1 1 auto; min-width: 0`; count keeps `margin-left: auto`.
  - `.set-album__header` gap smaller (bar right below the line).
  - `.set-album__grid`: drop the `max-width`; `.set-album__grid > .collection-slot { justify-self: center; }` placed after the `--fill` slot rule.
  - Rewrite the file header's "A set's album keeps medium cards, six at most a row." and the album section comment.
- Tests:
  - `test/controllers/library_set_test.rb` -- drop `gauge` and the gauge/kind/tier assertions (lines 31, 59, 66-71, 102, 105, 121, 128-130 area, 198, 254); assert no `.set-album__kind`, `.set-album__gauge`, `.set-album__facts`; `.set-album__title` holds the h1, then (complete) the stamp, then the count; the value texts of the matrix (en and fr); `ol.set-album__grid.collection-grid--fill` and `.card--grid` faces. In "no database id reaches the album" (l.299) remove the `set-album__tier-required` alternative and also strip ` (at|à) \d+` from the HTML before matching ids.
  - `test/controllers/public_profiles_controller_test.rb` -- l.126-131: value text unchanged (count and reached tier), no gauge; `.card.card--grid` count 5 and `collection-grid--fill` present (replaces the `card--m` / no-`--fill` assertions); l.158: replace the gauge assertion with the French value text.
  - `app/frontend/lib/collection-grid.test.ts` -- a describe for the album: `.set-album__grid` has no `max-width`, its slots `justify-self: center`; using `fill()` at the full content width (1280 − 2 × wide gutter = 1216) → 7 × 160 filling exactly, and 1024 (1024 − 2 × medium gutter = 968) → 6 columns of 148, medium face.
  - `test/system/public_profile_test.rb` -- selector updates only if broken (`.set-album__count`, `.set-album__stamp` stay); never run.
- Docs (`_bmad-output/initiative-gameble/ux-gameble/`):
  - `DESIGN.md` Set album line (l.916): header = name and "owned/total" on one line in VT323 / count style, the COMPLET stamp beside the count when complete, the progress bar right below with one tick per tier before completion (zero to five ranks; bronze, silver and gold on an earlier season's set), lit when reached, marks under the ticks as in Tier marks; no kind, no gauge list; a set of 3 or 4 cards has no ticks; the season mark and "à reconquérir" clauses kept and marked as placed by the ranked-tier design; grid = the Collection grid's fill rule across the panel's full width, edges aligned; phone two `card-m`. Add: "Entry 13.21's design (rank marks, album bar with one to five ticks) starts from this simplified header (author, 2026-10-19)." Drop the phone gauge-cell sentences.
  - `DESIGN.md` COMPLET stamp (l.917): "in the album header's name and count line, before the count".
  - `EXPERIENCE.md` set album row (l.235): name and owned / total, no kind, tier ticks on the bar, no gauge list; value text naming only the count and the reached tier ("31 cartes sur 62, palier adepte"; earlier season "…, palier or"; done "3 cartes sur 3, complet"); delete "The tier gauge is a list of three items…". Set complete row (l.377): stamp beside the count instead of "after its last tier cell". Worked example (l.598): "ADEPTE's tick lit".
  - `.memlog.md`: one `(decision)` line for this simplification (author, 2026-10-19).

## Tasks & Acceptance

**Execution:**
- [ ] `app/views/library/_album.html.erb`, `app/helpers/set_rows_helper.rb`, `config/locales/{en,fr}.yml` -- simplified header, value text with tiers, gauge removed, fill grid with grid faces.
- [ ] `app/frontend/styles/collection.css` -- title line, closer bar, full-width centred grid; gauge styles removed; header comments.
- [ ] `test/controllers/library_set_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `app/frontend/lib/collection-grid.test.ts` -- the matrix rows above.
- [ ] `DESIGN.md`, `EXPERIENCE.md`, `.memlog.md` -- as in the Code Map.

**Acceptance Criteria:**
- Given an album on desktop (1440, 1024 px) and a phone (390 px), when it renders, then the grid's first and last cards line up with the header panel's edges (within a few px), the header shows the name and count on one line and the bar right below with its ticks, and there is no kind and no tier list.
- Given a screen reader on the album's bar, when it reads the value, then it hears the count and the tier reached, nothing the header does not show.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` run, then they pass.

## Implementation Notes

- **Files touched:** `app/views/library/_album.html.erb`, `app/views/library/set.html.erb`, `app/views/public_profiles/set.html.erb`, `app/helpers/set_rows_helper.rb`, `config/locales/{en,fr}.yml`, `app/frontend/styles/collection.css`, `app/frontend/lib/collection-grid.test.ts`, `test/controllers/library_set_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `test/system/{library,collection_set,public_profile}_test.rb` (selectors only, not run), `ux-gameble/DESIGN.md`, `ux-gameble/EXPERIENCE.md`, `ux-gameble/.memlog.md`.
- **Title line end:** `.set-album__title` uses `justify-content: flex-end` and the count's `margin-left: auto` is dropped (deviation from the Code Map). With the stamp before the count, the count's auto margin would have pushed the stamp to the start of a wrapped line, away from the count; `flex-end` keeps both at the line's end when they wrap, and on the first line the growing h1 already pushes them right.
- **Unused `set` local:** the partial no longer reads `set` (the kind is gone), so both callers stop passing it.
- **Value text:** first built with the next tier (via `tier_words`), then reverted to its earlier form at the author's decision (see Plan Change Log): "1 carte sur 8, palier bronze" on the public profile's pirates album.
- **System tests:** besides `public_profile_test.rb`, the album pages in `library_test.rb` (3 lines) and `collection_set_test.rb` (2 lines) asserted `.card.card--m`; switched to `.card.card--grid`. Never run.

- Headless Chrome (scratch system test, not committed; a complete 16-card theme): album 1440 → 7 × 160, grid 104.5–1320.5 = header; 1280 → 7 × 156, first and last cards within 1 px of the header's edges; 1024 → 6 × 144 within 1 px; 800 → 4 × 170; 390 → 2 × 160; no sideways scroll. On the phone the stamp first stayed beside the name while the count wrapped alone: the stamp and count now sit in one `span.set-album__standing` (inline-flex), so they wrap together under the name, at the line's end.

## Plan Change Log

### 2026-10-19 — Author decision during review
- Trigger: the author, through the coordinator: the bar announces only what is shown, so its value text does not add the next tier's threshold.
- Amended: the intent's approach and the value-text rule and matrix rows (count and reached tier only, as before this ticket); the helper, the request tests and EXPERIENCE.md's set album row and the memlog line follow.
- Avoids: a spoken threshold the sighted header no longer shows.
- KEEP: the title line, the stamp and count wrapping together, the centred fill grid, the removed gauge and its strings.

### 2026-10-19 — Rebase onto entry 13.21's design
- Trigger: rebasing onto origin/develop brought entry 13.21 (rank marks designed, approved): DESIGN.md and EXPERIENCE.md already describe this simplified header, with the COMPLET stamp after the name (`mockups/rank-marks.html`: name, stamp, spacer, count), threshold figures under the rank marks and a visually hidden tier list.
- Amended: the stamp sits right after the name and the count keeps `margin-left: auto` (the `set-album__standing` wrapper and `justify-content: flex-end` are gone); DESIGN.md and EXPERIENCE.md taken from 13.21 with only this ticket's deltas: the album grid on the fill rule, centred, across the panel; no visually hidden tier list (the author's later decision: the bar announces only the count and the tier reached); the season mark clause marked open, as DESIGN.md does; the Set complete row's stamp beside the name.
- Not built here: the threshold figures under the marks, the rank marks and the lime complete bar, which entry 13.23 builds.
- KEEP: the centred full-width fill grid, the removed gauge and its strings, the value text unchanged.

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` EXPERIENCE.md's set album row still presented the season mark and "à reconquérir" as shown today, while the header has no per-tier element and DESIGN.md marks them as placed by the ranked-tier design. — The row now says the same: placed by the ranked-tier design, now that the header has no tier list.
  - `[low]` `[patch]` The album's alignment test passed at any setting: both widths it checked divide exactly, so the spare width was 0. — Added the 1280 px window beside a classic scrollbar (1201 px, 7 × 156, about 0.9 px spare at each edge once centred).
  - `[false]` `[reject]` The worktree no longer matched the reviewed diff (value text without the next tier). — Not a defect: the author's decision during review (Plan Change Log) reverted the value text; the reviewer saw the tree mid-update. The stray `package-lock.json` change was reverted and is not committed.

## Design Notes

- **Centred slots:** the fill grid's columns are `1fr` and each card is its column's width rounded down to even pixels (and capped), so start-aligned cards leave up to about 2 px per column at the row's end (13 px at 1280 px beside a classic scrollbar). Centring splits that spare width across both edges. Toutes les cartes keeps start alignment, where its rows line up with the search field above.
- **Spoken tiers:** with the list gone, the ticks show where every tier sits; the value text names the count and the tier reached, what the header shows (author, 2026-10-19).

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci` (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1320`; revert a stray `package-lock.json` change) -- expected: green.
- `bundle exec i18n-tasks unused` and `bundle exec i18n-tasks missing` -- expected: nothing new.

**Manual checks (if no CLI):**
- Headless Chrome on an album at 1440, 1024 and 390 px: grid and header edges, the title line, no sideways scroll.

## Auto Run Result

- **Summary:** the set album's header reads the set's name and its owned/total count on one line, the COMPLET stamp right after the name when complete and the count at the line's end, as the approved rank-marks mock draws it, then the progress bar right below with its tier ticks, lit when reached. The kind and the BRONZE · ARGENT · OR list with its hidden per-tier sentences are gone. At the author's decision the bar's value text is unchanged: the count and the tier reached ("5 cards out of 16, silver tier"). The album's cards use the collection's fill grid and grid face across the header panel's full width, each card centred in its column.
- **Files:**
  - `app/views/library/_album.html.erb`, `app/views/library/set.html.erb`, `app/views/public_profiles/set.html.erb`: the title line, no kind or gauge, the fill grid with grid faces; the partial no longer takes `set`.
  - `app/helpers/set_rows_helper.rb`: the gauge helpers removed.
  - `config/locales/en.yml`, `fr.yml`: the gauge's keys removed.
  - `app/frontend/styles/collection.css`: title line and standing, closer bar, full-width centred grid; gauge styles and their phone rules removed.
  - Tests: `test/controllers/library_set_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `app/frontend/lib/collection-grid.test.ts`; system selectors (`card--m` → `card--grid`, not run).
  - Docs: DESIGN.md (Set album, COMPLET stamp, with the note that entry 13.21 starts from this header), EXPERIENCE.md (set album, set complete, worked example), `.memlog.md`.
- **Review:** 2 patched (low), 0 deferred, 1 rejected (false: the tree changed under the reviewer at the author's decision).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 2).
- **Verification:** `bin/ci` green (2710 runs, 0 failures), `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing` clean; headless Chrome as in Implementation Notes (grid edges within 1 px of the header at 1440, 1280, 1024 and 800 px; 2 × 160 on the phone).
- **Residual risks:** the season mark and "à reconquérir" have no place on the simplified header until the ranked-tier design places them.

