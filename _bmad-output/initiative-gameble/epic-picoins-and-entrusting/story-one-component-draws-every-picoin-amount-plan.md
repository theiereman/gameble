---
title: 'One component draws every PiCoin amount'
type: 'feature'
ticket: '38.4'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '967d939c53af6f8f3095d9e0f4e45a154cd3cdbe'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Confier page prints amounts as plain text ("5,000 PiCoins") through a server helper with no client twin, no PiCoin mark and no accessible text, so every later market screen would invent its own way to draw a PiCoin.

**Approach:** Add the PiCoin mark to the pixel art sources at both sizes, one `PicoinAmountComponent` drawing an amount (compact or exact) with the mark and an exact-amount accessible name, a client `picoins` helper giving the same forms as the server `picoins` helper, both tested against one shared fixture, and move the Confier page and its result onto the component. Epic requirement R10.

## Boundaries & Constraints

**Always:** the compact form starts at 1,000, truncates to one decimal and never rounds up (1,099 reads "1k", 31,599 "31.5k", 999,999 "999.9k"); below 1,000 the compact form is the exact one; the exact form groups thousands; the locale gives the delimiter and the decimal separator (en `,` and `.`; fr U+00A0 and `,`), never a euro sign; zero reads "0"; the mark is `aria-hidden` and the amount's accessible name is the exact form plus "PiCoins" ("31 500 PiCoins" with U+00A0 in French), whatever form is visible; the mark comes only from `node script/pixel_art/export.mjs` (a source grid, never a hand-edited SVG) at 8 art pixels (16px) and 11 (22px); the server and client helpers are tested against the same fixture file; every string in `en.yml` and `fr.yml`; server HTML carries no `style` attribute.

**Never:** a raw `Intl.NumberFormat` or `toLocaleString` for an amount; a second amount component or a markup builder in script (later screens clone server-rendered templates holding the component); the Balance chip, the live recap or any new market screen (stories 5, 6, 8 and epic 39); signed or negative amounts (the charts' signed forms belong to epic 41); settings-driven words such as "PiCoins" held in a constant outside the locale files; hand-editing `app/frontend/images/pixel/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Zero | 0, either form, en and fr | "0" | No error expected |
| Under a thousand | 999, compact | "999", as exact | — |
| Threshold | 1,000 and 1,099, compact | "1k" both, never "1.1k" | — |
| Truncation | 31,599 / 7,299,999 / 999,999, compact, en | "31.5k" / "7.2M" / "999.9k" | — |
| French | 31,599 compact; 1,234,567 exact | "31,5k"; "1 234 567" with U+00A0 | — |
| Large | 1,200,000,000, compact, en and fr | "1,200M"; "1 200M" with U+00A0 | — |
| Accessible name | 31,500 compact, fr | visible "31,5k"; name "31 500 PiCoins" (U+00A0) | — |
| Not an integer | 1.5, "12" a string with letters, nil, a negative | helper raises | server `ArgumentError`, client `RangeError`; the component never renders a guess |
| Unknown client locale | locale "de" | falls back to the English forms | — |

</frozen-after-approval>

## Code Map

- `app/helpers/picoins_helper.rb`, `test/helpers/picoins_helper_test.rb` -- the existing server `picoins(amount, compact:)` (truncating, locale from `number.format`); keep as the one server formatter, add the integer and non-negative guard, test against the fixture.
- `app/frontend/lib/i18n.ts` (`formatNumber(value, delimiter)`) -- the client's digit grouping; reuse it, do not reimplement.
- `app/frontend/lib/local_time.ts` -- the only `Intl` use in the frontend (dates, allowed); the guard test must not trip on it.
- `script/pixel_art/export.mjs` (1,700+ lines, `ICONS`, `DESCRIPTIONS`, `files`, `iconSvg`) and `script/pixel_art/back_office_icons.mjs` -- the model for a new source module imported into the exporter; every file needs a `DESCRIPTIONS` line or the script refuses to run.
- `app/frontend/images/pixel/` -- export target, never edited by hand; `ShellHelper#pixel_icon(name, **attrs)` inlines an SVG with `aria-hidden` and the `pixel-icon` class.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` (`picoin-mark`, PiCoin mark paragraph) and the untracked option B mockup `/home/teyermann/projets/gameble/_bmad-output/initiative-gameble/ux-gameble/.working/picoin-mark.html` -- the round coin: `{colors.gold}` `#f4c542`, lit top-left edge `#ffe58f`, shaded bottom-right edge `#b5851a`, a π in `#120d05`; 8 art pixels small, 11 large.
- `app/components/season_mark_component.rb`, `gauge_component.rb`, `test/components/gauge_component_test.rb` -- ViewComponent conventions (keyword init, `**html_options`, class merge) and test style.
- `app/frontend/styles/tokens.css` (`--color-gold`, `--color-on-gold`), `app/frontend/entrypoints/application.css` (stylesheet imports), `app/frontend/styles/shell.css` (`.pixel-icon`).
- `app/views/market/entrustments/new.html.erb:36`, `create.html.erb:8,18,21` -- the four amount sites; `config/locales/en.yml` and `fr.yml` `market.entrustments.{new.value,create.minted,create.stayed.line,create.stayed.cap_left}` embed "PiCoins" in the sentence.
- `test/controllers/market/entrustments_controller_test.rb` (lines 35, 66, 97, 139, 168, 170, 171) and `test/system/market_entrust_test.rb` (36, 57-59) -- assert the old plain text; update to the component.
- `test/fixtures/files/` -- home of the shared fixture; `vitest.config.ts` includes `app/frontend/**/*.test.ts` in a node environment, so the client test reads the fixture with `node:fs`.

## Tasks & Acceptance

**Execution:**
- [ ] `test/fixtures/files/picoin_forms.json` -- create the shared fixture: a list of `{ "amount", "locale", "compact", "text" }` rows covering 0, 999, 1,000, 1,001, 1,099, 1,100, 31,599, 999,999, 1,000,000, 7,299,999, 1,200,000,000 (compact) and 0, 999, 1,000, 31,500, 1,234,567 (exact), each in en and fr, with U+00A0 written as ` ` -- one source of truth for both sides.
- [ ] `script/pixel_art/picoin_mark.mjs` -- create the source grids `PICOIN_MARKS` (`picoin-mark` 8 × 8 and `picoin-mark-large` 11 × 11, `look` text each); legend `h` `#ffe58f` (lit edge), `b` `#f4c542` (gold), `l` `#b5851a` (shaded edge), `p` `#120d05` (the π), `.` transparent; the grids are the mockup's option B "La pièce", copied exactly, row by row, no redrawing:
  `picoin-mark` (8 × 8): `..hhhh..` / `.hbbbbh.` / `hpppppph` / `hbpbpbbl` / `hbpbpbbl` / `hbpbppbl` / `.hbbbbl.` / `..hlll..`
  `picoin-mark-large` (11 × 11): `...hhhhh...` / `..hbbbbbh..` / `.hbbbbbbbh.` / `hbpppppppbh` / `hbbpbbpbbbl` / `hbbpbbpbbbl` / `hbbpbbpbbbl` / `hbbpbbppbbl` / `.hbbbbbbbl.` / `..hbbbbbl..` / `...hllll...`
  -- art source of the mark.
- [ ] `script/pixel_art/export.mjs` -- import `PICOIN_MARKS`, add each as `<name>.svg` through `iconSvg` and one `DESCRIPTIONS` line each (with its pixel size) -- exports the mark.
- [ ] `app/frontend/images/pixel/picoin-mark.svg`, `picoin-mark-large.svg` -- produced by running `node script/pixel_art/export.mjs`, never typed; then `--check` -- the exported files.
- [ ] `app/helpers/picoins_helper.rb` -- add an explicit guard before any formatting, never `Integer()` on the raw value (`Integer(nil)` raises `TypeError`, `Integer(1.5)` silently returns 1): accept an `Integer`, or a `String` matching `/\A\d+\z/` (converted with `Integer`); raise `ArgumentError` for anything else (a Float, nil, a String with other characters) before any `Integer()` call, and raise `ArgumentError` for a negative integer; keep the forms -- the guard of the contract.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- add `picoin_amount.accessible: "%{amount} PiCoins"` (same words in both) and reword the four Confier strings without "PiCoins", as `_html` keys taking the component: `new` drops `value`; `create.minted_html` ("%{amount} minted for you" / "%{amount} frappés pour vous"), `create.stayed.line_html` (singular and plural forms, French with `zero`, "(%{amount} each)"), `create.stayed.cap_left_html` -- the words now carried by the component.
- [ ] `app/components/picoin_amount_component.rb`, `picoin_amount_component.html.erb` -- create `PicoinAmountComponent.new(amount:, compact: false, size: :small, **html_options)`: a root `span.picoin-amount` (plus `--large`) with `role="img"` and `aria-label` from `picoin_amount.accessible` over the exact form, holding the mark (`pixel_icon("picoin-mark")` or `-large`, so `aria-hidden`) and `span.picoin-amount__figure` with the visible text from the server helper in the requested form; an unknown size raises -- the one amount component.
- [ ] `app/frontend/styles/picoin-amount.css`, `app/frontend/entrypoints/application.css` -- create and import: inline-flex, gap, figure in the JetBrains Mono face the Balance chip uses (`--font-mono` token or its existing equivalent), tabular numerals, `white-space: nowrap`, mark vertically aligned, the large size's figure larger -- looks of the amount, tokens only.
- [ ] `app/frontend/lib/picoins.ts` -- create `picoins(amount, { locale, compact })` over `formatNumber`: locale table `en` and `fr` (delimiter, separator), unknown locale reads as en, `RangeError` for a non-integer or negative amount, same truncation as the server -- the client form.
- [ ] `app/views/market/entrustments/new.html.erb`, `create.html.erb` -- draw the cell value, the total minted, each stayed line and the cap left with `PicoinAmountComponent` (exact form) inside the `_html` keys -- the Confier page and result on the component.
- [ ] `app/frontend/styles/market-entrust.css` -- keep `.market-entrust__value` and `__total` gold colour and sizing, drop what the component now owns -- no duplicated styling.
- [ ] `test/helpers/picoins_helper_test.rb` -- replace the hand-written cases by a loop over the fixture (compact and exact, both locales via `I18n.with_locale`), keep a refusal case asserting `ArgumentError` for 1.5, "12x", nil and -1 -- server side of the fixture.
- [ ] `app/frontend/lib/picoins.test.ts` -- loop over the same fixture read with `node:fs`, the refusals, the unknown-locale fallback, and a guard test refusing `Intl.NumberFormat` or `toLocaleString(` in any non-test file under `app/frontend` -- client side and the no-raw-Intl rule.
- [ ] `test/components/picoin_amount_component_test.rb` -- over the fixture, the visible figure of each compact and exact row equals the fixture text; `role=img` with `aria-label` "31,500 PiCoins" (en) and "31 500 PiCoins" with U+00A0 (fr) for a compact 31,500; the mark is `svg[aria-hidden=true]`; `size: :large` swaps the mark and adds the modifier; no `style` attribute; an unknown size raises -- the component contract.
- [ ] `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb` -- assert the amount through `.picoin-amount[aria-label="5,000 PiCoins"]` and the visible figure "5,000" in place of "5,000 PiCoins", all seven and three sites -- the Confier system tests still pass.

**Acceptance Criteria:**
- Given the fixture file, when the server helper test and the client vitest run, then both pass over the same rows, so the two forms cannot drift.
- Given 31,500 drawn compact in French, when the component renders, then the page shows "31,5k" and the amount's accessible name is "31 500 PiCoins" with U+00A0, the mark hidden from assistive technology.
- Given the Confier page with free copies and the result of a batch, when either renders, then every amount on it is a `.picoin-amount` and no amount is plain text.
- Given any non-test file under `app/frontend`, when the guard test scans it, then none formats a number with `Intl.NumberFormat` or `toLocaleString`.
- Given the pixel art sources, when `node script/pixel_art/export.mjs --check` runs, then it passes with the two mark files present and unedited.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The component is the only place that pairs the mark with a figure. The accessible name sits on the root as `role="img"` so a screen reader says "31 500 PiCoins" once whether the figure is compact or exact, and tests read the figure as ordinary visible text. Later screens put the component in a server-rendered `<template>`; script that updates a figure sets the text of `.picoin-amount__figure` and the root's `aria-label` with the client `picoins` helper (a template string with `%{amount} PiCoins` comes from the same `picoin_amount.accessible` key). Golden fixture rows:

```json
{ "amount": 31599, "locale": "fr", "compact": true, "text": "31,5k" }
{ "amount": 1200000000, "locale": "fr", "compact": true, "text": "1 200M" }
{ "amount": 1234567, "locale": "en", "compact": false, "text": "1,234,567" }
```

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: exit 0
- `bundle exec rubocop app/components/picoin_amount_component.rb app/helpers/picoins_helper.rb` -- expected: no offense
- `/home/teyermann/projets/gameble/node_modules/.bin/prettier --check app/frontend/lib/picoins.ts app/frontend/lib/picoins.test.ts` -- expected: clean
- `bundle exec packwerk check`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
- `bin/rails test test/helpers/picoins_helper_test.rb test/components/picoin_amount_component_test.rb test/controllers/market/entrustments_controller_test.rb` and `npm run test:js -- picoins` and `bin/rails test test/system/market_entrust_test.rb` -- run once at the end of the market run

**Manual checks (if no CLI):**
- Open the Confier page in both languages: each value shows the coin before the figure, and a screen reader (or the accessibility tree) names it "<exact> PiCoins".
