---
title: 'Refactor sweep'
type: 'chore'
ticket: '9'
created: '2026-10-28'
status: done
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [self-review]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The card back stories left small leftovers that their build records and review findings name.

**Approach:** Remove dead code and tidy what the epic added, without changing behavior.

</frozen-after-approval>

## Implementation Notes

- Removed the `unlockedCardBacks` field of the opening answer: it was always an empty list, never read (unlock toasts travel on the player stream). Dropped from `PacksHelper#pack_opening_json`, the `OpeningAnswer` type, the markup reader, the fixtures, the opening test and the packs controller test's key list and empty assertion.
- `Game::Handlers::CardBacks.call` names its `retroactive` value on its own line instead of one 150-character call.
- Deferred findings: the two entries whose source is this epic (player export and deletion notice; CAP-20 wording) already carry `resolved:` lines (moved to ticket 26.2), so none was left to resolve here.
- Left alone: `Game::CardBacks.active_key` is only called by tests (the picker and booster use `active_with_season`); kept because several tests assert on it and removing it means rewriting them. The one-versus-many naming of `GrantCardBackJob` (event back by Steam ids) and `GrantCardBacksJob` (earned backs of a player) is confusing but a rename touches the rake task and queue records, not worth the risk in a sweep.
- Not run by the builder, by the author's instruction: tests and checks. Ran only rubocop and `npm run format:check` on the touched files.

## Review Triage Log

Self-review of the diff, no subagent: behavior preserved; the JSON answer loses one key that no reader used.

## Verification

**Commands:**
- `bin/rails test test/controllers/packs_controller_test.rb test/domains/game` -- expected: pass
- `npm run test:js`, `npx tsc --noEmit` -- expected: clean
