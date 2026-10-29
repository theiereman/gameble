---
title: 'The title picker on the Personalization page'
type: 'feature'
ticket: '3'
created: '2026-10-28'
status: done
baseline_revision: '07e042d3a7c45c94abc94a78dc2235f8b546078b'
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

**Problem:** A player earns titles from their set tiers (ticket 24.1) but cannot choose which one represents them.

**Approach:** A "TITRE DE PROFIL" section on the Personalization page lists the earned titles as text in a radio group, grouped by rank with the highest first, with a first "Aucun titre" row. Choosing is immediate through a PATCH that goes through `Game::ChooseProfileTitle`, which stores the set kind, key and rank (never the metal) on `game_player_states` and publishes `Game::ProfileTitleChosen`.

## Boundaries & Constraints

**Always:** write only through the operation; one event inside its transaction, no feed handler; the chosen title is checked against the titles the player earned (`Failure(:title_not_earned)` even for a forged request); expand-only migration; every string in en.yml and fr.yml, `errors.game.title_not_earned` added by hand in both; Pundit policy on the action; no database ids.

**Never:** show the active title on the profile, the feed or trades (that is the next ticket); store the metal; reformat a locale file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Equip | earned title sent | stored, one event, toast "TITRE ÉQUIPÉ", the option is checked after reload | none |
| Remove | empty value | columns cleared, toast "TITRE RETIRÉ", "Aucun titre" checked | none |
| Forged | title not earned | nothing written, no event | alert toast, 422 on turbo and json |
| None earned | player without tiers | one sentence on how to earn one, no empty group, "Aucun titre" only | none |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/profile_titles.rb` -- earned titles (`Title` with kind, key, params, rank); reuse, add no write.
- `app/helpers/profile_titles_helper.rb` -- `profile_title_text`; reuse for the option text and the toast.
- `app/domains/game/app/operations/game/unlock_card_back.rb` and `receive_season_allocation.rb` -- operation pattern (`require_player`, `lock_bank`, `publish`, `stream_name`, `PlayerState.insert` then lock).
- `app/controllers/personalizations_controller.rb`, `app/views/personalizations/{show,_section}.html.erb`, `app/policies/personalization_policy.rb`, `config/routes.rb` -- the page, its section partial, policy and route.
- `app/controllers/showcases_controller.rb` -- pattern for the refusal toast, flash toast and focus after a redirect.
- `app/frontend/controllers/`, `app/frontend/styles/personalization.css` -- a thin Stimulus controller submitting the form on change; section styles.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- add nullable `active_title_kind`, `active_title_key`, `active_title_rank` to `game_player_states`, then a check that the three are all null or all set (added unvalidated, validated in a second migration); regenerate `db/schema.rb` as AGENTS.md says.
- [x] `app/domains/game/app/{operations/game/choose_profile_title.rb,events/game/profile_title_chosen.rb,queries/game/active_profile_title.rb}` -- the operation, its event and the read of the active title among the earned ones.
- [x] `app/controllers/profile_titles_controller.rb`, `app/policies/profile_title_policy.rb`, `config/routes.rb` -- PATCH `/personalization/title`.
- [x] `app/views/personalizations/{_title_picker.html.erb,show.html.erb}`, `app/frontend/controllers/radio_submit_controller.ts`, `app/frontend/styles/personalization.css` -- the section.
- [x] `config/locales/{en,fr}.yml` -- the approved copy and the error key.
- [x] tests -- operation, query, controller, system.

**Acceptance Criteria:**
- Given earned titles, when the player picks one, then it persists across a reload with the toast.
- Given a title not earned, when it is sent, then nothing is written and no event is published.
- Given no earned title, then the section shows the sentence and only "Aucun titre".

## Implementation Notes

Full route, implemented directly: the build runs in a worktree agent that cannot spawn a coding subagent.

## Plan Change Log

## Review Triage Log

Self-review of the diff (no subagent available in this worktree):
- Fixed: the controller's own `refuse` shadowed the `ApplicationController` rescue handler for a visitor; renamed `title_refused`.
- Fixed: the rank headings sit inside the radio group, which allows radios only; they are hidden from assistive technology since every option text already carries its rank.
- Kept: the posted value is split on `:` with a limit of three parts, so a set key containing a colon still round-trips; an unknown or malformed value ends in `title_not_earned`.
- Kept: `db/schema.rb` keeps the HEAD spelling of the unrelated `reached_by` check; the regenerated one only differs in how Postgres prints it.

## Design Notes

The sent value is `rank:kind:key` (a set key never holds a colon); an empty value removes the title.

## Verification

**Commands:**
- Ruby tests of the touched files and the Game suite, the system test of the page, `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, rubocop, i18n-tasks, `script/check_file_sizes`, `script/check_planning_references` -- all clean.
