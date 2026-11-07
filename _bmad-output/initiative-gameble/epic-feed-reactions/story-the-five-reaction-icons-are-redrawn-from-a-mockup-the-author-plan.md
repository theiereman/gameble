---
title: 'The five reaction icons are redrawn from a mockup the author approves'
type: 'feature'
ticket: 3
created: '2026-11-03'
status: done
baseline_revision: 'b3b5259a98d97178b903d379ea2562c80d5fb293'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
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

- `script/reaction_icons/sources/{thumb,heart,gg,wow,middle-finger}.svg` -- the five approved vector sources, already in place (written from the mockup's drawings). Each is a 32-unit viewBox in flat colour with a dark outline. They are the art: do not redraw them.
- `script/pixel_art/export.mjs` -- `ICONS["reaction-*"]`: five grids, under a comment "The five feed reactions"; plus their five `DESCRIPTIONS` entries ("reaction-*.svg"). Both are removed. Its `encodePng`, `decodePng`, `upToDate`, `failWhenStale` and `option` handling are the model for the new script; copy what is needed rather than importing from it (it runs its export on import).
- `app/frontend/images/pixel/reaction-{thumb,heart,gg,wow,middle-finger}.svg` -- the five old outputs. Once their grids are gone, the pixel export's `--check` names them "not exported"; delete the five files so the folder matches the export again.
- `test/lib/pixel_art_export_test.rb` -- how the pixel export's `--check` runs in CI: a Rails test that shells out to node (`Open3.capture2e`), plus tests for a missing and a stray file. The new export gets the same kind of test; `bin/rails test` runs it in CI, so `bin/ci` and the workflow need no new step.
- `app/views/reactions/_bar.html.erb` -- `pixel_icon("reaction-#{kind.dasherize}", class: "feed__reaction-icon")` becomes the PNG; the visually hidden name and the count stay as they are.
- `app/frontend/styles/feed-reactions.css` -- `.feed__reaction-icon { flex: none; height: 1.25em; width: auto; }`.
- `test/helpers/shell_helper_test.rb` -- "each feed reaction has its pixel icon" (around line 32) asserts `pixel_icon("reaction-#{kind}")` for `Game::FeedReaction::KINDS`; it moves to the new PNGs.
- `node_modules/pixelcrush` 0.2.1 -- `filter(pixels, { width, height, colors, crop: "none" })` returns `{ pixels, palette }`; alpha is binary by default; deterministic. Node use: wrap raw RGBA in a `Uint8ClampedArray`.
- `config/vite.json` -- `sourceCodeDir: app/frontend`; `vite_asset_path("images/pixel/...png")` is already used by views (landings), so `vite_asset_path("images/reactions/<file>.png")` serves the new files the same way.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- Brand & Style, "Fine pixel art over high-quality material" (around line 569).

## Tasks & Acceptance

**Execution:**
- [x] `package.json`, `package-lock.json` -- add `@resvg/resvg-js` as a devDependency pinned to an exact version (no caret), installed with npm -- node has no SVG rasteriser.
- [x] `script/reaction_icons/export.mjs` -- for each source in `script/reaction_icons/sources/`: render the SVG with resvg at 16 times the target (256 × 256), then run pixelcrush `filter` to 16 × 16 with 8 colours, `crop: "none"`. Write `app/frontend/images/reactions/<name>.png` as RGBA PNG. With no argument, it writes only the files that changed. `--check` exits 1 and names any file that differs (compared by decoded pixels) or is stray. `--out <dir>` writes elsewhere. Header comment in the style of the pixel export. Under 400 lines.
- [x] `app/frontend/images/reactions/*.png` -- the five outputs, written by the script, never by hand.
- [x] `script/pixel_art/export.mjs` -- remove the five `reaction-*` grids and their `DESCRIPTIONS`, then delete `app/frontend/images/pixel/reaction-*.svg` so `node script/pixel_art/export.mjs --check` passes.
- [x] `app/views/reactions/_bar.html.erb` -- `image_tag vite_asset_path("images/reactions/#{kind.dasherize}.png"), alt: "", width: 16, height: 16, class: "feed__reaction-icon"` (decorative: the hidden name labels the button).
- [x] `app/frontend/styles/feed-reactions.css` -- `.feed__reaction-icon` keeps `flex: none`, drops `height` and `width`, adds `image-rendering: pixelated`.
- [x] `test/lib/reaction_icons_export_test.rb` -- the committed PNGs match `--check`; a second export changes nothing; `--check` names a missing and a stray file; each PNG is 16 × 16. Model it on `test/lib/pixel_art_export_test.rb`.
- [x] `test/helpers/shell_helper_test.rb` -- the reaction icon test moves to the bar rendering, or to a check that each kind's PNG exists. Adjust any other test that looks for the reaction `svg` inside the bar (`test/system/feed_reactions_test.rb`, `test/controllers/reactions_controller_test.rb`, `test/controllers/feeds_controller_test.rb`, `test/jobs/live_feed_job_test.rb`).
- [x] `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- add the approved exception to "Fine pixel art over high-quality material". The five feed reaction icons are emoji-inspired vector drawings pixelated by pixelcrush to 16 × 16 in 8 colours, shown at 1 CSS px per pixel, with sources in `script/reaction_icons/`.
- [x] `AGENTS.md`, `CONTRIBUTING.md` -- next to the line about `app/frontend/images/pixel/`, say the same for `app/frontend/images/reactions/`: never hand-edit it, run `node script/reaction_icons/export.mjs` (`--check` verifies).

**Acceptance Criteria:**
- Given a feed entry, when the bar renders, then each reaction shows its pixelcrush PNG at 16 × 16 CSS px, crisp, beside its count, on desktop and on touch.
- Given the viewer's own reaction, when the bar renders, then that button keeps its accent fill and the icon keeps its colours.
- Given a clean checkout, when `node script/reaction_icons/export.mjs --check` and `node script/pixel_art/export.mjs --check` run, then both exit 0.

## Design Notes

**Author decisions, 2026-11-03:**
- **The direction:** first "no pixel art, something precise inspired by emoji", then "generate an image and apply the pixelcrush filter". The icons are pixel art made by the filter, matching the pixelated card art, not grids drawn by hand.
- **The pick:** round 3 is approved, keeping T7 (thumb), H7 (heart), G5 (GG bubble) and W6 (wow), each pixelcrushed to **16 × 16 in 8 colours and shown at 16px**. The lit state keeps the bar's accent fill.
- **The middle finger:** F6 and F7 are turned down as too ugly. The author pointed to a reference: a flat yellow hand from the back, a long rounded middle finger, shorter rounded knuckles each side, a broad palm, a thin darker line for the folded thumb. Then "make an equivalent without using the emoji directly". So **F8** is a new drawing of our own in that spirit, with its own paths and proportions, through the same pipeline. No third-party image enters the repo, so no credit is needed.
- **The DESIGN.md exception** for these five icons is approved.

**Why 16 × 16 at 1 CSS px:** at 2 CSS px (DESIGN's art pixel), the image would be 9 pixels and pixelcrush leaves a smudge. 20 pixels is heavier beside the 11px count. 4 colours lose the thumb's outline.

**Lit state:** colour icons keep their colours on the bar's accent fill, and their dark outline holds them on the blue. At 360px the fifth button wraps to a second line, as it does today.

**Pipeline:** resvg, not Chromium, so `--check` does not depend on a browser version. The mockup was generated with throwaway scripts (headless Chromium importing pixelcrush, canvas at 16 times the target); resvg's antialiasing differs slightly, so the committed PNGs may differ from the mockup by a few pixels.

**Alternatives kept in the mockup:** T8, H6, G6, W7, F6, F7, other sizes and palettes, the plain vectors in colour and monochrome, and rounds 1 and 2.

## Verification

Run Rails commands in this worktree with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w343 CHROME_BIN=/usr/bin/chromium` (the test database is already created and loaded).

**Commands:**
- `node script/reaction_icons/export.mjs --check` and `node script/pixel_art/export.mjs --check` -- expected: exit 0.
- `bin/rails test test/lib/reaction_icons_export_test.rb test/lib/pixel_art_export_test.rb test/helpers/shell_helper_test.rb test/controllers/reactions_controller_test.rb test/controllers/feeds_controller_test.rb test/jobs/live_feed_job_test.rb` -- expected: green.
- `bin/rails test test/system/feed_reactions_test.rb` -- expected: green.
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rubocop` on the touched Ruby -- expected: clean.

**Manual checks (if no CLI):**
- Open the five PNGs enlarged: each reads as its reaction, with no stray pixel.

## Plan Change Log

- 2026-11-03, before implementation: the author's approval of round 3 and the middle-finger decision were folded in. F8 replaces F7, the five sources were written to `script/reaction_icons/sources/`, and the export check runs as a Rails test like the pixel export's. The branch was moved onto develop's head (b3b5259a), so `baseline_revision` is that commit.

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `test/controllers/reactions_controller_test.rb`: the selector `src*='/middle-finger-'` matches only the hashed build file name, so it fails if a Vite dev server on the test port serves the unhashed path — the selector now matches `src*='middle-finger'`, like the other image tests.
  - `[low]` `[patch]` `script/reaction_icons/export.mjs` `decodePng`: the local `const filter` shadows the `filter` imported from pixelcrush — renamed to `rowFilter`.

## Auto Run Result

Status: blocked (human checkpoint). Mockup written at `_bmad-output/initiative-gameble/ux-gameble/mockups/reaction-icons.html`. Its first recommended set was T1, H1, G1, W1, F1, with the CSS sizing decision. No change to `export.mjs`, the exported SVGs or application code. Resume once the author has picked one drawing per reaction and answered the CSS question.

Round 2 (2026-11-03): the mockup was redrawn after the author's review. Recommended set T4, H4, G3, W4, F3, at most 9 rows at 2 CSS px. Round 1 is collapsed in the mockup. Still blocked until the author picks.

Round 3 (2026-11-03): the author's change of direction is recorded as a decision. The icons are vector drawings inspired by emoji and pixelated by pixelcrush. Recommended T7, H7, G5, W6, F7 at 16 × 16, 8 colours, 1 CSS px per pixel. The route moves to full. Rounds 1 and 2 are collapsed in the mockup. Still blocked until the author picks.

Round 3 approved (2026-11-03): T7, H7, G5, W6 and a new F8, at 16 × 16 in 8 colours. The block is cleared and the build is under way.

Build (2026-11-03): status built.

**Summary:** the five feed reaction icons are now our own vector drawings. `script/reaction_icons/export.mjs` renders each with resvg at 256 × 256 and pixelates it with pixelcrush to 16 × 16 in 8 colours. The PNGs are shown at 16px with `image-rendering: pixelated`. The five hand-drawn grids are gone from the pixel export. That export does not delete stray files, so their five SVGs were deleted directly. The reaction keys are unchanged.

**Files:**
- `package.json`, `package-lock.json`: `@resvg/resvg-js` 2.6.2 is pinned as a devDependency.
- `script/reaction_icons/sources/*.svg`: the five vector sources: T7, H7, G5, W6 and our own F8 middle finger.
- `script/reaction_icons/export.mjs`: the export, with `--check` (decoded-pixel compare, stray files) and `--out`.
- `app/frontend/images/reactions/*.png`: the five generated icons.
- `script/pixel_art/export.mjs`: the reaction grids and their descriptions are removed.
- `app/frontend/images/pixel/reaction-*.svg`: the old icons, deleted.
- `app/views/reactions/_bar.html.erb`: a decorative 16 × 16 `img` per kind.
- `app/frontend/styles/feed-reactions.css`: `height`/`width` dropped and `image-rendering: pixelated` added.
- `test/lib/reaction_icons_export_test.rb`: tests that the check passes, a re-export changes nothing, a missing or stray file is caught, and each icon is 16 × 16. `bin/rails test` runs these in CI, so no new CI step is needed.
- `test/controllers/reactions_controller_test.rb`: the bar renders five icons. `test/helpers/shell_helper_test.rb` no longer tests the old pixel icon.
- `DESIGN.md`: the approved exception.
- `AGENTS.md` and `CONTRIBUTING.md`: never hand-edit `app/frontend/images/reactions/`.
- The mockup: marked approved.

**Review (quick lens):**
- 2 findings, both low, both patched.
- 0 deferred, 0 rejected.
- `followup_review_recommended: false`: no high finding was patched, and fewer than two medium ones were.

**Verification:**
- Both `--check` runs exit 0: 5 reaction icons and 393 pixel-art files.
- The six Rails test files in Verification: 104 runs, 0 failures. `test/system/feed_reactions_test.rb`: 2 runs, 0 failures.
- `npm run test:js`: 835 passed.
- `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes` and rubocop on the touched Ruby: all clean.

**Residual risks:**
- resvg's antialiasing makes the committed PNGs differ from the mockup images by a few palette pixels each.
- GG is the busiest icon at 16px.
- The lockfile lists resvg's prebuilt binaries for every platform. npm installs only the current platform's.
