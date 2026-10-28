---
title: 'The seasonal allocation screen'
type: 'feature'
ticket: '2'
created: '2026-10-28'
status: 'built'
baseline_revision: '329a7e26a6a72f1947851ac46bb455761b8f8081'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After a season is published, a returning player must be told once, before the hub, what the ended season gave them and which tiers follow them into the new one; today the allocation of 17.1 is received silently and nothing shows it.

**Approach:** A page `/season-allocation` drawn in the approved design (mockup and spines): the h1 "ALLOCATION · SAISON N" with no sentence under it, then up to three sections and one CONTINUER button. The hub and the booster page redirect to it while the published season is unseen; its POST receives the allocation if still pending and marks it seen through a Game operation that publishes no event.

## Boundaries & Constraints

**Always:** Follow `ux-gameble/mockups/seasonal-allocation/index.html` and the Seasonal allocation sections of DESIGN.md and EXPERIENCE.md. Sections, in order: "Obtenu pendant la saison N" (tiers reached in play in the ended season's sets), "Débloqué pendant la saison N" (the achievements earned in that season, name and date, oldest first, weekly goal rewards excluded; the card backs sub-list is left to the card backs epic and absent for now; the section is omitted when empty), "Vos paliers dans la saison suivante" (tiers received at once, with the line "Reçus d'office dans la saison N, sans célébration."); a tier shows its name then its set, no season mark, no count of seasons, no tiers to win back, no "see more". Two columns on large screens, one on the phone, CONTINUER sticky at the foot of the scroll area. GET never writes; one Pundit policy per action; no database id in the page; strings in en.yml and fr.yml.

**Never:** No redirect from JSON or turbo requests; no event published by the marking operation; no change to the allocation operation or to what a tier means; no card back list yet; no JavaScript when HTML and CSS do the job.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Returning player, unseen season | seen marker below the published number, holds a card of an earlier season | Hub and booster page redirect to the screen; it lists the sections that have content | No error expected |
| Continue | POST while allocation pending | Allocation received, seen marker set to the published number, redirect to the hub | On failure a flash alert shows on the screen, nothing is marked seen |
| Seen already | seen marker equals the published number | The screen's address redirects to the hub; hub and booster page do not redirect | No error expected |
| No card from an earlier season | player holds only the published season's cards or none | Straight to the hub, no screen, no trace | No error expected |
| Trade accepted before returning | allocation already received by the trade | The third section lists the stored allocation rows; continuing only marks seen | No error expected |
| Visitor or banned | no signed-in player | Sign-in as for any page; no redirect | Pundit refusal as elsewhere |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/set_tier.rb` -- `RECEIVE_SQL` holds the carried-tier selection; extract the shared part and add `SetTier.carried` (read-only preview of what the allocation would insert).
- `app/domains/game/app/operations/game/receive_season_allocation.rb` -- reused by the new marking operation; `mark_collection_seen.rb` -- shape of the marking operation.
- `app/domains/game/app/queries/game/profile_titles.rb` -- `Title(kind,key,params,...)` shape that `SetLabel.for` accepts; `catalog` `SetsById` loads sets.
- `app/domains/game/app/models/game/achievements.rb`, `achievement_unlock.rb` -- catalogue and `unlocked_at`; `app/helpers/achievements_helper.rb#achievement_icon` -- takes anything with `key` and `earned`.
- `app/controllers/pages_controller.rb#home`, `boosters_controller.rb#show` -- get the redirect through a shared controller concern; `collection_seen_controller.rb` and `personalizations_controller.rb` -- controller and policy conventions; `application_controller.rb#throttle_player`.
- `app/views/personalizations/`, `app/frontend/styles/personalization.css` -- panel page conventions; `application.css` imports the stylesheets.
- `lib/application_record.rb` -- the `reading` role points to the primary; today the reading role is the primary, so the check needs no role of its own (a first version wrapped it in the writing role and made the booster system tests flaky).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/models/game/set_tier.rb` -- extract the carried selection, add `SetTier.carried(player_id:, season_id:)` -- preview without writing
- [x] `app/domains/game/app/queries/game/season_allocation_pending.rb` -- true when the published season is above the seen marker and the player holds a card of an earlier season, read on the primary like every read today -- shared by both redirects and the screen
- [x] `app/domains/game/app/queries/game/season_allocation_recap.rb` -- the three lists and the season numbers -- feeds the view
- [x] `app/domains/game/app/operations/game/mark_allocation_seen.rb` -- receive if pending, set the seen marker, no event -- the POST's write
- [x] `config/routes.rb`, `app/policies/season_allocation_policy.rb`, `app/controllers/season_allocations_controller.rb`, `app/controllers/concerns/season_allocation_gate.rb` -- show and create, redirects from the hub and the booster page
- [x] `app/views/season_allocations/`, `app/helpers/season_allocations_helper.rb`, `app/frontend/styles/season-allocation.css`, `config/locales/en.yml`, `config/locales/fr.yml` -- the page, its copy and styles
- [x] `test/` -- query, operation, controller and system tests for every matrix row

**Acceptance Criteria:**
- Given a published season above the player's seen marker and a card of an earlier season, when the player opens the hub or the booster page, then they land on the screen once and then reach the hub.
- Given the screen, when it renders in French and English on a phone and a desktop, then it matches the design with the sections that have content.

## Implementation Notes

Full route, implemented directly: this session cannot launch a coding subagent. A player who holds an earlier card but has no tier, achievement or carried tier sees the title and the button alone; the redirect predicate and the page share one query so the two cannot loop.

## Plan Change Log

## Review Triage Log

Own diff review (no independent reviewer: this session could not launch subagents).
- The redirect predicate and the page share `SeasonAllocationPending`, so the hub, the booster page and the screen cannot loop; JSON and non-GET requests are never redirected.
- GET writes nothing: the third section previews through the read-only `SetTier.carried` until the allocation is received, then reads the stored rows.
- The hub query budget grew by one (the seen marker read); the earlier-season holdings read happens only for an unseen season.
- Edge accepted: a player with earlier cards but no tier, achievement or carried tier sees the title and button only.
- Not reproducible-by-me failures seen in full runs: player/export tests failed in two of six full Ruby runs, then passed four times in a row; the booster system tests fail intermittently with or without the new gate and with or without the new system test (checked by disabling the gate). Not caused by this ticket.
- `bundle exec packwerk check` reports a syntax error in `app/views/back_office/players/index.html.erb` (not touched here), and `i18n-tasks check-normalized` flags `config/locales/pagy/fr.yml` (not touched here).

Independent review of e35a2865 (read-only reviewer) and how each finding was handled:
- Medium, fixed: the recap raised `NoMethodError` for a player with no state row (`nil >= n`); a missing row now reads as no received season, like the pending check reads it as seen season 0. Domain test: no state row is pending, the recap previews the carried tiers, marking creates the row. The controller test also renders the screen after the row is deleted, though the request's own activity write puts the row back before the action, so the domain test is the one that fails on the old code.
- Low, fixed: the recap's ended season is always the published number minus one (marker 1 and published 3 says season 2), and a null marker reads the same; both tested.
- Low, fixed: the gate leaves Turbo Frame requests alone (`turbo_frame_request?`), as it already did JSON and HEAD (`request.get?` is false for HEAD); a controller test pins the three.
- Low, kept: the hub budget stays at 20. The seen marker, the collection watermark and the active card back each read the same row through a different query (a pick, a join inside `CollectionSlots`, a join in `CardBacks`); loading it once would thread one object through three unrelated queries for one saved lookup.
- Low, covered by tests: the failure alert text, the section of the ended season with no season mark or season count on a tier, the booster page after the season is seen, a POST when nothing is pending, a player with no earlier card, the title taking the focus with the button as the screen's only stop, and the sticky button staying in view at three scroll positions on a phone-width list of twelve extra tiers.
- Low, accepted as planned: a player with earlier cards and nothing to show sees the title and the button only.
- Booster system tests (`booster_test.rb`, reveal timing) failed twice in two of three runs while three other agents ran suites on the same machine, then passed 90 of 90; they do not touch the allocation and are left for a separate fix.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers/season_allocations_controller_test.rb test/controllers/pages_controller_test.rb test/controllers/boosters_controller_test.rb` -- expected: pass
- `bin/rails test test/system/season_allocation_test.rb test/system/hub_test.rb test/system/booster_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing unused`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
