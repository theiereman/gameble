---
title: 'The card detail beside the grid on tablet and desktop'
type: 'feature'
ticket: '14'
created: '2026-10-19'
status: 'built'
baseline_revision: 'dc48b5b24e2afc02ed43ea44047680fd3c896fab'
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

**Problem:** On every width, a slot of "Toutes les cartes" (`/library/cards`) opens the card's detail as a separate page, so the player loses the grid with each card. DESIGN.md (Layout, per screen, Collection) puts the detail in the screen: beside the grid, 340px wide from 1180px and 300px from 900 to 1179px; in one column under the grid from 720 to 899px. The selected card gets a steady 3px accent frame (DESIGN.md, Selected card).

**Approach:** The grid page holds an empty `card-detail` Turbo Frame next to the grid. From 720px, a slot loads its card's existing detail (`cards#show`, with the grid context the link already carries) into that frame instead of visiting the page, and the URL becomes the card's. ◀ ▶ keep walking the grid as shown, and browser Back restores the grid at its scroll. Under 720px the slot still opens the detail page. Nothing changes on the server side except the grid page's markup.

## Boundaries & Constraints

**Always:**
- Layout of `/library/cards`:
  - From 1180px: RAPPORT 220px · grid fluid · detail 340px.
  - 900 to 1179px: grid fluid · detail 300px.
  - The detail column is always reserved there, so the grid never reflows on opening. Before any card is chosen, it shows a quiet panel: the kicker "Fiche de la carte" and one muted line, en "Choose a card to see its details." / fr "Choisissez une carte pour voir sa fiche.".
  - 720 to 899px: one column, with the detail under the grid. Nothing shows there until a card is opened; the open then scrolls the detail into view.
  - Beside the grid, the detail is sticky near the top of the viewport and scrolls inside itself when taller than the viewport. Its corner brackets are not clipped.
- Opening from a slot (owned face or missing slot), with a plain left click or Enter, from 720px:
  - The detail loads into the frame. The first open pushes a history entry; an open while the frame already holds a card replaces the entry, so Back always returns to the grid.
  - The screen does not slide: no screen-change View Transition, the same way ◀ ▶ avoid it.
  - Focus moves to the detail's heading without scrolling. EXPERIENCE.md's trade board does the same ("Trade board opened → the board heading").
  - Modified clicks (new tab, etc.) and widths under 720px keep the link's own behaviour.
- The selected card:
  - The grid link whose path is the card shown in the frame gets `aria-current="true"` and a steady 3px accent frame around its card, no animation; all others lose it.
  - The mark follows ◀ ▶ steps and is cleared when the filters or the search reload the grid.
- Inside the frame, the detail stays the existing `cards/_detail`: ◀ ▶ walk the grid as shown across its pages (replace), a card of a game not held is faded, and the share, repost, set and Steam links behave as on the page.
  - In a container too narrow for ◀ card ▶ (the 300px column), ◀ ▶ go side by side under the card, still 44 × 64. This applies only inside the grid's frame; the phone sub-view and the detail page do not change.
- Filters, search or a page change reload the `collection-results` frame, which holds the detail frame. They therefore come back with the empty detail.
- Locales: every string in `en.yml` and `fr.yml`.
- Markup: no `style` attribute, no database id, no planning ids, no new explanatory comments. Keep the repo's one-line module headers on new files.

**Never:**
- No change to `cards#show`, `CardsController`, `CollectionGridLoading`, the queries, the routes or the phone sub-view's behaviour. No new endpoint.
- Do not touch `app/views/library/_entry*`, `_set_search*` or `show*` (a parallel build owns them), the album, the hub or the booster.
- Nothing is server-rendered as selected, and no card opens automatically.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Desktop open | 1280px, click Hades's slot | Hades's detail in the 340px column, Hades framed, URL `/fr/cards/hades/seasons/4?grid[q]=`, grid scroll unchanged, focus on the detail heading | — |
| Step | ▶ in the column | the next grid card replaces it, framed in the grid if on this page; URL replaced | — |
| Back | after open (and steps) | the grid restored at its scroll with the empty column, focus on the slot left | — |
| Second open | column holds Hades, click Celeste | Celeste replaces it; Back still returns to the grid in one step | — |
| Not held | click a missing slot | detail with the faded card back | — |
| 1024px | click a slot | 300px column, ◀ ▶ under the card | — |
| 800px | click a slot | detail shown under the grid and scrolled into view; no placeholder before | — |
| Phone | 390px, tap a slot | the detail page opens, as today | — |
| Filter | column holds a card, tick a rarity | grid reloads, column back to the placeholder, no frame mark | — |
| Modified click | ctrl/cmd-click a slot | a new tab with the detail page | — |
| Missing frame in response | detail response without `card-detail` (a visitor whose grid no longer holds the card) | Turbo's frame-missing visit shows the response page | no special handling |

</intent-contract>

## Code Map

- `app/views/library/_collection.html.erb` -- inside `turbo_frame_tag "collection-results"`:
  - Wrap the grid (`library/grid`) in a results element.
  - Add `turbo_frame_tag "card-detail", target: "_top"` as its sibling (classes for layout), holding the placeholder panel (`PanelComponent`, quiet, the kicker `card_details.kicker` and the new line).
  - Put the new Stimulus controller on `.collection`, which sits outside both frames and so persists. Update the header comment's layout lines.
- `app/views/library/_grid.html.erb` -- no change needed. Slot links are `a.card-link` from `link_to_card_detail` and carry `grid` context, with `data-turbo-prefetch=false`.
- `app/views/cards/show.html.erb` -- read-only. It already wraps the detail in `turbo_frame_tag "card-detail", target: "_top"`. Its frame layout `layouts/turbo_rails/frame.html.erb` merges the head on a URL-changing frame visit.
- `app/views/cards/_detail.html.erb`, `_detail_nav.html.erb` -- read-only. ◀ ▶ already target the `card-detail` frame with `turbo_action: "replace"` and `sub-view#step`. The heading is `[data-sub-view-target=heading]` with `tabindex=-1`.
- `app/frontend/controllers/sub_view_controller.ts`:
  - Move the module-level step machinery (`beginStep`, `endStep`, `stepLoaded`, the paused view-transition meta, the timer, `focusAfterStep`, `stepTransition`) into a new `app/frontend/lib/sub_view_step.ts`. Accept a direction of `"previous" | "next" | "open"` and a focus wish of `"previous" | "next" | "heading" | null`.
  - In `connect`, a `"heading"` wish focuses the heading with `preventScroll`.
  - Export the phone media query from the lib and use it in both places.
  - Behaviour for ◀ ▶ is unchanged.
- New `app/frontend/controllers/collection_detail_controller.ts`:
  - `open` (click on `.collection`, delegated to grid `a.card-link`): return when the event is prevented, not button 0, has modifier keys, or the phone width matches.
  - Otherwise `preventDefault` and `beginStep("open", "heading")`, then `window.Turbo.visit(href, { frame: "card-detail", action })`. The action is `"replace"` when the frame already holds `.card-detail`, else `"advance"`.
  - `loaded` (`turbo:frame-load` bubbling from `#card-detail`): mark `aria-current` on the matching grid link by pathname of the frame's `src` and clear the others. After an open (not a step), scroll the frame into view when its top is outside the viewport.
  - Also clear the marks when `collection-results` loads.
- `app/frontend/lib/turbo.ts` -- add `frame?: string` to `visit`'s options type.
- `app/frontend/styles/collection.css`:
  - Results and detail columns in the `collection-results` frame: one column under 900px; `minmax(0,1fr) 300px` with the medium gap from 900px; `340px` with the wide gap from 1180px.
  - The detail frame: `display: block`, sticky (`top` about `--space-5`), `max-height: calc(100dvh - …)`, `overflow-y: auto`, and padding with a matching negative margin so the brackets are not clipped. Hidden under 720px.
  - The placeholder: hidden under 900px.
  - The selected-slot frame: 3px `--color-accent` around the card, inside the slot's bleed.
  - The narrow-panel container query, `@container (width < 304px)`, scoped to the detail frame. The ◀ ▶ grid areas sit under the card.
  - The detail panel's horizontal padding in the frame: about 16px, so ◀ 208px card ▶ fits 340.
  - Update the file header.
- `app/frontend/styles/card-detail.css` -- read-only, except a header line if needed. `.card-detail__layout` is already the inline-size container. The stage needs 44+4+208+4+44 = 304px. Step animations are keyed on `html[data-sub-view-step="previous|next"]`; "open" gets the default cross-fade.
- `app/frontend/styles/shell.css:1230` -- `html[data-sub-view-step] .main { view-transition-name: none }` already covers "open". The starfield (`starfield_controller.ts`) ignores visits during a step.
- `app/frontend/controllers/history_back_controller.ts` -- read-only. It records frame visits and refocuses `a.card-link` matching the page left on restore, which gives the Back focus.
- `app/frontend/lib/collection-grid.test.ts` -- the "1280px and up" row becomes the grid beside RAPPORT and the 340px detail: 1280 − 64 − 220 − 340 − 2×32 = 592px gives 4 × 136, small. Add 1024px: 1024 − 56 − 300 − 24 = 644 gives 4 × 148, medium. Keep the 800px row (752, 5 × 136).
- Locales `config/locales/{en,fr}.yml` -- `library.grid.detail_placeholder` (or an equivalent key under `library`).
- `test/controllers/library_controller_test.rb` -- the cards page renders the `card-detail` frame inside `collection-results`, with the placeholder in both locales, and no `[style]`. Query counts are unchanged.
- System tests (`test/system/card_detail_test.rb`, collection tests): never run; update selectors only if obviously broken.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/sub_view_step.ts` (new) + `sub_view_controller.ts` -- extract the step machinery, add "open" and the heading focus -- shared by ◀ ▶ and the grid's open.
- [x] `app/frontend/controllers/collection_detail_controller.ts` (new), `app/frontend/lib/turbo.ts` -- open in the frame from 720px, mark the selected slot, scroll the stacked detail into view.
- [x] `app/views/library/_collection.html.erb`, locales en/fr -- the frame with its placeholder, the controller.
- [x] `app/frontend/styles/collection.css` -- the columns, sticky detail, placeholder, selected frame, narrow ◀ ▶.
- [x] Tests:
  - Vitest for the pure parts. Selected-link matching by pathname, and the open decision (modifiers, phone, replace vs advance), extracted to a lib function if needed.
  - Stylesheet assertions in `collection-grid.test.ts`: the new rows, the 304px threshold against the stage's sizes, and the sticky detail.
  - Request test for the page markup.

**Acceptance Criteria:**
- Given a signed-in player on `/fr/library/cards` at 1280px, when they click a slot, then its detail shows in the 340px column with the card framed, the URL is the card's, and browser Back shows the grid at the same scroll with the empty column.
- Given the column showing a card, when ▶ is pressed, then the next card of the grid as shown replaces it and its slot is framed.
- Given a 390px window, when a slot is tapped, then the detail page opens as before.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass. `unused` lists only the pre-existing `rate_limit.*`.

## Implementation Notes

- The detail panel's horizontal padding in the frame is 12px (`--space-4`), not 16px: the column scrolls inside itself, and Chrome's thin scrollbar (10–11px) takes from its width. 340 − 11 − 24 = 305 ≥ 304 keeps ◀ card ▶ on one row at 1180px and up; at 16px they would drop under the card whenever the column scrolls. Measured in headless Chrome: layout 306px with the scrollbar.
- Under 900px the empty frame is `display: none` (`.collection-detail:has(> .card-detail)` shows it from 720px), which also hides the placeholder and avoids an empty grid row gap under the grid.
- A click on the slot whose card the frame already shows brings the detail into view when needed and focuses its heading, without a visit: reloading the card already shown would be a needless request.
- Whether a frame load follows an open (and so scrolls the stacked detail into view) is read from the step mark (`steppingInto("open")`), still set when the frame loads, rather than from a flag of the controller that an open that never loads would leave set.
- Pure decisions live in `app/frontend/lib/collection_detail.ts` (`opensBeside`, `openAction`, `selectedLink`), tested in `collection_detail.test.ts`.
- Request-test selectors updated for the new markup: the ids listed in `.collection` now end with `card-detail`, and the status line sits in `.collection-results__grid`.
- Verified in headless Chrome with a throwaway system test (deleted): open at 1280 (URL, focus on the heading, frame mark, history length unchanged by a step and a second open), Back (grid at its scroll, placeholder, focus on the slot last shown), a rarity filter (placeholder, no mark), 1024 (◀ ▶ under the card), 800 (detail under the grid, scrolled into view), 390 (the detail page).

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Re-clicking the slot already shown at 720–899px focused an off-screen heading without scrolling; the note claimed Turbo does not reload an unchanged src (Turbo 8 does). The same-src branch now reveals the frame before focusing; the note is corrected.
  - `[low]` `[patch]` `reveal` skipped scrolling whenever the frame's top was anywhere in the viewport, leaving a detail just above the fold. Now it scrolls unless the top is in the upper half of the viewport.
  - `[low]` `[reject]` A filter or search sent while a card is open replaces the card's history entry with the filtered grid, so Back returns to the unfiltered grid as it was when the card opened, one step more than before. That is the grid the ticket's Back promises. Removing the entry would need history surgery beyond a direct correction.
  - `[low]` `[patch]` The controller's `opening` flag stayed set when an open never loaded, so a later ◀ ▶ step scrolled as if it were an open. The flag is gone; the open is read from the step mark (`steppingInto("open")`). Turbo dispatches `turbo:frame-load` before the promoted visit's load (`#loadFrameResponse`), so the mark is still set.
  - `[low]` `[patch]` New explanatory JSDoc and CSS comments went against AGENTS.md. Deleted, keeping the module headers, the two constant one-liners and the thin-scrollbar constraint.
  - `[low]` `[patch]` The `sub_view_step.ts` header said every open cross-fades, and `shell.css`'s `html[data-sub-view-step] .main` comment still named only ◀ ▶. Both are reworded.

## Design Notes

- **Why a frame visit with the card's URL:** ◀ ▶ already replace the URL with the card's. Keeping the card URL makes Back restore the grid's Turbo snapshot at its scroll, the frame's previous children included, as the phone's "◀ Grille" already relies on. A reload of that URL shows the detail page, with "◀ Grille" back to the grid.
- **720 to 899px:** DESIGN.md's per-screen table gives one column there, with the detail under the grid. The 800px grid example (5 × 136, story 13) assumes the grid alone. Opening scrolls the detail into view; Back restores the grid's scroll.
- **Reserved column with a placeholder:** the grid examples at desktop widths assume the detail column. Collapsing it while empty would re-lay every card on the first open and move the clicked one.
- **Placeholder copy** is not in the copy deck. It is the one new string, and the author checks it on staging.

## Verification

**Commands:**
- `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1314 bin/rails test` -- expected: green (system tests skipped)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/ci` (same DATABASE_URL) -- expected: green; revert any stray `package-lock.json` "license" line

**Manual checks (if no CLI):**
- Headless Chromium on `/en/library/cards` at 1280, 1024, 800 and 390px:
  - open a slot, step ▶, go Back;
  - check the column widths, the frame mark, the URL, the scroll restored, and that the detail panel has no horizontal overflow.

## Auto Run Result

**Summary:**
- From 900px, `/library/cards` reserves a detail column beside the grid: 340px from 1180px, 300px below. It holds a quiet placeholder until a slot is opened.
- From 720px, a slot loads its card's existing detail into the `card-detail` frame. The first open pushes the card's URL; later opens replace it. Focus goes to the heading, and the slot is framed in accent (`aria-current`).
- ◀ ▶ still walk the grid as shown. Back restores the grid at its scroll with the placeholder.
- From 720 to 899px the detail shows under the grid and scrolls into view.
- Under 720px the slot still opens the detail page.

**Files:**
- `app/frontend/lib/sub_view_step.ts` (new): the step machinery taken out of the sub-view controller, plus the "open" step and the heading focus wish.
- `app/frontend/controllers/sub_view_controller.ts`: uses that lib.
- `app/frontend/controllers/collection_detail_controller.ts` (new): opening into the frame, the selected mark, and the reveal.
- `app/frontend/lib/collection_detail.ts` (new) and its test: the pure decisions.
- `app/frontend/lib/turbo.ts`: the `frame` option of `visit`.
- `app/views/library/_collection.html.erb`: the detail frame and the placeholder.
- `app/frontend/styles/collection.css`: the columns, the sticky detail, the selected frame, and ◀ ▶ under the card in the 300px column.
- `app/frontend/styles/shell.css`: comment only.
- `config/locales/{en,fr}.yml`: `library.grid.detail_placeholder`.
- `app/frontend/lib/collection-grid.test.ts`: the widths and the panel rules.
- `test/controllers/library_controller_test.rb`: the frame markup.

**Review:**
- 6 findings, all low: 5 patched, 1 rejected (the extra Back step after filtering with a card open; see the triage log), none deferred.
- Follow-up review recommended: false (patched: high 0, medium 0, low 5).

**Verification:**
- `bin/ci` passed (DATABASE_URL `gameble_test_w1314`): 2709 runs, 0 failures; packwerk and the migration round trip passed.
- `npm run test:js`: 421 passed.
- `npm run typecheck`, `bin/rails zeitwerk:check` and `i18n-tasks missing`: clean.
- `i18n-tasks unused`: only pre-existing keys.
- The implementer checked the matrix rows in headless Chrome with a throwaway system test (since deleted) at 1280, 1024, 800 and 390px. Project policy keeps system tests disabled, so the browser-only rows have no committed test. Covered by committed tests: the pure decisions, the stylesheet rules and the markup.

**Residual risks:**
- The placeholder copy is not in the copy deck.
- From 720 to 899px, DESIGN.md's one-column layout is read as the detail under the grid.
- With classic scrollbars that ignore `scrollbar-width: thin`, ◀ ▶ drop under the card at 1180px and up when the column scrolls.
- System tests that click grid slots at desktop width were neither run nor updated.
- Reloading a card URL opened beside the grid shows the detail page.
