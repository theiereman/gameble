---
title: 'The five reaction icons are redrawn from a mockup the author approves'
type: 'feature'
ticket: 3
created: '2026-11-03'
status: blocked
baseline_revision: '0f181fa47dcdbce6950e6aadc08413d33efbf527'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
blocked_at: "2026-11-03"
blocked_reason: "waiting for the author to pick the icons in ux-gameble/mockups/reaction-icons.html"
---

<intent-contract>

## Intent

**Problem:** The author found the five feed reaction icons (thumb, heart, GG, wow, middle finger) very poor on staging. Two rounds of hand-drawn pixel grids did not satisfy him either. The bar's stylesheet also squeezes every icon to `height: 1.25em` (13.75px), so no grid lands on whole pixels.

**Approach:** Author decision of 2026-11-03: the five icons leave the hand-drawn pixel set. Each is a precise vector drawing inspired by the emoji, in flat colour. A reproducible script rasterises it and runs it through pixelcrush, the filter that pixelates the card art. The app serves the resulting PNGs at a whole number of CSS px per pixel, under the same reaction keys, so the counts, the controller and the operation do not change. The author picks the drawings and the size in `ux-gameble/mockups/reaction-icons.html`, round 3.

## Boundaries & Constraints

**Always:** keep the keys `thumb`, `heart`, `gg`, `wow`, `middle_finger`. The output is deterministic, and `--check` compares decoded pixels, like `script/pixel_art/export.mjs`. Every icon renders at its exported size (no `height: 1.25em`), with `image-rendering: pixelated`. The vector sources are drawn by hand: no icon library, no vendor emoji artwork.

**Never:** hand-edit `app/frontend/images/pixel/` or the generated PNGs. Never type the emoji characters into the page: they render differently per OS, and 🖕 may be missing. Never change the reactions controller, operation or counts.

</intent-contract>

## Code Map

- `script/pixel_art/export.mjs` -- the five `ICONS["reaction-*"]` grids and their `DESCRIPTIONS` entries are removed. Its `encodePng`, `decodePng` and `upToDate` are the model for the new script's `--check`.
- `app/frontend/images/pixel/reaction-*.svg` -- the five outputs whose grids are removed. The pixel export's `--check` reports them as "not exported" until they are deleted from version control.
- `app/views/reactions/_bar.html.erb` -- renders `pixel_icon("reaction-#{kind.dasherize}", class: "feed__reaction-icon")`; that call becomes the new image.
- `app/frontend/styles/feed-reactions.css` -- `.feed__reaction-icon { height: 1.25em; width: auto }` goes; it gets `image-rendering: pixelated`.
- `test/helpers/shell_helper_test.rb` -- "each feed reaction has its pixel icon" asserts `pixel_icon("reaction-#{kind}")`; it moves to the new icon.
- `node_modules/pixelcrush` 0.2.1 -- `filter(pixels, { width, height, colors, crop: "none" })`, binary alpha, median cut; already used by `app/frontend/lib/card_art/worker_job.ts`.

## Tasks & Acceptance

**Execution:**
- [ ] `script/reaction_icons/sources/{thumb,heart,gg,wow,middle-finger}.svg` -- the picked vector sources, 32-unit viewBox, copied from the mockup's round 3 -- the art lives as reviewable SVG.
- [ ] `script/reaction_icons/export.mjs` -- rasterise each source at 16 times the target with `@resvg/resvg-js` (a new pinned devDependency; node has no rasteriser installed). Then run `filter` at the picked size and colours, and write `app/frontend/images/reactions/<key>.png`. `--check` exits 1 on a differing or stray file -- reproducible like the pixel export.
- [ ] `script/pixel_art/export.mjs`, and delete the five `pixel/reaction-*.svg` -- removes the old icons, so the pixel export's `--check` passes.
- [ ] `app/views/reactions/_bar.html.erb` -- `image_tag vite_asset_path("images/reactions/#{kind.dasherize}.png"), alt: "", width: 16, height: 16, class: "feed__reaction-icon"`; the visually hidden name stays.
- [ ] `app/frontend/styles/feed-reactions.css` -- the sizing change above.
- [ ] `test/helpers/shell_helper_test.rb` or a view test -- each kind's PNG exists and the bar renders five images. Add the new `--check` to `bin/ci` and the CI workflow beside the pixel export's.

**Acceptance Criteria:**
- Given a feed entry, when the bar renders, then each reaction shows its pixelcrush PNG at 16 × 16 CSS px, crisp, beside its count, on desktop and on touch.
- Given the viewer's own reaction, when the bar renders, then that button keeps its accent fill and the icon keeps its colours.
- Given a clean checkout, when `node script/reaction_icons/export.mjs --check` and `node script/pixel_art/export.mjs --check` run, then both exit 0.

## Design Notes

**Author decision, 2026-11-03:** first "no pixel art, something precise inspired by emoji", then "generate an image and apply the pixelcrush filter". The icons are therefore pixel art made by the filter, matching the pixelated card art, not grids drawn by hand.

This departs from DESIGN.md for these five icons only. The line to amend is DESIGN.md › Brand & Style, "Fine pixel art over high-quality material": "One art pixel is 2 CSS px (`{components.art-pixel.size}`) for everything drawn: … icons …". It needs an exception: the feed reaction icons are vector drawings pixelated by pixelcrush and shown at 1 CSS px per pixel. DESIGN.md › Shapes ("Round and angled forms appear only as pixel art") still holds for the pixelcrush output. It needs amending only if the plain vector alternative is picked.

**Round 3 recommendation:** five vector sources, each pixelcrushed to **16 × 16 in 8 colours and shown at 1 CSS px per pixel (16px)**:
- **T7**, thumb: side fist with a cuff.
- **H7**, heart: plump, with a highlight.
- **G5**, GG: in a purple speech bubble.
- **W6**, wow: open-mouthed face.
- **F7**, middle finger: the finger raised over three knuckles.

At 2 CSS px (DESIGN's art pixel) the image would be 9 pixels, and pixelcrush leaves a smudge. 20 pixels holds more detail but is heavier beside the 11px count. 4 colours lose the thumb's outline.

**Alternatives:**
- **Other drawings:** T8 (no cuff), H6 (flat), G6 (tag without a tail), W7 (raised brows and white eyes, muddy at 16), F6 (thumb across, busier). Any of them can also be taken at 20 × 20 or with 4 colours.
- **Plain vectors,** in colour or in monochrome through `currentColor`. These would be SVG files in `app/frontend/images/reactions/`, inlined by a helper like `pixel_icon`.
- **Rounds 1 and 2:** hand-drawn grids, at 22px and then at most 18px. They are collapsed in the mockup.

**Lit state:** colour icons keep their colours on the bar's accent fill, and their dark outline holds them on the blue. The purple GG reads least there; the mockup also shows the alternative, a raised panel with an accent ring and the count in accent. Monochrome lit turns dark on the blue, as today. At 360px the fifth button still wraps to a second line.

**How the mockup was generated:** with throwaway scripts kept outside the repo. A page run in headless Chromium (`--allow-file-access-from-files`) imports pixelcrush from `node_modules`, draws each colour SVG on a canvas at 16 times the target, and runs `filter` at 9, 16 and 20 pixels with 4 and 8 colours. A node script then embeds the outputs in the mockup as PNG data URIs. The real build should use resvg rather than Chromium, so that `--check` does not depend on a browser version.

## Verification

**Commands:**
- `node script/reaction_icons/export.mjs --check` and `node script/pixel_art/export.mjs --check` -- expected: exit 0.
- `bin/rails test test/helpers test/controllers/reactions_controller_test.rb` and `bin/rails test test/system/feed_reactions_test.rb` -- expected: green.
- `npm run lint:css`, `npm run format:check`, `script/check_file_sizes` -- expected: clean.

**Manual checks (if no CLI):**
- The author picks in `ux-gameble/mockups/reaction-icons.html` (round 3), then sees the icons on the feed on staging, desktop and phone, crisp at 16px.

## Auto Run Result

Status: blocked (human checkpoint). Mockup written at `_bmad-output/initiative-gameble/ux-gameble/mockups/reaction-icons.html`. Its first recommended set was T1, H1, G1, W1, F1, with the CSS sizing decision. No change to `export.mjs`, the exported SVGs or application code. Resume once the author has picked one drawing per reaction and answered the CSS question.

Round 2 (2026-11-03): the mockup was redrawn after the author's review. Recommended set T4, H4, G3, W4, F3, at most 9 rows at 2 CSS px. Round 1 is collapsed in the mockup. Still blocked until the author picks.

Round 3 (2026-11-03): the author's change of direction is recorded as a decision. The icons are vector drawings inspired by emoji and pixelated by pixelcrush. Recommended T7, H7, G5, W6, F7 at 16 × 16, 8 colours, 1 CSS px per pixel. The route moves to full. Rounds 1 and 2 are collapsed in the mockup. Still blocked until the author picks.
