---
title: 'The active title on the profile, in the feed and in trades'
type: 'feature'
ticket: '4'
created: '2026-10-28'
status: 'built'
baseline_revision: '20d65ecfc2d6c1d9feaa26ff91acdcc7136efd2d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: [self]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who chose a profile title (ticket 26.3) sees it nowhere: it does not show on the profile, in the feed or in trades.

**Approach:** Show the chosen title as text beside the player's name on the public profile, the settings summary, the friend profile frame, the feed entries and both sides of a trade board, through one helper and one style. The title is read through `Game::ActiveProfileTitle`, which checks it is still earned, and loaded for all players of a list in one batch.

## Boundaries & Constraints

**Always:** read through Game queries; a title no longer earned shows nothing; a player who chose none shows nothing; no query per row (feed and trades read their titles once per page); the same markup everywhere; every string already exists in en.yml and fr.yml.

**Never:** write anything on a GET; add a column; show the title in the live ticker or the card page strip (one-line sentences without the name block).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Worn title | chosen and still earned | "Adept · Valve" beside the name | none |
| Lapsed | chosen, tier gone | nothing | none |
| None | no choice | nothing | none |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/{profile_titles,active_profile_title}.rb` -- `for_players` batch reads; `call` keeps its single-player form.
- `app/domains/game/app/queries/game/{feed_entries,trades_of}.rb` -- feed `Entry` and trade `Row` carry the titles.
- `app/helpers/{profile_titles_helper,feed_helper}.rb` -- `active_title_tag`, the one rendering; `feed_sentence(titles:)`.
- views of the public profile, settings summary, friend profile frame, feed entry and trade side; `app/frontend/styles/profile-title.css`.

## Tasks & Acceptance

**Execution:**
- [x] queries -- batch title reads; feed entries and trade rows carry them.
- [x] helper and views -- `active_title_tag` on the five screens; feed passes `titles: true`, the ticker does not.
- [x] style -- `profile-title.css`.
- [x] tests -- batch query, controller display in English and French, system tests on the profile, feed and trade board.

**Acceptance Criteria:**
- Given a worn title, then it shows on the profile, in a feed line and on its side of a trade, in English and French.
- Given no title or a lapsed one, then nothing shows.
- Given a feed or trade list, then the tiers are read once for all players.

## Implementation Notes

Full route, implemented directly: the build runs in a worktree agent that cannot spawn a coding subagent.

## Plan Change Log

## Review Triage Log

Self-review of the diff (no subagent available):
- Kept: the feed title is uppercase by style, so tests match it case-insensitively.
- Kept: the live ticker and the card page strip omit the title, as one-line sentences.
- Kept: the trade list rows show no title; the board does, on both sides.

## Design Notes

The title text is `profile_title_text`, shared with the picker.

## Verification

**Commands:**
- Ran before the coordinator's instruction to stop: the touched Game, controller and system tests, rubocop, packwerk, zeitwerk, i18n-tasks, lint:css, format:check, file sizes and planning references, all clean. The full suite is left to the coordinator.
