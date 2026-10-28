---
id: 39
tracker_status: done
tracker_id: ""
type: story
title: "System tests rebuilt to be stable"
parent: epic-public-launch-readiness
after: [38]
hitl: false
risk: medium
---

# System tests rebuilt to be stable

## Description

The system tests (about 180 tests in 20 files, headless Chrome) fail at random often enough that nobody trusts them, so they are disabled in CI and as a check of work. They are rebuilt to be fully stable and useful: find why each one is flaky (timing reads instead of retrying matchers, animations and View Transitions, global state such as window size left changed, the Vite build, parallel workers, Chrome driver), fix the harness and the tests, drop or move down to request and vitest tests what does not need a browser, then switch them back on in CI on every push and restore the rule asking agents to run them for what they touch.

## Acceptance Criteria

Verify: The whole system suite passes ten full runs in a row locally and five CI runs in a row with no failure and no retry; the CI system-test job runs again; AGENTS.md asks again for the system tests of what a change touches; the full suite, vitest, packwerk and zeitwerk pass.

## References

- parent — _bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md

## Notes

- Decision (author, 2026-10-12): the system tests are disabled until this lands, in CI and in the agents' checks.
- Bug 38 fixes the two live update tests first; this story takes on the rest of the suite.
- Evidence: merging the achievements engine (2026-10-12), three booster tests failed in one run and passed in the next two, and passed on develop alone.
- From the sets epic retrospective (2026-10-20): the decision to celebrate in Booster.tsx (which opening's tiers, when the hand is complete, the remembered celebration on reload) has no test; cover it in vitest or a stable system test.
- From the same retrospective: test/system/library_test.rb (the side shelf, about lines 43-133) and card_detail_test.rb (about line 127) still assert the removed side detail column; rewrite or drop them.
- From the card catalog's refactor sweep (2026-10-20): test/system/library_test.rb also still counts locked missing slots in Toutes les cartes (about lines 71-76, 152, 212), where every card now shows its face (`.card--not-owned` for a player's, plain for a visitor's), expects a visitor's top bar status and grid on the collection entry (about line 205), and the state chips a visitor no longer has (about line 99); card_detail_test.rb's faded-back cases were rewritten then.
