---
title: 'Typography: VT323 for large text, Space Mono for the rest'
type: 'feature'
ticket: '14'
created: '2026-10-07'
status: done
baseline_revision: '69577d6a35f822de8e26a257005310e676d52cc2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The shell uses three pixel fonts (Pixelify Sans, Silkscreen, VT323). The author found VT323 unreadable at small sizes and chose option 3 of `ux-gameble/mockups/typography-options.html` on 2026-10-06: two fonts only.

**Approach:** VT323 keeps the large text only (logo, screen and hero titles, public and showcase names, banners, big numbers, timers, the card-xl title, the friend code); Space Mono (400, 700) takes every small text (menus, buttons, labels, chips, kickers, card lines and titles at s/m/l, publisher, running text). Pixelify Sans and Silkscreen leave: their files, licences, @font-face, preloads and tests. The tokens, DESIGN.md's Typography (section and frontmatter) and the card face baselines follow.

## Boundaries & Constraints

**Always:** Space Mono self-hosted as fontsource 5.3.0 woff2 subsets (latin + latin-ext, 400 and 700) with its OFL text, `font-display: block`, latin files preloaded, `font-src 'self'` untouched. Every text stays at or above the 10 px floor; VT323 appears only at 20 px or more. Every text style stays a `--font-<style>` + `--tracking-<style>` token pair; sizes in rem. Card faces keep their widths, heights, art boxes and line heights; a card-xl title fits two lines in its band.

**Never:** no Google Fonts, no new font beyond the two, no size change to art pixels or layout boxes, no change to the back-office beyond what the tokens carry, no edit to mockups, no skipped or loosened visual test (keep `TOLERANCE`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hub signed in, desktop | `/en` after Steam sign-in | body computed font is Space Mono; no element on the page is below 10 px; every VT323 element is 20 px or more; `document.fonts` holds no Pixelify or Silkscreen face | test fails naming the offending selector |
| Head | any page | exactly 3 preloads: space-mono-latin-400, space-mono-latin-700, vt323-latin-400 | No error expected |
| Card faces s/m/l/xl, tilted and revealed | the six visual cases | match regenerated baselines within `TOLERANCE` | diff written to tmp/screenshots |
| Long title on card-s | 40+ character game title | clamps to two lines, band height unchanged | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/fonts/` -- delete `pixelify-sans-*` (4), `silkscreen-*` (2), `OFL-PixelifySans.txt`, `OFL-Silkscreen.txt`; add `space-mono-latin{,-ext}-{400,700}-normal.woff2` and `OFL-SpaceMono.txt` from the fontsource 5.3.0 tarball already unpacked at `/tmp/claude-0/-home-user-gameble/115b2f08-d056-569c-824a-568a5a17ae41/scratchpad/space-mono/package/` (`files/`, `LICENSE`, unicode ranges in `latin-400.css` and `latin-ext-400.css`).
- `app/frontend/styles/fonts.css` -- 8 @font-face blocks (L10-80): keep VT323 (L64-80), replace the rest by 4 Space Mono blocks (latin-ext first, then latin, same ranges as fontsource); rewrite the header comment.
- `app/frontend/styles/tokens.css` L63-133 -- families: drop `--font-family-pixelify` and `--font-family-silkscreen`, add `--font-family-space-mono: "Space Mono", monospace`; drop `--font-weight-semibold` (unused after). Re-value every `--font-*` / `--tracking-*` per Design Notes.
- Raw family uses to retarget: `booster.css` L512 (canister title), L1257 (plate tier banner), L1320 (tray count), L1475 (zoom title) → VT323 at the sizes in Design Notes; `friends.css` L31 (code, 2rem) and L78 (input) → VT323.
- Comments naming fonts, update wording only: `fonts.css` L1-8, `card-detail.css` L409, `shell.css` L717, `hub.css` L31 and L356, `app/components/toast_component.rb` L3, `app/components/button_component.rb` L2, `app/views/layouts/_head.html.erb` L30.
- `app/views/layouts/_head.html.erb` L31 -- preload list → `%w[space-mono-latin-400 space-mono-latin-700 vt323-latin-400]`.
- `app/frontend/styles/card.css` L48-120 -- the four sizes pick title/publisher/meta tokens; no change unless a band overflows (then adjust the token's line-height, never the boxes). `.card__title` L173, `.card__publisher` L186, `.card__line` L269.
- `test/integration/shell_test.rb` L31-44 -- preload names and count (3).
- `test/system/shell_test.rb` L4-6, L12 `FONTS`, L44, L62 (`/Space Mono/`) -- plus the two new assertions of the matrix (fonts set, sizes) as helpers used by the desktop test.
- `test/system/card_face_visual_test.rb` + `test/support/card_baselines.rb` -- regenerate `test/fixtures/files/card_faces/{tilted-s,tilted-m,tilted-l,tilted-xl,revealed-m,revealed-xl}.png` with `UPDATE_CARD_BASELINES=1`, then run again without it.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- frontmatter `typography:` L61-219 (family, weight, size, line height, spacing per style), section Typography L485-503, and font mentions at L588, 602, 612, 614-616, 642, 721, 745, 749, 771, 792-793, 799, 803, 812, 822-823. `EXPERIENCE.md` L371 and L482 (wording: "the pixel fonts" → the two fonts; three files preloaded stays true).
- Not touched: `config/initializers/content_security_policy.rb`, mockups, `packages/`, back-office markup.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/fonts/` -- swap the files and licences -- the two-font set, self-hosted.
- [ ] `app/frontend/styles/fonts.css` -- Space Mono faces, VT323 kept, comment -- one source of @font-face.
- [ ] `app/frontend/styles/tokens.css` -- families, weights, every text style re-valued -- every screen follows through the tokens.
- [ ] `app/frontend/styles/booster.css`, `friends.css` -- retarget the six raw family uses -- no reference to a removed family remains.
- [ ] `app/views/layouts/_head.html.erb`, comments listed in the Code Map -- preloads and wording.
- [ ] `test/integration/shell_test.rb`, `test/system/shell_test.rb` -- new font list, body family, the fonts-set and size-floor assertions.
- [ ] `test/fixtures/files/card_faces/*.png` -- regenerate, inspect `tmp/screenshots` for clipped titles, adjust card title/publisher line-heights if a band overflows.
- [ ] `DESIGN.md`, `EXPERIENCE.md` -- Typography frontmatter, section and mentions.

**Acceptance Criteria:**
- Given any page, when its CSS and head are read, then no rule, file or preload names Pixelify Sans or Silkscreen, and `grep -ri "pixelify\|silkscreen" app test config` is empty.
- Given the hub on desktop, when computed styles are collected, then every VT323 element is ≥ 20 px, every other text element is ≥ 10 px, and `document.fonts` lists only Space Mono and VT323.
- Given the six card face cases, when the visual test runs on the regenerated baselines, then it passes, and the revealed-xl screenshot shows a two-line title inside its band.
- Given DESIGN.md, when the Typography section is read, then it names two fonts with the jobs and sizes the tokens carry.

## Implementation Notes

- 2026-10-07: implemented on `develop` from `69577d6`. Space Mono 400/700 from the fontsource 5.3.0 tarball (latin, latin-ext, `OFL-SpaceMono.txt`); Pixelify Sans and Silkscreen removed with their licences, faces and preloads. Every token re-valued per Design Notes; `--font-weight-semibold` dropped (no remaining use). Six raw family uses retargeted to VT323 (booster canister title, plate banner, tray count, zoom title, friend code, friend input).
- Band fix: at m the title (2 × 14px) plus a publisher at `line-height: normal` (~13.95px) overflowed the 40px band, so `--font-publisher-m` carries an explicit 0.75rem line-height (28 + 12 = 40); no box changed. DESIGN.md frontmatter follows.
- Review patches: `.friends__input` → `font: var(--font-body)` (was VT323 at the UA control size); `.invite-link__line` → `font: var(--font-screen-title)` (was a 24px line inheriting the body family); a `tilted-xl-long` baseline on the preview's long-title specimen; DESIGN.md Achievement tile wording.
- Tests: `shell_test.rb` (system) asserts the font set is exactly Space Mono and VT323, every text on the hub sits at 10px or more and every VT323 text at 20px or more; the integration test asserts the three preloads. Seven card face baselines regenerated with `TOLERANCE` unchanged.
- Environment: the container had Ruby 3.3.6 and the project needs 4.0.7 (`.ruby-version`); Ruby 4.0.7 was built from the GitHub tag into `/opt/rbenv/versions/4.0.7`. Baselines were rendered by the container's Chromium 141 with chromedriver 141 (no sandbox). CI's Chrome may differ by hinting: if `card_face_visual_test` fails there beyond `TOLERANCE`, regenerate the baselines on CI's renderer, never raise the tolerance.
- Full verification after the patches: rubocop clean, typecheck clean, 175 JS tests, 1428 Rails tests and 117 system tests (serial) green. `test:system` with parallel workers flaked in this container on tests unrelated to fonts (library, booster, card detail timing); every one passed serially and alone.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass 1 (quick)

Verdicts: 1 high, 1 medium, 2 low, 0 false, 0 maybe-false.

| # | Finding | Verdict | Route | Evidence |
|---|---|---|---|---|
| 1 | `friends.css` `.friends__input`: VT323 with no size, so the UA control size (13.33px) draws VT323 under the 20px floor on both friends inputs | high | patch | Confirmed: the rule sets `font-family` only and no stylesheet resets input fonts; `card-detail.css` sets its field's font explicitly. Fix: `font: var(--font-body)` (DESIGN.md Text field). |
| 2 | Acceptance "the revealed-xl screenshot shows a two-line title" unmet: the fixture title is one line; no baseline shows a two-line xl title under the new 22px/20px token | low | patch | Confirmed: `revealed-xl.png` and `tilted-xl.png` show one-line titles; the two-line behaviour is asserted by `card_preview_test.rb` at every size but with no image. Fix: a `tilted-xl-long` baseline on the preview's `epic-xl` long-title specimen. |
| 3 | `friends.css` `.invite-link__line`: `font-size: 1.5rem` with the family inherited from body, now a 24px Space Mono sentence on the invite page, a large text outside the token pairs | medium | patch | Confirmed in `invite_links/show.html.erb` L10; before the change it inherited VT323. Fix: `font: var(--font-screen-title)` with its tracking. |
| 4 | DESIGN.md Achievement tile names "Space Mono bold", a weight the Typography section reserves for card titles and buttons | low | patch | Confirmed; no achievement token or CSS exists. Fix: "Space Mono". |

Routing: no intent_gap, no bad_plan; four patches sent to the implementer and applied: `.friends__input` → `font: var(--font-body)`; `.invite-link__line` → `font: var(--font-screen-title)` with its tracking; a `tilted-xl-long` baseline on the preview's `epic-xl` specimen (two VT323 lines, clamped, inside the band); DESIGN.md Achievement tile → "Space Mono". Full verification re-run after the patches (see Implementation Notes).

## Design Notes

Pixelify 700 reads about 1.3× smaller than VT323 at the same px, and VT323 20 px is the readable floor, so large styles grow; Space Mono is wide (0.61 em advance) and reads larger than Silkscreen at the same px, so small styles shrink or hold. Mockup option 3 gives: titles 26, logo 30, showcase name 32, card-xl title 22/1, menu 13/.05em, button 13 bold/.08em, kicker 11/.12em, label 10.5/.06em, chips 12, body 14/1.5, publisher and ticker 12.5.

Token values (weight size/line family, tracking):
- VT323 400: screen-title 1.625rem/normal (phone 1.5rem), normal; hero 2.75rem/2.75rem; public-title 3rem/3rem (phone 2.5rem/2.5rem); banner 3.375rem/3.5rem 2px, banner-small 2.25rem/2.5rem 2px; showcase-name 2rem (phone 1.75rem) normal; count-large 2.875rem/2.625rem (phone 2.5rem/2.25rem); number 1.5rem; card-title-xl 1.375rem/1.25rem. Raw: canister title 1.625rem/1.625rem, plate banner and tray count 1.375rem/1.5rem, zoom title 1.75rem/1.875rem, friend code 2.5rem, friend input inherit size.
- Space Mono 700: card-title-s 0.625rem/0.6875rem, -m 0.75rem/0.875rem, -l 0.875rem/1rem; button 0.8125rem 1px; button-sm 0.6875rem 1px.
- Space Mono 400: card-meta 0.625rem 0.5px, card-meta-xl 0.6875rem 0.5px; publisher-m 0.625rem, -l 0.6875rem, -xl 0.75rem; menu 0.8125rem 0.65px; kicker 0.6875rem 1.5px (phone 0.625rem 1.25px); label 0.6875rem 0.5px; decorative-small 0.5rem 0.5px; body 0.875rem/1.3125rem; body-large 1rem/1.5rem (phone 0.9375rem/1.4375rem); body-small 0.75rem/1.125rem.

Baselines are rendered by the container's Chromium; CI's Chrome may differ by hinting. If CI exceeds `TOLERANCE`, the baselines are to be regenerated on CI's renderer, not the tolerance raised.

## Verification

**Commands:** (in this container: `export PATH=/opt/rbenv/versions/4.0.7/bin:$PATH DB_PORT=5432 CHROME_BIN=/tmp/claude-0/-home-user-gameble/115b2f08-d056-569c-824a-568a5a17ae41/scratchpad/chromium-nosandbox.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/115b2f08-d056-569c-824a-568a5a17ae41/scratchpad/chromedriver141/chromedriver-linux64/chromedriver SE_OFFLINE=true`; Ruby 4.0.7 built from source, gems installed, the test database prepared, `npm ci` done)
- `grep -rni "pixelify\|silkscreen" app config test _bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- expected: no match.
- `bin/rubocop && npm run typecheck && npm run test:js` -- expected: clean.
- `bin/rails test test/integration/shell_test.rb` -- expected: pass.
- `UPDATE_CARD_BASELINES=1 bin/rails test test/system/card_face_visual_test.rb && bin/rails test test/system/card_face_visual_test.rb test/system/shell_test.rb` -- expected: pass twice.
- `bin/rails test:system` -- expected: pass (booster, collection, card detail layouts with the new widths).

**Manual checks (if no CLI):**
- `tmp/screenshots/*.png` from the system tests: no clipped title, no label wrapping in a chip, VT323 only on titles and numbers.
