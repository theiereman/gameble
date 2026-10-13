---
title: 'The donation links read SOUTENIR, not Offrir un café'
type: 'feature'
ticket: '46'
created: '2026-10-13'
status: 'built'
baseline_revision: '8da410f4e605291643985cbafa846a24cc109e64'
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

**Problem:** The donation buttons of the legal page (section "Soutenir gameble") and of the settings' SOUTENIR row read « Offrir un café » / « Buy me a coffee », naming the provider's product rather than what the player does.

**Approach:** The two donation button labels read « Soutenir » in French and « Support » in English; the legal text that names Buy Me a Coffee as the payment provider stays, since it states where donations go. Verify: the legal page's and the settings' donation buttons read Soutenir in French and Support in English; no "Offrir un café" or "Buy me a coffee" label remains in the locales; the legal text still names Buy Me a Coffee as the provider; the full suite passes.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/fr.yml` -- `pages.legal.support.link` and `settings.show.support.link` read "Soutenir"; `pages.legal.support.text` keeps "Buy Me a Coffee".
- [x] `config/locales/en.yml` -- the same two keys read "Support"; `pages.legal.support.text` keeps "Buy Me a Coffee".
- [x] `test/controllers/pages_controller_test.rb` -- the French legal page's donation link reads "Soutenir (nouvel onglet)" and the section text still names Buy Me a Coffee; the English legal page's donation link reads "Support (new tab)".
- [x] `test/controllers/settings_controller_test.rb` -- the French settings' support link reads "Soutenir (nouvel onglet)"; an English settings page's support link reads "Support (new tab)".

**Acceptance Criteria:**
- Given a visitor on the legal page in French (English), when the "Soutenir gameble" ("Support gameble") section renders, then its donation button reads "Soutenir" ("Support"), opens the donation page in a new tab, and the section text still says donations go through Buy Me a Coffee.
- Given a signed-in player on the settings screen in French (English), when the SOUTENIR (SUPPORT) row renders, then its button reads "Soutenir" ("Support").

## Implementation Notes

Oneshot: two locale values per language plus the request tests that quote them. The UX documents (EXPERIENCE.md, DESIGN.md) do not quote the old label; the system test finds the settings row by its SOUTENIR label, which is unchanged.

Built: the four `link` values read "Soutenir" / "Support"; both `text` values still name Buy Me a Coffee. The French legal and settings tests now expect "Soutenir (nouvel onglet)" and the legal section text naming Buy Me a Coffee; the English legal and settings tests gained the "Support (new tab)" label and, on the legal page, the provider sentence. The settings view comment ("SOUTENIR opens the donation page") names the row and stays true. Files: `config/locales/fr.yml`, `config/locales/en.yml`, `test/controllers/pages_controller_test.rb`, `test/controllers/settings_controller_test.rb`.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none; the quick lens checked the locale values, the absence of the old labels, the rendered "(nouvel onglet)" / "(new tab)" suffix, the new assertions' placement and selectors, the settings system test's row lookup, and the repo rules.

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb test/controllers/settings_controller_test.rb` -- expected: all pass
- `grep -n "Offrir un café\|Buy me a coffee" config/locales/*.yml` -- expected: no match
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: all pass

## Auto Run Result

- **Summary:** the donation buttons of the legal page and of the settings' support row read « Soutenir » in French and « Support » in English; the legal text still says donations go through Buy Me a Coffee.
- **Files changed:**
  - `config/locales/fr.yml` -- `pages.legal.support.link` and `settings.show.support.link` read "Soutenir".
  - `config/locales/en.yml` -- the same two keys read "Support".
  - `test/controllers/pages_controller_test.rb` -- the French legal page expects "Soutenir (nouvel onglet)" and the provider sentence; the English one expects "Support (new tab)" and the provider sentence.
  - `test/controllers/settings_controller_test.rb` -- the French settings expect "Soutenir (nouvel onglet)"; the English settings expect "Support (new tab)".
- **Review:** quick lens, 0 findings; 0 patches, 0 deferred, 0 rejected.
- **Follow-up review recommended:** false (nothing patched).
- **Verification:** `bin/rails test` 2408 runs, 0 failures; `npm run test:js` 243 tests in 26 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 701 files, no offenses; `bundle exec i18n-tasks missing` none missing; no "Offrir un café" or "Buy me a coffee" left in the locales.
- **Residual risk:** on the settings screen the row label SOUTENIR now sits beside a button also reading Soutenir, as the ticket asks; the disabled system test still finds that row by its label.
