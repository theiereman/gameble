---
title: 'The community weekly goal is called the weekly mission everywhere a player reads it'
type: 'chore'
ticket: '13'
created: '2026-10-31'
status: 'built'
baseline_revision: '91b12f35be3494ca24e9a84241dcc7087a6fe87b'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The community weekly goal is called "objectif communautaire" / "community goal" on the hub, landing, capsule screen, toasts, the how-it-works page, the legal and deletion texts and the card back condition, while the coming active goals take the word "objectif"; the design renamed the weekly one the weekly mission, "MISSION HEBDO", so "objectif" names only the player's goals.

**Approach:** Rewrite the value of every player-facing locale key that names the weekly goal, in `config/locales/fr.yml` and `config/locales/en.yml`, to the mission wording of the copy deck (`MISSION HEBDO` / weekly mission, `MISSION ACCOMPLIE` / mission accomplished, `RÉCOMPENSE DE MISSION` / mission reward, "Une mission pour tous", "La prochaine mission s'ouvre aussitôt", "une mission commune chaque semaine", "Accomplissez des missions…"), keeping every key name, DOM id, CSS class, token, model, table and event as it is; update the tests that assert the old wording, and have the hub, landing and capsule system tests read the new one. The roadmap's milestones and stories are stored data the author writes in the back office, so they stay as they are.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `config/locales/fr.yml`, `config/locales/en.yml` -- new values for `pages.home.goal.{title,reached,previous_reached,previous_missed}`, `pages.how_it_works.goal.{title,week,reward.*}`, `pages.how_it_works.packs.reward`, `pages.legal.privacy.{stored.activity,retention.leftovers,deletion}`, `accounts.dialog.{note,kept}`, `card_backs.conditions.goal`, `booster.origin.reward`, `booster.strings.origin_reward`, `goal_rewards.create.title`, `landings.show.brotherhood.goal.{title,reached,ends}`, `landings.show.unlock.{subtitle,tiles.goal.title,tiles.goal.text,tiles.backs.text}` -- the mission wording, French `zero` forms kept.
- [ ] `test/` -- the controller, job and system tests asserting the old wording read the new one; `test/system/hub_test.rb` and a landing system test assert the mission panel's title.

**Acceptance Criteria:**
- Given either locale, when a player reads the hub panel, the landing, the capsule screen's origin, the reward toast, how it works, the legal page or the deletion dialog, then the weekly mission is named a mission and no "objectif" / "goal" names it.
- Given `bundle exec i18n-tasks missing` and `unused`, when run, then both are clean.

## Implementation Notes

Oneshot: about 80 lines, all locale values and test strings, one mechanical rename.

- Values rewritten by exact-substring rules, so French spacing before `:` and the `zero` plural forms stay as they were; 27 values per locale, no key renamed. A walk of both files finds no value matching /objectif|goal/i.
- Wording beyond the copy deck: the hub's last-week line reads "· mission accomplie" / "· mission manquée" ("mission accomplished" / "mission missed"); how it works reads "La mission hebdo" / "The weekly mission", "tous les joueurs mènent ensemble une même mission" / "all players take on one mission together", "Si la mission est accomplie" / "When the mission is accomplished"; legal texts, the deletion dialog and the card back condition say "la mission hebdo" / "the weekly mission"; the English backs tile reads "Complete missions to unlock new ones". The landing panel keeps its two lines (text, then "Mission accomplie : tous les participants sont récompensés."), which reads as the deck's single line.
- The 05 tile example chip "Atteint" / "Reached" stays: the copy deck keeps it.
- Not changed: the roadmap's milestones and stories (stored data written in the back office), the canister asset description "Goal reward" in `script/pixel_art/origin_canisters.mjs` (a developer manifest no player reads), code comments, DOM ids (`community-goal`), CSS classes and the `capsule-goal` token.
- Tests: wording updated in the pages, goal rewards, how-it-works, accounts controller tests, the live goal job test, and the booster reserves and season allocation system tests; the hub desktop system test asserts the panel title "Weekly mission"; a new landing system test reads "One mission for all", the next-mission line and the "Weekly mission" tile, and finds no "goal" on the landing.
- `bin/setup` (inside `bin/ci`) touched `package-lock.json`; reverted, not part of this change.

## Verification

**Commands:**
- `ruby` walk of both locale files for values matching /objectif|goal/i -- expected: none left for the weekly mission
- `bin/rails test test/controllers/pages_controller_test.rb test/controllers/goal_rewards_controller_test.rb test/controllers/how_it_works_test.rb test/controllers/accounts_controller_test.rb test/controllers/landing_page_test.rb test/jobs/live_goal_job_test.rb` -- expected: pass
- `bin/rails test test/system/hub_test.rb test/system/booster_reserves_test.rb test/system/season_allocation_test.rb test/system/landing_power_on_test.rb` -- expected: pass
- `bin/ci`, `npm run test:js`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `script/check_planning_references` -- expected: pass

## Review Triage Log

### 2026-10-31 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The landing test's `assert_no_text(/goal/i)` reads only the visible modules: those still `data-power=armed` below the power line hold children at opacity 0, so 06 to 09 were never checked — patched: the test now scrolls to the last module (`landing-boarding`), asserts no module is still armed, then asserts no "goal" text; the four touched system test files pass (35 runs).

## Auto Run Result

- **Summary:** the community weekly goal is the weekly mission in every player-facing text, French and English: 27 locale values per language rewritten to the copy deck's mission wording (MISSION HEBDO / Weekly mission, Mission accomplie / Mission accomplished, RÉCOMPENSE DE MISSION / MISSION REWARD, Une mission pour tous / One mission for all, and the how-it-works, legal, deletion dialog and card back texts). No key, DOM id, class, token, table or stored datum renamed.
- **Files changed:**
  - `config/locales/fr.yml`, `config/locales/en.yml` -- the mission wording.
  - `test/controllers/{pages_controller,goal_rewards_controller,how_it_works,accounts_controller}_test.rb`, `test/jobs/live_goal_job_test.rb` -- assert the new wording.
  - `test/system/booster_reserves_test.rb`, `test/system/season_allocation_test.rb` -- assert MISSION REWARD and the card back condition.
  - `test/system/hub_test.rb` -- the hub panel reads "Weekly mission".
  - `test/system/landing_power_on_test.rb` -- new test: the Brotherhood panel, the next-mission line and the unlock tile read the mission wording, and the powered-on landing shows no "goal".
  - `_bmad-output/initiative-gameble/deferred-work.md` -- the roadmap's stored wording, for the author.
- **Review:** quick lens, 1 finding: 1 patch (low), 0 deferred, 0 rejected.
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 1).
- **Verification:** `bin/ci` passed (3742 runs, 0 failures; i18n missing, packwerk, rubocop, format, CSS lint, planning references, file sizes, brakeman, schema, seeds); `npm run test:js` 756 passed; `bin/rails zeitwerk:check` all good; `bundle exec i18n-tasks missing` and `unused` clean; `script/check_planning_references` clean; the six touched controller/job test files pass (122 runs); `bin/rails test test/system/landing_power_on_test.rb test/system/hub_test.rb test/system/booster_reserves_test.rb test/system/season_allocation_test.rb` pass (35 runs) after the patch.
- **Residual risks:** the roadmap entries in production may still name the community goal (stored data; deferred to the author). The `goalRewardWeeks` export field and code names keep "goal" by design.
