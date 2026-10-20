---
title: 'The card detail back on its own page, and the grids aligned with the screen around them'
type: 'bugfix'
ticket: '25'
created: '2026-10-19'
status: done
baseline_revision: 'df8eca55ef6eb1e24c377ae1645c4ebdee8f2514'
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

**Problem:** On the author's review of entries 14 and 24, the detail column beside "Toutes les cartes" (`/library/cards`) is dropped. The author wants a card to open its full detail page at every width, and the cards of Toutes les cartes and of a set album to line up with every element of the screen around them. Today the grid's last card stops short of the search, FILTRES zone and top bar (spare width after the last card, the 185px cap), the phone's two 160px cards sit inset from the page edges, and from 720 to 1179px the top bar's contents stand 4px inside the page's (32px against 28px).

**Approach:**
- Remove what entries 14 and 24 added for the detail beside the grid. Keep only the step machinery extracted to `lib/sub_view_step.ts`, which ◀ ▶ still use, trimmed to ◀ ▶.
- The grid page goes back to the grid alone in its `collection-results` frame. A slot is a plain link to the card's detail page, and browser Back returns to the grid at its scroll (Turbo restore, `history_back_controller.ts`).
- On both fill grids (Toutes les cartes and the album), each card is as wide as its column, rounded down to an even pixel, and centred in its column, so the first and last cards meet the grid's edges within 1px. The 185px cap goes. On the phone, the two columns fill the page width.
- Under 1180px, the top bar's inline padding equals the page's (28px).

## Boundaries & Constraints

**Always:**
- Remove entirely:
  - `app/frontend/controllers/collection_detail_controller.ts`, `app/frontend/lib/collection_detail.ts` and its test.
  - `app/views/cards/_detail_waiting.html.erb`.
  - The `card_details.waiting.*` keys in en and fr.
  - The `frame?` option of `visit` in `lib/turbo.ts`.
  - The waiting styles in `card-detail.css`. Its phone `html:has(...)` selector goes back to `html:has(.card-detail__actions)`.
  - The whole detail-beside section of `collection.css`: `.collection-results` grid, `.collection-results__grid`, `.collection-detail`, the 304px container query and the `aria-current` slot frame.
  - Their tests and comments.
- `lib/sub_view_step.ts` stays for ◀ ▶. The "open" direction and the "heading" focus wish go, and its header names only ◀ ▶. `sub_view_controller.ts` loses the heading-wish branch and the comment lines about the grid. The `shell.css` comment on `html[data-sub-view-step] .main` names only ◀ ▶ again.
- Fill-grid rule, both grids:
  - Columns stay `repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr))` with the fixed gaps.
  - The slot is `width: round(down, 100%, 2px)` (no cap) with `justify-self: center`. This one rule replaces `.set-album__grid > .collection-slot`.
  - `--space-grid-card-max` is deleted.
  - Phone (`max-width: 719px`): `grid-template-columns: repeat(2, minmax(0, 1fr))`, without `justify-content: center`. The 8px gap under 372px stays.
- Top bar: a `--space-gutter-medium: 28px` token. `--space-page-padding-medium` reads `24px var(--space-gutter-medium) 32px`. `.top-bar__inner` takes `padding-inline: var(--space-gutter-medium)` under 1180px. The phone rule keeps its own gutter.
- DESIGN.md and EXPERIENCE.md:
  - Drop the beside-the-grid detail: the Collection row of the per-screen table, the Card detail paragraph's waiting part, the "Card detail waiting" copy-deck row, the Card detail behaviour sentence, and "Desktop: the card detail is a right-hand panel".
  - Record that a grid card opens its detail page at every width, with Back back to the grid at its scroll.
  - Record the alignment rule: the grid's first and last cards line up with the elements above it within 1px, with no cap and two filling columns on the phone. Update the grid examples and the tokens.
  - Add one `.memlog.md` decision line (author, 2026-10-19).
- No `style` attribute, no planning ids, no explanatory comments beyond file headers. Update the headers of `_collection.html.erb`, `collection.css` and `sub_view_step.ts`. Every string in both locales.

**Never:**
- No change to `cards#show`, `cards/_detail*`, routes, queries, `history_back_controller.ts`, the phone sub-view's behaviour, or the album header.
- Do not edit `pending-approvals.md`. Its 13.14 entry is the author's to settle.
- No JS layout measuring. The alignment is CSS only.

## I/O & Edge-Case Matrix

The grid widths are content widths, measured without a scrollbar. "Classic" means beside a 15px scrollbar. Gap 16px, or 8px under 372px.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cards 1440/1280 | grid 1216−220−32 = 964 | 6 × 146 (classic 949: 6 × 144) | — |
| Cards 1024 | grid 968 (classic 953) | 6 × 148 (6 × 144) | — |
| Cards 800 | grid 744 (classic 729) | 4 × 174 (4 × 170) | — |
| Album 1440/1280 | grid 1216 (classic 1201) | 7 × 160 (7 × 156) | — |
| Phone 390 | grid 350 (classic 335) | 2 × 166 (2 × 158) | — |
| Phone 360 | grid 320, gap 8 | 2 × 156 | — |
| Any fill row | — | spare per column < 2px, so each centred card is under 1px from its column's edges | — |
| Desktop sweep | grid widths 649–1216 | every card ≥ 140 (medium face) | — |
| Cards page markup | GET `/en/library/cards` | no `turbo-frame#card-detail`, no `collection-detail` controller, no `[aria-current]` slot link; slots are plain `a.card-link` to the card's page | — |

</intent-contract>

## Code Map

- `app/views/library/_collection.html.erb`:
  - Restore the pre-entry-14 shape: `<div class="collection">` without controller or action.
  - `turbo_frame_tag "collection-results", target: "_top", data: { turbo_action: "replace" }` holds the status `p`, `library/grid` and the collection-seen div directly. No `.collection-results__grid` wrapper, no `card-detail` frame.
  - Header comment: from 1180px the RAPPORT in a 220px column beside the grid; from 720px the grid alone; on the phone one column, RAPPORT folded, two cards a row. A slot opens its card's detail page.
- `app/frontend/styles/collection.css`:
  - Delete l.732–823, the detail-beside section, both media blocks included.
  - Fill slot rule (l.615): `width: round(down, 100%, 2px);` and `justify-self: center;`.
  - Delete `.set-album__grid > .collection-slot` (l.917).
  - Phone `.collection-grid` (l.1005): `grid-template-columns: repeat(2, minmax(0, 1fr));`, and drop `justify-content`.
  - Fix the stale 371px comment: the two cards now share the width, so the gap tightens to 8px on narrow phones.
  - Rewrite the file header.
- `app/frontend/styles/card-detail.css` -- delete the header paragraph about waiting (l.20–22), `.card-detail__empty-face`, `.card-detail--waiting …` rules, and revert the `html:has(...)` selector at about l.541.
- `app/frontend/styles/tokens.css` -- delete `--space-grid-card-max`. Add `--space-gutter-medium: 28px` beside the other gutters. Set `--space-page-padding-medium: 24px var(--space-gutter-medium) 32px`.
- `app/frontend/styles/shell.css`:
  - In the `@media (max-width: 1179px)` block (l.1274), add `.top-bar__inner { padding-inline: var(--space-gutter-medium); }`. The phone block later overrides it.
  - Revert the comment at l.1227 to ◀ ▶ only, as in `64970ee^`.
- `app/frontend/lib/sub_view_step.ts`:
  - `StepDirection = "previous" | "next"` and `FocusWish = "previous" | "next" | null`.
  - Keep `PHONE_WIDTH`, `beginStep`, `stepping`, `takeFocusWish` and `trackStepTransition`.
  - The header describes ◀ ▶ only.
- `app/frontend/controllers/sub_view_controller.ts`:
  - `connect`: `const wish = takeFocusWish(); if (wish) this.focusControl(wish) else if (…phone heading…)`.
  - Drop the header's grid lines (l.26–29).
- `app/frontend/lib/turbo.ts` -- `visit` options back to `{ action?: "advance" | "replace" }`.
- Delete:
  - `app/frontend/controllers/collection_detail_controller.ts`
  - `app/frontend/lib/collection_detail.ts` and `collection_detail.test.ts`
  - `app/views/cards/_detail_waiting.html.erb`
- `config/locales/en.yml`, `fr.yml` -- delete `card_details.waiting` (title, value).
- `app/frontend/lib/collection-grid.test.ts`:
  - Delete the "card detail beside the grid" describe, plus `detailColumn`, `WIDE_GRID`, `MEDIUM_GRID` and `MEDIUM`/`WIDE` if unused. Drop the `cardDetailStylesheet` import if unused.
  - `fill(gridWidth, gap = GAP)` returns `{ columns, card, spare }` with no cap. The card is `evenFloor((W − (n−1)gap)/n)`.
  - Add the matrix rows as `it.each`, each asserting `spare < 2`.
  - Assert the slot rule (`round(down, 100%, 2px)`, `justify-self: center`), that no `--space-grid-card-max` token remains, and that `.set-album__grid > .collection-slot` is gone.
  - Phone `repeat(2, minmax(0, 1fr))`. Read the 8px from the 371px rule.
  - Sweep the desktop widths 649–1216 for the medium face.
  - Top bar: the `--space-gutter-medium` token is used by both `--space-page-padding-medium` and `.top-bar__inner` in shell.css's 1179px block. Import `shell.css?raw` (add to `vitest.config.ts` `css.include` if raw imports need it).
  - `pageGutter` must read the new token form.
- `test/controllers/library_controller_test.rb`:
  - Delete `assert_waiting_detail` and the two waiting tests.
  - Add one test: the cards page (signed in, en) has no `turbo-frame#card-detail`, no `[data-controller~=collection-detail]` and no `a.card-link[aria-current]`, and its slot links point at `/en/cards/…`.
  - Restore the ids list (without `card-detail`) and the status selector `turbo-frame#collection-results > p[role=status]`.
- System tests: grep `collection-detail`, `card-detail--waiting`, `Choose a card`. Update selectors only, never run.
- Docs (`_bmad-output/initiative-gameble/ux-gameble/`):
  - `DESIGN.md`:
    - Tokens: drop `grid-card-max` (l.306) and add `gutter-medium`.
    - Per-screen Collection row (l.609): no detail column; a card opens its detail page at every width.
    - Collection grid paragraph (l.623): new rule and examples from the matrix.
    - Card sizes row "Grid card" (l.634): "140 wide or more, as wide as its column".
    - Card detail paragraph (l.924): drop the waiting part.
    - Set album paragraph (l.917): the phone gets two filling columns, not `card-m`.
  - `EXPERIENCE.md`:
    - Delete the copy-deck row (l.103).
    - Card detail row (l.234): replace the beside sentence with "a card of a grid opens its detail page at every width; browser Back and ◀ GRILLE return to the grid at its scroll (author, 2026-10-19)".
    - l.537: "the card detail is its own page".
  - `.memlog.md`: one `(decision)` line.

## Tasks & Acceptance

**Execution:**
- [x] `_collection.html.erb`, locales, deleted files, `turbo.ts`, `sub_view_step.ts`, `sub_view_controller.ts`, `card-detail.css`, `shell.css` comment -- remove the detail beside the grid.
- [x] `collection.css`, `tokens.css`, `shell.css` -- the fill rule (centred, no cap, phone filling) and the top bar's medium gutter.
- [x] `collection-grid.test.ts`, `library_controller_test.rb`, system selectors -- the matrix and the markup.
- [x] DESIGN.md, EXPERIENCE.md, `.memlog.md`.

**Acceptance Criteria:**
- Given `/en/library/cards` at 1280px, when a slot is clicked, then the card's detail page opens (full page, URL the card's), and browser Back shows the grid at the same scroll.
- Given Toutes les cartes or a set album at 1440, 1280, 1024, 800 and 390px in headless Chrome, when measured, then the first row's left and right card edges sit within 1px of the search field and FILTRES zone (cards) or the album header panel (album), and of the top bar's outer items.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass. `unused` may list only the pre-existing keys.

## Implementation Notes

- **Removal:** `_collection.html.erb` is the `64970ee^` shape, its header adding "A slot opens its card's detail page." `card-detail.css` is byte-identical to `740d75b^`. `collection_detail_controller.ts`, `lib/collection_detail.ts` and its test, and `cards/_detail_waiting.html.erb` are deleted; `card_details.waiting` is gone from both locales; `visit` lost `frame?`. `sub_view_step.ts` keeps its machinery with `StepDirection`/`FocusWish` trimmed to ◀ ▶ and a ◀ ▶-only header; `sub_view_controller.ts` lost the heading-wish branch and the grid lines of its header; the `shell.css` step comment is the `64970ee^` text.
- **Fill rule:** the `.collection-grid--fill > .collection-slot` rule now reads `width: round(down, 100%, 2px); justify-self: center;`, the album's own `justify-self` rule is gone, `--space-grid-card-max` is deleted, and the phone grid is `repeat(2, minmax(0, 1fr))` without `justify-content`. The whole detail-beside section of `collection.css` is deleted; the 371px comment now says the two cards share the page's width.
- **Top bar:** `--space-gutter-medium: 28px`, `--space-page-padding-medium: 24px var(--space-gutter-medium) 32px`, and `.top-bar__inner { padding-inline: var(--space-gutter-medium); }` in shell.css's 1179px block (the phone block, later in the file, still sets its own padding).
- **Tests:** `collection-grid.test.ts` rebuilt around `fill(gridWidth, gap)` returning `{ columns, card, spare }` (a shared `share()` helper also serves the phone's fixed two columns), the matrix rows as `it.each` with `spare < 2`, the 649–1216 sweep, the slot, phone and album rule assertions, and a top-bar test importing `shell.css?raw` (already in `vitest.config.ts`'s `css.include`). `pageGutter` reads either a px value or a `var(--token)`. `library_controller_test.rb`: the waiting helper and its two tests are replaced by one test of the plain grid (no `card-detail` frame, no `collection-detail` controller, no `aria-current` slot, every slot link under `/en/cards/`); the ids list and the status selector are restored. No system test referenced the removed markup or copy.
- **Docs decision:** DESIGN.md now carries the code's values for the medium gutter: `gutter-medium: 28px` and `page-padding-medium: 24px 28px 32px`, so "the inline part of `page-padding-medium`" holds and the grid examples (148px at 1024) follow from it; the doc's other spacing tokens, one breathing-room step under the code's, are left as they were. The Collection grid paragraph says the medium face holds on tablet, desktop and phones from 328px wide, and narrower phones take the small face. The Gutters bullet now names all three gutters. The `card-m` card-size row no longer lists "phone collection", since the phone grid now fills its two columns.
- **Verification:** `RAILS_ENV=test bin/rails test` (2782 runs, green), `bin/ci` green, `npm run test:js` (434 green), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` and `i18n-tasks missing` green; `i18n-tasks unused` lists only the 16 pre-existing keys (date, rate_limit, time.formats). `package-lock.json`'s stray `name` change was reverted.
- **Not done:** the headless-Chrome acceptance pass on the real pages (scratch system test) was not run, since this session was told not to run system tests. In its place, a static page in headless Chrome reproducing the slot rule (bleed, negative margin, `round(down, 100%, 2px)`, `justify-self: center`) measured the first row at grid widths 964, 949, 968, 953, 744, 729, 1216, 1201, 350, 335 and 320 (gap 8): cards of 146, 144, 148, 144, 174, 170, 160, 156, 166, 158 and 156px, every first and last card at most 0.94px from the grid's edges. The click-to-page and Back-to-scroll behaviour, and the top bar against the page at 1024 and 800, still want a check on the real app.
- **Done afterwards by the caller:** the real-app checks listed under "Not done" were run in headless Chrome: the click to the page, Back to the scroll, and the top bar and the grids at 1440, 1280, 1024, 800 and 390 px. The results are in the Auto Run Result.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 3, false 2, maybe-false 0
- findings:
  - `[low]` `[patch]` `package-lock.json` still carried the worktree's name as the root `name` (npm install, then `npm run test:js`, rewrote it). — Reverted with `git checkout package-lock.json`; the commit leaves it untouched.
  - `[false]` `[reject]` The first AC (a slot opens the card's page, and Back restores the grid at its scroll) is unverified. — The caller checked it in headless Chrome on the real app with a scratch system test, deleted afterwards. At 1440, 1280, 1024, 800 and 390 px, a slot opens `/en/cards/…` as a full page with no grid on it, and Back returns to `/en/library/cards` with scrollY 1200 before and after (Auto Run Result).
  - `[false]` `[reject]` The second AC (edges measured on the real pages, the top bar included) is unverified. — The caller measured the real pages, Toutes les cartes and the album, at the five widths; every first-row edge is within 0.94 px of the search, the FILTRES zone, the album header and the top bar's items (Auto Run Result).
  - `[low]` `[patch]` DESIGN.md said a card always takes the medium face, which is false on phones under 328 px, where the two columns fall under 140 px. — The sentence now gives the medium face on tablet, desktop and phones from 328 px, and the small face below.
  - `[low]` `[patch]` DESIGN.md's new `gutter-medium: 24px` contradicted the code's 28 px and the paragraph's own examples. — The doc now has `gutter-medium: 28px` and `page-padding-medium: 24px 28px 32px`. The other doc spacing tokens predate this change and are left alone.

## Design Notes

- **Centred rather than flush to the pixel:** cards stay an even pixel count for the 2px art pixel, so a column keeps up to 2px spare. Centring splits it, leaving each outer edge under 1px from the grid's edge, the tolerance the album already met (entry 19). Exact flush would need the column count in CSS (typed division) or script.
- **No cap:** beside the RAPPORT alone, a desktop or tablet grid always has 4 or more columns, so a column stays under about 180px and 185px never binds. On the phone the cap would leave 430–480px phones inset, so it goes.
- **Top bar:** the bar used the 32px desktop gutter under 1180px while the page used 28px. A shared token aligns them on every screen.

## Verification

**Commands:**
- With `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1325`:
  - `RAILS_ENV=test bin/rails test` -- expected: green
  - `bin/ci` -- expected: green
- `npm run test:js` -- expected: green
- `npm run typecheck` -- expected: green
- `bin/rails zeitwerk:check` -- expected: green
- `bundle exec packwerk check` -- expected: green
- `bundle exec i18n-tasks missing` and `unused` -- expected: green
- Revert any stray `package-lock.json` change.

**Manual checks (if no CLI):**
- Headless Chrome (scratch system test, not committed) at 1440, 1280, 1024, 800 and 390px, on Toutes les cartes (state all) and an album:
  - the left and right edges of the first row's cards against the top bar's items, the search field, the FILTRES zone and the album header;
  - a slot click opening the page, and Back restoring the scroll.

## Auto Run Result

**Summary:**
- The detail column beside Toutes les cartes is gone, with its waiting detail, frame loading, history handling, styles, strings and tests.
- At every width a grid card opens its detail page, and Back returns to the grid at its scroll.
- Both fill grids (Toutes les cartes and the set album) now size each card to its column, rounded down to an even pixel and centred in it, with no 185 px cap. On the phone, two columns share the page's width.
- Under 1180 px the top bar takes the page's 28 px gutter. The first and last cards of a row therefore line up within 1 px with the search, the FILTRES zone, the album header, the RAPPORT's column and the top bar.

**Files:**
- `app/views/library/_collection.html.erb`: the grid alone in `collection-results`.
- Deleted:
  - `collection_detail_controller.ts`
  - `lib/collection_detail.ts` and its test
  - `cards/_detail_waiting.html.erb`
- `lib/sub_view_step.ts`, `sub_view_controller.ts`: kept for ◀ ▶, trimmed of "open" and the heading wish.
- `lib/turbo.ts`: no `frame` option.
- `card-detail.css`: as before entry 24.
- `collection.css`:
  - the detail section removed;
  - the fill slot centred and uncapped;
  - the phone's two columns now fill the width.
- `tokens.css`: `--space-grid-card-max` removed, `--space-gutter-medium` added.
- `shell.css`: the top bar's medium gutter, and the step comment restored.
- `config/locales/{en,fr}.yml`: `card_details.waiting` removed.
- `collection-grid.test.ts`, `library_controller_test.rb`: the new matrix and markup tests.
- DESIGN.md, EXPERIENCE.md, `.memlog.md`.

**Review:**
- 3 low findings patched: the lockfile, and two DESIGN.md sentences or tokens.
- 0 deferred.
- 2 rejected as false: both ACs were verified on the real app in headless Chrome.
- Follow-up review recommended: false (patched: high 0, medium 0, low 3).

**Verification:**
- `bin/ci` green, with DATABASE_URL `gameble_test_w1325`: 2782 runs, 0 failures.
- `npm run test:js`: 434 passed.
- `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` and `i18n-tasks missing` are clean. `i18n-tasks unused` lists only pre-existing keys (date, rate_limit, time.formats).
- Headless Chrome, scratch system test (not committed, run once), with a classic 15 px scrollbar. Each value is the first row's [left, right] edges against the elements above it:

| Width | Toutes les cartes: cards | Search/FILTRES (top bar items) | Album: cards | Album header (top bar items) |
|---|---|---|---|---|
| 1440 | 6 × 146, [357.16, 1319.81] | [356.5, 1320.5], top bar right 1320.5 | 7 × 160, [104.5, 1320.5] | [104.5, 1320.5] ([104.5, 1320.5]) |
| 1280 | 6 × 144, [284.41, 1232.56] | [284, 1233], top bar right 1233 | 7 × 156, [32.92, 1232.06] | [32, 1233] ([32, 1233]) |
| 1024 | 6 × 144, [28.75, 980.25] | [28, 981] ([28, 981]; was [32, 977]) | 6 × 144, [28.75, 980.25] | [28, 981] |
| 800 | 4 × 170, [28.13, 756.88] | [28, 757] ([28, 757]; was [32, 753]) | 4 × 170, [28.13, 756.88] | [28, 757] |
| 390 | 2 × 158, [20.75, 354.25] | [20, 355] ([20, 355]) | 2 × 158, [20.75, 354.25] | [20, 355] |

- From 1180 px, the RAPPORT's left edge (104.5 at 1440, 32 at 1280) matches the top bar's left item. Largest offset: 0.94 px.
- Back, at all five widths: a slot click opens `/en/cards/…` as a full page with one `card-detail` frame and no grid. Back returns to `/en/library/cards` with scrollY 1200 before and after.

**Residual risks:**
- On phones with overlay scrollbars the cards are 2 × 166 at 390 px (computed, not measured). Phones under 328 px wide get the small face.
- The 185 px cap is gone. It no longer binds anywhere on desktop or tablet, but the author chose it.
- DESIGN.md's other spacing tokens still sit one step under the code's (pre-existing).
- After Back, no element was focused in headless Chrome (the history-back controller's return focus). This was not compared with the behaviour before entry 14.
