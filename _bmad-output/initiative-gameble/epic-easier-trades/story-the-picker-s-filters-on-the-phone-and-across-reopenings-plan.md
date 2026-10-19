---
title: "The picker's filters on the phone and across reopenings"
type: 'feature'
ticket: '3'
created: '2026-10-19'
status: 'built'
baseline_revision: 'ebeaea4045b3e8df40f59b104c0bae3bf91340fe'
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

**Problem:** On a phone the picker's search, two chip groups, match count and clear action push the card grid down to a sliver of the full-height sheet; and the filter state lives in `TradePicker`, which `TradeBoard` unmounts on close, so every reopening starts from no filter (issue 63, point 4).

**Approach:** Lift the per-side filter state (the `SideFilter` entry 2 shaped, plus whether the chip groups are unfolded) from the picker to the board, one per side, passed down as controlled props; under 720px the two chip groups fold behind a "FILTRES" disclosure button showing the count of chips on, while the search, the match count and the clear action stay outside the fold and above the scrolling grid.

## Boundaries & Constraints

**Always:**
- The board holds one picker filter state per side index, created fresh when the island mounts (`EMPTY_FILTER`, folded); the picker reads and changes it through props. Closing (PLACER, ANNULER, ✕, Esc, scrim, `turbo:before-cache`, `gameble:trade-editing`) keeps it; nothing resets it but CLEAR or a new mount (another trade, another page).
- Fold state is part of what is kept: the picker reopens folded or unfolded as left.
- Fold only under 720px (the existing phone media query in `trades.css`); at 720px and above the disclosure button is not displayed and the groups always show, whatever the fold state.
- Disclosure: a `<button type="button">` with `aria-expanded` and `aria-controls` naming the groups' container; chevron (`pixel_icon("arrow-small-right", class: "filters__chevron")`, passed as a prop like `closeIcon`), title "FILTRES" / "FILTERS", and a count badge of rarities + chips on (search not counted, it stays visible), hidden at zero, preceded by a visually hidden "Filtres actifs :" like the collection's zone. Reuse the collection's `.filters__chevron`, `.filters__title`, `.filters__count` looks; the chevron turns 90° when expanded.
- Order in `.trade-picker__filters`: search, disclosure button, groups (rarities, collections), foot (match count + clear). The foot never folds; clear still resets search, rarities and chips and focuses the search, and leaves the fold as is.
- Strings in `en.yml` and `fr.yml` under `trades.island.strings` (`filters_title`, `filters_active`) with matching `TradeBoardStrings` fields. No `style` attribute, no new `gameble:*` event, no browser storage, no planning ids or explanatory comments in code.

**Never:** No change to `filterCards`, the chips, the per-card counts, face rendering or paging (entry 4), selection or sending; no keeping filters across page loads or trades; no folding on desktop.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Phone, first open | 390px, picker opened | search, "FILTRES" button collapsed, no badge, match count; chips hidden; grid fills the rest | — |
| Unfold | tap FILTRES | rarity and collection chips show; `aria-expanded="true"` | — |
| Fold with chips on | Rare + their duplicates on, tap FILTRES | chips hidden, badge "2", match count and EFFACER LES FILTRES still visible | — |
| Reopen same side | filters set, PLACER or ANNULER, reopen | same query, chips, fold state; grid filtered as left | — |
| Other side | friend side filtered, open own side | own side empty filter, folded | — |
| Another trade | navigate to another trade or draft | every side empty and folded | — |
| Clear | EFFACER LES FILTRES | filters empty, badge hidden, fold unchanged, focus on search | — |
| Desktop | ≥ 720px | no FILTRES button, groups shown even if folded state | — |

</intent-contract>

## Code Map

- `app/frontend/components/TradePicker.tsx` -- holds `filter` in `useState(EMPTY_FILTER)` (:37) and updates it with functional `setFilter` (:121-150); `clearFilters` (:62-65); the filters block (:107-163). Replace the local state with props `filter`, `folded`, `onFilter(next)`, `onFold(next)` (or one `filters`/`onFilters` pair); wrap the two fieldsets in a container with an id, add the disclosure button before it.
- `app/frontend/components/TradeBoard.tsx` -- `picking` index (:111), renders `TradePicker` (:258-270), `TradeBoardProps` (:83-94), `TradeBoardStrings` (:35-81). Add the per-side state (`useState(() => sides.map(() => FRESH))`), pass it and its updater; add `chevronIcon` to props and `filtersTitle`, `filtersActive` to strings.
- `app/frontend/lib/trade_board.ts:105-120` -- `SideFilter`, `EMPTY_FILTER`, `filtering`. Add the per-side picker filter type (filter + folded) with its fresh value and an `activeChips(filter)` count (rarities + chips); `+ trade_board.test.ts` rows for it.
- `app/helpers/trades_helper.rb:156-164` -- `trade_island_props`: add `chevronIcon: pixel_icon("arrow-small-right", class: "filters__chevron").to_str`. Strings come from `trade_island_strings` (camelized `trades.island.strings`), nothing else to change.
- `app/frontend/styles/trades.css` -- `.trade-picker__filters` (:663-668); phone block `@media (max-width: 719px)` (:870+). Add `.trade-picker__fold` (button reset, flex row like `.filters__summary` in `collection.css:276-283`, `min-height: var(--space-touch-min)` on phone), hidden by default and shown in the phone block; `.trade-picker__groups` (flex column, gap `var(--space-3)`) and its folded modifier `display: none` only in the phone block; chevron rotation on `[aria-expanded="true"]`.
- `config/locales/en.yml`, `fr.yml` -- `trades.island.strings`: fr `filters_title: "Filtres"`, `filters_active: "Filtres actifs :"`; en "Filters", "Active filters:" (as `library.filters.title`/`active`).
- `test/controllers/trades_controller_test.rb:412-416` (`island_props`) -- assert `chevronIcon` is an svg and `strings.filtersTitle` is "Filtres" on a draft or counter board.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md:254` (Card picker behaviour row) -- add: on the phone the chip groups fold under "FILTRES" with the count of chips on, search, count and clear in view; filters and fold are kept while the board stays open.
- Do not touch `test/system/` (disabled).

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/trade_board.ts` + `trade_board.test.ts` -- picker filter state type and fresh value, `activeChips` -- the state the board keeps.
- [x] `app/frontend/components/TradeBoard.tsx` -- per-side state, pass to the picker, `chevronIcon` and strings types -- filters survive the picker's unmount.
- [x] `app/frontend/components/TradePicker.tsx` -- controlled filters, disclosure button, groups container -- the phone fold.
- [x] `app/frontend/styles/trades.css` -- fold button and folded groups under 720px only.
- [x] `app/helpers/trades_helper.rb`, `config/locales/en.yml`, `fr.yml`, `test/controllers/trades_controller_test.rb` -- chevron prop, two strings, their assertion.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- the picker row.

**Acceptance Criteria:**
- Given Hugo on a 390px phone in Lea's picker, when he unfolds FILTRES, checks Rare and their duplicates, then folds, then the chips hide, the badge reads 2, and the match count and the clear action stay visible above the grid.
- Given that state, when he taps ANNULER and reopens Lea's picker, then the same chips are on, the fold is as left and the grid shows the same matches; his own side's picker opens with no filter.
- Given Hugo leaves for another trade's board, when he opens a picker there, then no filter is on and the groups are folded.
- Given a desktop width, then no FILTRES button shows and both chip groups are visible.

## Implementation Notes

- The board keeps `PickerFilters[]` (`{ filter, folded }`) per side index; `TradePicker` is controlled through `filters`/`onFilters`. Every transition is a pure function in `trade_board.ts` (`freshPickerFilters`, `replacePickerFilters`, `withFilter`, `clearedFilters`, `toggledFold`, `activeChips`), covered by vitest.
- The disclosure button is `display: none` outside the phone query and the folded modifier only applies inside it, so desktop never folds.
- Matrix audit: "Reopen same side", "Other side", "Another trade" (fresh state per mount) and "Clear" are covered at state level by vitest; the CSS/DOM rows ("Phone, first open", "Unfold", "Fold with chips on", "Desktop") and the reopen/other-trade flow end to end were run in headless Chrome at 390px and 1400px with a throwaway Capybara script kept out of the repo (system tests stay disabled): button visible and collapsed, chips hidden, badge 2 with match count and clear in view when folded, same chips and fold after ANNULER and reopen, own side and another friend's draft fresh and folded, no button on desktop.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none; the quick lens checked every acceptance criterion, the rules and the plan's constraints against the diff.

## Design Notes

A `<details>` cannot stay open on desktop while folding on the phone without script, so the fold is a disclosure button whose effect CSS limits to the phone query; the desktop never sees a folded state. The count badge counts chips only because the search field stays in view.

```ts
export type PickerFilters = { filter: SideFilter; folded: boolean }
export const FRESH_PICKER_FILTERS: PickerFilters = { filter: EMPTY_FILTER, folded: true }
export const activeChips = ({ rarities, chips }: SideFilter) => rarities.length + chips.length
```

Keep every state change a pure function in `trade_board.ts` so vitest covers the matrix: fresh states for n sides, replacing one side's state (the other side untouched), clearing (filter emptied, fold kept), toggling the fold. The components only wire them.

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1803`; never run system tests)
- `npm run test:js` and `npm run typecheck` -- expected: all pass
- `bin/rails test test/controllers/trades_controller_test.rb` -- expected: pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: green

**Manual checks:**
- In a headless browser at 390px, the picker folds and unfolds with count and clear in view, and reopens as left.

## Auto Run Result

- **Summary:** the board keeps each side's picker filters (search, rarities, collection chips) and fold state, so closing and reopening the picker in the same trade finds them as left; a new mount (another trade or page) starts empty and folded. Under 720px the rarity and collection chips fold behind a "FILTRES" disclosure button with a count badge of chips on; the search, the match count and the clear action stay in view above the grid. Desktop is unchanged.
- **Files:** `app/frontend/lib/trade_board.ts` (+ test: `PickerFilters` and its pure transitions, `activeChips`), `app/frontend/components/TradeBoard.tsx` (per-side state, chevron prop, strings types), `TradePicker.tsx` (controlled filters, disclosure button, groups container), `app/frontend/styles/trades.css` (fold under 720px only), `app/helpers/trades_helper.rb` (`chevronIcon`), `config/locales/{en,fr}.yml` (`filters_title`, `filters_active`), `test/controllers/trades_controller_test.rb` (strings and icon in props), `ux-gameble/EXPERIENCE.md` (Card picker behaviour row).
- **Review:** quick; 0 findings, nothing patched, deferred or rejected. Follow-up review not recommended.
- **Verification:** `bin/ci` green (2710 runs, 0 failures, seeds); `npm run test:js` 437 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` clean; headless Chrome at 390px and 1400px (throwaway script, not committed) confirmed the matrix rows.
- **For the author to check:** on a phone the chips start folded on every new board and are then kept folded or unfolded as left; the disclosure reads "FILTRES" with the count of chips on, like the collection's zone.
- **Residual risks:** each keystroke in the search now re-renders the board, not only the picker; invisible at today's volumes, entry 4 measures with thousands of cards.

