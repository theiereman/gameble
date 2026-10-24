---
title: 'The all cards page title names the collection'
type: 'bugfix'
ticket: 13
created: '2026-10-24'
status: 'blocked'
blocked_at: '2026-10-24'
blocked_reason: 'no subagents'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The browser title of the all cards page (`/:locale/library/cards`) reads "Toutes les cartes · Collection · gameble" / "All cards · Collection · gameble", which a visitor without a collection reads as another screen.

**Approach:** Set `library.cards.title` to "Toutes les cartes · gameble" in `config/locales/fr.yml` and "All cards · gameble" in `config/locales/en.yml`, and assert the title in the page's request test in both locales, signed out and signed in. The top bar's "Collection" screen title, the h1 and the set album's title stay as they are.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `config/locales/fr.yml`, `config/locales/en.yml` -- change `library.cards.title` only -- the ticket's two strings.
- [ ] `test/controllers/library_controller_test.rb` -- update the signed-in title assertion; add one test reading the title of `/fr/library/cards` and `/en/library/cards` signed out and signed in -- the ticket's verify, on the outermost surface (the rendered `<title>`).

**Acceptance Criteria:**
- Given a published season, when a visitor or a signed-in player opens `/fr/library/cards`, then the page title is "Toutes les cartes · gameble".
- Given a published season, when a visitor or a signed-in player opens `/en/library/cards`, then the page title is "All cards · gameble".

## Implementation Notes

Oneshot: two locale strings and their request-test assertions, under twenty lines.

- Files: `config/locales/en.yml`, `config/locales/fr.yml` (`library.cards.title` only), `test/controllers/library_controller_test.rb` (the signed-in assertion updated; a new test reads `<title>` in `fr` and `en`, signed out then signed in, the player chip proving which).
- The no-season branch of `library/cards` uses the same key, so it follows. The set album's "%{set} · Collection · gameble" and the top bar's "Collection" are untouched, as EXPERIENCE.md names the album's title that way.
- No system test asserts this title; `test/system/library_test.rb` ran green with a local Chromium.
- Not ours: `bin/ci`'s gem audit fails on crass 1.0.7 (GHSA-pq4g-8rxf-4g29, advisory dated 2026-10-23), and `i18n-tasks check-normalized` reports the locale files unnormalized; neither is in this diff, and CI's i18n step (`missing`) passes.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb` -- expected: all pass.
- `bundle exec i18n-tasks health` (or the repo's i18n-tasks check) -- expected: no missing or unused keys.
- `bin/rails test` (PARALLEL_WORKERS=2), `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green.

## Auto Run Result

Status: blocked
Blocking condition: no subagents. This build session had no tool to launch the Quick review lens's subagent, so the review did not run: no lens was launched and the Review Triage Log is empty.

- Change: `library.cards.title` reads "Toutes les cartes · gameble" (`config/locales/fr.yml`) and "All cards · gameble" (`config/locales/en.yml`). The request test's signed-in assertion follows, and a new test reads the title of `/fr/library/cards` and `/en/library/cards` signed out and signed in (`test/controllers/library_controller_test.rb`).
- Verification, on Postgres 16 and this build's own database: `bin/rails test test/controllers/library_controller_test.rb` 56 runs, 0 failures; `bin/ci` green except the gem audit (crass 1.0.7, GHSA-pq4g-8rxf-4g29, which this change did not introduce), with Rails tests at 3170 runs, 0 failures, and packwerk, rubocop, `i18n-tasks missing`, typecheck and brakeman passing; `npm run test:js` 561 passed; `bin/rails zeitwerk:check` all good; `i18n-tasks unused` clean; `test/system/library_test.rb` 7 runs, 0 failures with a local Chromium.
- To finish: run the Quick review on the diff since the baseline, then mark the plan `built`.
