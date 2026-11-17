---
title: 'Refactor sweep'
type: 'refactor'
ticket: '4'
created: '2026-11-17'
status: 'built'
baseline_revision: '7250f668710f8b30d2074d4f05fe3a270fec09eb'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The three builds of the duel capsule, record and achievements epic left one N+1 (each DERNIERS DUELS row reads its opponent alone), a few expressions written twice in the record and profile queries and the spoken result helpers, one comment the code can state, and two contradicting lines in `deferred-work.md` about the Duelliste back.

**Approach:** Make only the cleanups below, each behaviour-neutral; record every other finding as deferred. No migration, no change to a rendered page, a JSON answer, a stream or the pixel art.

Cleanups:
1. `Accounts::PlayersById` reads the opponents of all DERNIERS DUELS rows in one query for `DuelHistory`.
2. `Game::DuelRecord::WINS_SQL` is the duels-won metric's SQL; `Game::ProfileActivity` reads `AchievementProgress::FIRST_DISCOVERIES_SQL` instead of its copy.
3. `duel_result_spoken` builds on `duel_result_line_spoken`, which a duel result and a history row share.
4. `Game::DuelCapsule.award` loses its explanatory comment.
5. Eleven French strings of the record and Comment ça marche's duels section took a plain space before `:` and `;`; they take the narrow no-break space `FrenchTypographyTest` requires (a defect, not a cleanup, found by the full suite).
6. `deferred-work.md` states what is true about the Duelliste back and settles the N+1 line.

</intent-contract>

## Implementation Notes

Oneshot: about thirty lines, each local and behaviour-neutral.

Checked and found clean: no file of the epic over its limit; no unused method or constant in the capsule, record, history and achievement files; no TypeScript beyond one string; the remaining comments are the pixel art descriptions the sibling icons carry.

The Duelliste back: the capsule ticket added the 17 x 17 blades emblem and the duel origin to `origin_canisters.mjs`; the back keeps its own motif (seven rows of blades over two cards, its own palette) in `named_backs.mjs`, the emblem leaving no room for the cards, and DESIGN.md asks for exactly that. The earlier deferred line saying the capsule ticket "may reuse" the grid and the later `resolved` line were not in conflict about the code, only about the reason; the line now says it. No code change.

Weighed and left, in `deferred-work.md`: the four blade drawings, the `nil` of `Game::DuelCapsule.award`. Not touched: migrations, the pixel art, the plans' deferred items that are behaviour work (top-bar chips on the closing push, an empty tier in the season, achievement flavours).

## Verification

**Commands:**
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing` -- expected: clean
- System tests `duel_record_test.rb`, `duel_capsule_test.rb`, `duel_achievements_test.rb`, one at a time -- expected: green

## Auto Run Result

**Summary:** cleanup across the epic's capsule, record, history and spoken-result code, plus one typography fix the full suite found.

**Files changed**
- `app/domains/accounts/app/queries/accounts/players_by_id.rb` (new), `app/models/duel_history.rb`: one query for the opponents of the last duels.
- `app/domains/game/app/queries/game/duel_record.rb`, `profile_activity.rb`: reuse the metric SQL instead of copies.
- `app/helpers/duels_helper.rb`: `duel_result_spoken` builds on `duel_result_line_spoken`.
- `app/domains/game/app/models/game/duel_capsule.rb`: one comment dropped.
- `config/locales/fr.yml`, `test/controllers/duels_controller_test.rb`: narrow no-break space before `:` and `;`.
- `test/models/duel_history_test.rb`, `test/domains/accounts/players_by_id_test.rb` (new).
- `_bmad-output/initiative-gameble/deferred-work.md`: the Duelliste lines made true, the N+1 settled, two entries.

**Review (none, pinned):** the author reviews the whole duel diff.

**Verification:** `bin/rails test` (6000 runs, only the known error pages build script test fails), the three system test files of entries 1 to 3 one at a time, `npm run test:js`, `zeitwerk:check`, `packwerk check`, `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing`, rubocop: clean.

**Follow-up review recommended:** false.
