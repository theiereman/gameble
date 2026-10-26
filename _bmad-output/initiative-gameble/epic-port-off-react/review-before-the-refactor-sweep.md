# Review before the refactor sweep

Cross-ticket review of the epic, `f2096c5b..f598eb0f` (the trade board in Stimulus, the booster's state, the booster in Stimulus, React leaving the toolchain), read-only, 2026-10-26. It scopes the refactor sweep; the sweep's plan takes its Do and Leave lists as input.

## Done when, at f598eb0f

1. Holds: nothing in app, config, test, lib, script, the package files, lockfiles, tsconfig or vite.config names react, turbo-mount or plugin-react; `app/frontend/components/` is gone.
2. `trades_test.rb` unchanged. `booster_test.rb` also lost four "Cards revealed" counter assertions (the ticket note drops the counter) and gained three tests in the booster's state ticket; both recorded in the plans, nothing to sweep.
3. Vitest 708 tests, `tsc`, `zeitwerk:check`, `packwerk`, `i18n-tasks` clean. Every exported function of `lib/booster.ts` is named in its test; in `lib/trade_board.ts` only the internal `visibleCards` is not.
4. Holds: `script/check_markup_apis` runs in `.github/workflows/ci.yml` and `config/ci.rb`, allowing only `lib/server_html(.test)?.ts`.

## Findings

| # | Where | Finding | Severity | Sweep |
|---|---|---|---|---|
| 1 | `trades_helper.rb:7,153-171,190`, `boosters_helper.rb:7,24,55,162-172` | Root wiring written twice: `trade_board_actions`/`booster_actions` and `trade_board_strings`/`booster_strings` are the same; outlets listed by hand on the board, derived from `BOOSTER_ACTIONS.keys` on the booster; naming differs (`trade_board_data` vs `booster_root_data`) | medium | yes: one shared helper |
| 2 | `boosters_controller_test.rb:97-103` vs `trades_controller_test.rb` | Only the booster's controller test checks every action route, outlet selector and `[style]` absence | low | yes, tests |
| 3 | `lib/booster_timers.ts`, `trade_board_controller.ts:144,561`, `lib/trade_board_faces.ts:67` | Generic timers module named for the booster; the board keeps its own `later()`; the face loader's retry is not disposed on disconnect (bounded to 3) | low | yes: shared `lib/screen_timers.ts`; disposing the loader optional |
| 4 | `lib/booster_templates.ts`, `booster_celebration_controller.ts:111`, fragment clones in `booster_controller.ts:323,561,599`, `trade_board_controller.ts:149`, `trade_board_side_controller.ts:93`, `trade_board_picker_controller.ts:242` | Three template-cloning variants | low | yes: shared `lib/templates.ts`; keep each call site on its variant (`cloneTemplate` drops whitespace nodes) |
| 5 | `booster_canister_controller.ts:26`, `booster_info_controller.ts:13`, `trade_board_picker_controller.ts:274`, `lib/stepper.ts:28`, `booster_stage_controller.ts:53`, `booster_actions_controller.ts:13` | Text/data/flag writers copied five times, plus inline write-if-changed in tray, plate, side, actions | low | yes |
| 6 | `trade_board_controller.ts:75,69`, `booster_zoom_controller.ts:16,23,25`, `booster_celebration_controller.ts:89`, `booster_stage_controller.ts:44,51`, `booster_plate_controller.ts:21`, `booster_controller.ts:219` | Duplicated `opensElsewhere`, `RAYS_TIERS`/`BANNER_TIERS`, `Fragments`/`ZoomFragments`, `Intent<Detail>` | low | yes |
| 7 | `trade_board_controller.ts:83-98` vs `lib/booster_markup.ts` | The board's `cardFrom`/`number` live untested in the controller | low | yes: move to lib with a test |
| 8 | `lib/stepper.ts:1`, `lib/trade_board.ts:52` | Generic stepper imports `stepperKey` from the board's module | low | yes: move it into `stepper.ts` |
| 9 | `lib/celebration.ts:103` | `nextResult` is dead since the booster in Stimulus; only its test calls it | low | yes: delete with its test |
| 10 | board side/picker controllers vs booster stage/actions/zoom | `cancelable: true` on every intent on the board, only where cancelled on the booster | low | yes: pick one rule |
| 11 | `booster_controller.ts:382-412` vs `trade_board_controller.ts:197-207` | The booster re-renders the whole screen on each of eight outlet connections (about nine renders at load); the board renders only the connecting outlet | low | yes, carefully: run the booster system tests (focus microtask) |
| 12 | `trade_board_send_controller.ts` | Child exposes `reflect(blocked)`; every other child exposes `render(view)` | low | yes |
| 13 | `trades.css:1014-1042`, `trade_board_controller.ts:516-521` | `trade-swap__ring/confetti/flash` and `trade-swap-*` keyframes outlive the removed controller | low | yes: rename to `trade-board__…` |
| 14 | `trade_board_controller.ts:332-333,557-558`, `_board.html.erb:12`, `_draft_board.html.erb:3` | Editing/swapping written as data attributes and as classes; only tests read the classes | low | no: system test reads them |
| 15 | `lib/booster_motion.ts`, `boosters_helper.rb` (lines 1-2, 16-23, 37-41, 53-54), `boosters_controller.rb:1-14`, `packs_helper.rb:39-41` | Comments that restate names, against the comment policy; the board's new code has none | medium | yes: files and methods this epic created only |
| 16 | `booster_controller.ts:225`, `boosters_helper.rb:4` | `RESERVE_PIPS = 10` twice | low | optional: count the rendered `.booster__pip` nodes |
| 17 | `config/locales/fr.yml` `booster.strings.hint_remaining`, `hint_done`, `summary`, `canister_facts` | French plurals without `zero` | low | yes: zero text identical to `one` |
| 18 | locales | Board copy split between `trades.board/side/chip.*` and `trade_board.*` | low | no: churn for no rule |
| 19 | `lib/trade_board.ts`, `lib/booster.ts` | Transition naming differs (imperative vs past participle), `apply` signatures differ | low | no: churn for no rule |
| 20 | `config/i18n-tasks.yml` | Both `strings` scopes ignored wholesale; checked by hand, every key is used | low | no |

Checked and clean in the epic's lines: planning ids, `style=` in the screens' views and helpers, database ids, Pundit `authorize` on every action, script-built nodes under aria-hidden parents, dead CSS from the React markup, unused Stimulus targets and values. "island" survives only in `test/system/booster_test.rb` (kept) and fixture strings in `test/lib/post_deploy_hook_test.rb`.

## Deferred and rejected items from the plans

- Throw inside a booster sequence keeps the navigation lock (medium, unverified): not for the sweep; behaviour change, own ticket.
- Phone closing hint and the no-season canister label untested: yes, test-only.
- "Reveal all" looks enabled during a Légendaire's hold: no, visible; awaits the author.
- Trade picker paging past 36, fold button, comparison chips, `BOARD_ACTIONS` never checked against the root's methods: yes, as system tests (pairs with 2).
- Leave: the broad `.booster [hidden]` rule, `folded_hint` in strings and markup, "4 cards at most" copy, lines computed on both sides, happy-dom version, the status list in Ruby, TS and CSS.
- Out of scope: `booster_controller.ts` at 1,324 lines (file sizes belong to the code-quality epic).

## Sweep scope

**Do**
- One Ruby helper for a rich screen's root data (action routes, outlet selectors, strings) used by `TradesHelper` and `BoostersHelper`; the booster-style wiring and `[style]` assertions in `trades_controller_test.rb`.
- Shared front-end helpers replacing the copies: `lib/screen_timers.ts` (used by the board's swap), `lib/templates.ts`, a text/data/flag writer, `opensElsewhere`, one banner/rays tier list, one `Fragments` type, one `Intent<Detail>` type.
- The board's markup readers into lib with a test; `stepperKey` into `stepper.ts`.
- Delete `nextResult` and its test.
- One rule for `cancelable`.
- `reflect` → `render` on the send child; `trade-swap__*` → `trade-board__*`.
- Strip name-restating comments from the files and methods this epic created.
- French `zero` forms on the four keys.
- System tests for the picker's paging, fold and chips, the phone closing hint, the no-season canister label.
- Optional: render only the connecting outlet in the booster; drop the TS `RESERVE_PIPS`; dispose the face loader on disconnect.

**Leave**
- `test/system/booster_test.rb`; the `trade-board--editing`/`--swapping` classes.
- The `trades.*` / `trade_board.*` locale layout; transition naming.
- The lock-on-throw and Reveal-all items.
- Pre-epic comment and planning-id debt, file sizes.
