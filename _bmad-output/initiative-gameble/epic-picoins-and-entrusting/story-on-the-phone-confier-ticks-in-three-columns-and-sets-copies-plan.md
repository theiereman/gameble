---
title: 'On the phone, Confier ticks in three columns and sets copies in the recap sheet'
type: 'feature'
ticket: '38.6'
created: '2026-11-10'
status: 'draft'
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

**Always:** one tree, two layouts: the state module (`entrust.ts` and a new `entrust_layout.ts`) holds `layout`, `pendingLayout` and `sheetOpen`; a media query change only asks for a layout, which is applied when no sheet is open and at connect; the root writes `data-layout` and asks the recap controller to place the recap (desktop slot or sheet body) only when the applied layout changes; all layout CSS is keyed on `data-layout`, never on a media query, so a held layout never half-switches; the server renders `data-layout="wide"`; the recap panel, its templates, submit button and sentences exist once (no duplicated ids), and moving the panel keeps the submit button inside the form `#entrust`; the sheet is the existing `BottomSheetComponent` opened by the bar's `bottom_sheet_opener` link, so focus trap, scrim, drag, Esc and focus return are the sheet's own; the sheet's title is "Confier" and closing returns focus to "CONFIER ▸"; the polite status region is one element, outside the sheet, always rendered, driven by the same debounce as today, so it keeps speaking while the sheet is closed; recap lines are reconciled by ref, never rebuilt, so a stepper keeps focus while it is pressed; recap steppers are the server-rendered `trades/_stepper` partial cloned from a `<template>`, 44px wide targets, shown only in the phone layout, absent for a line with a single free copy; the cell's own stepper is hidden in the phone layout and the cell only ticks; every amount in the bar goes through `drawAmount`; the bar pins (sticky above the phone tab bar and safe area) only from 560 CSS px of viewport height and scrolls with the content below that, with a 2px lime rule above it; children talk to the root by `dispatch`, the root drives them through outlets; no markup built in script; no `style` attribute in server HTML; every string in `en.yml` and `fr.yml` with French `zero` plural forms; no new `gameble:*` event; the sheet-open signal is the existing `gameble:sheet-shown`; files stay under 400 lines (TypeScript, Ruby) and 500 (CSS).

**Never:** a second recap, a second submit button or a second status region; a layout change while the sheet is open; a media-query-only phone layout; card art in the cells; a filter sheet or filter changes; the card detail entry (7), the Balance chip (8), the suspended banner (10), settings or back-office changes; any change of the preview rule, the shared fixture or the operation; a per-card confirmation; hand-edited `app/frontend/images/pixel/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Load on a phone | viewport 719px or narrower | `data-layout="phone"`, three columns, bar shown, recap in the closed sheet, cell steppers hidden | — |
| Load on desktop | wider than 719px | `data-layout="wide"`, as story 38.5 | — |
| Tick | tap a cell | lime frame and check; bar count and total follow | — |
| Open the recap | tap "CONFIER ▸" | sheet opens on the recap, focus on its first control, steppers 44px on lines with several free copies | — |
| Set copies | tap a line's `+` | copies raise within 1..free, total, bar and `copies[...]` input follow, focus stays on the stepper | — |
| Validate | tap "CONFIER n EXEMPLAIRES" in the sheet | POST as on desktop, result page | refusals re-render the page inline as today, ticks kept |
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
- The status region leaves the panel, so it speaks while the sheet is closed; the bar itself is not live.
- The bar is shown on every phone load, including with nothing ticked, so the full-cap line and the prompt stay reachable; it counts the copies that will really be entrusted and shows the exact received amount.
- The bar's action is a `bottom_sheet_opener` link (as the other sheets), title "Confier", labelled "CONFIER ▸" / "Confier ▸".
- CSS is keyed on `data-layout`; the story 38.5 media rule for the two columns and the sticky recap moves under `[data-layout="wide"]`.
- Phone-only CSS goes in a new `market-entrust-phone.css` to keep the existing files under 500 lines.
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
- [ ] `app/frontend/controllers/entrust_recap_controller.ts` -- element becomes the layout wrapper; new targets `aside`, `slot`, `sheet` (the dialog), `sheetBody`, `bar`, `barCount`, `barTotal`, `stepperTemplate`; `place(layout)` appends the aside to `sheetBody` (phone) or `slot` (wide); `sheetIsOpen()` returns the dialog's `open`; render writes the bar; keyed line reconcile (reuse a line by `data-ref`, create missing ones from the template, remove stale ones, never re-append an existing line, reflect each line's stepper with `reflectStepper` and remove it when `stepper` is null); `step` and `stepperKey` actions dispatch `copies` like the grid; keep the status debounce unchanged -- the one recap, wherever it sits.
- [ ] `app/frontend/controllers/entrust_recap_controller.test.ts` -- extend: a line stepper `+` dispatches `copies` with the line's ref and the stepper keeps focus across the re-render; lines are reused (same element after a re-render); `place("phone")` moves the aside into the sheet body and `place("wide")` back, the submit button staying inside the form; the bar shows the count and exact total; status behaviour unchanged with the panel moved.
- [ ] `app/frontend/controllers/entrust_controller.ts` -- on connect watch `window.matchMedia(PHONE_QUERY)` (guard a missing `matchMedia`), feed `layoutAsked`; add `sheetShown` action for `gameble:sheet-shown` that reads `recap.sheetIsOpen()` and feeds `sheetShown`; render writes `element.dataset.layout` and calls `recap.place` only when the applied layout differs from the last one; remove the listener on disconnect; the Esc guard stays (it already yields to an open dialog) -- the root drives the layout.
- [ ] `app/frontend/controllers/entrust_controller.test.ts` -- vitest with a stubbed `matchMedia`: layout set at connect; a change while idle switches `data-layout`; a change while the sheet is open is held and applied when `gameble:sheet-shown` reports it closed; ticks survive both switches; Esc with a dialog open is not prevented -- the switch held while the sheet is open.
- [ ] `app/helpers/market_entrustments_helper.rb` -- add `"entrust-recap" => { copies: :copies }` to `ENTRUST_ACTIONS`, keep outlets for the three children, and add `gameble:sheet-shown@document->entrust#sheetShown` to the root's actions; add `bar_count` to the strings -- wiring.
- [ ] `app/views/market/entrustments/new.html.erb`, `_recap.html.erb`, `_bar.html.erb`, `_sheet.html.erb` -- the form root gets `data-layout="wide"`; `.market-entrust__layout` carries `data-controller="entrust-recap"` and its two values (moved off the panel); layout holds the grid, a `slot` div wrapping the recap panel, the bar and the sheet inside the form; the panel drops its controller attribute and keeps its ids, templates and submit; `_bar` is a `role="group"` row with the count, an exact `PicoinAmountComponent` total and a `tag.a(**bottom_sheet_opener("entrust-recap-sheet"))` "CONFIER ▸"; `_sheet` renders `BottomSheetComponent.new(id: "entrust-recap-sheet", title: t(".sheet_title"))` with an empty body target; add the `stepperTemplate` (`trades/_stepper` with `controller: "entrust-recap"`) and move the polite status paragraph out of the panel to the wrapper -- server markup both layouts share.
- [ ] `app/frontend/styles/market-entrust.css`, `market-entrust-recap.css` -- move the 720px two-column rule and the sticky recap under `[data-layout="wide"]`; hide `.entrust-recap__stepper` and the bar in the wide layout -- layout keyed on `data-layout`.
- [ ] `app/frontend/styles/market-entrust-phone.css`, `app/frontend/entrypoints/application.css` -- create and import: under `[data-layout="phone"]` three equal columns, compact cells (name, rarity and season, value; the cell stepper and free line hidden), the recap hidden from the layout (it lives in the sheet), the bar (flex row, panel background, 2px `--color-lime` top rule, sticky above `calc(var(--tabbar-height) + env(safe-area-inset-bottom, 0px))` inside `@media (min-height: 560px)`, in flow below), the recap line's stepper with 44px buttons, the submit sticky at the bottom of the sheet body; tokens only; run `npm run lint:css` at the end -- the phone look.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `market.entrustments.new.sheet_title` ("Entrust" / "Confier"), `bar_action` ("Entrust ▸" / "Confier ▸"), `bar_label`; `strings.bar_count` with `zero/one/other` ("%{count} copies" / "%{count} exemplaires", `zero` form in French); both languages, no dynamic keys.
- [ ] `test/controllers/market/entrustments_controller_test.rb` -- the page carries `data-layout="wide"`, the bar with an opener to `entrust-recap-sheet`, the sheet dialog with its title, one submit button, one status region, the recap panel inside the form, no `style` attribute; GET writes nothing -- markup contract.
- [ ] `test/system/market_entrust_test.rb` -- one phone-width test (`resize_to 390, 844`, retrying matchers): visit with two held editions (one with two free copies), assert three columns (`data-layout=phone`, the cell stepper not visible), tick two cells, assert the bar's count and total, open "Entrust ▸", assert the dialog is open with the recap lines and a visible 44px stepper on the multi-copy line, raise it, assert the total and the bar, click "Entrust 3 copies" inside the sheet, assert the result total and the holdings; the existing desktop tests stay green at the default size.

**Acceptance Criteria:**
- Given a viewport of 719px or less, when Confier loads, then the grid has three columns with ticks only, the bar shows the count, the total and "CONFIER ▸", and no stepper shows in a cell.
- Given ticked cells on a phone, when "CONFIER ▸" opens the sheet, then the recap lines hold 44px steppers on lines with several free copies, the total and the bar follow a raise, and focus stays on the pressed stepper.
- Given the sheet is open, when the viewport crosses 720px, then `data-layout` does not change, and when the sheet closes it changes once and the recap panel moves, ticks kept.
- Given the sheet is open, when Esc is pressed, then the sheet closes and the ticks stay; given it is closed and ticks are pending, Esc does nothing.
- Given the panel moved into the sheet, then the form still submits it, ids stay unique, and the status region keeps announcing "<n> copies, <amount> PiCoins" with the sheet closed.
- Given a viewport height under 560px, then the bar scrolls with the content; from 560px it pins above the tab bar.
- Given a viewport wider than 719px, then story 38.5's screen is unchanged.

## Implementation Notes

## Plan Change Log

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
