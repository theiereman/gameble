---
title: 'Popularity-led prestige score'
type: 'feature'
ticket: '12'
created: '2026-10-06'
status: 'built'
baseline_revision: '28aee29275da3c7342adc46b6863d03686c66562'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** `Steam::PrestigeScore` (Wilson lower bound + 0.01 × log10(count)) lets acclaim dominate, so season 1's Légendaires are small acclaimed games; the author wants the best-known games to lead ("c'est quand même généralement les gros jeux qu'on considère légendaire"), chosen on 2026-10-06 after a simulation on the 12,326 games of the staging import.

**Approach:** prestige = log10(review_count) + 4 × WilsonLowerBound(percent_positive / 100, review_count), z = 1.96; still a pure function of review score and count only (CAP-3, AD-4), strictly increasing in each input, same argument validation; `COUNT_WEIGHT` gives way to `SHARE_WEIGHT = 4` with a header comment on the choice. Tests follow (a 1.5M-review 87 % game ranks above a 5k-review 98 % game; a 10k-review 95 % game ranks below a 200k-review 92 % game), as do the spec's Rarity section (player-facing rule "the better known and the better liked a game is, the rarer its card"), a memlog decision line and an epic Note. No season data is touched: the formula applies from the next publication or rescore.

</intent-contract>

## Implementation Notes

Oneshot: one formula, its tests and the docs, well under 100 lines.

- `packs/steam/app/models/steam/prestige_score.rb` — new formula and constant `SHARE_WEIGHT`.
- `test/packs/steam/cards_test.rb` — the "acclaim dominates" test becomes "popularity leads, acclaim separates", with the two ordering cases from the author and pinned values; grid and domain tests unchanged.
- `test/jobs/steam_import_step_job_test.rb` — `with_count_weight` (stubbed `COUNT_WEIGHT`) becomes `with_share_weight`.
- Draft preview, rescore, publish season, set builder and the game benchmark feed explicit scores or stub `call`, so they do not depend on the formula; the import controller test (600 vs 90,000 reviews at 90 %) still holds.
- `README.md` — the calibration steps name `SHARE_WEIGHT` instead of `COUNT_WEIGHT`.
- Review patches: the open prestige-formula question is marked resolved in the epic, the initiative and the architecture; the brief's one-line rule follows the spec.
- Docs: `catalog-and-rarity.md` (Formula, Player-facing rule), `spec-gameble.md` (the Prestige formula open question is resolved), `.memlog.md` decision line, epic Note.

## Verification

**Commands:**
- `bin/rubocop`, `bundle exec packwerk validate && bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js`, `bin/rails db:test:prepare test`, `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- expected: all pass.

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 4, false 0, maybe-false 0 (1 rejected as a plan edit)
- findings:
  - `[low]` `[patch]` The last ordering assertion in `test/packs/steam/cards_test.rb` carried the "never rare for being little known" message, which the grid test checks, not that line — message now says a perfect score does not lift a little-known game above a well-known, well-liked one.
  - `[low]` `[patch]` The epic's new Decision note sat after a blank line, splitting the Notes list — blank line removed.
  - `[low]` `[patch]` The prestige-formula open question stayed open in the epic Notes, `initiative-gameble.md` and `architecture-gameble.md` while the spec dropped it — each now records it resolved (tier shares kept at calibration, formula by story 2.12).
  - `[low]` `[patch]` `brief-gameble.md` line 12 still stated "the more acclaimed, the rarer", superseded by the memlog decision — replaced with the new rule.
  - `[low]` `[reject]` The plan's `context: []` lists none of the docs it changes — the fix edits this build's plan; every doc is named in the Implementation Notes.

## Auto Run Result

- **Summary:** `Steam::PrestigeScore` now computes `log10(review_count) + 4 × Wilson lower bound` (z = 1.96), `SHARE_WEIGHT = 4` replacing `COUNT_WEIGHT`, still a pure function of score and count with the same validation; no season data is touched.
- **Files:** `packs/steam/app/models/steam/prestige_score.rb` (formula and header); `test/packs/steam/cards_test.rb` (new ordering and pinned values); `test/jobs/steam_import_step_job_test.rb` (`with_share_weight`); `README.md` (calibration steps name `SHARE_WEIGHT`); `spec-gameble/catalog-and-rarity.md` (Formula, Player-facing rule); `spec-gameble/spec-gameble.md` (open question removed); `spec-gameble/.memlog.md` (decision); `epic-steam-catalog.md` (Decision note, open question resolved); `initiative-gameble.md`, `architecture-gameble.md`, `brief-gameble.md` (question resolved, rule follows).
- **Review:** quick lens; 4 low patches applied, 0 deferred, 1 rejected (plan edit).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 4).
- **Verification:** `bin/rubocop` no offenses; packwerk validate and check clean; i18n-tasks missing none; `npm run typecheck` ok; `npm run test:js` 166 passed; `bin/rails db:test:prepare test` 1218 runs, 0 failures; `bin/rails test:system` 100 runs, 0 failures.
- **Residual risks:** season 1 on staging keeps the old scores until the next publication; a rescore of the draft now gives scores from about 2.7 to 10 instead of 0 to 1.06, which the preview and the tier cut only order.
