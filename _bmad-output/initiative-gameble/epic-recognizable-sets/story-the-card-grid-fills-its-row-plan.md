---
title: 'The card grid fills its row'
type: 'feature'
ticket: '13'
created: '2026-10-19'
status: done
baseline_revision: '60d659efe2063e36f303b152f7c34349c39f75bc'
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

**Problem:** "Toutes les cartes" shows fixed 160 × 240 faces in as many columns as fit, leaving a ragged gap at the row's end. DESIGN.md (Layout, Collection grid; Card sizes, "Grid card") asks for cards resized between 120 and 170 px wide that fill the row, the small face layout under 140 px, and the pixel filter run again at the rendered art size after a resize.

**Approach:** A new `grid` card size whose dimensions come from its grid slot. The grid fills its row with `minmax(min, 1fr)` columns. Each slot is an inline-size container sized to its column, rounded down to even pixels and capped at 170. The face takes the medium layout from 140 px and the small one below it. The card-art controller draws a grid face at its rendered art size and draws it again once a resize settles.

## Boundaries & Constraints

**Always:**
- Only the grid of `library/_grid.html.erb` changes. The set album keeps `card-m` at 6 columns, and so does every other face.
- Columns: as many as fit at `--space-grid-card-min` plus the column gap. The gaps stay fixed (`--space-grid-gap-columns` / `-rows`), and extra width adds a column. Card width is the column width, rounded down to an even pixel and capped at `--space-grid-card-max`. Height is 1.5 × width.
- Under 720 px the grid keeps its two 160 px columns, so a phone sees today's `card-m` face.
- A grid face is 140 px wide or more: medium layout (frame 4, padding 4, `card-m` fonts and line heights, publisher shown). Below 140 px: small layout (frame 3, padding 3, `card-s` fonts and line heights, no publisher).
- The art box spans the body's width. Its height is what the frame, padding, gaps, both footer lines and the title band's reference height (40 px medium, 22 px small) leave, rounded down to an even pixel. One art pixel is 2 CSS px, so the canvas is half the art box.
  - A grid face at 160 px is exactly `card-m`: an art box of 144 × 148.
- A missing-card slot takes the same size as a face in the same grid.
- The copies, editions and "Nouveau" badges stay at the card's corners.
- A grid face draws its art only near the viewport, as today. Once drawn, a size change redraws it at the new art size after the resize settles (about 150 ms without change); one not yet drawn simply draws at its size when it comes near. The tilt's transform never changes the measured size.
- No `style` attribute in server HTML. No planning ids, no explanatory comments beyond the repo's file headers. No new strings.

**Never:**
- No change to the album, booster, trades, card detail, profiles or the other card sizes.
- No server-side width guess, no new route, no change to queries or paging.
- No horizontal page scroll at any width.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 800 px window | grid alone, about 752 px wide | 5 columns of 136 px, small layout | — |
| 1280 px and up | aside 220 px + grid about 972 px | 7 columns of 124 px, small layout | — |
| Medium width | grid giving columns of 140 to 170 px | medium layout, publisher shown | — |
| Phone | under 720 px | 2 columns of 160 px, a face identical to `card-m` | — |
| Resize | window widened after the art was drawn | canvas redrawn at new art width / 2 × height / 2 | an abort cancels the pending draw |
| Not measured | art box with no layout (0 × 0) | draws at the server's `m` art size | — |

</intent-contract>

## Code Map

- `app/components/card_component.rb` + `.html.erb`:
  - Add `:grid` to `SIZES`. Its `ART` placeholder is `m`'s 72 × 74.
  - Publisher shown (CSS hides it under 140). Not large: compact rarity icon, number without season.
  - Grid faces add `data-card-art-fluid-value="true"` to `.card__art`.
- `app/frontend/styles/card.css` -- `.card--grid`:
  - Medium values, with `--card-width: 100cqi`, `--card-height: calc(1.5 * var(--card-width))`, `--card-art-width` from the width and `--card-art-height` via `round(down, …, 2px)`.
  - An `@container (width < 140px)` block switches to the small values and hides `.card__publisher`.
  - Update the header ("Four sizes").
- `app/frontend/styles/collection.css`:
  - New modifier `.collection-grid--fill`: `grid-template-columns: repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr))`.
  - Its slots get `box-sizing: content-box` and `width: round(down, min(100%, var(--space-grid-card-max)), 2px)`, `aspect-ratio: 2 / 3`, `min-height: 0`, and `container-type: inline-size`. The intrinsic size must not exceed the real one (e.g. 120 × 180).
  - Its `.card-link` and `.missing-slot` are `100cqi` × `calc(1.5 * 100cqi)`.
  - Keep the phone rule (`repeat(2, var(--card-m-width))`, l.971) and the narrow gap rule (l.1016) working for the modifier.
  - Rewrite the file header (l.1-8) and the grid section comment.
- `app/views/library/_grid.html.erb` -- `ol.collection-grid.collection-grid--fill`; `CardComponent.new(card:, size: :grid)`; update the header comment ("medium face").
- `app/frontend/controllers/card_art_controller.ts`:
  - New `fluid` Boolean value. A fluid draw measures `this.element.clientWidth/clientHeight` (immune to the tilt transform) and falls back to the values when 0.
  - A `ResizeObserver` on fluid elements redraws, debounced, once a draw ran and the size differs from the drawn one. A redraw aborts the previous draw's controller. `disconnect` clears the timer and the observer.
- New `app/frontend/lib/card_art/fluid_size.ts` (+ `.test.ts`, node env, no DOM): `artPixels(cssWidth, cssHeight, fallback)` → `{ width, height }` in art pixels (CSS / 2, floored, fallback on non-positive), and a small `settle(callback, delay)` debouncer if it helps testing.
- Tests:
  - `test/components/card_component_test.rb`: the grid size (classes, art values 72 × 74, fluid flag, publisher rendered, compact icon, number alone). Existing sizes have no fluid flag.
  - `test/controllers/library_controller_test.rb` l.114: `.card.card--m` → `.card.card--grid`; assert `ol.collection-grid.collection-grid--fill`.
  - `test/controllers/public_profiles_controller_test.rb` l.128: the album keeps `card--m` and no `--fill`.
  - Vitest `?raw` stylesheet assertions for the card.css and collection.css rules (pattern: `app/frontend/lib/card-rarity-effects.test.ts`; add `collection` to `vitest.config.ts` `css.include` if it is imported raw).
  - Matrix coverage for the layout rows (800 px, 1280 px, medium width, phone): in the stylesheet test, read the grid tokens (min, max, column gap) from `tokens.css`, assert the `--fill` rule's `repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr))` and the slot's even-pixel cap, then evaluate the CSS Grid auto-fill math (`n = floor((W + gap) / (min + gap))`, card = even floor of `min((W - (n - 1) gap) / n, max)`) for each row's grid width and its layout (`< 140` small).
  - System tests `test/system/library_test.rb:68`: selector update only, never run.

## Tasks & Acceptance

**Execution:**
- [x] `card_component.rb`, `card_component.html.erb`, `card_component_test.rb` -- the `grid` size and its fluid art flag.
- [x] `card.css` -- the `card--grid` medium/small layouts sized from the slot container.
- [x] `collection.css`, `library/_grid.html.erb` -- the filling grid and its slots; headers rewritten.
- [x] `fluid_size.ts` (+ test), `card_art_controller.ts` -- measured draw and settled redraw.
- [x] Request, component and stylesheet tests above.

**Acceptance Criteria:**
- Given the card grid at window widths of 800, 1024 and 1440 px, when it renders, then every column holds a card of the same even width between 120 and 170 px, the last column ends within one card width + gap of the grid's right edge, and no horizontal scroll appears.
- Given a grid card under 140 px wide, when it renders, then it shows the small layout without publisher; at 140 px or more the medium layout with publisher.
- Given a grid whose faces were drawn, when the window is resized and the resize settles, then each drawn canvas's size equals half its art box.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check` and `bundle exec packwerk check` run, then they pass.

## Implementation Notes

- `CardComponent::FIXED_SIZES` (s, m, l, xl) joins `SIZES` (+ grid); the back-office card preview iterates `FIXED_SIZES`, since a grid face has no slot container there and would need a new size label string.
- The controller ignores a resize while the art box has no layout (a slot skipped by `content-visibility`), so a far slot is not redrawn at the fallback size; it redraws once laid out again.
- `test/system/library_test.rb:68` targets the set album (`library_set_path`), which keeps `card--m`: no system selector needed changing.
- `vitest.config.ts` lists `collection` and `tokens` for raw import; the layout matrix lives in `app/frontend/lib/collection-grid.test.ts`.
- Manual check (headless Chrome, signed-in dev player, art requests served a local PNG): 800 px → 5 × 136 small, art 124 × 138, canvas 62 × 69; 1024 and 1440 px → 7 × 124 small, canvas 56 × 60; 840 px → 5 × 144 medium with publisher, art 128 × 124; 600 px → 2 × 160, art 144 × 148, canvas 72 × 74. A resize 800 → 1440 → 840 redrew every drawn canvas at half its art box; no sideways scroll at any width.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A grid Légendaire lost its glitter: `tilt_controller.ts` sized the flake field with `parseFloat` of `--card-width` / `--card-height`, which on `card--grid` are the unresolved `100cqi` / `calc(1.5 * 100cqi)`, so the field was 100 × 0 and held no flake. Fixed: the custom properties are read only when in px, otherwise the face's `offsetWidth` / `offsetHeight` (checked in headless Chrome: 128 × 192 for a grid face, also in a slot skipped by `content-visibility`). The field still does not follow a later resize (cosmetic, not fixed).
  - `[low]` `[reject]` A face whose art failed is redrawn on every settled resize, so "Image unavailable" briefly gives way to an empty canvas and the image is requested again. Only seen when resizing the window over a missing image; the fix is an extra guard.
  - `[low]` `[patch]` New explanatory comments outside file headers (`card.css` over `.card--grid`, `collection.css` over `--fill`, `RESIZE_SETTLE_MS`, JSDoc in `fluid_size.ts`, the `ART` sentence), one of them wrong about `contain-intrinsic-size`, which has no effect on a slot with an explicit width and an aspect ratio. Comments deleted; the no-op declaration and its test assertion removed.

## Design Notes

- **CSS for layout, JS for the canvas:** CSS sizes the grid before any script runs, so the first paint shows the final columns with no jump. Only the canvas resolution needs JS.
- **Fixed title band, flexible art:** a band shrinking with the card would clip the medium layout's two title lines and publisher (40 px of text). So the band keeps its reference height and the art absorbs the size change.
- The design's 1920/1366/1024 examples predate the 1280 px content cap and the larger gaps (16/20). The 800 px example (5 × 136) holds. The rule wins over the examples.

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci` -- expected: green (revert a stray `package-lock.json` "license" line `bin/ci` may write)

**Manual checks (if no CLI):**
- A one-off headless Chromium measurement (scratch script, not committed) of `/en/library/cards` at 800, 1024 and 1440 px: column count, card widths, layout class, canvas sizes after a resize.

## Auto Run Result

- **Summary:** "Toutes les cartes" fills its row. It uses `minmax(120px, 1fr)` columns, each slot an inline-size container as wide as its column (even pixels, at most 170). It holds a new `CardComponent` size `grid`: the medium layout from 140 px, the small one below. Its art is drawn at the rendered art box and drawn again once a resize settles. The album and every other face are unchanged; the phone keeps two 160 px cards.
- **Files:**
  - `app/components/card_component.rb`, `.html.erb`: the `grid` size and its fluid art flag.
  - `app/controllers/back_office/cards_controller.rb`: the preview lists the fixed sizes only.
  - `app/frontend/styles/card.css`: `.card--grid`, sized from its slot container, with the small layout under 140 px.
  - `app/frontend/styles/collection.css`: `.collection-grid--fill` and its slots.
  - `app/views/library/_grid.html.erb`: the filling grid and grid faces.
  - `app/frontend/controllers/card_art_controller.ts`, `app/frontend/lib/card_art/fluid_size.ts` (+ test): the measured draw and the settled redraw.
  - `app/frontend/controllers/tilt_controller.ts`: glitter sized from the layout on a grid face.
  - `app/frontend/lib/collection-grid.test.ts`, `vitest.config.ts`: stylesheet and layout matrix tests.
  - Component, library and public profile request tests.
- **Review:** 2 patched (1 medium, 1 low), 0 deferred, 1 rejected (a failed art redrawn on resize: rare, cosmetic, fixing it needs a guard).
- **Follow-up review recommended:** false (patched: high 0, medium 1, low 1).
- **Verification:**
  - Green: `bin/ci` (2708 runs, 0 failures), `npm run test:js` (407), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`.
  - One `bin/ci` run failed once in `Game::WeeklyGoalTest` with a foreign key error from the test database, which is shared with other sessions. The file passed alone, and the next full run was green.
  - Headless Chrome measurement as in Implementation Notes.
- **Residual risks:**
  - The design's column examples at 1920, 1366 and 1024 px do not hold under the 1280 px content cap and the 16 px gap. At 1280 px and up the grid shows 7 small cards of 124 px.
  - The glitter field keeps the size it had when the face connected.
