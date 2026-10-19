---
title: 'Larger cards in the filled grid on desktop'
type: 'bugfix'
ticket: '20'
created: '2026-10-19'
status: 'built'
baseline_revision: '64970ee9ba7d5c2b50cdc3491c2578316da3932a'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Entry 13's fill grid starts its columns at 120 px. Since entry 14 put the detail column beside the grid (grid 592 px wide at the 1280 px content cap, 644 px at 1024 px), a desktop shows 4 small-face cards of 136 px at 1280 and up, too small for the author.

**Approach:** The grid's smallest column becomes 140 px (`--space-grid-card-min`), still filling the row and capped at 170 px, so every desktop column takes the medium face; the small face stays in the stylesheet for a column under 140 px only. The phone keeps two 160 px cards. The stylesheet matrix test and DESIGN.md (token, Card sizes row, Collection grid examples) are corrected to what the rule gives with the detail column: 1440 and 1280 px → 3 × 170, 1024 px → 4 × 148, 800 px → 4 × 170, phone → 2 × 160.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/styles/tokens.css` -- `--space-grid-card-min: 140px`.
- [ ] `app/frontend/lib/collection-grid.test.ts` -- `MIN` 140; the layout matrix rows: 800 px window (grid 752) 4 × 170 medium, 1280 px and up (`WIDE_GRID` 592) 3 × 170 medium, 1024 px (`MEDIUM_GRID` 644) 4 × 148 medium, medium width 780 5 × 142 medium; assert no desktop row is small.
- [ ] `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- token `grid-card-min: 140px`; Card sizes row "140 to 170 wide"; Collection grid: a desktop card always takes the medium face (small face only under 140 px), examples corrected as above.

**Acceptance Criteria:**
- Given `/library/cards` at 1440, 1280, 1024 and 800 px, when it renders, then every card is the same even width between 140 and 170 px in the medium face (publisher shown), filling the row; under 720 px two 160 px cards.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check` and `bundle exec packwerk check` run, then they pass.

## Implementation Notes

Oneshot: a one-token change, its stylesheet test and three DESIGN.md lines (under 30 lines). Values computed with the shipped tokens (16 px column gap, 32/28 px page gutters, 220 px RAPPORT, 340/300 px detail column); DESIGN.md's own spacing block still lists older gaps (12/16) and gutters, which this ticket does not touch.

- Files: `app/frontend/styles/tokens.css` (`--space-grid-card-min` 140px), `app/frontend/lib/collection-grid.test.ts` (MIN 140, a column at MIN is medium, matrix rows 800 → 4 × 170 and 1280 → 3 × 170), DESIGN.md (token, Card sizes row, Collection grid text and examples).
- Headless Chrome (one-off scratch system test, not committed, window widths include a 15px classic scrollbar): 1440 → grid 592, 3 × 170; 1280 → grid 577, 3 × 170; 1024 → grid 629, 4 × 144; 800 → grid 729, 4 × 170; 390 → 2 × 160; medium face everywhere, no sideways scroll. DESIGN.md's 1024 example names both 148 (overlay scrollbar) and 144 (classic).
- At 1280 px and up the 170 px cap leaves each 186 px column 16 px wider than its card, so the gaps read about 32 px and the row ends about 50 px short of the detail column; that is the cap the ticket keeps.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[reject]` At 1280 px and up the 170 px cap leaves 3 columns of about 187 px holding 170 px cards, so the gaps read about 33 px and about 17 px stays after the last card: the row is not visibly filled. — Real, but the intent fixes both bounds: on a 592 px grid four columns would be 136 px (under 140) and three are capped at 170, so no column count meets both without spare width. Kept as the cap the ticket asks for; reported to the author for the staging check.
  - `[low]` `[patch]` DESIGN.md's Collection grid still said extra width never spreads the cards apart, which the capped examples contradict. — Sentence extended: past the largest grid card a column keeps its spare width after its card, about 33 px apart at 1280.
  - `[low]` `[patch]` The matrix's 800 px row used a 752 px grid (24 px gutters); under 1180 px the gutters are 28 px, so 744 px. — The row now works its width out from the medium page padding (`STACKED_GRID`); same result, 4 × 170.
  - `[low]` `[patch]` The plan's "no desktop row is small" was only asserted on four rows. — A test sweeps every grid width from the narrowest desktop grid (1180 px beside a classic scrollbar, 477 px) to the full 1216 px content width and asserts the medium face.

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci` -- expected: green

**Manual checks (if no CLI):**
- Headless Chrome on `/en/library/cards` at 1440, 1280, 1024, 800 and 390 px: column count, card width, medium layout.

## Auto Run Result

- **Summary:** the filled card grid's columns start at 140 px instead of 120 (`--space-grid-card-min`), still filling the row and capped at 170 px, so every desktop card takes the medium face. Result: 1440 and 1280 px → 3 × 170 (grid 592 px beside the RAPPORT and the detail), 1024 px → 4 × 148 (4 × 144 beside a classic scrollbar), 800 px → 4 × 170, phone → 2 × 160.
- **Files:**
  - `app/frontend/styles/tokens.css`: `--space-grid-card-min` 140px.
  - `app/frontend/lib/collection-grid.test.ts`: the new minimum, the corrected matrix rows (800 px from the stylesheet's gutters) and a sweep of every desktop grid width for the medium face.
  - `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`: token, Card sizes row, Collection grid text and examples.
- **Review:** 3 patched (low), 0 deferred, 1 rejected (medium: the cap's spare width at 1280 px and up is what the intent's two bounds give; reported to the author).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 3).
- **Verification:** `bin/ci` green (2726 runs, 0 failures), `npm run test:js` (431), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`; headless Chrome as in Implementation Notes.
- **Residual risks:** at 1280 px and up the three 170 px cards stand about 33 px apart with about 17 px spare after the last; the author may prefer another split of that width.

