---
title: 'The all cards page title names the collection'
type: 'bugfix'
ticket: 13
created: '2026-10-24'
status: 'built'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
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

### 2026-10-24 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `patch` The block variable `title` in the new title test shadows the file's `title(card_season_id, locale)` helper — renamed to `page_title` in both loops.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb` -- expected: all pass.
- `bundle exec i18n-tasks health` (or the repo's i18n-tasks check) -- expected: no missing or unused keys.
- `bin/rails test` (PARALLEL_WORKERS=2), `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green.

## Auto Run Result

Status: built

- Summary: `library.cards.title` reads "Toutes les cartes · gameble" / "All cards · gameble"; the set album's title and the top bar's "Collection" are unchanged.
- Files: `config/locales/fr.yml`, `config/locales/en.yml` (the title); `test/controllers/library_controller_test.rb` (the title in both locales, signed out and signed in).
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 1 finding, patched (low); nothing deferred or rejected.
- Follow-up review recommended: false (no high or medium patched).
- Verification: the unattended run's `bin/ci` (3170 runs, 0 failures; gem audit flags crass 1.0.7, pre-existing), `npm run test:js` 561 passed, `zeitwerk:check`, `test/system/library_test.rb` 7 runs green; after the patch, `bin/rails test test/controllers/library_controller_test.rb` 56 runs, 0 failures. Postgres 16, no migration.
- Residual risks: none known.
