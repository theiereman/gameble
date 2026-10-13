---
title: 'Rarity follows popularity, the rating only orders games of equal popularity'
type: 'feature'
ticket: '3'
created: '2026-10-13'
status: 'built'
baseline_revision: '61230dc9be4810be1ea8692c56f220103afffb82'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Dev seeds stamp the current prestige VERSION on scores the formula never computed.
    evidence: |-
      db/seeds.rb writes prestige_score: number.to_f with review_count set apart (250,000 every 12th seed, 500 for hidden gems), so local rarities contradict the stated rule; pre-existing since the seeds were written, made more visible now that the score is the review count.
    location: >-
      db/seeds.rb:31
    severity: low
---

<intent-contract>

## Intent

**Problem:** `Steam::PrestigeScore` (log10(count) + 4 × Wilson lower bound) still lets a well-liked, less-reviewed game outrank a much more reviewed one. The author decided (2026-10-13) that the review count alone ranks the games and the share of positive reviews only breaks ties between equal counts, with no rating floor.

**Approach:** The score becomes the review count plus the positive percent in thousandths: `review_count + percent_positive / 1000` (5,000 reviews at 98 % scores 5000.098). One float orders by count, then by rating, so `Catalog::PublishSeason`, `RarityThresholds` and the preview stay unchanged. `VERSION` goes to 3, so a draft that mixes the two formulas is refused until it is rescored. The spec, the architecture's settled-formula line and the how-it-works rarity copy follow.

## Boundaries & Constraints

**Always:** the score depends only on the percent (Integer 0–100) and the count (Integer ≥ 1), and refuses anything else as it does today. It is strictly increasing in each input. Any count n ranks above n − 1 at any rating: the rating adds at most 0.1. `Steam::RescoreCards` keeps rewriting the draft with the current formula and needs no change. The how-it-works rarity copy reads no constant that no longer exists. Every string goes in both en.yml and fr.yml. Code and tests carry no planning ids.

**Never:** no migration, and no change to a published season, to `Catalog::RarityThresholds`, `PublishSeason` or the tier shares. No rating floor. No rescore or publication run here: staging is the author's.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Popularity wins | 1,500,000 reviews at 40 % against 5,000 at 99 % | the first scores higher and, once published, takes the higher rarity | No error expected |
| Equal counts | 20,000 at 95 % against 20,000 at 60 % | 95 % scores higher | No error expected |
| Adjacent counts | n at 0 % against n − 1 at 100 % | n scores higher | No error expected |
| Bad input | nil, a Float, -1, 101, a count of 0 | ArgumentError, as today | raises |
| Mixed draft | a draft holding version 2 and version 3 scores | publication refused with `mixed_score_versions` until rescored | existing guard |

</intent-contract>

## Code Map

- `packs/steam/app/models/steam/prestige_score.rb` -- the formula. `VERSION = 2`, `Z`, `SHARE_WEIGHT`, `wilson_lower_bound`. Rewrite: `VERSION = 3`, one scale constant (the rating's thousandths), and drop Z, SHARE_WEIGHT and Wilson. Its header comment cites planning ids; rewrite it without them, short.
- `packs/steam/app/models/steam/card_mapping.rb:52-53` -- calls `PrestigeScore.call` and stamps `PrestigeScore::VERSION`. Leave it unchanged.
- `packs/steam/app/operations/steam/rescore_cards.rb` -- re-runs the cards step from the stored apps. Leave it unchanged; its tests swap `PrestigeScore.call` through `with_formula`.
- `packs/catalog/app/models/catalog/rarity_thresholds.rb`, `packs/catalog/app/operations/catalog/publish_season.rb` -- cut the tiers by score descending; equal scores share a tier. Read-only.
- `app/views/pages/_rarity_rule.html.erb:6` -- passes `weight: Steam::PrestigeScore::SHARE_WEIGHT` into `pages.how_it_works.rarity.score`. That constant goes away.
- `config/locales/en.yml:231-238`, `config/locales/fr.yml:238-247` -- the `pages.how_it_works.rarity.{rule,score,cut,ties}` copy. The French `cut` has a `zero` form; keep it.
- `test/controllers/how_it_works_test.rb` -- checks the headings, the shares and the numbers, but not the rarity wording.
- `test/packs/steam/cards_test.rb:62-96` -- the PrestigeScore unit tests, whose Wilson values must be replaced. `ready(run, *appids, **overrides)` and `cards_page(run)` write a draft. Lines 238 and 278 compare against `PrestigeScore.call` and still hold.
- `test/jobs/steam_import_step_job_test.rb:308-345` -- `with_share_weight(1)` swaps `SHARE_WEIGHT` so the second import scores with another formula. Replace it with a `with_formula` swap of `PrestigeScore.call`, the way `test/packs/steam/rescore_cards_test.rb:43-49` does.
- `_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md:36-39` -- the Rarity section's Formula and Player-facing rule.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md:499` -- the settled-formula line.

## Tasks & Acceptance

**Execution:**
- [x] `packs/steam/app/models/steam/prestige_score.rb` -- score = `review_count + percent_positive.fdiv(<scale 1_000>)`, keeping the ArgumentError checks. `VERSION = 3`. Remove Wilson, Z and SHARE_WEIGHT. -- one float orders by count, then by rating.
- [x] `test/packs/steam/cards_test.rb` -- replace the value and ordering test with the new values (score(98, 5_000) == 5000.098; much-reviewed and badly rated > less-reviewed and well liked; equal counts ordered by rating; n at 0 % > n − 1 at 100 %). Keep the monotonic grid and domain tests. Add one end-to-end test: a cards page over fixed apps, then `Catalog::PublishSeason`, asserting the published rarities (layout in Design Notes). -- proves the rule at the outermost surface, the published tier.
- [x] `test/jobs/steam_import_step_job_test.rb` -- replace `with_share_weight` with a `with_formula` swap of `Steam::PrestigeScore.call`. -- SHARE_WEIGHT no longer exists.
- [x] `app/views/pages/_rarity_rule.html.erb` + `config/locales/en.yml` + `config/locales/fr.yml` -- drop the `weight` interpolation. Rewrite `rule`, `score`, `cut` and `ties` for the new rule: the more reviews, the rarer; the positive share only orders games with exactly the same number of reviews; ties need the same count and the same share. -- the screen states the rule the game applies.
- [x] `test/controllers/how_it_works_test.rb` -- in both locales, assert that the rarity section shows the `rule` and `score` copy. -- guards the copy against the rule.
- [x] `_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md`, `architecture-gameble.md:499`, `spec-gameble/.memlog.md` -- the new formula and the player-facing sentence, "The more reviews a game has on Steam, the rarer its card." -- the spec follows the decision.
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- one open entry with the staging steps (Design Notes). -- running anything on staging is the author's.

**Acceptance Criteria:**
- Given a draft of fixed games scored by the new formula, when it is published, then a game with far more reviews and a poor rating takes a higher rarity than a less-reviewed, well-liked game, and of two games with the same review count on either side of a tier cut, the better rated one takes the higher tier.
- Given the how-it-works screen in French or English, when it is read, then its rarity section says that the review count decides and the positive share only orders games with equal counts, and it names no weight.
- Given a draft holding version-2 scores, when the latest import is rescored, then every card-season carries version 3 and publication succeeds (the existing rescore test, unchanged).

## Implementation Notes

- `Steam::PrestigeScore`: `review_count + percent_positive.fdiv(PERCENT_SCALE)` with `PERCENT_SCALE = 1_000`, `VERSION = 3`; Wilson, `Z` and `SHARE_WEIGHT` removed, the header rewritten without planning ids. `CardMapping`, `RescoreCards`, `RarityThresholds` and `PublishSeason` untouched.
- `test/packs/steam/cards_test.rb`: the value test now checks 5000.098, 1,500,000 at 40 % above 5,000 at 99 %, equal counts ordered by rating, and n + 1 at 0 % above n at 100 % for several n; the grid and domain tests are unchanged and pass. New end-to-end test over 21 ready apps (1.5M at 40 %, 1M, 500k, the 30,000 pair at 95 % and 60 %, fillers 24,000 down to 10,000, 5,000 at 99 %) → cards page → `Catalog::PublishSeason`, asserting legendary, epic, rare, rare, uncommon (the 60 % twin), uncommon × 4, common × 12.
- `test/jobs/steam_import_step_job_test.rb`: `with_share_weight(1)` replaced by a `with_formula` swap (count / 1,000,000), as in the rescore test.
- How-it-works: the `weight` interpolation is gone; `rule` is now the spec sentence ("The more reviews a game has on Steam, the rarer its card." / "Plus un jeu a d'évaluations sur Steam, plus sa carte est rare."), `score` says the count alone ranks and the share only orders exactly equal counts, `cut` ranks "this way, from the most reviewed game to the least" (French `zero` kept), `ties` needs the same count and the same share. `how_it_works_test` asserts `rule` and `score` in the rarity section in both locales.
- Docs: `catalog-and-rarity.md` Formula and Player-facing rule, `architecture-gameble.md` settled-formula line, a new memlog decision, and one open pending-approvals entry with the staging rescore steps. Outside the code map: `README.md`'s calibration step still named `SHARE_WEIGHT`; its line now describes the new formula.
- Review round (patches): VERSION pinned beside the value, the publication assertion shows its failure, brief line 12, the spec's Formula line (evidence, whole-number percent), the pending-approvals entry (expected thresholds, hall of fame check) and the preview's thousands delimiter.
- Verified: `bin/rails test` 2413 runs green (no system tests), `npm run test:js` 255 passed, `zeitwerk:check`, `packwerk check`, `rubocop`, `i18n-tasks missing` and `unused` all clean.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 18 findings — high 0, medium 1, low 14, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) Nothing pinned the VERSION bump: every test compared against the constant, so VERSION 2 with the new formula passed. Fixed: the value test asserts `[ 3, 5_000.098 ]` against `[ VERSION, score(98, 5_000).round(3) ]`.
  - `[false]` `[reject]` (intent-alignment) A banded reading of "same popularity" is not implemented. The author's 2026-10-13 decision note says "breaks ties between equal counts; no rating floor", which settles the strict reading.
  - `[false]` `[reject]` (intent-alignment) The staging-preview Verify is not exercised by the diff. The ticket's constraints make staging the author's; the steps are in pending-approvals, and the same rule is proven at the published tier on fixed games.
  - `[low]` `[reject]` (intent-alignment) The how-it-works test checks the copy's wiring, not its wording. Asserting the wording would duplicate the yml; the copy is reviewed in the diff.
  - `[low]` `[patch]` (blind) The brief still stated "better known and better liked". Fixed: brief line 12 now has the new player-facing rule.
  - `[low]` `[reject]` (blind) The epic note and tickets.toml say "almost alone". The ticket file's own notes carry the settled decision, and this workflow never writes ticket files.
  - `[low]` `[defer]` (blind) Dev seeds stamp VERSION on `number.to_f` scores unrelated to their review counts. Pre-existing: the seeds never computed the formula.
  - `[low]` `[patch]` (blind) The impact on sets (Les Phénomènes almost all Légendaire, Les Pépites all Commune) was not flagged to the author. Fixed: the pending-approvals entry asks for a look at the hall of fame sets' rarity mix.
  - `[low]` `[reject]` (blind) The publication test hard-codes the tier shares. A recalibration of SHARES breaking this test announces the change; deriving cuts adds test logic for an uncommon edit.
  - `[low]` `[patch]` (blind) `assert ...success?` hid the failure code. Fixed: `assert result.success?, result.inspect`.
  - `[low]` `[reject]` (blind) `with_formula` is duplicated in two test files. Extracting a shared support helper is more than a direct correction, for a four-line helper.
  - `[low]` `[reject]` (blind) The how-it-works test does not guard the wording. Same as the intent-alignment row above.
  - `[false]` `[reject]` (blind) The plan has no review record. The triage log is written at this step; the README edit is recorded in Implementation Notes.
  - `[low]` `[patch]` (blind) "the ticket's Verify" in pending-approvals points nowhere. Fixed: the entry inlines the expected thresholds and the games entering and leaving Légendaire.
  - `[low]` `[patch]` (blind) The spec dropped the evidence for the decision. Fixed: the Formula line cites the staging season 4 simulation (174k, 36k, 9.5k, about 24 % change tier).
  - `[low]` `[patch]` (blind) The tie-break uses Steam's whole-number percent while the spec said "share". Fixed: the spec says the percent as Steam gives it, a whole number.
  - `[low]` `[reject]` (blind) The Design Notes say "exact" where "ordering-safe" is meant. Its fix edits this build's plan.
  - `[low]` `[patch]` (blind) The back-office preview printed millions with no thousands separator. Fixed: the five `number_with_precision` calls pass the locale's `number.format.delimiter`.

## Design Notes

**Why one float, not a two-key sort in PublishSeason:** `RarityThresholds`, `DraftPreview`, `ScorePanel` and `ScoreVersions` all read one scalar `prestige_score`. Changing the scalar touches one file. A sort on count then rating would rewrite all of them and make Catalog read the review count for rarity. The percent is an Integer, so thousandths keep it exact and readable in the preview: 174000.098 is 174,000 reviews at 98 %. The rating adds at most 0.1, so count n + 1 always outranks count n. A double stays exact well past 10⁸ reviews.

**End-to-end fixture (21 cards: rank 1 Légendaire, 2 Épique, 3–4 Rare, 5–9 Peu commune, 10–21 Commune):** a 1,500,000-review game at 40 % (rank 1, Légendaire); a pair at 30,000 reviews, 95 % and 60 % (ranks 4 and 5, so Rare and Peu commune); a 5,000-review game at 99 % (Commune); fillers with distinct counts placing them. Assert the exact rarities. `ready(run, appid, review_count:, review_percent_positive:)` per group.

**Staging steps, after the deploy that carries VERSION 3:** in the back-office, open the latest completed import run and press "Rescore the cards". When its pass completes, the season preview shows the new tiers and no mixed-version verdict. Check the Légendaires and Épiques against the ticket's Verify, then publish when satisfied. If the rescore is refused because the run's season is already published, the next import scores with version 3 by itself. A published season is never rescored.

## Verification

**Commands:**
- `bin/rails test` -- expected: green (no system tests)
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: all clean

## Auto Run Result

- **Summary:** `Steam::PrestigeScore` is now `review_count + percent_positive / 1000` (VERSION 3): the review count alone ranks the games and the positive percent only orders equal counts. PublishSeason, RarityThresholds and the preview read the one float unchanged, and RescoreCards rewrites a draft with it. The spec, brief, architecture, memlog, README and how-it-works rarity copy (en, fr) state the new rule.
- **Files:** `packs/steam/app/models/steam/prestige_score.rb` (formula, VERSION 3); `app/views/pages/_rarity_rule.html.erb` and `config/locales/{en,fr}.yml` (rarity copy, no weight); `app/views/back_office/seasons/_preview.html.erb` (thousands delimiter); `test/packs/steam/cards_test.rb` (values, version pin, end-to-end published tiers); `test/jobs/steam_import_step_job_test.rb` (formula swap); `test/controllers/how_it_works_test.rb` (rule and score shown); `README.md`; `spec-gameble/catalog-and-rarity.md`, `spec-gameble/.memlog.md`, `brief-gameble/brief-gameble.md`, `architecture-gameble/architecture-gameble.md`, `pending-approvals.md` (staging rescore entry).
- **Review:** 18 findings. 9 patched (1 medium, 8 low), 1 deferred (dev seeds), 8 rejected with reasons in the triage log (3 false, 5 low).
- **Follow-up review recommended:** false. One medium and no high were patched; the medium was a test pin, now verified.
- **Verification:** `bin/rails test` 2413 runs, 0 failures; `npm run test:js` 255 passed; `zeitwerk:check`, `packwerk check`, `rubocop` and `i18n-tasks missing` clean. No system tests.
- **Residual risks:** staging's draft holds version-2 scores and is refused publication until the author rescores it (pending-approvals). About 24 % of cards change tier, and hall of fame sets shift rarity mix (Les Phénomènes nearly all Légendaire); this is the author's to judge on the preview.
