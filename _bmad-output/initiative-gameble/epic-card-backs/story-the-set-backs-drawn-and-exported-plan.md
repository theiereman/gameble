---
title: 'The set backs drawn and exported'
type: 'feature'
ticket: '3'
created: '2026-10-28'
status: done
baseline_revision: '07e042d3a7c45c94abc94a78dc2235f8b546078b'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The catalogue holds Standard only, and the 47 set backs the author approved (43 themes, 4 hall of fame sets) exist only on the approval page.

**Approach:** Port the approved designs to `script/pixel_art/export.mjs` with one shared anatomy (frame, field, brackets, ring, motif, 5 x 7 word), export each in the five card sizes and register each asset in `Game::CardBacks`.

## Boundaries & Constraints

**Always:** Generated PNGs only through the export; the approved variants (JUMP J1, RACING R1, ADVENTURE A2, BULLETS B2); every theme and hall of fame key has a back.

**Never:** Grant a back (entry 2), hand-edit `app/frontend/images/pixel/`, redraw a back the author approved.

</frozen-after-approval>

## Implementation Notes

Oneshot. The anatomy lives in `script/pixel_art/set_backs.mjs`, the 47 designs (key, word, two colours, 17 x 17 motif) in `script/pixel_art/set_back_designs.mjs`, extracted from the approved page by running its own motif generators, so the grids are the approved ones. Asset names keep the key as is: `back-theme-souls_like-m.png`, `back-hall_of_fame-mal-aimes-m.png`. Catalogue keys are `set-<kind>-<key>` with an unlock rule `:set_tier` targeting the kind and key; the grant itself is entry 2. The 5 x 7 font covered every word, so none changed.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: 339 files up to date (40 existing backs and other art + 235 new)
- `bin/rails test test/domains/game` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean

Files: `script/pixel_art/export.mjs`, `script/pixel_art/set_backs.mjs`, `script/pixel_art/set_back_designs.mjs`, 235 PNGs, `Game::CardBacks`, `test/domains/game/card_backs_test.rb`.

## Review Triage Log

No subagent was available to this run (a fork cannot spawn one), so the builder read the diff against the plan and AGENTS.md. The game domain suite (673 runs, 0 failures), packwerk, zeitwerk, rubocop and `--check` pass.

- checked: the Ruby theme and hall of fame lists duplicate the design keys; the catalogue test compares them with `Catalog::Themes` and `Catalog::HallOfFame`, and a second test requires the 5 images of every back.
- low, accepted: at xs and s the lettering is skipped when it does not fit (as on the approval page); the motif keeps its whole-pixel scale, at least one art pixel per cell.
