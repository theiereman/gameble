---
title: 'View transitions only where the screen really changes'
type: 'feature'
ticket: '27'
created: '2026-10-25'
status: 'in-progress'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every Turbo visit to another path is a screen change: Turbo starts a View Transition (both pages carry `<meta name="view-transition" content="same-origin">`) and `.main`, named `screen`, slides out and in (`app/frontend/styles/shell.css`). Between the steps of Échanges (its list, a trade's board, the friend chooser, a draft, a counter) the list and the frame stay on screen, so the slide means nothing (walkthrough finding 19). The author settled it (2026-10-24): keep the transition only where the screen changes (hub to a screen, a grid to a card detail); the Échanges steps and the sub-views that keep the same frame lose it.

Inventory today: the hub to any screen, the collection's entry, its grids and albums, a grid or an album or the booster to a card detail, a profile to its collection or set, Back and Forward: a slide. A visit to the same path (a refresh, a form sent back to it, a tab, filter or page of the same screen): no slide (`html[data-screen-change=same]`) but Turbo still starts a transition of the root picture with no animation. The card detail's ◀ ▶ (`lib/sub_view_step.ts`): the page meta is held at `none`, only the card moves. The back-office: no slide. The Échanges steps: a slide, the one to remove.

**Approach:** One rule says whether a visit keeps the frame of the page shown: the same path, or two pages of Échanges, except on the phone (under 720px, where the list and a board are each their own view, and the board slides over the list as EXPERIENCE.md's phone sub-view says) a visit to or from the list. A visit that keeps the frame gets the `same` mark, as today, and holds the page's view-transition meta at `none` until the next page's head brings it back, so Turbo starts no transition at all; the card detail's step shares that hold. A Back or Forward is judged from the path last shown instead of always counting as a change. Reduced motion (no meta) and browsers without `startViewTransition` are untouched; the trade board's React island is not changed.

</intent-contract>

## Implementation Notes

Oneshot: one pure rule, a small change to the screen-change mark and to the step's meta hold, CSS comments and tests; no server code.

- **Deviation from the Approach: no meta hold.** Turbo 8.0.23 caches the page being left after `turbo:visit` (`Visit#loadResponse` calls `cacheSnapshot()` and clones the live document a tick later), so a meta held at `none` from `turbo:visit` would land in the cached snapshot of any cacheable page and switch off the transition on a later Back to it, or on its preview. Releasing it at `turbo:before-cache` would make the hold a no-op on every cacheable page, since that event fires before Turbo reads the meta. The change therefore widens the existing mechanism only: a frame-keeping visit gets `html[data-screen-change=same]`, so `.main` is not captured apart and the root picture (`animation: none`) swaps at once, exactly as a same-page visit does today. Turbo still calls `startViewTransition` for it, with nothing moving; the author judges the result on staging. `lib/sub_view_step.ts` is untouched.
- `app/frontend/lib/screen_change.ts` (new): `keepsFrame(fromPath, toPath, { phone })`, true for the same path or two pages under `/:locale/trades`, except under 720px (`PHONE_WIDTH`, the breakpoint where `styles/trades.css` shows the list or a board alone) a visit to or from the list itself (`/:locale/trades`). Tested in `screen_change.test.ts`.
- `app/frontend/controllers/starfield_controller.ts`: the mark uses `keepsFrame`; a restoration (Back, Forward) is judged from the path at the last `turbo:load` instead of always counting as a screen change, so Back between two trades keeps the frame. Side effect: a Back to an entry with the same path (another page or filter of one screen) no longer slides either, which fits the rule.
- `app/frontend/styles/shell.css`: the `same` rule's comment names the steps of Trades; no rule changed. The meta, reduced motion and browsers without `startViewTransition` are untouched; so is the React island.
- Inventory checked: the hub to a screen, the collection's entry, grids and albums, any grid or the booster to a card detail, a profile to its collection or set, Friends, Feed, Settings: still a slide. Same-path visits (refresh, tabs, filters, pages, the chooser to a draft) and the card detail's ◀ ▶ already had none. Only the steps of Trades changed.
- Tests: `trades_test.rb` "on a desktop the screen slides into and out of Trades, never between its steps" (hub → list slides; list → board, board → board, the in-place counter, Back to the earlier board keep the frame; the wordmark to the hub slides), fails against the old controller at the first board; the phone test now asserts the slide from the list to a board and back. `shell_test.rb` "a grid to a card detail is a screen change".
- Under the shared machine's load (load average about 26, nine builds) two picker tests of `trades_test.rb` failed once each in long runs ("the board and its picker work by keyboard", "a draft is kept in the browser…", both waiting for `.trade-picker`); neither path makes a Turbo visit the change affects (the first starts from a full `visit`, the second from Friends into the draft, a screen change before and after), they passed three times in a row alone and the whole file passed on the next run.
- Verified in headless Chromium 141, Postgres 16 on 5433: `npm run test:js` (566), `npm run typecheck`; `bin/rails test test/system/trades_test.rb test/system/shell_test.rb` (36 runs) and, earlier in the run, with `card_detail_test.rb` and `settings_test.rb` (37 runs, card detail and settings all green); `bin/rails test` with 2 workers (3171 runs, 0 failures); `bin/rails zeitwerk:check`, `bundle exec packwerk validate` and `check`, `bin/rubocop` (943 files), `bin/brakeman`, `i18n-tasks missing`: pass. `bin/ci` itself was not run (its schema steps need Postgres 18; no migration here).

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck` -- expected: pass, with the frame rule's cases
- `bin/rails test test/system/trades_test.rb test/system/shell_test.rb test/system/card_detail_test.rb test/system/settings_test.rb` -- expected: pass; new assertions read the `same` mark and the screen's computed `view-transition-name`: none between the Échanges steps on a desktop (Back included), `screen` from the hub into Échanges and back out, from the list to a board and back on a phone, and from a grid to a card detail
- `bin/rails test`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: pass

**Manual checks (if no CLI):**
- On staging, the author moves between the Échanges steps and sees no slide, while hub to collection and a grid to a card detail still slide.

## Auto Run Result
