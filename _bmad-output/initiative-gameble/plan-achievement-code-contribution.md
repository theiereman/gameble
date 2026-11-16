---
title: 'A code-contribution achievement the author grants from the back office'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'built'
baseline_revision: 'fd5b3df20764746a9f457dca184ccbb58ed1d892'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The author wants an achievement for contributing to the gameble code. Nothing in the game can tell who contributed, so the author must grant it by hand.

**Approach:** Keep a nullable marker on `game_player_states`, add an administrator-only action on the back office players list that sets it through a Game operation publishing an event, and add one catalogue entry read from the marker.

## Boundaries & Constraints

**Always:** Follow `plan-achievements-untraced-actions.md` for the marker column (expand-only migration, regenerated `db/schema.rb`), the operation shape, the event, the handler trigger, the glyph, both locales, the privacy and export wording. The action is a POST behind `BackOffice::PlayersPolicy`-style authorization for administrators only, rate-limited like the bans, and the button shows only for a player in good standing not yet marked. The grant raises the usual achievement toast through the existing grant path.

**Decisions (author, 2026-11-16):** The author grants it by hand; there is no GitHub link or automatic check. No undo action. Name: fr "Contribution en nature", en "Contribution in Kind"; glyph `clasp`.

**Never:** No change to `Accounts` (Game may read Accounts, never the reverse); no moderation-history row; no automation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|----------|--------------|----------|
| Grant | Administrator, player in good standing | marker set once, event published, achievement granted |
| Repeat | Player already marked | refused, marker unchanged, no second event |
| Not an administrator | Moderator or player | refused by policy, nothing written |
| Banned, deleted or unknown player | any | refused, nothing written |

</frozen-after-approval>

## Code Map

- `app/controllers/back_office/bans_controller.rb`, `players_controller.rb`, `app/policies/back_office/players_policy.rb` (`destroy? = administrator?`), routes under `scope "back-office"`, `views/back_office/players/index.html.erb` and `_erase_action.html.erb` -- the pattern for a staff action and its button.
- `Accounts::BanPlayer.refusal`, `Accounts::Player.acting_staff?` -- the staff checks to mirror in the Game operation.
- `app/domains/game/app/models/game/player_state.rb`, `operations/game/mark_link_opened.rb` -- marker pattern from the lot B plan.
- `achievements.rb`, `achievement_progress.rb`, `handlers/achievements.rb`, `achievements_helper.rb`, `export_of.rb`, privacy text in `config/locales/*.yml`.

## Tasks & Acceptance

**Execution:**
- [ ] Migration: `code_contribution_at` datetime on `game_player_states`; regenerate `db/schema.rb`.
- [ ] `operations/game/grant_code_contribution.rb`, `events/game/code_contribution_granted.rb`, controller, route, policy, button partial on the players list (admin, good standing, not yet marked), event registration.
- [ ] Catalogue entry `code_contribution` (metric `code_contributions`, threshold 1), metric, handler trigger, glyph mapping, en/fr strings, privacy and export wording.
- [ ] Tests: operation (each matrix row), controller, policy, metric, button visibility; totals derived from `CATALOGUE`.

**Acceptance Criteria:**
- Given an administrator on the players list, when they grant the achievement to a player in good standing, then the player earns it and sees the toast.

## Verification

**Commands:**
- `bin/rails test` and `npm run test:js` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing`, `npm run format:check` -- clean

## Implementation Notes

## Plan Change Log

## Review Triage Log

- Pass 1 (quick): 4 patched, 3 rejected.
  - patched -- no test showed the grant earning the achievement: an end-to-end test performs the grant job and checks the unlock.
  - patched -- hard-coded catalogue total removed from the catalogue pin test.
  - patched -- export test now asserts the marker is nil when ungranted.
  - patched -- the class comment restated the name: removed.
  - rejected -- `staff_id` unused in the event data: kept as the audit trail of who granted.
  - rejected -- one `:player_not_found` code for banned and deleted players: the button is hidden for them, the refusal only guards a forged POST.
  - rejected -- the trigger count `23` in `achievements_test.rb` is a hand count of events: it is the existing pattern of that test.
