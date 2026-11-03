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

**Approach:** Draw new candidates in `ux-gameble/mockups/reaction-icons.html` (exact grids, resting, hover and lit, on a feed entry desktop and phone, beside the tab, rarity and trade icons); the author picks one per reaction. Then replace the five grids in `script/pixel_art/export.mjs` under the same keys, regenerate with the export, and let the SVGs render at their exported size (2 CSS px per art pixel, at most 9 rows, so 18px at most).

</intent-contract>

## Implementation Notes

Oneshot: five grids in `export.mjs` (`ICONS["reaction-*"]`, and their sizes in `DESCRIPTIONS`), the five regenerated SVGs, and one CSS rule, well under 100 lines.

**Round 2 (after the author's review of 2026-11-03), recommended set**: at most 9 rows, one-pixel strokes; grids in the mockup's "Grid for the export" blocks.
- **T4** thumb, 9 × 9: classic thumbs-up as a one-pixel line, a pointed thumb, two finger lines, the cuff a solid two-pixel band.
- **H4** heart, 9 × 8: H1's solid shape scaled down.
- **G3** GG, 11 × 7: G1's two G in one-pixel strokes.
- **W4** wow, 9 × 9: W1 as a one-pixel ring face, two tall eyes, an open O mouth.
- **F3** middle finger, 8 × 9: a two-pixel finger four rows above two-pixel knuckles on both sides, the rest of the fist a one-pixel line.

**Round 2 alternatives:** T5 (square-tipped line thumb), T6 (solid silhouette); H5 (7 × 6); G4 (two-pixel stems, 12 × 7); W5 (W1 scaled down, solid); F4 (solid fist, the heaviest), F5 (solid, index on one side, ring and lower pinky on the other, thumb cut, 9 × 9).

**Round 1 (superseded, kept collapsed in the mockup):** T1, H1, G1, W1, F1 at 11 rows (22px), solid. The author found them too big and too heavy, T1 deformed and the middle finger not good. H1 and G1 were good ideas, and round 2 keeps them.

**Size:** the rule is a whole number of CSS px per art pixel, so the size is 2 CSS px per art pixel, as DESIGN gives it. At 1 CSS px a 9-row icon is 9px tall, the height of the count's digits, and its one-pixel strokes become 1px hairlines of muted grey that vanish on an ordinary screen. The mockup shows that row. At 2 CSS px the icons are 14 to 18px tall in the 34px button (44px on touch), a little taller than the 11px label's capitals, with 2px strokes like every other icon in the app.

**CSS decision for the author with the pick:** unchanged by the new size. `.feed__reaction-icon` in `app/frontend/styles/feed-reactions.css` must drop `height: 1.25em; width: auto` (keeping `flex: none`) so each SVG keeps the width and height the export writes. At 13.75px no grid lands on whole pixels. The ticket asked for no other code; this is one declaration. Every icon height is even (14, 16 or 18px), so centring in the 34px or 44px button lands on whole pixels. At 360px the five buttons need about 240px against a 228px text column, so the fifth wraps to a second line (round 1 needed about 270px). From a 390px screen up they fit on one line.

**After the pick:** replace the five `reaction-*` grids in `script/pixel_art/export.mjs` (keys unchanged), update their sizes in `DESCRIPTIONS`, run `node script/pixel_art/export.mjs`, and apply the CSS change if approved. Never hand-edit `app/frontend/images/pixel/`. The mockup's renderer is the export's (`rowRuns`), so the grids paste as they are.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: exit 0 after the export ran.
- `bin/rails test test/helpers` and the feed reaction system test (`bin/rails test test/system/<feed reactions file>.rb`) -- expected: green; keys unchanged so `pixel_icon` still resolves.
- `npm run lint:css` -- expected: clean if the CSS rule changes.

**Manual checks (if no CLI):**
- The author approves the drawings in `ux-gameble/mockups/reaction-icons.html`, then sees them on the feed on staging, desktop and phone, crisp at 14 to 18px, the lit one dark on blue.

## Auto Run Result

Status: blocked (human checkpoint). Mockup written at `_bmad-output/initiative-gameble/ux-gameble/mockups/reaction-icons.html`; recommended set T1, H1, G1, W1, F1, plus the CSS sizing decision above. No change to `export.mjs`, the exported SVGs or application code. Resume once the author has picked one drawing per reaction and answered the CSS question.

Round 2 (2026-11-03): the mockup redrawn after the author's review; recommended set T4, H4, G3, W4, F3 at most 9 rows at 2 CSS px. Round 1 is collapsed in the mockup. Still blocked until the author picks.
