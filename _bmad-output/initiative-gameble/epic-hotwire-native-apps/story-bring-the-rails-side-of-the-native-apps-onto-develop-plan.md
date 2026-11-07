---
title: 'Bring the Rails side of the native apps onto develop'
type: 'feature'
ticket: '1'
created: '2026-11-04'
status: 'built'
baseline_revision: '63f772b3de0be0467534736fb7d4f625c77a2fa9'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A first implementation of the Hotwire Native apps' server side exists on the branch hotwire-native-v1 of thoKling/gameble, started from a develop of 29 October; develop has moved on, and the code breaks some of this repository's rules.

**Approach:** Cherry-pick the server commit (c72e4dc) and the push platform check (1b0e98c) of that branch onto this branch with their authorship, resolve the conflicts against current develop, regenerate the schema from the migrations, and make the code follow the repository rules.

</frozen-after-approval>

## Implementation Notes

Oneshot: the code is already written upstream; what is left is conflict resolution and conformity edits, with no design to settle. Two commits are picked, the shells and the CI commits of the branch are left to later stories.

## Verification

**Commands:**
- `bin/rails test test/controllers/hotwire_native_test.rb test/controllers/native_sessions_controller_test.rb test/controllers/native_sign_ins_controller_test.rb test/controllers/push_devices_controller_test.rb test/domains/accounts/push_devices_test.rb test/jobs/push_notice_job_test.rb test/models/push_notices_test.rb` -- expected: 0 failures
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: all pass
- `bundle exec rubocop` on the touched Ruby files -- expected: no offence

## Review Triage Log

- false: authorship not kept. The upstream commits c72e4dc and 1b0e98c are authored by `Claude <noreply@anthropic.com>` on the friend's branch (`git show --format=%an%ae`); the picked commits carry the same author, with the committer as the local user.
- false: operations without an event. Many accounts operations do not publish (`NoteLastSeen`, `AddClerkSignInMethod`, `CloseWelcome`, `RecordExport`, `ReportPlayer`); registering and forgetting a push device follows that pattern.
- medium, defer: a sign-in ticket can be redeemed more than once within its two minutes; a one-time use needs storage and fits the sign-in hand-off hardening with app links.
- medium, defer: a device stays linked to the player who registered it after the session ends, and is not registered again after a new sign-in; the fix belongs to the shells (register on sign-in) and the real-device push story.
- low, patched: the comment above the forgery-protection skip is one line.
