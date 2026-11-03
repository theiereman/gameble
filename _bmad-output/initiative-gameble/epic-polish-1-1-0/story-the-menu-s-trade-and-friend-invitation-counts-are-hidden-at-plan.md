---
title: "The menu's trade and friend invitation counts are hidden at zero"
type: 'bugfix'
ticket: '4'
created: '2026-11-03'
status: 'built'
baseline_revision: '0f181fa47dcdbce6950e6aadc08413d33efbf527'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The hub menu's TRADES and FRIENDS entries, and the same entries on the Social landing, show a greyed `0` badge (`menu-item__badge--zero`) when nothing waits, and the player stream keeps rendering that `0` when a count drops to zero. The phone tab bar and the achievements badge already render nothing at zero.

**Approach:** Make `pages/_menu_trades_badge` and `pages/_menu_invitations_badge` render nothing at zero, exactly like `pages/_menu_achievements_badge` (strict locals, `if count.positive?` around the badge and its visually-hidden text). Every render site (hub menu, Social landing, player stream update) goes through those two partials, so the stream slots (`#menu-trades-badge`, `#plus-trades-badge`, `#menu-friends-badge`, `#plus-friends-badge`) empty at zero and fill again from zero. Drop the now-unused `.menu-item__badge--zero` CSS rule and fix the badge comment in `hub.css`; keep the disabled-entry badge rule and the locale keys (the French `zero` forms stay).

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `app/views/pages/_menu_trades_badge.html.erb` -- strict local `waiting:`, render only when positive, no `--zero` class
- [ ] `app/views/pages/_menu_invitations_badge.html.erb` -- strict local `invitations:`, render only when positive, no `--zero` class
- [ ] `app/frontend/styles/hub.css` -- drop `.menu-item__badge--zero` from the disabled-badge rule; the comment says counts show no zero
- [ ] Tests asserting a `--zero` "0" badge -- assert no badge at zero, one at 1: `test/jobs/player_stream_job_test.rb`, `test/controllers/pages_controller_test.rb`, `test/controllers/trades_controller_test.rb`, `test/integration/player_stream_tag_test.rb`, `test/system/live_updates_test.rb`, `test/system/trades_test.rb`

**Acceptance Criteria:**
- Given no trade and no invitation waiting, when the player opens the hub or the Social landing, then neither the trades nor the friends entry shows a count nor any visually-hidden count text.
- Given an invitation arrives, when the player stream updates, then the friends entries show `1`; when it is accepted, the count disappears live.
- Given a count streams to zero, when the update renders, then the stream slots are emptied (the update template carries no badge).

## Implementation Notes

Oneshot: two view partials, one CSS rule and the tests that asserted the greyed zero; well under 100 lines.

- Both partials now mirror `pages/_menu_achievements_badge`: strict locals and nothing rendered at zero, so the hub menu, the Social landing and every player stream update share the behaviour.
- `hub.css`: `.menu-item__badge--zero` dropped (no other user); the disabled-entry badge rule kept.
- Locale keys untouched: the French `zero` forms stay for the plural rule even though zero no longer renders.
- The sender session in the live AMIS badge system test now seeds a stale `9` badge instead of emptying the slot, so the zero update is proven to clear it.
- Verified: 160 unit/controller/integration runs and 27 system runs (live_updates, trades) green; stylelint, prettier, planning references, file sizes, zeitwerk, packwerk, rubocop clean.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` The Social landing's trades row at zero had no test — added a `/social` check of an empty `#plus-trades-badge` slot to the menu 04 slot test in `test/integration/player_stream_tag_test.rb`.
  - `[low]` `[patch]` The trades stream at zero was checked on `menu-trades-badge` only — the job test now asserts both `menu-trades-badge` and `plus-trades-badge` carry an empty template.
  - `[false]` `[reject]` Execution checklist left unticked — the fix edits this build's plan, and the Implementation Notes record every task as done.

## Verification

**Commands:**
- `bin/rails test test/jobs/player_stream_job_test.rb test/controllers/pages_controller_test.rb test/controllers/trades_controller_test.rb test/integration/player_stream_tag_test.rb` -- expected: green
- `bin/rails test test/system/live_updates_test.rb test/system/trades_test.rb` -- expected: green
- `npm run lint:css && npm run format:check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: clean

## Auto Run Result

- **Change:** the hub menu's TRADES and FRIENDS entries and the Social landing's rows show no count when nothing waits, at first render and when the player stream updates a count to zero or from zero; the greyed `0` badge and its `--zero` CSS are gone.
- **Files:**
  - `app/views/pages/_menu_trades_badge.html.erb` -- strict local, renders nothing at zero
  - `app/views/pages/_menu_invitations_badge.html.erb` -- strict local, renders nothing at zero
  - `app/frontend/styles/hub.css` -- `.menu-item__badge--zero` dropped, badge comment updated
  - `test/jobs/player_stream_job_test.rb`, `test/controllers/pages_controller_test.rb`, `test/controllers/trades_controller_test.rb`, `test/integration/player_stream_tag_test.rb`, `test/system/live_updates_test.rb`, `test/system/trades_test.rb` -- assert no count at zero, `1` when one waits
- **Review:** quick lens; 2 low patches applied (test coverage of the Social trades slot and its stream at zero), 0 deferred, 1 rejected (plan checklist: fix would edit the plan).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 2).
- **Verification:** 152 runs of the job, pages, trades and player stream tag tests green after the patches; 27 system runs (live_updates, trades) green; stylelint, prettier, planning references, file sizes, zeitwerk, packwerk, rubocop clean.
- **Residual risk:** none known; the French `zero` plural forms stay in the locales unused at zero.
