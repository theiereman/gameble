---
title: 'A back earned in several seasons wears the season the player picks'
type: 'feature'
ticket: '6'
created: '2026-10-28'
status: done
baseline_revision: '88b5fc4d78ab050b0ab8ad8afce177d58af2ce72'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [self-review]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A set back is earned again in every season the player reaches its back tier (a carried tier counts), but the player cannot say which season's mark the back wears, and the opened pack does not remember one.

**Approach:** Store the picked season on the player's state and on each opened pack, read the seasons a set back was earned in from the player's tier rows joined to the sets' seasons, let the picker choose among them, and lay a season-mark stamp over the existing back on the booster and in the picker preview. Never redraw a back per season.

## Boundaries & Constraints

**Always:** the stamp is a small "S2" mark laid over the existing back image; only set backs carry seasons (goal, achievement and event backs are earned once); a back earned in one season shows no choice and no stamp; a tier and the grid never show a stamp; the pack stores the season it wore at opening.

**Never:** a redrawn back per season; a stamp on the picker grid tiles; an id in a URL; a write from a GET.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Earned in two seasons | choose back with season 1 | state stores back and season 1; next pack stores 1; booster shows S1 | No error |
| Earned in two seasons, no season given | choose back | latest season stored | No error |
| Earned once | choose back | no season stored, no stamp | No error |
| Season not earned | choose back with a season outside the back's seasons | nothing changes | Failure(:unknown_season) |
| Other back chosen | choose another back | season cleared | No error |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/earned_set_backs.rb` -- tier-row SQL for the back tier; the seasons query shares it.
- `app/domains/game/app/queries/game/card_back_seasons.rb` -- new: season numbers a back was earned in, per back.
- `app/domains/game/app/operations/game/choose_card_back.rb` -- takes `season:`, validates it, stores it, event carries it.
- `app/domains/game/app/operations/game/open_pack.rb`, `models/game/card_backs.rb` -- the pack stores the active season.
- `app/helpers/packs_helper.rb`, `app/views/boosters/_opened.html.erb`, `app/frontend/lib/booster_markup.ts`, `opening.ts`, `booster_motion.ts`, `controllers/booster_stage_controller.ts`, `styles/booster-layouts.css` -- the season reaches the back element as a data attribute drawn by CSS.
- `app/components/season_mark_component.rb` -- new: the stamp, reused by the recap.
- `app/views/personalizations/_back_picker.html.erb`, `app/controllers/card_backs_controller.rb`, `app/controllers/personalizations_controller.rb`, `styles/personalization.css` -- the mark choice and the preview stamp.
- `db/migrate/` -- two nullable integer columns, `db/schema.rb` regenerated.

## Tasks & Acceptance

**Execution:**
- [x] migration -- `active_card_back_season` on player states, `card_back_season` on packs -- expand only
- [x] `Game::CardBackSeasons` and `ChooseCardBack` -- seasons read and validated, season stored
- [x] `OpenPack` and pack helpers -- the pack stores and serves its season
- [x] booster markup, CSS and the stamp component -- the stamp over the back
- [x] picker -- the mark choice and the preview stamp, texts in en and fr
- [x] tests -- query, operation, controller, helper, vitest, system

**Acceptance Criteria:**
- Given a back tier of the same set in two seasons, when the player opens the picker, then both marks are offered and the chosen one is stamped on the preview.
- Given a pack opened with a picked season, when the booster shows its cards, then the back carries the stamp of that season.
- Given a back earned once, when the picker shows it, then there is no mark choice and no stamp.

## Implementation Notes

- Assumption (not written in the spec): the mark is the season's number ("S2"), stored as an integer; only set backs have seasons; choosing a multi-season back without naming a season stores the latest; a single-season back stores none.
- Assumption: the recap of the finished season (9.8) is not changed here; the stamp component is ready for it.
- Not run by the builder: tests and checks (the coordinator runs them once in the main tree).

## Plan Change Log

## Review Triage Log

Self-review of the diff (no subagent, no test run by the builder):

- `EarnedSetBacks.call` now de-duplicates keys, since its rows carry the season number; behaviour for unlocking is unchanged.
- `ChooseCardBack` validates the requested season against the tier rows before storing; a back with fewer than two earned seasons stores none, so the stamp and the choice only appear for a real choice.
- The pack copies the season at opening in the same single query that already read the active back, so the opening's query count is unchanged.
- The stamp is a data attribute drawn by a pseudo-element on the booster and a component in the picker preview; the grid tiles and the tiers never show it.
- Player export gains `activeSeason` and `cardBackSeason`; its tests are updated. The `CardBackChosen` event now carries `season`; the one test asserting its data is updated.
- Not covered by a system test: the stamp on a revealed booster (only vitest and the template attribute are tested); the coordinator may add one.

## Verification

**Commands:**
- `bin/rails test test/domains/game/card_back_seasons_test.rb test/domains/game/choose_card_back_test.rb test/controllers/card_backs_controller_test.rb` -- expected: green
- `npm run test:js` -- expected: green
