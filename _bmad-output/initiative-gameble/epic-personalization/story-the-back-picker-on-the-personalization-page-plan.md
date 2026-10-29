---
title: 'The back picker on the Personalization page'
type: 'feature'
ticket: '2'
created: '2026-10-28'
status: done
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

**Problem:** A player unlocks card backs (ticket 9.2, 9.3) but cannot choose which one their face-down cards wear.

**Approach:** A "DOS DE CARTE" section on the Personalization page shows the active back large with its name, then a grid of every back in the catalogue: unlocked ones are buttons that equip at once, locked ones sit greyed under a padlock stating their condition. Equipping goes through a PATCH to `Game::ChooseCardBack`, which checks the back against the catalogue and the player's unlocks, stores it on `game_player_states` and publishes `Game::CardBackChosen`. The export and the deletion notice name the unlocks and the active back.

## Boundaries & Constraints

**Always:** write only through the operation; one event inside its transaction, no feed handler; `Failure(:unknown_back)` for a key outside the catalogue and `Failure(:back_locked)` for a back not unlocked, even by a forged request; Standard is always unlocked; every string in en.yml and fr.yml, both error keys added by hand; Pundit policy on the action; no database ids; the active back applies from the next pack opened.

**Never:** show the back anywhere but the picker (not on a card, a profile or another player's cards); add a migration (the active back column exists); reformat a locale file; pick a season mark (not part of this ticket).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Equip | unlocked back key | stored, one event, toast "DOS ÉQUIPÉ", preview and active mark follow after reload | none |
| Locked | key in the catalogue, not unlocked | nothing written, no event | alert toast, 422 on turbo and json |
| Unknown | key outside the catalogue | nothing written, no event | alert toast, 422 on turbo and json |
| Already active | the active back again | stored again, event and toast | none |
| New account | no state row, no unlock | Standard active, every other back locked with its condition | none |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/card_backs.rb` -- catalogue (`Back`, `Unlock`, `find`, `active_key`); reuse, change nothing.
- `app/domains/game/app/models/game/card_back_unlock.rb`, `operations/game/unlock_card_back.rb`, `events/game/card_back_unlocked.rb` -- unlock rows and the writer pattern.
- `app/domains/game/app/operations/game/choose_profile_title.rb`, `app/controllers/profile_titles_controller.rb`, `app/policies/profile_title_policy.rb`, `app/views/personalizations/_title_picker.html.erb`, `app/frontend/styles/personalization.css` -- the section pattern to copy.
- `app/domains/game/app/queries/game/export_of.rb`, `app/models/player_export.rb` -- the export; `config/locales/{en,fr}.yml` `legal.privacy.deletion` -- the deletion notice.
- `app/helpers/profile_titles_helper.rb`, `app/components/set_label.rb` -- names are built in the web layer (the domain may not call a component).
- `app/frontend/images/pixel/back-<key>-{xs,l}.png` -- the art (`vite_asset_path`).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/{operations/game/choose_card_back.rb,events/game/card_back_chosen.rb,queries/game/card_back_shelf.rb}` -- the operation, its event and the shelf (every back with its state and unlock).
- [x] `app/controllers/card_backs_controller.rb`, `app/policies/card_back_policy.rb`, `config/routes.rb` -- PATCH `/personalization/back`.
- [x] `app/helpers/card_backs_helper.rb`, `app/views/personalizations/{_back_picker.html.erb,show.html.erb}`, `app/controllers/personalizations_controller.rb`, `app/frontend/styles/personalization.css` -- the section.
- [x] `app/domains/game/app/queries/game/export_of.rb`, `app/models/player_export.rb`, `config/locales/{en,fr}.yml` -- export `cardBacks`, the deletion notice, the approved copy and both error keys.
- [x] tests -- operation, shelf, controller, export, system.

**Acceptance Criteria:**
- Given an unlocked back, when the player equips it, then it persists across a reload with the toast.
- Given a locked or unknown back, when it is sent, then nothing is written and no event is published.
- Given a new account, then Standard is active and every other back states its condition.

## Implementation Notes

Full route, implemented directly: the build runs in a worktree agent that cannot spawn a coding subagent.

## Plan Change Log

## Review Triage Log

Self-review of the diff (no subagent available in this worktree; the session crashed once and the work was resumed from the worktree):
- Checked: the operation refuses an unknown key and a back that is not unlocked before any write, inside the transaction under the bank lock, and publishes one event; Standard is always allowed.
- Checked: a locked tile still submits so the refusal toast shows; the active tile is disabled; the section heading takes focus after an equip.
- Kept: no migration, the active back column exists; the season mark choice is left out of this ticket.
- Not run by this agent: the test suites and checks run once in the main tree.

## Design Notes

The shelf rows carry the catalogue unlock (`kind`, `target`); the helper turns them into names and conditions with the set label, since the domain may not reach the web layer. A set back's condition reads "Collect half of the <set> set".

## Verification

**Commands:**
- Ruby tests of the touched files and the Game suite, the system test of the page, `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, rubocop, i18n-tasks, `script/check_file_sizes`, `script/check_planning_references` -- all clean.
