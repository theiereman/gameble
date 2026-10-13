---
title: 'The opened pack page speaks like every other screen'
type: 'feature'
ticket: '49'
created: '2026-10-13'
status: 'built'
baseline_revision: 'd4bb544d9e4230af98367803ead0077e33a5dc53'
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

**Problem:** The opened pack page (`packs.show`) reads « Ton paquet, Confrère », « Ton bonus du jour » and « Les cartes de ton paquet » in French and « Your pack, Brother », « Your daily bonus », « The cards of your pack » in English: the medieval direction's tu, a title for the player, and "paquet"/"pack" where every other screen says booster.

**Approach:** The three strings follow EXPERIENCE.md's voice (vous, never tu, no title for the player) and its word for the thing ("booster" is the player-facing word for the spec's pack; the daily one is "le booster du jour" / "the daily booster", as the daily booster panel and the how-it-works page say): FR « Votre booster », « Votre booster du jour », « Les cartes de votre booster »; EN « Your booster », « Your daily booster », « The cards of your booster ». Verify: the opened pack page's heading, bonus heading and cards line use vous and no Confrère or Brother in French and English, as EXPERIENCE.md's voice says; the controller tests that asserted the old strings assert the new ones; the full suite passes.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/fr.yml` -- `packs.show.heading` "Votre booster", `heading_bonus` "Votre booster du jour", `cards` "Les cartes de votre booster".
- [x] `config/locales/en.yml` -- `packs.show.heading` "Your booster", `heading_bonus` "Your daily booster", `cards` "The cards of your booster".
- [x] `test/controllers/packs_controller_test.rb` -- the English heading assertion expects "Your booster", the French one "Votre booster", the bonus one "Your daily booster"; the form-opened page also asserts the cards list's accessible name.
- [x] `test/controllers/daily_bonuses_controller_test.rb` -- the English bonus heading expects "Your daily booster"; the French one quotes "Votre booster du jour" instead of reading it through `I18n.t`.

**Acceptance Criteria:**
- Given a player whose opened five-card pack page renders in French (English), when the page loads, then its h1 reads "Votre booster" ("Your booster") and its card list is labelled "Les cartes de votre booster" ("The cards of your booster").
- Given an opened daily bonus pack, when its page renders in French (English), then its h1 reads "Votre booster du jour" ("Your daily booster").
- Given the locales, when searched outside the back-office, then no "Confrère", "Brother" or tu form remains on the opened pack page.

## Implementation Notes

Oneshot: six locale values and four test assertions. The view (`app/views/packs/show.html.erb`) already reads the keys and needs no change. The planning docs that quote the old strings (retrospectives, epic closures, pending-approvals) are history and stay.

Leftovers found by searching `config/locales/*.yml`, `app/`, `packs/` and `config/routes.rb` for tu forms, Confrère/Confrérie, Brother/Brotherhood and officier/officer outside the back-office sections (not fixed: none belongs to the opened pack page):
- `feeds.show.nameless` and `friends.show.nameless` -- « Officier sans nom » / « Nameless officer » names a player with no persona name by a title, against "no title for the player".
- `public_profiles.show.visibility.friends_only`, `.private`, `.banned` -- « … les officiers de la Confrérie … » / « … the Brotherhood's officers … »: staff named in the Brotherhood voice on a player screen, while EXPERIENCE.md keeps the Brotherhood to the community goal line.
- `errors.accounts.staff_required` -- « Seuls les officiers de la Confrérie, modérateurs ou administrateurs, peuvent faire cela. » / "Only the Brotherhood's officers …", shown to a non-staff player who reaches a staff action.
- `config/routes.rb` -- public profiles live at `/:locale/brothers/:token` (helpers `brother_path`, `brother_report_path`, `brother_set_path`): "brothers" is visible in every shared profile URL; renaming it would need redirects for links already shared.
- Allowed by EXPERIENCE.md: `pages` community goal line « Toute la Confrérie ouvre … » / "The whole Brotherhood opens …". Third person, not tu: presence lines « Ouvre un booster », « Récupère son booster du jour ».
- Out of scope (back-office officer voice, tu imperatives included): `back_office.*` and the staff error codes under `errors.*` (« Recharge la page », « Lance d'abord un import », …).

Built: the six `packs.show` values read as planned. `packs_controller_test.rb` expects "Your booster", "Votre booster" and "Your daily booster", and now also asserts the card list's accessible name in both languages ("The cards of your booster", "Les cartes de votre booster"); `daily_bonuses_controller_test.rb` expects "Your daily booster" and quotes "Votre booster du jour" instead of reading it back through `I18n.t`, so the test pins the copy. Files: `config/locales/fr.yml`, `config/locales/en.yml`, `test/controllers/packs_controller_test.rb`, `test/controllers/daily_bonuses_controller_test.rb`.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none; the quick lens checked the three keys the view reads, the page's other strings and the shell's, every test and system test for the old copy, the new `aria-label` assertions, the EXPERIENCE.md voice and the existing daily booster wording, and the repo rules. Its two notes on the plan's own text (unticked task boxes, a task line that read backwards) were housekeeping, fixed in the plan.

## Verification

**Commands:**
- `bin/rails test test/controllers/packs_controller_test.rb test/controllers/daily_bonuses_controller_test.rb` -- expected: all pass
- `grep -n "Confrère\|Brother\"\|ton paquet" config/locales/*.yml` -- expected: no match on `packs.show`
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: all pass

## Auto Run Result

- **Summary:** the opened pack page reads « Votre booster », « Votre booster du jour » and « Les cartes de votre booster » in French, "Your booster", "Your daily booster" and "The cards of your booster" in English: vous, no Confrère or Brother, and "booster" as every other screen says.
- **Files changed:**
  - `config/locales/fr.yml` -- `packs.show.heading`, `heading_bonus`, `cards` in vous and booster.
  - `config/locales/en.yml` -- the same three keys, without Brother and with booster.
  - `test/controllers/packs_controller_test.rb` -- the headings expect the new copy; the card list's accessible name is asserted in both languages.
  - `test/controllers/daily_bonuses_controller_test.rb` -- the bonus heading expects "Your daily booster" and quotes "Votre booster du jour".
- **Review:** quick lens, 0 findings; 0 patches, 0 deferred, 0 rejected.
- **Follow-up review recommended:** false (nothing patched).
- **Verification:** `bin/rails test` 2414 runs, 0 failures; `npm run test:js` 273 tests in 28 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 703 files, no offenses; `bundle exec i18n-tasks missing` none missing; no "Confrère", "Brother" or "ton paquet" left in `packs.show`.
- **Residual risk:** the leftovers listed in Implementation Notes (« Officier sans nom », the profile visibility lines naming the Brotherhood's officers, `errors.accounts.staff_required`, the `/brothers/` profile URLs) still speak in the Brotherhood voice on player screens; each needs the author's call.
