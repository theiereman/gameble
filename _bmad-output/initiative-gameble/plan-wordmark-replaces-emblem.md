---
title: 'The gold GAMEBLE wordmark replaces the emblem'
type: 'feature'
ticket: ''
created: '2026-10-12'
status: 'done'
baseline_revision: '68a77453e0b1144ce6e9b5f609efd9855f51d85d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The brand is a 12×12 emblem (two stacked cards and a gold "+") that the author finds ugly, followed by the word "gameble" set in VT323. The repository's GitHub page has no header.

**Approach:** A flat gold pixel wordmark "GAMEBLE" replaces both the emblem and the VT323 word everywhere the brand appears. Where a wide wordmark cannot fit (the Standard card back's centre disc, the canister's emblem window), the wordmark's own gold "G" stands in as a monogram. The README opens with the animated header GIF the author approved.

## Boundaries & Constraints

**Always:**
- The wordmark design (approved on the canvas, variant "or plat"):
  - 7×9 bold glyphs (below), 1 art pixel per glyph cell, 3 art pixels between letters, no outline, no shadow.
  - Rows are banded by `t = y/9`: `t<0.2` `#fff3c4`, `<0.52` `#f4c542`, `<0.78` `#d99a1f`, otherwise `#8f5e0a`.
  - A glyph pixel with no glyph pixel above it is `#fff3c4`.
  - A static diagonal shine: `s = x + y`, middle `round(cols*0.17) + round(9/2)`, start `middle - 2`. Pixels at `s-start` in `[0,2)` or exactly `3` take their tier's lifted colour: `#ffffff`, `#fff3c4`, `#ffe08a`, `#d99a1f`.
  - Glyphs:
    - G `.######`,`#######`,`##.....`,`##.....`,`##..###`,`##..###`,`##...##`,`#######`,`.######`
    - A `.#####.`,`#######`,`##...##`,`##...##`,`#######`,`#######`,`##...##`,`##...##`,`##...##`
    - M `##...##`,`###.###`,`#######`,`##.#.##`,`##.#.##`,`##...##`,`##...##`,`##...##`,`##...##`
    - E `#######`,`#######`,`##.....`,`######.`,`######.`,`##.....`,`##.....`,`#######`,`#######`
    - B `######.`,`#######`,`##...##`,`######.`,`######.`,`##...##`,`##...##`,`#######`,`######.`
    - L `##....` (×7), then `######` (×2)
- Every pixel file comes from `script/pixel_art/export.mjs`. The glyphs and colours are defined once there and feed both the SVG and the PNG monogram.
- The brand keeps its accessible name, `t("shell.top_bar.brand")` (or the link's existing `home` label). The wordmark SVG stays `aria-hidden`.

**Never:**
- Hand-edit `app/frontend/images/pixel/`.
- Add new locale strings.
- Use animation or a hover shine: those belong to a separate ticket.
- Change the other card backs, the starfield or `canister-small`.

</frozen-after-approval>

## Code Map

- `script/pixel_art/export.mjs`:
  - `ICONS` (L147-419; `logo` at L148-165) is consumed by `iconSvg` (L421-443).
  - `drawLogo` (L568-573) is called only by the Standard back (`default:` case, L787-815; the logo at L810-811, the 5×7 "GAMEBLE" word at L812-813) and by the canister body (L875-882, window `wx=35 wy=55 ww=30 wh=32`).
  - The `files` Map is at L1071-1080. `DESCRIPTIONS` (L1086-1116) needs exactly one entry per file, or the script throws.
- `app/helpers/shell_helper.rb:22`: `pixel_icon(name, **attrs)` inlines `images/pixel/<name>.svg` and adds `aria-hidden`. Reuse it as is.
- `app/views/shell/_top_bar.html.erb` L24-53: four brand branches. Each is `pixel_icon("logo", class: "top-bar__logo")` followed by `<span class="top-bar__name">`. Branches :24 and :46 are links labelled `shell.top_bar.home`; :41 (home and public pages) and :50 (phone brand) are `<p>`.
- `app/views/pages/_showcase.html.erb:34` and `_invitation.html.erb:7`: the dimmed logo inside the `.hub-showcase__outline` dashed card (196×304).
- `app/frontend/styles/shell.css`:
  - `.top-bar__brand` (L246) carries the font and uppercase that only served the text.
  - `.top-bar__logo` (L257) is 24×24.
  - Phone rules are at L1325-1345.
- `app/frontend/styles/hub.css:280`: `.hub-showcase__logo` is 24×24 at opacity .35.
- Tests that name the logo:
  - `test/integration/shell_test.rb` :60-61, :116-118, :174-178, :297;
  - `test/controllers/card_preview_tags_test.rb:76`;
  - `test/controllers/pages_controller_test.rb:189`.
- Tests that need no change:
  - `test/lib/pixel_art_export_test.rb` counts the committed files dynamically.
  - `test/helpers/shell_helper_test.rb:46` inlines every SVG.
- System tests that read the visible text "GAMEBLE": `test/system/shell_test.rb` :359, :393 and `card_detail_test.rb:128`. System tests are disabled, so keep their selectors coherent without running them.
- `README.md`: has no header today. The GIF is at `/tmp/claude-1000/-home-teyermann-projets-gameble/6be9fa25-60c7-44e6-a725-d418d3d66a2b/scratchpad/header/gameble-header.gif` (1600×480).
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` (L488, 678, 687, 699, 708, 739, 758) and `EXPERIENCE.md` (L54, L147) describe the logo.

## Tasks & Acceptance

**Execution:**
- [ ] `script/pixel_art/export.mjs`:
  - Add the wordmark glyphs and the gold tier/lift colours.
  - Build a `wordmark` grid (66×9) with the banding, edge light and shine, and add it to `ICONS`.
  - Replace the `logo` ICONS entry with it, and replace `drawLogo` with `drawMonogram(g, x, y, k)`: the wordmark's "G", banded the same way, at k× scale.
  - The Standard back puts the monogram centred in its disc; the canister body puts it centred in its emblem window.
  - Update `DESCRIPTIONS`.
  - Run the export, so that `logo.svg` disappears, `wordmark.svg` appears, and `back-standard-*.png` and `canister-body.png` change.
- [ ] `app/views/shell/_top_bar.html.erb`: in all four branches, use `pixel_icon("wordmark", class: "top-bar__wordmark")`. Keep the brand text as `<span class="top-bar__name visually-hidden">`.
- [ ] `app/views/pages/_showcase.html.erb` and `_invitation.html.erb`: use `pixel_icon("wordmark", class: "hub-showcase__wordmark")`, and update the comment.
- [ ] `app/frontend/styles/shell.css` and `hub.css`: rename the logo rules to the wordmark (natural SVG size, `display:block`). Keep the dimmed opacity. Drop the text-only typography from `.top-bar__brand`, unless other children need it.
- [ ] Tests: update the integration and controller selectors to `svg.pixel-icon.top-bar__wordmark` and `svg.hub-showcase__wordmark`; the `.top-bar__name` text assertions stay. Update the three system-test text checks so they target the link by its accessible name.
- [ ] `.github/assets/gameble-header.gif` (copied from the scratchpad) and `README.md`: put `<p align="center"><img src=".github/assets/gameble-header.gif" width="800" alt="gameble"></p>` above the title.
- [ ] `DESIGN.md` and `EXPERIENCE.md`: replace "logo"/emblem wording with the gold wordmark (top bar, public page, empty showcase), and the "G" monogram (Standard back, canister).

**Acceptance Criteria:**
- Given any page with the top bar, desktop or phone, when it renders, then the gold wordmark shows where the emblem and the VT323 "gameble" were, and the brand link or paragraph is still named "gameble…" for assistive technology.
- Given the hub with no notable pull, or an invitation, when it renders, then the dashed outline holds the dimmed wordmark.
- Given the Standard back and the canister, when they are exported, then their centre shows the gold "G" monogram and no emblem.
- Given the repository's README on GitHub, when opened, then the animated header shows at 800 px wide above the title.

## Implementation Notes

## Plan Change Log

## Review Triage Log

Pass 1 (quick lens): 0 high, 0 medium, 3 low, 0 false, 0 maybe-false.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| `a.top-bar__home:hover` colour rule in shell.css is dead: the link's text is visually hidden and the wordmark's fills are fixed | low | patch | The rule only set `color`; nothing in the link uses `currentColor`. Deleted; hover feedback is ticket 7.40's sweep. |
| The 132 px wordmark touches the packs chip on a 320 px wide phone | low | rejected | Fits at 360 and 390 px (the reference phones, checked by the reviewer); a 320 px screen is rare and a fix needs new layout rules (wrapping or a smaller mark), not a direct correction. |
| New multi-line descriptive comments in export.mjs break the AGENTS.md comment rule | low | patch | AGENTS.md allows only one-line comments on external constraints; the comments restate the code. Removed. |

## Design Notes

The monogram reuses the wordmark's "G" so that the round disc and the 30×32 window carry the same mark as the wordmark itself. At k=2 it measures 14×18 art px, which fits the window. On the back, choose k from the disc radius as `drawLogo` did. Its grid is 66 art px wide, which is 132×18 CSS px in the top bar (the bar is 56 px tall).

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: exit 0
- `bin/rails test test/integration/shell_test.rb test/controllers test/lib/pixel_art_export_test.rb test/helpers/shell_helper_test.rb` -- expected: green
- `bin/ci` -- expected: green (rubocop, packwerk, i18n-tasks, full test suite)
- `npm run test:js` and `bin/rails zeitwerk:check` -- expected: green

**Manual checks:**
- Open `wordmark.svg`, `back-standard-l.png` and `canister-body.png`. Expected: the wordmark matches the canvas, and the monogram is centred.
