---
title: 'A goal on the Steam library set shows its name'
type: 'bugfix'
ticket: '2'
created: '2026-11-03'
status: done
baseline_revision: '0f181fa47dcdbce6950e6aadc08413d33efbf527'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      A Steam library goal's kind line still reads Custom set / Set perso, in the goal row and its accessible sentence.
    evidence: |-
      goal_kind_name checks only custom?, so the Steam library goal takes the custom set kind; the collection's own Steam library entry uses library.entry.steam_library.kind instead. Predates this change, and the ticket asks only for the name.
    location: >-
      app/helpers/goals_helper.rb goal_kind_name
    severity: low
---

<intent-contract>

## Intent

**Problem:** A goal aimed at the Steam library set shows an empty name everywhere a goal is named (collection goal rows, card goal bookmark words, the grid's goal filter chip, trade board bookmarks, goal toasts and accessible sentences), because `GoalsHelper#goal_set_name` reads the custom set's stored `name`, which the Steam library set leaves null; its displayed name is the locale string `custom_sets.library.name` (My Steam library / Ma bibliothèque Steam).

**Approach:** Let a goal's target carry its custom set's kind (`Game::GoalNeeds` already joins `game_custom_sets`; pluck its `kind` too and expose `steam_library?` on `Target` and `Need`), and have `goal_set_name` name a Steam library target with `t("custom_sets.library.name")`, keeping a game set's `SetLabel` and a custom set's stored name. Every naming surface already goes through `goal_set_name`, so no view changes. Cover it with a helper test (Steam library, custom and game-set goals, English and French) and a domain assertion on the target.

</intent-contract>

## Implementation Notes

Oneshot: about 40 lines across the goal query, the goals helper and their tests; one helper is the single point every goal-naming surface reads.

- `Game::GoalNeeds` plucks `game_custom_sets.kind` beside the token and name; `Target` carries it as `custom_set_kind` and answers `steam_library?`, which `Need` delegates.
- `GoalsHelper#goal_set_name` names a Steam library target with `custom_sets.library.name`; every surface (goal rows, filter chip, card detail bookmarks, remove label, trade boards, toasts, sentences) reads that helper, so no view changed.
- `test/models/goal_marks_test.rb` builds `Target` by hand and gained the new field.
- The French goal strings put U+202F before the colon; the helper test spells it.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` goal_set_name repeats the Steam-library-or-stored-name choice custom_set_display_name makes — both read the same locale key, so a label change edits only the locale files; sharing the rule needs a new method over two unrelated types, more complexity than the harm.
  - `[low]` `[defer]` A Steam library goal row's kind line still reads Custom set — real, but predates this change and the ticket asks only for the name; deferred.

## Verification

**Commands:**
- `bin/rails test test/helpers/goals_helper_test.rb test/domains/game/goal_needs_test.rb test/models/goal_marks_test.rb` -- expected: green
- `bin/rails test` -- expected: green
- `bin/rails test test/system/goals_test.rb test/system/goal_bookmarks_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rubocop` on touched files -- expected: clean

## Auto Run Result

- Summary: a goal on the Steam library set is named My Steam library / Ma bibliothèque Steam wherever a goal is named; the goal query carries the custom set's kind and the goals helper names the library set from the locale.
- Files changed:
  - `app/domains/game/app/queries/game/goal_needs.rb` -- target carries the custom set kind and answers `steam_library?`
  - `app/helpers/goals_helper.rb` -- `goal_set_name` names the Steam library set
  - `test/helpers/goals_helper_test.rb` -- new: Steam library, custom and game-set goal names in English and French
  - `test/domains/game/goal_needs_test.rb` -- a Steam library goal says so
  - `test/models/goal_marks_test.rb` -- hand-built target gains the kind
- Review: quick lens, 2 findings; 0 patches, 1 deferred (kind line), 1 rejected (repeated naming rule, see triage log).
- Follow-up review recommended: false (0 patched).
- Verification: the three touched test files green (11 runs); `bin/rails test` 4250 runs, 0 failures; system tests goals, goal_bookmarks and steam_library 13 runs, 0 failures; zeitwerk:check, packwerk, check_planning_references, check_file_sizes and rubocop clean.
- Residual risk: none beyond the deferred kind line.
