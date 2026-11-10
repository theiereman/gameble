---
title: 'On the phone, Confier ticks in three columns and sets copies in the recap sheet'
type: 'feature'
ticket: '38.6'
created: '2026-11-10'
status: 'built'
baseline_revision: '975d0cc8dc1aa561a6ac04a9802ed9b7e7bf6642'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/story-the-confier-screen-previews-the-batch-as-the-player-ticks-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Under the phone breakpoint Confier still draws the desktop screen: auto-fill cells with steppers, and the recap stacked under a long grid, out of reach of the thumb.

**Approach:** The root `entrust` controller writes `data-layout` (`wide` | `phone`) from the 720px breakpoint and changes it only when its state module says the screen is idle (no sheet open). In the phone layout the same server-rendered tree draws three columns of ticks, a bar over the content (count, total, "CONFIER ▸") and the one recap panel moves into a `BottomSheetComponent`, its lines holding 44px steppers, before validating. Epic requirement R7.

## Boundaries & Constraints

**Always:** one tree, two layouts: the state module (`entrust.ts` and a new `entrust_layout.ts`) holds `layout`, `pendingLayout` and `sheetOpen`; a media query change only asks for a layout, which is applied when no sheet is open and at connect; the root writes `data-layout` and asks the recap controller to place the recap (desktop slot or sheet body) only when the applied layout changes; all layout CSS is keyed on `data-layout`, never on a media query, so a held layout never half-switches; the server renders `data-layout="wide"`; the recap panel, its templates, submit button and sentences exist once (no duplicated ids), and moving the panel keeps the submit button inside the form `#entrust`; the sheet is the existing `BottomSheetComponent` opened by the bar's `bottom_sheet_opener` link, so focus trap, scrim, drag, Esc and focus return are the sheet's own; the sheet's title is "Confier" and closing returns focus to "CONFIER ▸"; two polite status lines fed by one debounce, never both written: the panel's own line (inside the recap panel, so it travels into the sheet and an open dialog holds its status) and the wrapper's `bar` line (outside the panel and the sheet, always rendered, visually hidden), the bar line being the one written only in the phone layout with the sheet closed; recap lines are reconciled by ref, never rebuilt: a missing line is inserted at its view position (`insertBefore` the next existing line of the view, or appended when it is last), an existing line is moved only when its position really differs from the view's order (an unchanged order touches no node), so a stepper keeps focus while it is pressed and while a line appears or the order changes; recap steppers are the server-rendered `trades/_stepper` partial (rendered with `controller: "entrust-recap"`, so it wires `mousedown->entrust-recap#keepFocus`, `click->entrust-recap#step` and `keydown->entrust-recap#stepperKey`) cloned from a `<template>`, 44px wide targets, shown only in the phone layout, absent for a line with a single free copy; the cell's own stepper is hidden in the phone layout and the cell only ticks; every amount in the bar goes through `drawAmount`; the bar pins (sticky above the phone tab bar and safe area) only from 560 CSS px of viewport height and scrolls with the content below that, with a 2px lime rule above it; children talk to the root by `dispatch`, the root drives them through outlets; no markup built in script; no `style` attribute in server HTML; every string in `en.yml` and `fr.yml` with French `zero` plural forms; no new `gameble:*` event; the sheet-open signal is the existing `gameble:sheet-shown`, which `dispatchGameble` dispatches on `window`, so the root binds `gameble:sheet-shown@window->entrust#sheetShown` (the precedent is `gameble:bank-updated@window->booster#bankUpdated`), never `@document`; the root's last-placed layout starts as `wide` (the server markup) and a connect places the recap from the actual DOM; files stay under 400 lines (TypeScript, Ruby) and 500 (CSS).

**Never:** a second recap or a second submit button; a layout change while the sheet is open; a media-query-only phone layout; card art in the cells; a filter sheet or filter changes; the card detail entry (7), the Balance chip (8), the suspended banner (10), settings or back-office changes; any change of the preview rule, the shared fixture or the operation; a per-card confirmation; hand-edited `app/frontend/images/pixel/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Load on a phone | viewport 719px or narrower | `data-layout="phone"`, three columns, bar shown, recap in the closed sheet, cell steppers hidden | — |
| Load on desktop | wider than 719px | `data-layout="wide"`, as story 38.5 | — |
| Tick | tap a cell | lime frame and check; bar count and total follow | — |
| Open the recap | tap "CONFIER ▸" | sheet opens on the recap, focus on its first control, steppers 44px on lines with several free copies | — |
| Set copies | tap a line's `+` | copies raise within 1..free, total, bar and `copies[...]` input follow, focus stays on the stepper | — |
| Validate | tap "CONFIER n EXEMPLAIRES" in the sheet | POST as on desktop, result page | a refusal re-renders the page with the refusal above the grid, outside the panel and the sheet (sheet closed on the phone), `role=alert`, ticks kept |
| Nothing ticked | bar tapped | sheet opens on the prompt, validation disabled | — |
| Full cap | `cap_left` 0 | sheet shows the full-cap line, validation disabled | — |
| Resize while the sheet is open | viewport crosses 720px | layout held; applied when the sheet closes | — |
| Resize while idle | viewport crosses 720px | layout switches at once, recap panel moves, ticks kept | — |
| Esc, sheet open | Esc | the sheet closes, ticks untouched | — |
| Esc, sheet closed, ticks pending | Esc | nothing happens (as 38.5) | — |
| Short viewport | height under 560px | bar scrolls with the content | — |
| Market closed | closed version | bar and sheet usable, validation disabled | page notice as today |

## Decisions (settled in planning, no human checkpoint in this run)

- The breakpoint is 720px (`max-width: 719px`), the one the other screens use; the client names it once in `entrust_layout.ts`.
- The recap panel moves between the desktop slot and the sheet body instead of being rendered twice: one set of ids, one submit button, one preview render. The controller element owning the targets (the layout wrapper) never moves, so Stimulus does not reconnect it.
- The `entrust-recap` controller moves from the recap panel to the layout wrapper so the bar, status region, slot and sheet are all its targets whichever layout is applied.
- Refusals: the `role="alert"` refusal paragraph leaves the recap panel and is rendered in the form above the filters and the layout, in both layouts (class `market-entrust__refusal`, `tabindex="-1"`), so a re-render with the sheet closed still shows and announces it; the sheet is not reopened. The old `entrust-recap__refusal` class and its CSS rule go; the settings-changed, nothing-fits, card-no-longer-free and market-closed refusals all use it. The recap controller never touches it.
- Status: the panel keeps its polite line (so an open dialog holds its own status line, which stays announced because it is inside the dialog), and the wrapper gains a second visually-hidden polite line (`barStatus`) for the closed sheet. One debounce feeds both: when it fires, the text is written to the one line that applies now (`barStatus` when the applied layout is `phone` and the sheet is closed, else the panel's line) and the other is emptied, so nothing speaks twice and the dialog is never silent. Re-parenting one live region was rejected: a moved live region is not reliably announced.
- Locale keys: the new partials use full keys, like `_recap`: `market.entrustments.new.sheet_title`, `market.entrustments.new.bar_action`, `market.entrustments.new.bar_label` and `market.entrustments.strings.bar_count` (strings are shipped to the client), never lazy `.key`; `i18n-tasks health` sees them as used.
- Line order: recap lines follow the view order (most valuable first); the reconcile inserts and moves minimally as stated in Boundaries, and the stepper template's per-line `ref` is read from `event.currentTarget.closest(".entrust-recap__line").dataset.ref`, the same way the grid reads its cell.
- The bar is shown on every phone load, including with nothing ticked, so the full-cap line and the prompt stay reachable; it counts the copies that will really be entrusted and shows the exact received amount.
- The bar's action is a `bottom_sheet_opener` link (as the other sheets), title "Confier", labelled "CONFIER ▸" / "Confier ▸".
- CSS is keyed on `data-layout`; the story 38.5 media rule for the two columns and the sticky recap moves under `[data-layout="wide"]`.
- Phone-only CSS goes in a new `market-entrust-phone.css` to keep the existing files under 500 lines.
- The sheet-open state is read from the dialog itself: the `BottomSheetComponent` renders its `<dialog>` with no data or target attributes and is not modified, so the recap controller has no `sheet` target; `sheetIsOpen()` returns `this.sheetBodyTarget.closest("dialog")?.open === true`. The sheet's `close` event fires after `open` is false and `openFrom` dispatches after the dialog is open, so the read is right when `gameble:sheet-shown` arrives.
- Opening or closing the sheet moves the status: the root, after feeding `sheetShown`, calls `recap.refreshStatus()`. It writes the last posted text (`posted`) into `activeStatus()` and empties the other line, with no debounce and without changing `posted`/`waiting`, so a dialog just opened announces the current count and total instead of staying silent, and the bar line is emptied. When nothing was posted yet it does nothing. The debounce still suppresses a repeat of the same text.
- Initial and restored layout: the root's last-placed layout starts as `wide`, matching the server markup (aside in the slot, `data-layout="wide"`), so a phone connect applies `phone` and places the aside into the sheet body. At connect the root also re-places from the actual DOM: it compares where the aside really sits (`aside.parentElement` is the slot or the sheet body) with the layout it applies, and calls `recap.place` when they differ, so a Turbo cache restore taken in the phone layout and reconnected on desktop does not leave the aside inside the sheet; `data-layout` is rewritten at connect from the media query whatever the stored value.
- The one system test is at phone width (390x844); the layout hold is covered by vitest on the state module and the root.

</frozen-after-approval>

## Code Map

- `app/frontend/lib/entrust.ts` -- state and `start`; gains `layout`, `pendingLayout`, `sheetOpen` (defaults `wide`, `null`, `false`).
- `app/frontend/lib/entrust_view.ts` -- `recapViewOf`, `LineView`, `drawAmount`; gains a line stepper view and a bar view.
- `app/frontend/lib/booster_layout_watch.ts`, `lib/booster_view.ts` (`layoutAsked`, `layoutApplied`, `idle`) -- the pending-layout pattern to mirror; `lib/booster_types.ts` `PHONE_QUERY` is `(max-width: 719px)`.
- `app/frontend/lib/stepper.ts` -- `reflectStepper`, `quantityFromButton/Key`, `keepStepperFocus` reused for the line steppers.
- `app/frontend/controllers/entrust_controller.ts` -- root: render, outlets, Esc guard; gains matchMedia watch, `sheetShown`, `data-layout`, recap placement.
- `app/frontend/controllers/entrust_recap_controller.ts` (+ `.test.ts`) -- recap, status debounce; gains bar, slot/sheet placement, keyed line reconcile, line steppers.
- `app/frontend/controllers/entrust_grid_controller.ts` -- cells; unchanged (the cell stepper is hidden by CSS).
- `app/frontend/controllers/bottom_sheet_controller.ts`, `app/components/bottom_sheet_component.*`, `app/helpers/bottom_sheet_helper.rb` -- the sheet, its opener and the `gameble:sheet-shown` events.
- `app/helpers/market_entrustments_helper.rb` -- `ENTRUST_ACTIONS`, `ENTRUST_CHILDREN`, `entrust_root_data`; gains the recap's `copies` action and the sheet-shown action.
- `app/views/market/entrustments/new.html.erb`, `_recap.html.erb`, `_grid.html.erb`, `_cell.html.erb` -- the markup; the wrapper `.market-entrust__layout` becomes the recap controller's element.
- `app/views/trades/_stepper.html.erb` -- the stepper partial, reusable with `controller:`.
- `app/frontend/styles/market-entrust.css` (250 lines), `market-entrust-recap.css` (137), `bottom-sheet.css`, `trades-responsive.css` (44px stepper buttons), `entrypoints/application.css` -- styles; `--tabbar-height` for the bar's offset.
- `config/locales/en.yml:2194`, `fr.yml` -- `market.entrustments.*`; Copy deck, Confier of `ux-gameble/EXPERIENCE.md` (line 180) and the phone lines of Confier (line 360), `DESIGN.md` line 1259.
- `test/system/bottom_sheet_test.rb`, `test/application_system_test_case.rb` (`resize_to`, teardown restores the size) -- phone system test patterns.
- `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb`, `app/frontend/lib/entrust.test.ts` -- tests to extend.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/entrust.ts` -- add `layout: Layout`, `pendingLayout: Layout | null` and `sheetOpen: boolean` to `EntrustState` and to `start` (`wide`, `null`, `false`); export `Layout = "wide" | "phone"` -- the state module owns the layout.
- [ ] `app/frontend/lib/entrust_layout.ts` -- create: `PHONE_QUERY`, `layoutFor(phoneMatches)`, `layoutAsked(state, layout)` (stores the request, applies it at once when `sheetOpen` is false, clears it when equal to the current), `sheetShown(state, shown)` (records it, applies a pending layout when it closes), `idle(state)`; pure, no DOM -- the held-while-open rule.
- [ ] `app/frontend/lib/entrust_layout.test.ts` -- vitest: asked while idle applies at once; asked while the sheet is open is held and `layout` unchanged; applied when the sheet closes; asked then reverted while open leaves no change; asking the current layout is a no-op; ticks, filters and active cell are untouched by any switch.
- [ ] `app/frontend/lib/entrust_view.ts` -- `LineView` gains `stepper: StepperView | null` (ticked line with more than one free copy, from `stepperOf`) and `RecapView` gains `bar: { count: string; amount: number }` (count through a `barCount` plural string, amount the received total); add `barCount` to `EntrustStrings` -- view models for the sheet's lines and the bar.
- [ ] `app/frontend/controllers/entrust_recap_controller.ts` -- element becomes the layout wrapper; new targets `aside`, `slot`, `sheetBody`, `bar`, `barCount`, `barTotal`, `stepperTemplate`; `place(layout)` appends the aside to `sheetBody` (phone) or `slot` (wide); `sheetIsOpen()` returns `this.sheetBodyTarget.closest("dialog")?.open === true` (no `sheet` target, the component is not modified); `placedIn()` returns `"sheet"` or `"slot"` from `aside.parentElement`; `refreshStatus()` re-writes the posted text into `activeStatus()` and empties the other line, no debounce; render writes the bar; keyed line reconcile (reuse a line by `data-ref`; walk the view in order: a missing line is created from the template and inserted before the next existing line of the view, or appended when last; an existing line is moved only if it is not already the node expected at that position; stale lines are removed; no node is touched when the order is unchanged; reflect each line's stepper with `reflectStepper` and remove it when `stepper` is null); `step`, `stepperKey` and `keepFocus` actions (`keepFocus` calls `keepStepperFocus`) dispatch `copies` like the grid, the ref coming from the line the event's `currentTarget` sits in; new targets `barStatus`; remember the applied layout in `place`; the debounce fires into `activeStatus()` (see Decisions) and empties the other -- the one recap, wherever it sits.
- [ ] `app/frontend/controllers/entrust_recap_controller.test.ts` -- extend: a line stepper `+` dispatches `copies` with the line's ref, a mousedown on a stepper button is default-prevented (`keepFocus`) and the stepper keeps focus across the re-render; a new line for a more valuable card is inserted at the top while another line's stepper holds focus, and that stepper stays the same node and keeps focus; an unchanged order moves no node (a MutationObserver sees no childList record); a reordered view moves only the lines out of place; status: layout `wide` writes the panel line only, phone with the sheet closed writes `barStatus` and empties the panel line, phone with the dialog `open` writes the panel line and empties `barStatus`, and `refreshStatus()` after the dialog opens writes the previously posted text into the panel line and empties `barStatus` (and the reverse once it closes), with the debounce still dropping a repeat of the same text; lines are reused (same element after a re-render); `place("phone")` moves the aside into the sheet body and `place("wide")` back, the submit button staying inside the form; the bar shows the count and exact total; status behaviour unchanged with the panel moved.
- [ ] `app/frontend/controllers/entrust_controller.ts` -- on connect watch `window.matchMedia(PHONE_QUERY)` (guard a missing `matchMedia`), feed `layoutAsked`; add `sheetShown` action for `gameble:sheet-shown` that reads `recap.sheetIsOpen()` and feeds `sheetShown`; the last-placed layout starts as `wide`; connect re-places from the actual DOM (`recap.placedIn()` against the layout applied) and render writes `element.dataset.layout` and calls `recap.place` only when the applied layout differs from the last one; `sheetShown` ends with `recap.refreshStatus()`; remove the listener on disconnect; the Esc guard stays (it already yields to an open dialog) -- the root drives the layout.
- [ ] `app/frontend/lib/entrust.test.ts`, `app/frontend/controllers/entrust_recap_controller.test.ts`, `app/frontend/controllers/entrust_controller.test.ts` (existing helpers and fixtures) -- adjust what the new state fields and the moved controller element change so the old assertions still describe 38.5: the `start` helpers default `layout: "wide"`, `pendingLayout: null`, `sheetOpen: false`; state literals gain the three fields; the recap and root fixtures put `data-controller="entrust-recap"` on a wrapper holding the `slot`, `aside`, `sheetBody`, `bar`, `barCount`, `barTotal`, `barStatus` targets and the panel's `status` line, the panel no longer carrying the controller; `matchMedia` is stubbed in the root fixtures so existing cases run in `wide`; no old assertion is dropped or loosened.
- [ ] `app/frontend/controllers/entrust_controller.test.ts` -- vitest with a stubbed `matchMedia`: layout set at connect; a change while idle switches `data-layout`; a phone connect (stubbed `matches: true`) places the aside into the sheet body and writes `data-layout="phone"`; a restore case (markup with the aside already inside the sheet body, `matches: false`) re-places it into the slot at connect; a change while the sheet is open is held and applied when `gameble:sheet-shown` reports it closed, the event dispatched on `window` with `dispatchGameble`; opening or closing the sheet calls `refreshStatus`; ticks survive both switches; Esc with a dialog open is not prevented -- the switch held while the sheet is open.
- [ ] `app/helpers/market_entrustments_helper.rb` -- add `"entrust-recap" => { copies: :copies }` to `ENTRUST_ACTIONS`, keep outlets for the three children, and add `gameble:sheet-shown@window->entrust#sheetShown` to the root's actions; add `bar_count` to the strings -- wiring.
- [ ] `app/views/market/entrustments/new.html.erb`, `_recap.html.erb`, `_bar.html.erb`, `_sheet.html.erb` -- the form root gets `data-layout="wide"`; the `@refusal` paragraph (`role="alert"`, `tabindex="-1"`, class `market-entrust__refusal`) moves out of `_recap` into the form, above the filters, rendered in both layouts; `.market-entrust__layout` carries `data-controller="entrust-recap"` and its two values (moved off the panel); layout holds the grid, a `slot` div wrapping the recap panel, the bar and the sheet inside the form; the panel drops its controller attribute and keeps its ids, templates and submit; `_bar` is a `role="group"` row with the count, an exact `PicoinAmountComponent` total and a `tag.a(**bottom_sheet_opener("entrust-recap-sheet"))` "CONFIER ▸"; `_sheet` renders `BottomSheetComponent.new(id: "entrust-recap-sheet", title: t("market.entrustments.new.sheet_title"))` with an empty body target; both partials use full `market.entrustments.new.*` keys, no lazy keys; add the `stepperTemplate` (`trades/_stepper` with `controller: "entrust-recap"`); the panel keeps its status paragraph and the wrapper gets a second `barStatus` polite visually-hidden paragraph -- server markup both layouts share.
- [ ] `app/frontend/styles/market-entrust.css`, `market-entrust-recap.css` -- move the refusal rule from `.entrust-recap__refusal` to `.market-entrust__refusal` (full width above the grid); move the 720px two-column rule and the sticky recap under `[data-layout="wide"]`; hide `.entrust-recap__stepper` and the bar in the wide layout -- layout keyed on `data-layout`.
- [ ] `app/frontend/styles/market-entrust-phone.css`, `app/frontend/entrypoints/application.css` -- create and import: under `[data-layout="phone"]` three equal columns, compact cells (name, rarity and season, value; the cell stepper and free line hidden), the recap hidden from the layout (it lives in the sheet), the bar (flex row, panel background, 2px `--color-lime` top rule, sticky above `calc(var(--tabbar-height) + env(safe-area-inset-bottom, 0px))` inside `@media (min-height: 560px)`, in flow below), the recap line's stepper with 44px buttons, the submit sticky at the bottom of the sheet body; tokens only; run `npm run lint:css` at the end -- the phone look.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- final key paths in both files: `market.entrustments.new.sheet_title` ("Entrust" / "Confier"), `market.entrustments.new.bar_action` ("Entrust ▸" / "Confier ▸"), `market.entrustments.new.bar_label` (the bar group's accessible name), and `market.entrustments.strings.bar_count` with `zero`, `one`, `other` (en "0 copies" / "%{count} copy" / "%{count} copies"; fr `zero` "0 exemplaire", `one` "%{count} exemplaire", `other` "%{count} exemplaires"); no dynamic keys; run `bundle exec i18n-tasks health` at the end.
- [ ] `test/controllers/market/entrustments_controller_test.rb` -- the existing `.entrust-recap__refusal` selectors (closed market, settings changed, free copies) become `.market-entrust__refusal`, and a refused POST asserts the alert is a child of the form, not of the `aside` and not of the sheet dialog; the page carries `data-layout="wide"`, the bar with an opener to `entrust-recap-sheet`, the sheet dialog with its title, one submit button, two polite status lines (one inside the panel, one outside it and outside the sheet), the recap panel inside the form, no `style` attribute; GET writes nothing -- markup contract.
- [ ] `test/system/market_entrust_test.rb` -- one phone-width test (`resize_to 390, 844`, retrying matchers): visit with two held editions (one with two free copies), assert three columns (`data-layout=phone`, the cell stepper not visible), tick two cells, assert the bar's count and total, open "Entrust ▸", assert the dialog is open with the recap lines and a visible 44px stepper on the multi-copy line, raise it, assert the total and the bar, click "Entrust 3 copies" inside the sheet, assert the result total and the holdings; the existing desktop tests stay green at the default size (the settings-changed test's selector follows the rename). A second phone-width test, "a refusal shows above the grid with the sheet closed": tick a cell, change the settings behind the form as the existing settings-changed test does, open the sheet, click the validate button, then assert the dialog is closed (`assert_no_selector "dialog[open]"`) and `.market-entrust__refusal[role=alert]` is visible with the refusal text and outside the dialog, ticks kept.

**Acceptance Criteria:**
- Given a viewport of 719px or less, when Confier loads, then the grid has three columns with ticks only, the bar shows the count, the total and "CONFIER ▸", and no stepper shows in a cell.
- Given ticked cells on a phone, when "CONFIER ▸" opens the sheet, then the recap lines hold 44px steppers on lines with several free copies, the total and the bar follow a raise, and focus stays on the pressed stepper.
- Given the sheet is open, when the viewport crosses 720px, then `data-layout` does not change, and when the sheet closes it changes once and the recap panel moves, ticks kept.
- Given the sheet is open, when Esc is pressed, then the sheet closes and the ticks stay; given it is closed and ticks are pending, Esc does nothing.
- Given the panel moved into the sheet, then the form still submits it, ids stay unique, and the outer status line keeps announcing "<n> copies, <amount> PiCoins" with the sheet closed.
- Given a viewport height under 560px, then the bar scrolls with the content; from 560px it pins above the tab bar.
- Given a refused validation on a phone, when the page re-renders with the sheet closed, then the refusal shows above the grid as a `role=alert` outside the panel and the sheet, the ticks are kept, and the sheet stays closed.
- Given the sheet is open and a copy is raised, when the selection rests, then the status line inside the sheet announces the new count and total; given the sheet is closed on the phone, then the outer line announces it and the panel's line stays empty; given the wide layout, then only the panel's line speaks.
- Given a new more valuable line appears while a line stepper has focus, then the new line sits at its ranked position, the focused stepper is the same node and keeps focus, and an unchanged order moves no line.
- Given the locale files, then `market.entrustments.new.{sheet_title,bar_action,bar_label}` and `market.entrustments.strings.bar_count` (with French `zero`) exist in en and fr and `i18n-tasks health` passes.
- Given a viewport wider than 719px, then story 38.5's screen is unchanged.

## Implementation Notes

Built without running any test or rubocop (bundler could not resolve gems in the worktree). The `bar` target was not added to the recap controller: the bar has no behaviour of its own beyond its count and total targets. `ENTRUST_CHILDREN` was dropped, the three outlets come from `ENTRUST_ACTIONS`.

## Plan Change Log

- Review: checked the diff against the plan, spec and AGENTS.md (no new write path, GET or id exposure, locale keys in en and fr with French zero form, markup free of style attributes, size and planning-id checks clean, prettier clean). No defect found; rubocop could not run in the worktree (bundler cannot resolve gems).

## Review Triage Log

## Design Notes

State rule, the same pattern as the capsule opening's:

```ts
export function layoutAsked(state: EntrustState, layout: Layout): EntrustState {
  const asked = { ...state, pendingLayout: layout === state.layout ? null : layout }
  return state.sheetOpen ? asked : settle(asked)
}
```

`settle` applies `pendingLayout` when set; `sheetShown(false)` calls it, so a layout asked during the sheet is applied once, at close.

## Verification

**Commands:**
- `npm run test:js -- entrust` -- pass (run at the end of the market run)
- `bin/rails test test/controllers/market` -- pass
- `bin/rails test test/system/market_entrust_test.rb` -- pass
- `bundle exec rubocop <touched files>`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `npm run format:check`, `npm run lint:css`, `script/check_file_sizes`, `script/check_planning_references` -- clean

**Manual checks:**
- At 390px wide with an open market: tick cells, open the sheet, raise a copy, validate; resize across 720px with the sheet open and see nothing move until it closes.
