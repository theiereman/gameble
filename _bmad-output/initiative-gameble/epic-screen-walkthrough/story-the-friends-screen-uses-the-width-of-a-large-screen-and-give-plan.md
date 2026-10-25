---
title: 'The friends screen uses the width of a large screen and gives the friend list the lead'
type: 'feature'
ticket: 28
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
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On a desktop the Amis screen (`app/views/friends/show.html.erb`, `app/frontend/styles/friends.css`, capped at 520px) is one narrow column: the invite panel, the invitations, then friend rows whose name, presence and three buttons ("VOIR LE PROFIL", "ÉCHANGE", "RETIRER") wrap on one line and do not align from row to row. The author wants the width used and the friend list to lead; settled 2026-10-24: the pseudo opens the profile dialog, ÉCHANGE is the only filled button, RETIRER moves into a more-actions (⋯) menu with a confirmation.

**Approach:** Lay the screen out as DESIGN.md's Amis row already says: from 900px a side area on the left (invite panel and invitations, 380px from 1180px, 300 to 360px from 900) and the friend list fluid on the right; one column under 900px, the phone order unchanged. Each friend row puts name, presence, the trade action and a ⋯ button in fixed columns shared by every row (a subgrid, when the list is wide enough; a stacked row when narrow). The name becomes a button opening the friend profile dialog (accessible name "Voir le profil de <name>"), so "VOIR LE PROFIL" leaves the row; ÉCHANGE (or the Trades closed line) stays the one filled button; the ⋯ button (accessible name "Plus d'actions pour <name>", a new pixel `more` icon, unfilled) opens a native popover anchored to it holding "RETIRER" (accessible name "Retirer <name> de vos amis"), which opens the existing confirmation dialog; closing that dialog returns focus to the ⋯ button. Both locales gain the new strings, the unused `friends.show.see_profile` goes; controller and system tests follow; EXPERIENCE.md's Friend row and DESIGN.md's Friends section and Amis layout follow. The friend profile dialog's own content is untouched.

</intent-contract>

## Implementation Notes

Oneshot (pinned): one screen's markup, stylesheet and strings, a one-line focus-return rule for dialogs opened from a popover menu, one pixel icon, and the tests and docs that describe the row. No model, operation, route or policy changes.

- Files touched: `app/views/friends/show.html.erb` (`.friends__layout` grid of `.friends__side` and `.friends__main`; the dialogs stay after it), new `app/views/friends/_friend_row.html.erb` (name button, presence, `.friends__trade`, `.friends__more` with the ⋯ button and its `popover` menu), `app/helpers/friends_helper.rb` (`friend_actions_menu_id`, `dialog_opener_attributes` for the two non-`.button` dialog openers), `app/frontend/controllers/dialog_opener_controller.ts` (an opener inside a popover returns focus to the popover's invoker: the modal closes the menu, so the menu item cannot take the focus back), `app/frontend/styles/friends.css`, `script/pixel_art/export.mjs` and the exported `app/frontend/images/pixel/more.svg`, `config/locales/{en,fr}.yml` (row strings moved from `friends.show` to `friends.friend_row` for the partial's relative lookups, `more_actions_for` added, the unused `see_profile` dropped), `test/controllers/friends_controller_test.rb`, `test/system/friends_test.rb`, and EXPERIENCE.md (Friend row) and DESIGN.md (Amis layout row, Friend row).
- Decisions: ÉCHANGE stays a secondary button (the filled blue-grey one; primary is one per view and a list has several rows); the ⋯ button and the menu are unfilled. The row layout follows the friend list's width with a container query (560px): wide, the list is a grid of `minmax(12ch, 1fr) fit-content(14rem) fit-content(20rem) auto` and each row a subgrid, so name, presence, trade and ⋯ start at the same x in every row; narrow (the phone), name over presence with ⋯ beside them and the trade below. The layout widths are DESIGN.md's (380px from 1180px, `clamp(300px, 30vw, 360px)` from 900px, one column under 900px in the existing order). The menu sits under its button through the popover's implicit anchor (`position-area`), with a bottom-right fallback where anchor positioning is not supported.
- The friend li keeps `friends__row` beside `friends__friend`: the invitations controller tests select friends by `.friends__row .friends__name`.

### Verification run (2026-10-25)

- `bin/rails test test/controllers/friends_controller_test.rb test/controllers/invitations_controller_test.rb test/controllers/friend_profiles_controller_test.rb test/controllers/trades_controller_test.rb`: 109 runs, pass.
- `bin/rails test test/system/friends_test.rb`: 8 runs, 64 assertions, pass (three new: desktop columns and row alignment with a long name, the desktop empty states, removal through ⋯ with cancel returning focus to ⋯). Screenshots at 1400px (rows aligned, menu open under ⋯) and 390px (one column) checked by eye.
- The other system tests on the screen: `live_updates_test.rb -n /Friends/` (3 runs), `trades_test.rb -n /draft.is.kept/` (the one that clicks Trade on the Amis row), `feed_test.rb -n /friend/` (2 runs): pass.
- `node script/pixel_art/export.mjs --check`, `npm run typecheck`, `npm run test:js` (561 tests), `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `bin/rubocop`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: pass.
- `PARALLEL_WORKERS=2 bin/rails test`: 3171 runs, 1 failure, `Game::PioneerOfTest#test_the_first_discoverer_and_the_date,_in_one_query` (fixture `2.weeks.ago` set at load, compared to `2.weeks.ago` at run time within 1 minute; 135 s apart on a machine shared by nine builds). Untouched by this change; passes alone (3 runs).

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/friends_controller_test.rb test/controllers/invitations_controller_test.rb test/controllers/friend_profiles_controller_test.rb test/controllers/trades_controller_test.rb` -- expected: pass
- `bin/rails test test/system/friends_test.rb test/system/live_updates_test.rb test/system/trades_test.rb` -- expected: pass
- `node script/pixel_art/export.mjs --check`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `bin/rubocop`, `bin/brakeman --quiet --no-pager`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass

**Manual checks (if no CLI):**
- Screenshots from the friends system tests at desktop and phone widths: friend list on the right and larger, rows aligned, side area on the left; one column on the phone.

## Auto Run Result
