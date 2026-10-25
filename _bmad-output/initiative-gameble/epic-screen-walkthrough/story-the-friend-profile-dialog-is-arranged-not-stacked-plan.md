---
title: 'The friend profile dialog is arranged, not stacked'
type: 'feature'
ticket: 29
created: '2026-10-25'
status: 'built'
baseline_revision: '27b677d308e8106cc52d312bb30f36340222094b'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The friend profile dialog (`app/views/friend_profiles/show.html.erb`, loaded lazily into `app/views/friends/_profile_dialog.html.erb` when the friend's name is clicked on the Amis screen) stacks "ÉCHANGE" (primary), "VOIR LE PROFIL" and "VOIR LA COLLECTION" (filled secondary) one under the other at their own widths, then "SIGNALER" as a lone orange link, all left-aligned in a wide empty panel. Settled by the author 2026-10-24: as on the friends screen, ÉCHANGE is the only filled button; SIGNALER and the removal sit in a more-actions (⋯) menu; the two views of the friend side by side.

**Approach:** Under the unchanged identity (avatar, name, presence, cards collected), the actions sit on one three-column grid filling the panel: "ÉCHANGE" (primary, or the Trades closed line) spans the first two columns with "⋯" beside it in the third, as on the friend row; under it "VOIR LE PROFIL" and "VOIR LA COLLECTION" share the two columns, equal widths, unfilled (the control border, no fill, accent fill on hover), so their left and right edges meet ÉCHANGE's. When the dialog is narrower than 420px (the phone's bottom sheet) the two views stack, each as wide as ÉCHANGE. "⋯" is the friend row's control, extracted into a shared `friends/_more_actions` partial (same pixel `more` icon, native `popover role="group"`, accessible names "Plus d'actions pour <name>"): in the dialog its menu holds "SIGNALER" (accessible name "Signaler <name>", opens the existing report dialog) and "RETIRER" ("Retirer <name> de vos amis", opens a remove-friend confirmation rendered inside the profile frame under its own id); closing either returns focus to the dialog's "⋯" (the existing dialog-opener rule), and the profile dialog keeps its close button, Esc and focus return to the friend's name. Strings move to `friends.more_actions` in both locales; controller and system tests follow; EXPERIENCE.md's Friend profile row and DESIGN.md's Friend profile line follow.

</intent-contract>

## Implementation Notes

Oneshot (pinned): one dialog's markup and stylesheet, a partial shared with the friend row, a few strings, and the tests and docs that describe the dialog. No model, operation, route, policy or script change.

- Files touched: `app/views/friend_profiles/show.html.erb` (the trade in `.friend-profile__trade`, the shared ⋯ menu, the two views, the report dialog and a remove-friend dialog of its own), new `app/views/friends/_more_actions.html.erb` (the ⋯ button and its `popover role="group"` menu, extracted from `_friend_row.html.erb`, which now renders it; SIGNALER only when given a report dialog), `app/views/friends/_remove_dialog.html.erb` (an optional `id:`), `_public_profile_link` and `_collection_link` (`friend-profile__view` in place of `button--secondary`; used only by the dialog), `app/helpers/friends_helper.rb` (`friend_profile_actions_menu_id`, `friend_profile_remove_dialog_id`, `friend_report_dialog_id`), `app/frontend/styles/friends.css`, both locales (`friends.friend_row.{more_actions_for,remove,remove_friend}` moved to `friends.more_actions.{menu,remove,remove_friend}`, plus `report` and `report_player`), `test/controllers/friend_profiles_controller_test.rb`, `test/system/friends_test.rb`, EXPERIENCE.md (Friend profile and Report dialog rows) and DESIGN.md (Friend profile).
- Decisions: ÉCHANGE stays primary in the dialog (one view, one primary, as DESIGN.md already had it); the views lose their fill and keep the control border, so ÉCHANGE is the only filled button. The grid is `1fr 1fr auto`: ÉCHANGE over columns 1-2, ⋯ in 3, the views in 1 and 2, so the views' outer edges meet ÉCHANGE's; under a 420px container (the phone sheet) it becomes `1fr auto` with the views stacked under ÉCHANGE. The profile frame renders its own remove confirmation (`friend-profile-remove-<token>`) rather than opening the friends page's `remove-friend-<token>`: the frame stays whole when its page is fetched alone, and the existing dialog-opener rule returns focus to the dialog's ⋯ when it closes, as for the report dialog. The menu's two rows get a `--space-2` gap. No JavaScript changed: the dialog-opener's popover rule from 16.28 already covers the dialog's menu.

### Verification run (2026-10-25)

- `bin/rails test test/controllers/friend_profiles_controller_test.rb test/controllers/friends_controller_test.rb test/controllers/invitations_controller_test.rb`: 50 runs, 506 assertions, pass.
- `bin/rails test test/system/friends_test.rb`: 10 runs, 99 assertions, pass (two new: the desktop arrangement with Esc returning focus to the name; removal from the dialog's menu with cancel returning focus to its ⋯; the report test now goes through the menu and checks focus back on ⋯ after ✕; the phone test checks the stacked views on ÉCHANGE's edges). Screenshots at 1400px (ÉCHANGE and ⋯ on one line, the two unfilled views side by side on its edges; the menu open with REPORT and REMOVE) and 390px (views stacked, full width of ÉCHANGE) checked by eye.
- `live_updates_test.rb -n /Friends/` (3 runs) and `trades_test.rb -n /draft.is.kept/` (1 run): pass.
- `bundle exec i18n-tasks missing` and `unused`, `bin/rubocop` (945 files), `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `node script/pixel_art/export.mjs --check`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`, `npm run typecheck`, `npm run test:js` (580 tests): pass.
- `PARALLEL_WORKERS=2 bin/rails test`: 3188 runs, 33632 assertions, 0 failures, 0 errors.

## Plan Change Log

## Review Triage Log

### 2026-10-24 — Review pass
- verdicts: 2 findings — high 0, medium 2, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` The views stacked by a container query on `.friend-profile`, measured inside the panel's padding, so they stacked below a 468px dialog and stood side by side on a 480px phone sheet — they now stack on the phone's sheet (under 720px, the app's phone breakpoint); DESIGN.md's Friend profile line says so.
  - `[medium]` `patch` The unfilled views lost their control border when focused or pressed, the generic `.button:focus-visible` and `.button:active` winning — `.button.friend-profile__view` keeps the control border under the focus ring and when pressed, as the menu items do.

## Verification

**Commands:**
- `bin/rails test test/controllers/friend_profiles_controller_test.rb test/controllers/friends_controller_test.rb test/controllers/invitations_controller_test.rb` -- expected: pass
- `bin/rails test test/system/friends_test.rb` -- expected: pass
- `npm run typecheck`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `bin/rubocop`, `bin/brakeman --quiet --no-pager`, `node script/pixel_art/export.mjs --check`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass

**Manual checks (if no CLI):**
- Screenshots from the friends system tests of the dialog at 1400px and 390px: ÉCHANGE and ⋯ on one line, the two views side by side (stacked on the phone) on the same edges, the menu open under ⋯ with SIGNALER and RETIRER.

## Auto Run Result

Status: built

- Summary: the friend profile dialog arranges its actions on one grid under the identity: ÉCHANGE the only filled button with the ⋯ menu beside it (SIGNALER and RETIRER, the same menu partial as the friend row), VOIR LE PROFIL and VOIR LA COLLECTION side by side under it at equal widths, unfilled with the control border; on the phone's sheet the two views stack; focus rules unchanged (Esc and ✕ return to the friend's name, a dialog opened from ⋯ returns to ⋯).
- Files: `app/views/friend_profiles/show.html.erb`, the new `app/views/friends/_more_actions.html.erb`, `_friend_row.html.erb`, `_remove_dialog.html.erb`, `_public_profile_link.html.erb`, `_collection_link.html.erb`, `app/helpers/friends_helper.rb`, `app/frontend/styles/friends.css`, both locales, the friend profiles controller test, `test/system/friends_test.rb`, EXPERIENCE.md and DESIGN.md.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 2 findings, both medium, both patched; nothing deferred or rejected.
- Follow-up review recommended: true — two mediums were patched; the unverified risk is the views' focus and pressed look, which no test measures.
- Verification: after the patches, `friends_test.rb` and `friend_profiles_controller_test.rb` 20 runs, 0 failures on Chromium 141; the unattended run's friends and invitations controller tests, the live updates and trades system tests touching the screen, i18n-tasks, rubocop, packwerk, brakeman, zeitwerk, pixel art check, typecheck, vitest 580 and the full suite (3188 runs, 0 failures) passed.
- Residual risks: the menu inside a modal relies on the top layer and anchor positioning (Safari and Firefox on staging); each friend's removal confirmation exists twice on the page once their profile loaded; DESIGN.md still gives a private friend's dialog an avatar, as before.
