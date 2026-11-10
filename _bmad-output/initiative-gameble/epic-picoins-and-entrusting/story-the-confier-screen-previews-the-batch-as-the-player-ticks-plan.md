---
title: 'The Confier screen previews the batch as the player ticks'
type: 'feature'
ticket: '38.5'
created: '2026-11-10'
status: 'built'
baseline_revision: '10d2b80544811ede551472acf4fbf6427f618f2d'
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

**Problem:** Confier is a plain form of number fields: the player cannot search, tick, see the recap, the amount really received under the daily cap, or the copies that will stay, before validating.

**Approach:** Make Confier a rich screen: one root `entrust` controller holding a pure state module (`app/frontend/lib/entrust.ts`), with child controllers for the filters, the grid and the recap, all fed by server-rendered markup and templates. The preview applies the operation's rule (list order is most valuable first, whole copies, a copy that does not fit is skipped, a cheaper one may pass) to the values and the cap left that the server drew, and is tested against the operation on one shared fixture. Epic requirements R5, R6 (desktop), R16 (client side).

## Boundaries & Constraints

**Always:** the server draws values, the cap left (`daily_cap - MintedToday`, floored at 0, read at draw) and the settings token; the client never invents a value; the preview orders ticked cells by their position in the server's list (value, season, title, ref: the order the controller already sends); a line of `n` copies entrusts `min(n, cap_left / value)` and the rest stay; "VOUS RECEVEZ" is the sum of what fits; the stepper reaches every free copy, an only copy included; DOUBLONS keeps editions of which the player owns two or more copies, on by default; no markup built in script, only server `<template>`s cloned and text, attributes and `hidden` written; amounts drawn by cloning a server-rendered `PicoinAmountComponent` and filling it through the client `picoins` helper (exact form, accessible text from a locale string); a ticked cell posts `copies[<card slug>:<season number>]` as today (refs, never ids); children talk to the root by `dispatch`, the root drives them through outlets; the page speaks to the chrome through no new `gameble:*` event; server HTML carries no `style` attribute; a refusal (busy, nothing fits, amounts changed) re-renders the screen inline, keeps the ticks (clamped to the free copies of the redrawn list) and redraws values, cap and token from the answer; the recap carries a server-rendered sentence "Les cartes confiées ne vous sont pas rendues." (with an id) and the Rare-or-better note (with an id, shown only while an entrusted Rare or better exists); the submit button's `aria-describedby` lists the sentence id, plus the note id only while the note is shown; the polite status region is empty at load, then posts "<n> exemplaires, <amount> PiCoins" (accessible amount form) after about 500 ms without change, never when the text is unchanged, and never moves focus; filters are inline chips (search, rarity chips, DOUBLONS) with no filter sheet or overlay; every string in `en.yml` and `fr.yml`, French plural keys with a `zero` form; the GET writes nothing; files stay under 400 lines (TypeScript, Ruby) and 500 (CSS).

**Never:** the phone layout, three columns, the bottom bar and the recap sheet (story 6), the card detail entry (7), the Balance chip (8), the suspended banner partial (10), the settings or back-office changes; card art in the cells; a client copy of any value or cap; a per-card confirmation or warning for Rare or better; a second amount component; an Esc that navigates or clears the ticks; hand-edited `app/frontend/images/pixel/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tick | press a cell, or Space/Enter on the focused one | cell ticked at 1 copy with the lime frame and check, recap line added | — |
| Stepper | cell with 3 free, stepper to 3 | copies 3, clamped 1..free, recap and total follow | — |
| Keys | focus a ticked cell, `+` / `−` | copies change within 1..free; on an unticked cell nothing | — |
| Arrows | focus in the grid | arrows, Home, End move the one tab stop between visible cells | — |
| Over the cap | 50,000 left; ticked Legendary (100,000), 2 Uncommon (2,000), Common (1,000) | recap lists the Legendary first, marks it as staying and names it; VOUS RECEVEZ 5,000; gauge previews the use; button reads CONFIER 3 EXEMPLAIRES | — |
| Partial line | 2,500 left, 3 Commons at 1,000 | 2 counted, 1 named as staying | — |
| Rare or better | an entrusted Rare, Epic or Legendary | the "À noter" note names it; never blocks | — |
| Full cap | `cap_left` 0 | validation disabled, line "Votre plafond du jour est atteint. Il se renouvelle à 00:00 UTC." | — |
| Nothing ticked | no tick | recap prompts to choose, validation disabled | — |
| Filtered out | a ticked cell hidden by a filter | stays ticked and in the recap | — |
| Filters empty | DOUBLONS on and no double | "no match" line with a clear action | — |
| Empty | no free copy at all | "Aucune carte à confier." with OUVRIR UNE CAPSULE | — |
| Amounts changed | settings version moved after the draw | 422, inline refusal, new values and token drawn, ticks kept | `amounts_changed` message |
| Nothing fits / busy | server refuses | inline refusal, ticks kept | `nothing_fits` / `market_busy` message |
| Esc | ticks pending; filters are inline chips on this desktop-only story, so no overlay exists | nothing happens: ticks, filters and page untouched | — |
| Market closed | closed version | screen usable, validation disabled | page notice as today |

</frozen-after-approval>

## Code Map

- `app/controllers/market/entrustments_controller.rb` -- `new`/`create`, `load_page`, `ticked`, `most_valuable_first`; add `@cap_left`, `@owned`-aware list, inline `@refusal` instead of `flash.now`.
- `app/views/market/entrustments/new.html.erb` (+ new partials) -- the plain form to replace; keep sign-in, closed and empty notices.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- `Copy` lacks the owned quantity DOUBLONS needs; list is already sorted most valuable first.
- `app/domains/game/app/operations/game/market/entrust_cards.rb`, `minted_today.rb`, `models/game/market/settings.rb` -- the rule to mirror; `token`, `daily_cap`, `entrustment(rarity)`.
- `app/frontend/lib/{stepper,grid_keys,i18n,picoins,dom_writes,templates,screen}.ts` -- reuse: `reflectStepper`, `quantityFromButton/Key`, `keepStepperFocus`, `nextIndex`, `columnsOf`, `formatNumber`, `picoins`, `writeText`, `cloneFirstElement`, `Intent`.
- `app/frontend/controllers/trade_board_controller.ts`, `trade_board_picker_controller.ts`, `lib/trade_board.ts`, `lib/trade_board_filter.ts` -- the pattern to follow (root with outlets, state module, filters, chips, `.trade-pick__*` frame and check CSS in `trades-picker.css`).
- `app/views/trades/_picker.html.erb`, `_pick.html.erb`, `_stepper.html.erb` -- markup for the search, chips, cell with toggle button and check, stepper partial (its filter sheet and `BottomSheetComponent` are not reused here: inline chips only) (reusable with `controller:`).
- `app/components/gauge_component.rb`, `app/frontend/lib/gauge.ts` (`litSegments`), `controllers/side_gauge_controller.ts` -- the cap gauge.
- `app/components/picoin_amount_component.rb`, `app/frontend/lib/picoins.ts`, `test/fixtures/files/picoin_forms.json` -- amounts.
- `app/frontend/styles/market-entrust.css` (125 lines), `trades-picker.css`, `tokens.css`, `app/frontend/entrypoints/application.css` -- styles and imports.
- `config/locales/en.yml:2194`, `fr.yml:1935` -- `market.entrustments.*`; Copy deck, Confier of `ux-gameble/EXPERIENCE.md` (line 180) gives the French lines; `catalog.rarity.*` exist.
- `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb` (uses `fill_in "copies[...]"`), `test/support/{market,holdings}.rb`, `test/domains/game/market/entrust_cards_test.rb` -- tests to adapt and mirror.

## Tasks & Acceptance

**Execution:**
- [ ] `test/fixtures/files/entrust_preview_cases.json` -- create the shared cases: `{ name, values: {rarity: amount}, cap_left, lines: [{ rarity, copies }] (in page order), entrusted: {rarity: n}, stayed: {rarity: n}, received }`; one line per rarity; cover under the cap, Flow 8, skip then fit, partial line, nothing fits, cap zero, an exact fit, a cheaper copy after a skipped one -- one source for both sides. `cap_left` is the cap LEFT at the draw, not the stored daily cap (a stored cap must stay positive: `game_market_settings` checks `daily_cap > 0`); a cap-zero case is `cap_left: 0` with a ticked line, expected `entrusted` empty, `received` 0, `stayed` equal to every ticked line. A case whose operation answers `nothing_fits` (nothing fits, cap zero) keeps `entrusted: {}`, `received: 0` and `stayed` equal to the ticked copies per rarity.
- [ ] `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- add `owned` (holding quantity) to `Copy` and the SQL -- DOUBLONS reads it.
- [ ] `app/frontend/lib/entrust.ts` -- pure state module: `start(copies, capLeft, ticked)`, `toggle`, `setCopies`, `bump` (ticked only, clamped 1..free), `setFilter` (query folded for accents and case, rarities, doubles default true), `clearFilters`, `visible`, `preview` (ordered lines by list position with entrusted and stayed counts, `received`, `capUsed`, rare-or-better entrusted names, count, `full`, `canValidate`, `pending`), `moveActive` over visible cells via `nextIndex` -- no DOM.
- [ ] `app/frontend/lib/entrust.test.ts` -- vitest: ticks, steppers (only copy reachable), keys, ordering, filters keeping hidden ticks, cap preview against every row of the shared fixture (ties each case to the operation).
- [ ] `app/frontend/lib/entrust_view.ts` -- view models for grid, filters and recap from the state, and `drawAmount(node, amount, {locale, accessible})` filling a cloned amount (figure through `picoins`, `aria-label` from the locale string) -- keeps controllers thin.
- [ ] `app/frontend/controllers/entrust_controller.ts` -- root: values `locale`, `capLeft`, `open`, `strings`, `copies` read from cell data, `ticked` from the server; owns the state, handles child events (`filter`, `toggle`, `copies`, `bump`, `move`, `clear`), renders through outlets, `data-pending-edit` while ticks exist, document `keydown` Esc guard that never navigates or clears.
- [ ] `app/frontend/controllers/entrust_filters_controller.ts` -- inline filters, no sheet and no overlay: search input, rarity chips, DOUBLONS chip (all always visible), count of active filters, clear; dispatches `change`, `clear`; no Esc handling of its own.
- [ ] `app/frontend/controllers/entrust_grid_controller.ts` -- cells, one tab stop with arrows, Space/Enter/press toggle, `+`/`−`, stepper buttons and keys via `lib/stepper`, hidden `copies[...]` input enabled only when ticked, empty-match line; dispatches `toggle`, `copies`, `bump`, `move`; visible hint of the keys.
- [ ] `app/frontend/controllers/entrust_recap_controller.ts` -- recap: clones line and amount templates, VOUS RECEVEZ, gauge segments (`litSegments`), stays list, Rare-or-better note, full-cap line, button label "CONFIER n EXEMPLAIRES" and disabled state; the server-rendered "not given back" sentence stays visible (never cloned) and the controller keeps the button's `aria-describedby` equal to that sentence id plus the Rare-or-better note id only while the note is shown (removes the id when hidden); polite status region (`role="status"`, `aria-live="polite"`): empty at load, then writes "<n> exemplaires, <amount> PiCoins" (n through the locale plural string, amount in its accessible form) after a 500 ms debounce of no change, skipped when the text equals the last one posted, never touching focus.
- [ ] `app/controllers/market/entrustments_controller.rb` -- pass `@cap_left`, set `@refusal` from the failure on 422 (rendered inline, no flash), keep `@ticked`.
- [ ] `app/views/market/entrustments/new.html.erb`, `_filters.html.erb`, `_grid.html.erb`, `_cell.html.erb`, `_recap.html.erb` -- root `data-controller="entrust"` with outlets and values, cells as `li` with toggle button, check, edition, `PicoinAmountComponent` value, free count, stepper (when free > 1) from `trades/_stepper` and the hidden input; recap panel, templates, `GaugeComponent`, the "not given back" sentence with an id, the Rare-or-better note with an id (hidden by default), an empty polite status region, `ButtonComponent` submit with `aria-describedby` set to the sentence id; empty and sign-in notices unchanged -- server markup the controllers drive.
- [ ] `app/frontend/styles/market-entrust.css`, `app/frontend/styles/market-entrust-recap.css`, `app/frontend/entrypoints/application.css` -- grid with the picker's lime frame and check, recap panel beside the grid on desktop (stacked below it under the desktop breakpoint, phone untouched), gauge, stay lines with the alert edge, rare note on the sunken panel; tokens only; import.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- search, filters, DOUBLONS, recap, VOUS RECEVEZ, cap gauge label, stays and Rare-or-better sentences (French lines of the Copy deck; fr "Les cartes confiées ne vous sont pas rendues." and its en line; the polite status line with `zero/one/other` for the copies), full-cap line, nothing-ticked prompt, key hint, `submit` with `zero/one/other`, steppers' labels, amount accessible string for the client -- both languages.
- [ ] `test/domains/game/market/entrust_preview_cases_test.rb` -- include `Holdings`, `MarketSettings`; per fixture case (one test per case, name from the case): `open_market!` with the case `values` as `entrustment_<rarity>` and a fixed positive `daily_cap` (`CAP = 1_200_000`, a constant of plain integers, no model named in the class body); pre-mint `CAP - cap_left` through `Game::Market::Mint.credit(player_id:, amount:, settings_id:)` when that is positive (as `minted_before` in `entrust_cards_test.rb`), so `cap_left` 0 mints the whole cap and the stored cap is never zero (`Settings` rows are read-only and checked `daily_cap > 0`); one card-season per rarity from the catalog fixtures (`common_card_one`, `uncommon_card_one`, `rare_card_one`, `legendary_card_one`, `portal_one` for epic), the player holding each ticked line's copies; call `EntrustCards` with `lines` built in the case's page order (a Hash keeps insertion order, which is the order the rule reads). Compare in rarity terms: on `Success`, `entrusted` is `value.copies` per rarity read back from `ArchiveDeposit` (card-season to rarity), `received` is `value.minted`, `stayed` is `value.stayed` mapped from `card_season_id` to rarity with `copies`; on `Failure(:nothing_fits)` (the nothing-fits and cap-zero cases, where `result.value!` does not exist) assert `result.failure == :nothing_fits`, then expect `entrusted` empty, `received` 0 and `stayed` built by the test from the ticked lines themselves (every ticked rarity with its copies, since a failure carries no stayed list), and assert no ledger entry, deposit or holding changed. Assert the minted total equals `received` in every case -- proves the client rule equals the operation.
- [ ] `test/controllers/market/entrustments_controller_test.rb` -- update to the new markup (hidden inputs, data values, token, inline refusal, ticks kept on 422, no `style`, GET writes nothing, `owned` drives DOUBLONS data).
- [ ] `app/frontend/controllers/entrust_recap_controller.test.ts` -- vitest on the recap controller with fake timers: status empty at load; one change then 500 ms posts "2 exemplaires, 5,000 PiCoins" once; rapid changes within 500 ms post only the last; an unchanged text posts nothing again; focus stays where it was; `aria-describedby` on the button is the sentence id alone, gains the note id when a Rare is entrusted and loses it when not.
- [ ] `test/system/market_entrust_test.rb` -- adapt the three existing tests to ticking; add the desktop flow (filter, tick two cells, raise one stepper, recap and VOUS RECEVEZ change, a copy over the cap named, validate, result) and the amounts-changed flow (a new settings version inserted while the form is open: refusal inline, new amounts, ticks kept); retrying matchers only; assert the "not given back" sentence is visible, the button's `aria-describedby` names it and (after ticking a Rare) the note, the status region is empty on load then reads the count and amount, and Esc with ticks pending leaves ticks, filters and page unchanged.

**Acceptance Criteria:**
- Given 50,000 cap left, when the player ticks a Legendary, two Uncommon and a Common, then the recap lists the Legendary first as staying, VOUS RECEVEZ reads 5,000 and the button reads CONFIER 3 EXEMPLAIRES.
- Given the shared cases, when the state module and `EntrustCards` run them, then they agree on entrusted, stayed and received.
- Given a cell with several free copies, when the stepper or `+` is used, then it reaches the free count and no further; given an only free copy, it ticks but shows no stepper.
- Given DOUBLONS on by default, when the player turns it off, then single-copy editions appear and can be ticked.
- Given the recap, then "Les cartes confiées ne vous sont pas rendues." shows and CONFIER n EXEMPLAIRES has `aria-describedby` listing that sentence, plus the Rare-or-better note only while it is shown.
- Given ticks changing, then the status region is empty at load, posts "<n> exemplaires, <amount> PiCoins" after about 500 ms without change, not again for an unchanged text, and focus never moves.
- Given a full cap, then validation is disabled and the line shows; given a ticked selection and Esc with no overlay open, then ticks and page are untouched.
- Given settings changed behind the open form, when the player validates, then the refusal shows inline, new amounts are drawn, the ticks are kept and nothing is minted.
- Given no free copy, then "Aucune carte à confier." and OUVRIR UNE CAPSULE show.

## Implementation Notes

Decisions settled in planning (no human checkpoint in this run):

- Cells are text cells (name, rarity, season, value, free count) as the page has them: the story names rarity, season and value, and card art (`card-s`) would need the card faces loaded per cell; it can join later without touching the state module.
- Filters are search by game name, the five rarity chips and DOUBLONS; genre and goal filters of the trade picker are left out because `EntrustableCopies` carries neither. DOUBLONS matches an owned quantity of two or more (reserved copies included), the stepper max is the free count.
- Validation stays enabled when a selection fits nothing (the server's `nothing_fits` refusal shows inline, as the story lists it); it is disabled for a zero cap left, for no tick and for a closed market.
- Esc: no global Esc navigation exists yet, so the root only guards it (no clearing, no leaving) and exposes `data-pending-edit` for the day one exists; there is no filter sheet on this desktop-only story (filters are inline chips), so Esc has nothing to close; a sheet belongs to the phone story.
- Inline refusal replaces the flash on 422 so the message sits by the recap; the controller still renders `new`, so the ticks come back from the posted refs and are clamped to the redrawn free counts, dropping any no longer free.
- Hidden `copies[...]` inputs, enabled only when ticked, keep the POST shape of stories 1 and 3; the phone layout only stacks the recap under the grid until story 6 adds its bar and sheet.
- The shared fixture stores the cap left, not the stored cap: the Ruby test picks a positive daily cap and pre-mints the difference, because a zero cap is not a valid settings row; a `nothing_fits` failure carries no `stayed`, so the Ruby test derives it from the ticked lines, which is what the client preview shows for a selection that fits nothing.
- The state module's cap rule mirrors `split_by_cap`; the shared fixture, read by vitest and a Ruby test running the operation, keeps them from drifting.

## Plan Change Log

- 2026-11-10 review: checked the diff against the plan, spec and AGENTS.md (read-only GET, tokens in markup, Pundit unchanged, en/fr parity with zero forms, no style attributes, file sizes, preview rule against the operation). No defect found; no code change. Ruby static checks (rubocop, packwerk) could not run in the worktree (gems missing); `ruby -c` is clean.

## Review Triage Log

## Design Notes

Preview rule, the same as `EntrustCards#split_by_cap`:

```ts
let left = capLeft
for (const copy of listOrder(ticked)) {
  const fits = Math.min(copy.copies, Math.floor(left / copy.value))
  left -= fits * copy.value
}
```

## Verification

**Commands:**
- `npm run test:js -- entrust` -- pass (run at the end of the market run)
- `bin/rails test test/domains/game/market test/controllers/market` -- pass
- `bin/rails test test/system/market_entrust_test.rb` -- pass
- `bundle exec rubocop <touched files>`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `npm run format:check`, `npm run lint:css`, `script/check_file_sizes`, `script/check_planning_references` -- clean

**Manual checks:**
- On desktop, open Confier with an open market: filter, tick, step and use the keys; the recap and VOUS RECEVEZ follow, the hint of keys is visible.
