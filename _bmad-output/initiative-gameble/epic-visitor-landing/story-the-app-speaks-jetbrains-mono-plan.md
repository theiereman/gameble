---
title: 'The app speaks JetBrains Mono'
type: 'feature'
ticket: '1'
created: '2026-10-19'
status: done
baseline_revision: '47dfa417570a430382b24a089feea3cf59e660ba'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app and the static error pages set every small text in Space Mono, at the weights and with the VT323 figures DESIGN.md had before 2026-10-13; DESIGN.md (Typography) now names JetBrains Mono 400 and 700, bold for every style at 12px and below, and every figure in JetBrains Mono bold. The landing cannot ship until the app uses JetBrains Mono.

**Approach:** Swap the self-hosted Space Mono woff2 subsets and licence for JetBrains Mono's (fontsource 5.3.0, latin and latin-ext, 400 and 700), then bring `tokens.css` level with DESIGN.md's typography for the app's existing styles: the bold small styles, and the figure tokens (`number`, `count-large`, a new `clock`) in JetBrains Mono bold at 0.75 of their VT323 size, with the figures set straight in VT323 moved onto them.

## Boundaries & Constraints

**Always:** VT323 keeps the titles, the friend code and every text DESIGN.md gives it; the large counts keep their line heights; fonts stay self-hosted, `font-display: block`, the three latin files preloaded; error page assets go through `script/error_pages/build.mjs`.

**Never:** No landing tokens (`landing-*`, they come with the landing stories); no size or layout change beyond the figure resizes; no Google Fonts or CDN; no hand-edit of `public/errors/` or of the pixel art.

**Decision (author, 2026-10-19):** the ticket covers all of DESIGN.md's JetBrains Mono rules, not the family swap alone: bold at 12px and below, and figures out of VT323.

</frozen-after-approval>

## Code Map

- `app/frontend/fonts/` -- `space-mono-latin{,-ext}-{400,700}-normal.woff2` and `OFL-SpaceMono.txt` to replace with `jetbrains-mono-*` and `OFL-JetBrainsMono.txt`; the VT323 files stay
- `app/frontend/styles/fonts.css` -- four Space Mono `@font-face` blocks and the header comment; keep fontsource's unicode ranges
- `app/frontend/styles/tokens.css:72-142` -- `--font-family-space-mono`, the VT323 figure tokens (`count-large`, `count-large-phone`, `number`) and the small-text tokens
- `app/views/layouts/_head.html.erb:34-37` -- the latin preloads
- `public/errors.css` -- two Space Mono `@font-face` and three `font:` lines; `.error__code` (the status, 120px VT323) stays
- `script/error_pages/build.mjs:18-26` -- `SOURCES` copies fonts and licences into `public/errors/` and stamps URLs
- Figures set in VT323 outside tokens: `booster-layouts.css` `.booster-tray__count-value`; clock on `--font-screen-title`: `hub.css` `.daily-booster__clock`
- `--font-number` used as a 24px title, not a figure: `shell.css` `h2`, `card-detail.css` `.public-card__pitch-title`
- `--font-number` / `--font-count-large` used for figures (follow the token, no edit): `achievements.css`, `collection.css` `.set-album__count`, `settings.css` `.how-it-works__percent`, `shell.css` `.packs-chip__count`, `.rarity-legend__count`, `trades.css` `.trade-add__plus`
- VT323 titles that stay: booster plate tier, zoom title, canister title, celebration ribbon, COMPLET stamp, `.friends__code`
- `booster.css:1458` -- uses `--font-family-space-mono` directly
- Tests: `test/integration/shell_test.rb:33-38` (preloads), `test/integration/error_pages_test.rb:12-20` (copies), `test/system/shell_test.rb` (font names; system tests are disabled, update the text only)
- Docs and comments: `README.md:275`, `app/components/button_component.rb:2`, `toast_component.rb:3`, `card-detail.css:431`, `shell.css:976`

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/fonts/` -- download `@fontsource/jetbrains-mono@5.3.0` latin and latin-ext 400/700 woff2 and its OFL licence, delete the Space Mono files -- the new self-hosted family
- [x] `app/frontend/styles/fonts.css` -- four `JetBrains Mono` `@font-face` blocks with fontsource's unicode ranges; update the comment
- [x] `app/frontend/styles/tokens.css` -- `--font-family-jetbrains-mono`; 700 for `card-meta`, `card-meta-xl`, `publisher-m/l/xl`, `kicker`, `kicker-phone`, `label`, `body-small`; `number` 700 1.125rem, `count-large` 700 2.15625rem/2.625rem, `count-large-phone` 700 1.875rem/2.25rem, new `clock` 700 1.21875rem with its tracking, all on JetBrains Mono; regroup the comments by font
- [x] `app/frontend/styles/booster.css`, `booster-layouts.css`, `hub.css`, `shell.css`, `card-detail.css` -- rename the family var; tray count on `--font-number`-style JetBrains Mono bold 1.03125rem/1.5rem; daily clock on `--font-clock`; `h2` and pitch title on `--font-screen-title-phone`; fix the Space Mono comments
- [x] `app/views/layouts/_head.html.erb` -- preload `jetbrains-mono-latin-400`, `-700`, `vt323-latin-400`
- [x] `script/error_pages/build.mjs`, `public/errors.css` -- swap sources and family, then run the build to regenerate `public/errors/` and the stamps
- [x] tests, `README.md`, component comments -- rename

**Acceptance Criteria:**
- Given the repository outside planning folders, when searched for "space mono" or "spacemono", then nothing matches
- Given any page, when it loads, then `document.fonts` holds JetBrains Mono and VT323 only and the three latin files are preloaded
- Given a count, odds, quantity or clock, when shown, then it renders in JetBrains Mono bold; titles and the friend code stay VT323
- Given an error page, when it loads, then its text is JetBrains Mono from `public/errors/` with `OFL-JetBrainsMono.txt` beside it, and `build.mjs --check` passes

## Design Notes

- `h2` and the public card's pitch title used `--font-number` as a 24px VT323 title; they move to `--font-screen-title-phone`, the DESIGN.md token with that exact value, so they look unchanged.
- The error page's large status code stays VT323: a page title, not a count.
- The card face baselines (`test/fixtures/files/card_faces/`) go stale; they belong to the disabled system tests and are regenerated when those are rebuilt.

## Implementation Notes

- The fontsource 5.3.0 latin and latin-ext unicode ranges are identical to Space Mono's, so only the family and file names changed in `fonts.css`.
- The tray count is 22px VT323 times 0.75: 16.5px (1.03125rem) on its 1.5rem line.
- `build.mjs` restamped `errors.css` in the ten error pages and removed the two Space Mono copies and their licence from `public/errors/`.

## Verification

**Commands:**
- `git grep -niI -e "space.\?mono" -e spacemono -- . ':(exclude)_bmad/**' ':(exclude)_bmad-output/**' ':(exclude).agents/**' ':(exclude).claude/**'` -- expected: no match
- `node script/error_pages/build.mjs --check` -- expected: exit 0
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` -- expected: pass

**Manual checks:**
- Hub, booster, collection set album, achievements, error page in a browser: small text in JetBrains Mono, figures bold.

## Review Triage Log

Pass 1 (quick): high 0, medium 2, low 1, false 0, maybe-false 0, pre-existing deferred 1.

- medium, patch: `settings.css` `.how-it-works__odds tbody td { font-weight: normal }` (0,1,2) overrode the bold `--font-number` of the odds cells; `font-weight: normal` kept on `tbody th` only.
- medium, defer: `.hub-goal__figures` is a count on `--font-body`, regular before and after; not caused by this change, logged in deferred-work.md.
- low, patch: `.trade-add__plus`, a decorative "+", followed `--font-count-large` and shrank to 34.5px bold; set back to VT323 46px explicitly.
- medium, patch: the rewritten `fonts.css` header still named planning documents, which AGENTS.md forbids in code; reworded.
