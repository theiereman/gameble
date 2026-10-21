---
title: 'The card detail names its pioneer'
type: 'feature'
ticket: '13'
created: '2026-10-21'
status: 'built'
baseline_revision: '8e8d585f3f1224526e2a84aaec1883d9dd195c13'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/key-card-detail-pioneer.html'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The card detail never says who first discovered a card, so the « Découvrez » promise has nothing behind it.

**Approach:** The facts block gains one PIONNIER row, right after SAISON: the first player to discover the published season's edition of the card, as a link to their profile with the discovery date; « Un joueur anonyme » with the date for anyone not allowed to see that profile.

## Boundaries & Constraints

**Always:**
- One line per card, for the edition of the published season, even when the detail shows an older season.
- Named, with a link, to any viewer for whom `Game::Visibility` allows the pioneer's profile, a visitor included when that profile is public; a banned or deleted pioneer, a private or friends-only profile the viewer may not see: « Un joueur anonyme », no link, the date kept. Staff see what any player sees.
- A card with no recorded discovery shows no row; nothing is backfilled.
- The link uses the player's token, never a database id; strings in `en.yml` and `fr.yml`; the French date reads « le 1er mars 2026 » on the first of a month.
- The signed-out public card page shows the same pioneer too (author, 2026-10-21, renegotiating the plan): one line "Pionnier" with its value, between the rarity line and the description, in the same named or anonymous form; the public card page's query count rises by the pioneer read only.

**Never:**
- No change to how first discoveries are recorded, no pioneer per edition.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Named | Viewer allowed to see the pioneer's profile (a visitor, if public) | PIONNIER row: name link to the profile, date | None |
| Anonymous | Banned or deleted pioneer, or profile hidden from the viewer | « Un joueur anonyme » and the date, no link | None |
| Public card page | Visitor opens a shared link | The pioneer line between the rarity line and the description | None |
| Older season shown | Detail of a past season's edition | The published season's pioneer | None |
| No discovery | No first-discovery row | No PIONNIER row | None |

</frozen-after-approval>

## Code Map

- `packs/game/app/queries/game/pioneer_of.rb` (new) -- one query: card id to the published season's first discovery, its player and date; model on `held_editions.rb`
- `packs/game/app/models/game/visibility.rb` -- `visible?(viewer, owner, staff_sees_all: false)` decides named or anonymous; a nil viewer sees a public profile
- `app/controllers/concerns/card_detail_loading.rb`, `app/controllers/cards_controller.rb` -- load the pioneer for the signed-in detail only, never for `@public`
- `app/views/cards/_detail.html.erb`, `app/helpers/card_details_helper.rb` -- the row between SAISON and SETS, `brother_path(token:)`, persona name through `Accounts::PersonaName`
- `app/frontend/styles/card-detail.css` -- `card-detail__pioneer`, `-date`, `-anon` from the mock; same focus ring as the sets links
- `config/locales/{en,fr}.yml` -- `card_details.facts.pioneer`, `card_details.pioneer.anonymous`, a long-day date format
- `test/controllers/cards_controller_test.rb`, `test/fixtures/game/first_discoveries.yml` -- fixtures all name the banned player: add a visible pioneer; query counts rise by the pioneer reads; the page must still carry no database id

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/pioneer_of.rb`, `app/controllers/...`, `app/views/cards/_detail.html.erb`, `app/frontend/styles/card-detail.css`, `config/locales/*` -- build the row as the Code Map describes
- [ ] `test/` -- one test per matrix row, the query-count tests updated, no id in the page, the French first-of-month date

**Acceptance Criteria:**
- Given a card whose pioneer's profile the viewer may see, when the detail opens, then PIONNIER shows their name as a link and the date.
- Given a banned or deleted pioneer, or a profile hidden from the viewer, when the detail opens, then it shows « Un joueur anonyme » with the date and no link.
- Given the signed-out public card page, when it loads, then it shows the pioneer line, named for a public profile and « Un joueur anonyme » otherwise, and no database id reaches the page.

## Implementation Notes

## Plan Change Log

## Review Triage Log

- low, rejected: `-anon` class has no CSS rule; the dd already inherits the bright colour, so rendering is identical and the fix adds nothing.
- low, rejected: a friends-only pioneer adds one friendship query for a signed-in viewer; real but cheap, and a guard would add complexity.
- low, rejected: persona name cleaned in the controller, other views clean in the view; style only.
- low, rejected: ambiguous public-page header comment; comment only.
- low, rejected: fixtures unchanged, tests reassign the pioneer; the flake needs a run across midnight.
- low, rejected: `long_day_first` duplicates `long_day` in en; harmless, it lets the helper pick a key per locale.

## Design Notes

Decided without the author, from the spec: a visitor reads the name of a public profile (author, 2026-10-21, which amends the spec line saying visitors read « anonyme »); staff are not given the banned pioneer's name. No backfill: only discoveries since first discoveries were recorded exist; older card-seasons show no row.

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb test/packs/game` -- expected: passes
- `bin/rails test`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean
