---
title: 'Four tabs and no More'
type: 'feature'
ticket: '2'
created: '2026-11-02'
status: 'built'
baseline_revision: '41d33ee00aef56aa9a486a9ec24207804dcbf2a6'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The phone tab bar has five tabs and a "More" screen that buries eight destinations; "Collection" and "All cards" are two entries for one thing, and drill-down headers still show a wordmark, a divider and a title.

**Approach:** Four tabs (Capsule, Sets, Social, Me) drawn as new pixel icons; All cards becomes a view of Sets reached by a two-segment switch on both screens; the More screen goes and its route redirects; every former More destination is reachable within two taps; on phone a drill-down header shows only a back button.

## Boundaries & Constraints

**Always:** server-rendered ERB; en and fr strings together; pixel icons only through `node script/pixel_art/export.mjs`; keep `navigation-lock` and the visitor tab set working; the tab bar stays phone only; badges keep updating through the player stream; desktop header and hub menu unchanged.

**Decisions (author, 2026-11-02):** the Social and Me tabs open two interim menu pages (Social: Trades, Friends, Feed; Me: Settings, Personalization, Achievements, How it works, Support); the Capsule tab opens the booster screen and the hub stays reachable from the G button; the trades-waiting and friend-invitation badges move to Social, the achievements badge to Me.

**Never:** the Social and Me pages themselves (entries 8 and 12 replace the interim landings), the bottom sheet, the bell, new trade rules, adding tests to the oversize `test/system/shell_test.rb` and `test/integration/shell_test.rb` beyond fixing broken assertions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tab bar | signed-in player on a phone | four tabs Capsule, Sets, Social, Me with the current one marked, including on a drill-down of that tab | none |
| Old route | GET /en/more | permanent redirect to the Me landing | none |
| Visitor | signed out | two-tab bar unchanged | none |
| Reach | any former More destination | within two taps from a tab | none |

</frozen-after-approval>

## Code Map

- `app/views/shell/_tab_bar.html.erb` (34 lines) -- tab list and active-tab table; `shell-status.css` 163-245 hardcodes `repeat(5, ...)`.
- `app/views/pages/more.html.erb`, `PagesController#more`, `config/routes.rb:169`, `robots_controller.rb:6`, `settings.css:191-207` -- the screen to turn into the Me landing and redirect.
- Social landing: new small page listing Trades, Friends, Feed (route and policy) -- to be replaced by entry 8.
- `app/views/library/show.html.erb`, `library/cards.html.erb` -- add the Sets | All cards switch; keep `library_cards_path` (visitor tab, landings, legend).
- Back buttons `more_path` with label key `.more` in settings, personalizations, feeds, friends, achievements, how_it_works views -- point to the new parent.
- `_top_bar.html.erb`, `shell-screens.css` 155-179, `shell-top-bar.css` 42-48 -- phone drill-down header with the back button only.
- Badges `#tab-more-badge`, `#tab-trades-badge`, `player_streams/_update.turbo_stream.erb:8`, `test/jobs/player_stream_job_test.rb` 75-95.
- `script/pixel_art/export.mjs` tab icons ~629-703 and descriptions ~1467; `shell.tabs.*` and `shell.screens.more` in both locales; `shell_helper.rb` SCREEN_LABELS and `shell_top_level_screen?`.
- Tests to fix: `test/integration/shell_test.rb` 90-114, 238, 274, 291-304, 329; `test/integration/error_pages_test.rb:141`; `test/system/shell_test.rb` 81-120, 545.

## Tasks & Acceptance

**Execution:**
- [ ] `script/pixel_art/export.mjs` -- four tab icons, run export
- [ ] routes, controller, policy, views -- Me and Social landings, More redirect
- [ ] `_tab_bar.html.erb`, CSS -- four tabs, badges moved
- [ ] library views -- Sets | All cards switch
- [ ] drill-down views and header -- back to parent, back-only header on phone
- [ ] locales, existing assertions, new tests (tab bar, redirect, reach in two taps, badges)

**Acceptance Criteria:**
- Given a signed-in phone, when the page loads, then four tabs show and the current one is marked.
- Given the old More URL, when requested, then it redirects.
- Given a drill-down on phone, when it loads, then the header shows only a back button.

## Review Triage Log

- medium, patch: a system test still clicked the Collection tab; now the Sets tab.
- medium, patch: a system test still clicked the Trades tab; now Social then the Trades row.
- medium, patch: the Social and Me landings were not top-level and showed no G button; added to the top-level screens.
- low, rejected: stale query comments, no test for the trade board drill-down tab, the two-step visitor redirect.
- unverified: system tests were not run (author asked not to run them: too heavy); the updated query budgets and the new landing tests ran green in the Rails suites.

## Verification

Write the tests but do not run the suites; the orchestrator runs them once in the main tree. Do not commit.

**Commands (run by the orchestrator):**
- `bin/rails test test/integration test/controllers test/helpers test/jobs` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `script/check_file_sizes && script/check_planning_references && node script/pixel_art/export.mjs --check && bundle exec i18n-tasks missing` -- expected: pass
- system tests touching the tab bar -- expected: pass

## Code Review

### 2026-11-04 — 0 decision-needed, 4 patch, 2 defer, 4 rejected

- [x] [Review][Patch] Pin the robots.txt disallow of the new Me and Social screens [test/controllers/search_engines_test.rb]
- [x] [Review][Patch] Pin the Me tab badge update in the reward claim stream [test/controllers/achievement_claims_controller_test.rb]
- [x] [Review][Patch] Pin that a visitor on How it works gets no phone back link [test/controllers/how_it_works_test.rb]
- [x] [Review][Patch] Delete the comments that narrate history or restate names [config/routes.rb], [app/frontend/styles/shell-screens.css], [test/integration/phone_tabs_test.rb]
- [x] [Review][Defer] Tab-current state for the pack and custom-set screens is not pinned by a test — deferred: low, needs fixtures with tokens; add to the phone tabs table on the next touch
- [x] [Review][Defer] Orphan pixel icons tab-hub and tab-collection may remain in the export script — deferred: check usage, then remove through the pixel export

**Rejected**
- Header title hidden too broadly: false, top-level screens keep the title as a visually hidden heading by design.
- Trades without phone_back, other drill-downs without a current tab: low, no such screen found.
- Redirect target hard-coded, two-step redirect for visitors: low, already rejected in the plan.
- Badge collision at 360 px, i18n unused keys, switch focus styling, plan file inconsistencies: low or edits the plan.
