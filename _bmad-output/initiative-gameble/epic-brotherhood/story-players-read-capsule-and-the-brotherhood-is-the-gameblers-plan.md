---
title: 'Players read capsule, and the Brotherhood is the Gameblers'
type: 'chore'
ticket: '18'
created: '2026-10-15'
status: 'built'
baseline_revision: '271fd0c56ef20b82730ea32df0b4bfeea4ea71e3'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The interface says booster (« booster », "booster") where the spec's player-facing words now say capsule, and contributor docs name the Brotherhood "Gamblers". The weekly goal panel still carries the old line, and the reward notice does not carry the Management thank-you the Copy deck now gives it (EXPERIENCE.md, Voice and Tone, Copy deck rows "Community goal" and "Goal reward notice").

**Approach:** Change values, never keys: every French and English locale string that says booster or pack says capsule, with French feminine agreements around it (articles, adjectives, participles, pronouns, « celle », « elle », « prochaine », « suivante », « Scellée », « Prête », « Récupérée »), across zero/one/other forms. The goal line becomes the Copy deck's invitation with the week's target. The goal reward claim's success toast becomes the reward notice: title « Objectif atteint » / "Goal reached" and the Management thank-you. CONTRIBUTING.md and the issue templates say Gameblers and capsule. Tests asserting the old copy follow.

**Assumptions (author unavailable, conservative choice):**
- Entry 17 shipped first (its plan is `built`): the reward waits for the claim button, so the notice is the claim's success toast (Turbo Stream toast and the no-JavaScript flash), not a toast on the hub render; its text "a rejoint votre réserve" is true at that moment.
- The back office's specimen label and intro also say capsule (an interface string, read by the author only).
- Issue template and CONTRIBUTING wording that describes the game (bug-report example, feature-idea area "Packs and reveal", lore examples) says capsule, so reporters use the words they read on screen.
- Plural keys keep their present forms; only their values change.

## Boundaries & Constraints

**Always:** Keys, Ruby/TS identifiers, CSS classes, routes, URLs, DB, events, pixel icon names and the `pack`/`booster` internal vocabulary stay. "carte" / "card" stays. French uses « vous » and U+202F before « : ; ? ! ». Every changed key changes in both `fr.yml` and `en.yml`.

**Never:** No change to the goal's mechanics, odds, reserve or claim operation, nor to their tests beyond copy assertions. No `_bmad-output/` edits other than this plan. No planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Goal panel | hub, target 1 200 | « La Confrérie invite ses membres à unir leurs efforts pour ouvrir 1 200 capsules cette semaine. » | none |
| Claim succeeds | POST goal reward, Turbo Stream or HTML | toast titled « Objectif atteint » with « La Direction vous remercie pour votre participation. Une capsule rare a rejoint votre réserve. » | none |
| Claim refused | reserve full | alert toast « … ouvrez une capsule pour récupérer votre capsule rare. », no title | unchanged codes |

</frozen-after-approval>

## Code Map

- `config/locales/fr.yml`, `config/locales/en.yml` -- every booster/pack value: `shell.screens/tabs/packs`, `pages.home.menu/showcase/invitation/daily/goal`, `pages.legal`, `pages.how_it_works.packs/timing/daily/goal` (the « Il » pronouns and « S'il ne contient » refer to the capsule), back office `cards` specimen, `packs.show`, `boosters.show/island` (`states.sealed`, `open_next`), `friends…activities`, `achievements.names/conditions`, `accounts.dialog.note`, `daily_bonuses`, `goal_rewards`, `card_details.preview`, `cards.show`, `sessions.create.welcome`, `errors.game.*`.
- `app/controllers/goal_rewards_controller.rb` -- success sets the toast title (`flash[:toast_title]` in HTML, `@title` for the stream), like `trades_controller.rb#toast`.
- `app/views/goal_rewards/create.turbo_stream.erb` -- passes `title: @title` to `ToastComponent`.
- `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/lore-idea.yml`, `bug-report.yml`, `feature-idea.yml` -- Gameblers and capsule.
- Tests asserting copy: `test/controllers/*` (daily_bonuses, goal_rewards, achievements, accounts, card_preview_tags, cards, friends, pages…), `test/components/*`, `test/system/*` (kept in step though not run), `app/frontend/lib/*.test.ts` sample strings.

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- rewrite the values above; add `goal_rewards.create.title` -- the copy change.
- [x] `app/controllers/goal_rewards_controller.rb`, `app/views/goal_rewards/create.turbo_stream.erb` -- title the success toast -- the reward notice.
- [x] `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/*.yml` -- Gameblers, capsule -- contributor docs.
- [x] tests -- follow the new copy; assert the notice's title in `test/controllers/goal_rewards_controller_test.rb`.

**Acceptance Criteria:**
- Given the locale files, when grepping values for booster/pack/Gambler, then no player-facing match remains.
- Given i18n-tasks, when running missing and unused, then both report nothing.
- Given the goal's mechanics tests, when the suite runs, then they pass with only copy assertions changed.

## Implementation Notes

- Implemented in-session: this run had no subagent tool, so the implementation and the Quick review lens ran in the building session itself instead of in fresh subagents (author unavailable; recorded rather than halting).
- Locale values rewritten with exact old/new pairs (each asserted to occur the expected number of times); English by a word-bounded booster→capsule pass over values only, keys untouched. Feminine agreements done by hand: « Prête », « Récupérée », « Prochaine dans », « Scellée », « Ouvrir la suivante », « celle du jour », « Elle contient / s'ajoute / est refusée », « ouvrez-en une », « vous la récupérez », « Si elle ne contient », « Chaque capsule ouverte est remplacée … après la dernière capsule en attente … si toutes étaient prêtes », « ouvertes ou non », « Récupère sa capsule du jour », « Première capsule », « premières capsules ».
- `goal_rewards.create.title` added in both locales; the claim's success sets it as the toast title (stream: `@title`; HTML: `flash[:toast_title]`), refusals stay untitled.
- Tests: copy assertions updated from the old/new value pairs (system tests too, though not run); new assertions for the toast title on both answers and its absence on refusals. Pre-existing comments that name planning documents were left as they were.
- Left saying booster/pack on purpose: i18n keys, identifiers, CSS classes, routes (`/booster`, `/packs`), comments, the pixel icon name `pack`, test names and descriptions of internal behaviour, and the disabled PWA manifest (no booster in it).

## Plan Change Log

## Review Triage Log

Pass 1 (Quick lens, in-session): high 0, medium 0, low 1, false 0, maybe-false 0.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| The automated test-copy pass also rewrote three test comments, two of which name planning documents | low | patch | Reverted the three comment lines to their original text so the diff touches only assertions; no planning id is written by this change. |

## Verification

**Results (2026-10-15, Postgres 16 in the container):**
- `bin/rails test` -- 2547 runs, 0 failures, 0 errors, 0 skips (system tests skipped by design).
- `npm run test:js` -- 32 files, 325 tests passed. `npm run typecheck` -- clean.
- `bin/rails zeitwerk:check` -- All is good. `bundle exec packwerk check` -- no offenses. `bin/rubocop` -- 742 files, no offenses.
- `bundle exec i18n-tasks missing` -- none. `bundle exec i18n-tasks unused` -- 4 pre-existing keys (`rate_limit.reading_throttled`, `rate_limit.throttled`, en and fr), untouched by this change; nothing new.

**Commands:**
- `bin/rails test` -- expected: no failures
- `npm run test:js`, `npm run typecheck` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: clean
- `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: nothing
