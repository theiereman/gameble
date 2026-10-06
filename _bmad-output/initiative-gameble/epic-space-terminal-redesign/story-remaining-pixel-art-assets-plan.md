---
title: 'Remaining pixel-art assets'
type: 'feature'
ticket: '8'
created: '2026-10-06'
status: done
baseline_revision: 'a26b1d7f8bba85fb953601df45311edab245d20f'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** AD-27 ships every pixel-art asset as a static file exported once by a script, but `script/pixel_art/export.mjs` (story 8.1) only exports the logo and the interface icons. The card backs, the booster canister, the hub planet and the avatars exist only as procedural canvas code in the approved prototypes, so the booster and hub stories have nothing to show. The author has to approve all the art once, on one sheet.

**Approach:** Port the prototypes' drawing code (`backCanvas`, `CANV`, `drawPlanet`, `avatarURL` with `PALS`/`AV_ROWS`, and the helpers `drawLogo`, `ptext`, `ptextS`, `FONT`, `mixc`) pixel for pixel into the export script, on an in-memory RGBA buffer. Write each image as a PNG at 1x art resolution under `app/frontend/images/pixel/`, extend `--check` to the PNGs, and add a `--sheet <path>` mode. That mode writes one self-contained HTML review sheet of every exported file (8.1's and 8.8's) at 2 CSS px per art pixel.

## Boundaries & Constraints

**Always:**
- Pixels equal the prototype's canvas output. Same formulas, same constants, same rounding (`Math.round` in `P`, integer `fillRect`), same `mixc` and `clamp`, and the same RNG seed `sd = w*131 + protoId.length*977`, where protoId is the prototype id (`std`, `s1`, `w38`, `gold`, `aur`, `b17`, `cent`, `snow`), since the id's length changes the stars and snow. `fillRect` clips to the canvas, and later fills overwrite earlier ones. Every colour is opaque. Pixels never drawn stay transparent (alpha 0).
- Deterministic: a second run changes no file. The script writes a PNG only when its decoded pixels differ. `--check` compares decoded pixels (IHDR plus unfiltered rows), never compressed bytes, so a different zlib build cannot fail it.
- Node built-ins only (`node:zlib`, `node:fs`), with no new npm dependency. No runtime drawing code enters `app/` (AD-27). Never push or deploy.

**Never:**
- Do not change 8.1's SVG outputs. That includes `avatar-default.svg` and `canister-small.svg`, which stay as the shell uses them.
- Do not wire the new files into any view, component, island or `Game` constant. The booster stories, AD-25's back catalogue and the profile screens do that later.
- Do not draw the canister's label text, hazard band or LEDs. They are DOM layers in the prototype (`.l1`, `.l2`, `.chz`, `.cled`) and change colour when armed. Do not draw the locked-back padlock or graying. Do not add the prototype's 56×84 `t` thumbnail size, which is not a DESIGN card size.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export | `node script/pixel_art/export.mjs` | Writes 8.1's 29 SVGs, plus 40 card backs, 3 canister parts, 1 planet and 8 avatars as PNGs, and prints the count | — |
| Re-run | run again | No file content changes | — |
| Check, clean | `--check` | Exit 0 and prints the count | — |
| Check, drift | a PNG's pixels edited, a file missing or a stray file in the folder | Exit 1, naming each file | — |
| Sheet | `--sheet <path>` | Writes one HTML file with every exported file inlined, labelled with its file name and what it is. Exported files are not touched. | Missing path argument: exit 1 with usage |

</intent-contract>

## Code Map

- `script/pixel_art/export.mjs` -- 8.1's generator. `ICONS` + `iconSvg` + `starfieldSvg` build `files` (a Map from name to SVG string), and `--check` lists files that differ or are stray. Extend it here, keeping its header comment style. Generalise `files` to hold SVG strings and PNG specs (`{width, height, rgba}`).
- `_bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html` -- the reference. The helpers are at lines 1244-1247 (`mk`, `clamp`, `hex`, `mixc`) and 1331-1343 (`B32`, `FONT`, `ptext`, `ptw`, `drawLogo`, the `Object.assign(FONT…)` glyphs, `ptextS`). `backCanvas(id,w,h)` is at 1347-1440, `CANV` (caps 100×20, body 100×110) at 1624-1663 and `drawPlanet()` (200×200) at 1666-1680. The avatars (`PALS`, `AV_ROWS`, `avatarURL`) are at 2070-2079. `mobile.html` holds identical copies of all of these.
- Back sizes are half of DESIGN's card sizes (`backURL` uses `SZ[sz].w/2|0`): `xs` 50×75, `s` 56×84, `m` 80×120, `l` 104×156, `xl` 120×180. The drawing depends on the size (`k` thresholds, words skipped when `ptw(s) > w-16`), so each size is its own file.
- `test/lib/pixel_art_export_test.rb` -- runs `--check`. Add a test beside it that parses PNG IHDRs.
- `app/helpers/shell_helper.rb` `pixel_icon` -- only inlines `<name>.svg`, so PNGs don't affect it. `vite-plugin-ruby` already serves `app/frontend/images/**`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` -- Add a pixel buffer (`fillRect` clipped, `P` with `Math.round`), port the helpers and the four drawings verbatim in logic, and add a minimal PNG encoder (signature, IHDR RGBA 8-bit, filter 0 rows, `zlib.deflateSync` level 9, CRC32) and decoder for the check (inflate IDATs, compare the raw rows). Add the outputs:
  - `back-<name>-<size>.png` for names `standard`, `saison-1`, `semaine-38`, `etoile-dor`, `aurore`, `millesime-2017`, `centurion`, `soldes-hiver` × sizes `xs`, `s`, `m`, `l`, `xl`.
  - `canister-cap-top.png` (100×20), `canister-body.png` (100×110) and `canister-cap-bottom.png` (100×20).
  - `planet.png` (200×200).
  - `avatar-<colour>.png` (16×16) for `PALS` `hugo`→`blue`, `lea`→`pink`, `max`→`gold`, `ines`→`jade`, `tom`→`orange`, `sam`→`lavender`, `x1`→`grey`, `x2`→`violet`.

  Write a PNG only when its pixels differ. Extend `--check` to decode the PNGs. Add `--sheet <path>`: a self-contained HTML file (no external requests) with SVGs inlined as markup, so `currentColor` icons take the text colour, and PNGs as base64 `data:` URIs at `width = 2 × art width`. It has `image-rendering: pixelated` on every image, the DESIGN ground `#0b0f15` with text `#c7d5e0`, and sections for interface icons (8.1), card backs (a grid of backs × sizes), the canister (the three parts, then stacked as assembled), the planet and avatars. Each item carries its file name and a one-line description, from a `DESCRIPTIONS` map covering every file; the script throws when one is missing. It also carries a note that the canister's label text, hazard band and LEDs are page layers.
- [x] `app/frontend/images/pixel/*.png` -- run the script and commit the 52 PNGs.
- [x] `script/pixel_art/export.mjs` -- also accept `--out <dir>` (default `app/frontend/images/pixel`) for the write, `--check` and `--sheet` modes, so tests can run against a temporary copy.
- [x] `test/lib/pixel_art_export_test.rb` -- keep the `--check` test. Add tests covering each I/O row in a `Dir.mktmpdir`: the export writes every file; a second run leaves every file's bytes and mtime unchanged; `--check` exits 0 after an export; `--check` exits 1 and names the file after one PNG pixel is changed (re-encode it with Ruby `Zlib`), after a file is deleted, and after a stray file is added; `--sheet` writes an HTML file holding every exported file's name and no `http` URL; `--sheet` with no path exits 1. Add a test that reads each committed PNG's IHDR and asserts the backs at half of each card size, the canister parts adding up to 100×150, the planet at 200×200 and the avatars at 16×16.
- [x] `_bmad-output/initiative-gameble/epic-space-terminal-redesign/pixel-art-sheet.html` -- generate it with `--sheet`.

**Acceptance Criteria:**
- Given the script, when run twice, then `git status` shows no change after the second run and `--check` exits 0.
- Given a PNG with one pixel changed, when `--check` runs, then it exits 1 and names that file.
- Given the sheet opened in a browser, when viewed, then every file in `app/frontend/images/pixel/` appears once, at 2 CSS px per art pixel, pixelated, on the dark ground, with its file name and description, and the page makes no network request.
- Given the backs at size `m`, when compared with the prototype's `backCanvas(id,80,120)` output, then they match pixel for pixel. Check this by running the ported code against the prototype's functions copied into a scratch Node harness with a fake canvas.

## Design Notes

PNG rather than SVG: the backs, canister and planet are full gradient fields (many colours per row). As run-merged SVG they would weigh about 40 KB each, as 8.1's medieval card SVGs do, against a few KB as PNG. DESIGN.md allows either format. Comparing decoded pixels keeps `--check` stable across Node and zlib builds.

The sheet is a review artefact outside `app/`. It is generated by the script, so it always matches the files.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails db:test:prepare test` -- pass
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- pass

**Manual checks (if no CLI):**
- Open the sheet in headless Chromium and screenshot it. Check that the backs read as DESIGN's table describes and that nothing is blurred.

## Implementation Notes

- The port runs on a canvas stand-in (`canvas(w,h)` in `export.mjs`): `fillStyle` takes `#rrggbb` and ignores anything else, as a canvas does; `fillRect` paints opaque pixels, clipped, and throws on a fractional rectangle (a real canvas would antialias it). No drawing ever hits either case: a probe run with invalid colours made fatal passed.
- Pixel equality was checked for all 52 PNGs, not only the `m` backs: the prototype's own functions (`key-screens.html` lines 1244-1247, 1331-1344, 1347-1441, 1624-1663, 1666-1681, 2070-2079, the code map's ranges are one line short at the ends of `ptextS`, `backCanvas` and `drawPlanet`) were run in a Node `vm` with a fake canvas, and again in headless Chromium on a real canvas through `getImageData`. Both gave 52/52 identical to the decoded PNGs. `mobile.html` holds the same code.
- `--sheet` reads the files back from the `--out` folder and refuses (exit 1, same messages as `--check`) when the folder is not up to date, so the sheet always shows exactly the committed files. Inlined SVGs drop their `xmlns` attribute, so the sheet carries no `http` string at all.
- The write mode now writes an SVG or PNG only when its content (decoded pixels for PNGs) differs, so a second run keeps every mtime. The 29 SVGs are byte-identical to 8.1's.
- The decoder accepts all five PNG row filters (only RGBA 8-bit non-interlaced), so a file re-saved by another tool still passes when its pixels are the same.
- The 52 PNGs weigh 138 KB in all; the sheet 221 KB.

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` The sheet shows the three canister parts twice: once as their own figures and once in the "assembled" stack. The acceptance criterion says "appears once". Real, but the Tasks section asks for the assembled stack. The stack is captioned "assembled" rather than with file names, so each labelled file still appears once. The only fix is to edit this build's plan.
  - `[low]` `[reject]` `--sheet` has no guard on its path, so `--sheet app/frontend/images/pixel/x.html` would leave a stray file and could overwrite an export. Real, but it needs a developer to point the review sheet into the asset folder by hand, and the next `--check` names the stray file at once. The fix adds a path guard.
  - `[low]` `[reject]` An unknown or misspelt argument (`--chek`, `--sheet=foo.html`) falls through to write mode and exits 0. This fallback is 8.1's, kept unchanged. Write mode only rewrites files whose pixels differ, so a typo changes nothing in a clean tree. The fix adds argument validation.
  - `[false]` `[reject]` A directory named like an exported file crashes `upToDate` with `EISDIR`. Nothing creates such a directory, and the script fails loudly with a stack trace instead of passing or writing wrongly. That is correct behaviour for an unreachable state.

## Auto Run Result

- **Summary:** `script/pixel_art/export.mjs` now also exports the eight card backs of DESIGN.md (Standard, Saison 1, Semaine 38, Étoile d'or, Aurore, Millésime 2017, Centurion, Soldes d'hiver), each at the five card sizes. It also exports the canister (top cap, body, bottom cap), the hub planet and eight placeholder avatars. All are PNG at 1x art resolution under `app/frontend/images/pixel/`, drawn by code ported pixel for pixel from the approved prototypes. Run in Node and in Chromium, the prototypes' own functions give the same pixels for all 52 PNGs, from `key-screens.html` and from `mobile.html`. `--check` compares decoded pixels. `--out <dir>` and `--sheet <path>` are new. The review sheet `pixel-art-sheet.html` shows all 81 files at 2 CSS px per art pixel.
- **HITL review done (2026-10-06):** the author approved the sheet. Previously pending: the ticket is `hitl`. The author reviews `_bmad-output/initiative-gameble/epic-space-terminal-redesign/pixel-art-sheet.html` once, as asked in `pending-approvals.md`. The story is not `done` until the author approves it.
- **Files:**
  - `script/pixel_art/export.mjs`: canvas stand-in, the ported drawings, PNG encode and decode, `--out`, `--sheet`, `DESCRIPTIONS`.
  - `app/frontend/images/pixel/*.png`: 52 new files, 138 KB. 8.1's 29 SVGs are unchanged.
  - `test/lib/pixel_art_export_test.rb`: each I/O row in a temporary folder, plus the PNG sizes.
  - `_bmad-output/initiative-gameble/epic-space-terminal-redesign/pixel-art-sheet.html`: the review sheet, generated.
- **Review:** quick lens, 4 findings. Patched 0, deferred 0. Rejected 4:
  - three low: the canister shown twice as the task asked, no path guard on `--sheet`, and 8.1's fallback to write mode;
  - one false: the directory-named-like-a-file crash.
- **Follow-up review:** not recommended (`false`): no patch on this pass.
- **Verification:**
  - `node script/pixel_art/export.mjs --check`: 81 files up to date. A second run writes 0.
  - `bin/rubocop`: no offenses.
  - `packwerk validate` / `check`: clean.
  - `i18n-tasks missing`: none.
  - `npm run typecheck`: clean.
  - `npm run test:js`: 126 passed.
  - `bin/rails db:test:prepare test`: 1153 runs, 0 failures.
  - `bin/rails test:system`: 75 runs, 0 failures. The first run had one error in `tome_test.rb` ("Unable to find `.top-bar .steam-sign-in__button`"). No app code changed, and the test passed three times alone and in a full re-run.
  - The sheet was screenshot in headless Chromium: pixelated, on the dark ground, every file labelled.
- **Residual risks:**
  - The new files are not wired anywhere yet. The booster (8.11/8.12), AD-25's catalogue and the profile screens use them.
  - The xs size (50 × 75) is not in the prototype's `SZ`; the prototype logic drops its words except HIVER.
  - At xs and s, the Standard back's "GAMEBLE" touches the corner brackets, as in the prototype.
  - The avatars are the prototype's per-person placeholders; how players get one is open.
  - The canister's label text, hazard band and LEDs stay page layers, for the booster story.
