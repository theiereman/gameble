---
title: "A banned, deleted or newly private player's duel finishes, and their name leaves its history"
type: 'feature'
ticket: '8'
created: '2026-11-17'
status: 'built'
baseline_revision: '4bf2fd3ba9d44e3ded6c7b53d43aecf72b95a3e6'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      A ban or deletion pushes no board to the other seat, so the removed player's name reads "anonyme" there from the next board (the next move, at most a minute) and on every page load; the client drops a board of the same move number.
    evidence: |-
      `app/models/duel_stream.rb` hears only duel events; a push on ban would be dropped by the board's strictly-newer rule.
    severity: low
  - summary: >-
      A player who goes private mid-duel keeps playing their moves; only a removed player's lease is no longer renewed.
    evidence: |-
      the duel rules let later moves act for a seat made private (`Game::DuelSteps`); nothing closes the page of a newly private player.
    severity: low
---

<intent-contract>

## Intent

**Problem:** A ban, a deletion or a switch to private writes no duel row, yet the duel must finish and the removed player's name must leave its history; a deleted player's seat, a challenge to them and the data export were not handled.

**Approach:** The game plays the removed player's moves through the clock; the finishing move (or the end of a challenge) and `Game::ReleasePlayer` empty a deleted player's seat; a received challenge of a deleted player lapses in the deletion; every screen names the opponent through one helper that reads anonymous for a removed or missing player; the export lists the player's finished duels with the opponent unnamed.

## Boundaries & Constraints

**Always:** Obey `AGENTS.md`. A banned player keeps their seat's player (they may be unbanned); only a deleted player's seat is emptied, and only once the seat is `left`. Handlers never publish.

**Never:** No migration (the seat's player is already nullable); no change to `DuelRules`, the clock or the duel screens' markup.

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/duel_steps.rb`, `answer_round.rb` -- `release_deleted` empties a deleted player's seat after the finish or the lapse event is published.
- `app/domains/game/app/operations/game/release_duel_seats.rb` (new), `release_player.rb` -- lapse the deleted player's received challenge, empty their `left` seats.
- `app/domains/game/app/operations/game/note_duel_presence.rb` -- no lease for a removed player's seat.
- `app/domains/game/app/queries/game/challenges_received.rb` (new), `app/models/player_stream.rb` -- the challenger hears the lapse on the player stream.
- `app/views/duels/_sheet_outcome.html.erb`, `app/views/player_streams/_update.turbo_stream.erb` -- `duel_plain_name`.
- `app/domains/game/app/queries/game/export_of.rb`, `app/models/player_export.rb` -- `duels` section.

## Tasks & Acceptance

**Execution:**
- [x] Operations and queries above
- [x] Operation, handler and export tests; one system test (Hugo banned in round 4)

**Acceptance Criteria:**
- Given Hugo is banned during round 4, when his time runs out, then his moves are played automatically and Léa's duel reaches its result, which reads anonymous.
- Given a deleted player's duel, when it finishes, then their seat's player is empty and the finish event still names them.
- Given a finished duel of a player who is later deleted, then the seat is emptied and the result kept.
- Given a received challenge of a deleted player, then it lapses within the deletion and its challenger is told.
- Given the export of a player with duels, then each lists date, score, result and rounds and names no opponent.

## Implementation Notes

- Implemented directly; the coordinator replaced the per-ticket review with one final review of the whole duel diff.
- The ban's sign-out already rotates the player stream; the duel seat stream is unchanged, so `NoteDuelPresence` stops renewing a removed player's lease.

## Plan Change Log

## Review Triage Log

No review ran for this ticket (pinned `none` by the coordinator).
