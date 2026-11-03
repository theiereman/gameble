---
title: 'The five reaction icons are redrawn from a mockup the author approves'
type: 'feature'
ticket: 3
created: '2026-11-03'
status: blocked
baseline_revision: '0f181fa47dcdbce6950e6aadc08413d33efbf527'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
blocked_at: "2026-11-03"
blocked_reason: "waiting for the author to pick the icons in ux-gameble/mockups/reaction-icons.html"
---

<intent-contract>

## Intent

**Problem:** The author found the five feed reaction icons (thumb, heart, GG, wow, middle finger) very poor on staging. Two causes: the drawings themselves (a thumb with no knuckles or cuff, 1px-stroke GG and WOW lettering two rows shorter than the hands, a finger that is a stick on a blob), and the bar's stylesheet, which squeezes every icon to `height: 1.25em` of an 11px label (13.75px), so an 11-row icon gets 1.25 CSS px per art pixel, a 9-row one 1.53, a 7-row one 1.96: blurred, uneven pixels at three scales, against DESIGN's rule that one art pixel is 2 CSS px.

**Approach:** Draw new candidates in `ux-gameble/mockups/reaction-icons.html` (exact grids, resting, hover and lit, on a feed entry desktop and phone, beside the tab, rarity and trade icons); the author picks one per reaction. Then replace the five grids in `script/pixel_art/export.mjs` under the same keys, regenerate with the export, and let the SVGs render at their exported size (2 CSS px per art pixel, 22px tall).

</intent-contract>

## Implementation Notes

Oneshot: five grids in `export.mjs` (`ICONS["reaction-*"]`, and their sizes in `DESCRIPTIONS`), the five regenerated SVGs, and one CSS rule, well under 100 lines.

**Recommended set** (each 11 rows, 22px tall; grids in the mockup's "Grid for the export" blocks):
- **T1** thumb, 12 × 11: side fist, thumb up from the index knuckle, three folded fingers notched apart, a cuff behind the wrist.
- **H1** heart, 11 × 11: plain solid heart, one empty top row so it sits on the hands' baseline.
- **G1** GG, 13 × 11: two bold G in two-pixel strokes, nine rows tall.
- **W1** wow, 11 × 11: astonished face, solid disc with two tall eyes and a low round O mouth cut out.
- **F1** middle finger, 9 × 11: back of the hand, a two-pixel finger, folded knuckles beside it, the thumb across marked by a cut.

**Alternatives:** T2 (heavier thumb, banded fingers, closed cuff), T3 (no cuff); H2 (outline), H3 (H1 with one pixel of shine); G2 (GG cut out of a solid tag, 15 × 11); W2 (outline face), W3 (bold WOW text, 21 × 7, 42px wide); F2 (11 wide, three-pixel finger).

**Decision for the author with the pick:** the icons only come out crisp if `.feed__reaction-icon` in `app/frontend/styles/feed-reactions.css` drops `height: 1.25em; width: auto` (keeping `flex: none`), so the SVG keeps the width and height the export writes. The ticket asked for no other code; this is one declaration, and without it no drawing can be crisp. At 22px the five buttons need about 270px, so on a 360px phone the bar takes two lines (it already wraps).

**After the pick:** replace the five `reaction-*` grids in `script/pixel_art/export.mjs` (keys unchanged), update their sizes in `DESCRIPTIONS`, run `node script/pixel_art/export.mjs`, apply the CSS change if approved; never hand-edit `app/frontend/images/pixel/`. The mockup's renderer is the export's (`rowRuns`), so the grids paste as they are.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: exit 0 after the export ran.
- `bin/rails test test/helpers` and the feed reaction system test (`bin/rails test test/system/<feed reactions file>.rb`) -- expected: green; keys unchanged so `pixel_icon` still resolves.
- `npm run lint:css` -- expected: clean if the CSS rule changes.

**Manual checks (if no CLI):**
- The author approves the drawings in `ux-gameble/mockups/reaction-icons.html`, then sees them on the feed on staging, desktop and phone, crisp at 22px, the lit one dark on blue.

## Auto Run Result

Status: blocked (human checkpoint). Mockup written at `_bmad-output/initiative-gameble/ux-gameble/mockups/reaction-icons.html`; recommended set T1, H1, G1, W1, F1, plus the CSS sizing decision above. No change to `export.mjs`, the exported SVGs or application code. Resume once the author has picked one drawing per reaction and answered the CSS question.
