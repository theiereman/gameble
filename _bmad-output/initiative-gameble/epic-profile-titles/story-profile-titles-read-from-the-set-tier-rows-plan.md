---
title: 'Profile titles read from the set tier rows'
type: 'feature'
ticket: '1'
created: '2026-10-28'
status: done
baseline_revision: '91cb61f674b56491b4c7e500a6fdf391828befce'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player's collecting has no name yet: the set tier rows record what they reached, but nothing turns them into the profile titles the later entries pick and display.

**Approach:** A query reads the player's `game_set_tiers` rows and returns one title per set kind, key and rank across seasons, with the latest season it was reached in; a helper renders it from the rank and the set's label in both languages. Nothing is stored.

## Boundaries & Constraints

**Always:** Bronze counts as apprentice, silver as adept, gold as master, `complete` as the completion title; one query; no migration; every string in `en.yml` and `fr.yml`.

**Never:** Store a title or its text; add a picker or a display (entries 2 and 3).

</frozen-after-approval>

## Implementation Notes

Oneshot: a query (`Game::ProfileTitles`), a rendering helper (`ProfileTitlesHelper`), two locale blocks and their tests, under 100 lines of code.

## Verification

**Commands:**
- `bin/rails test test/domains/game/profile_titles_test.rb test/helpers/profile_titles_helper_test.rb` -- expected: pass
- `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: clean

## Review Triage Log

No review subagent ran: this session was a worker fork that may not launch subagents. The author read the diff instead (query, helper, locale keys, two test files); no finding.

Verified: `bin/rails test` on the two new test files (7 runs, 0 failures), `i18n-tasks missing` and `unused` clean, `packwerk check`, `zeitwerk:check`, `check_file_sizes`, `check_planning_references` and rubocop clean.
