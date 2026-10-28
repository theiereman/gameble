---
title: 'The back catalogue, unlock rows and the active back'
type: 'feature'
ticket: '1'
created: '2026-10-28'
status: 'built'
baseline_revision: '234ff21a550370af83a76a1315d8492a380ad650'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The only card back is Standard and `Game::CardBacks.active_key` always answers it: nothing records a back a player has unlocked or chosen.

**Approach:** Add the unlock rows and an active back column, make `Game::CardBacks` the one catalogue (key, asset, unlock rule), add `Game::UnlockCardBack` as the only writer, publishing `Game::CardBackUnlocked`, and let `active_key` read the player's choice, falling back to Standard when it is not unlocked. CAP-20 and AD-25 drop the faded back on a card not owned.

## Boundaries & Constraints

**Always:** Expand-only migrations; one event per unlock, published inside the operation's transaction; Standard needs no row; `db/schema.rb` regenerated from the migrations.

**Never:** Grant any back from a handler (entry 2), draw any set back (entry 3), add the picker (Personalization), announce an unlock (entry 5).

</frozen-after-approval>

## Implementation Notes

Oneshot: two migrations, a model, the catalogue, one operation, one event and tests, around 100 lines of code. The spec and the architecture spine carried the faded-back rule; this entry removes it, as the author decided on 2026-10-28.

## Verification

**Commands:**
- `bin/rails test test/domains/game/unlock_card_back_test.rb test/domains/game/card_backs_test.rb test/controllers/packs_controller_test.rb` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing` -- expected: clean

Files: `db/migrate/20261028100000_create_game_card_back_unlocks.rb`, `db/migrate/20261028100001_add_active_card_back_to_game_player_states.rb`, `db/schema.rb` (regenerated from the migrations on a dedicated database), `Game::CardBackUnlock`, `Game::CardBacks` (catalogue, `find`, `active_key` in one query), `Game::CardBackUnlocked`, `Game::UnlockCardBack`, `Game::ReleasePlayer` (also removes the unlock rows), CAP-20 and AD-25 (faded back dropped), and tests. The catalogue holds Standard only: the set backs are entry 3, the goal, achievement and event backs entry 7.

## Review Triage Log

No subagent was available to this run, so the diff was read by the builder against the plan and AGENTS.md, with the full Ruby suite (3222 runs, 0 failures), packwerk, zeitwerk, rubocop and i18n-tasks clean.

- low, deferred: the player data export and the account deletion notice do not mention card backs yet; the picker (Personalization) and the unlock announcement (entry 5) are where a player first sees them, so both land there. Recorded in `deferred-work.md`.
- low, deferred: CAP-20 still says the picker is "in the profile"; the UX session of 2026-10-28 moved it to the Personnalisation page. Recorded in `deferred-work.md`.
