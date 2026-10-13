---
title: 'Reward packs get their own odds'
type: 'feature'
ticket: '16'
created: '2026-10-13'
status: done
baseline_revision: '42d2480d5c839476627a830077b3a7cc5254dde2'
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

**Problem:** `Game::DrawOdds::REWARD` is the daily bonus table (legendary 1 % per card) and `Game::RewardDraw` then forces a card from `EPIC_OR_BETTER` (legendary 1 in 6) when none of the five is an Épique or better, so about one reward pack in 6 holds a Légendaire. The author decided (2026-10-08) one Légendaire in 50 reward packs.

**Approach:** Give `REWARD` its own table and retune `EPIC_OR_BETTER`, keeping `RewardDraw` as it is (five cards at REWARD odds, one replaced from EPIC_OR_BETTER when none is tier 4 or 5): REWARD = `{ 2 => 7_000, 3 => 2_400, 4 => 588, 5 => 12 }` (the bonus table with its Épique-or-better share of 6 % kept, the Légendaire part cut to 0.12 %), EPIC_OR_BETTER = `{ 4 => 9_809, 5 => 191 }`. A pack holds a Légendaire with probability 1 − 0.9988⁵ + 0.94⁵ × 0.0191 ≈ 2.000 %, one in 50. `BONUS` (daily bonus) and `REGULAR` stay as they are; whether the daily bonus comes down too is the author's open question in pending-approvals and stays out of scope.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/models/game/draw_odds.rb` -- REWARD its own table, EPIC_OR_BETTER retuned, the comments say the one-in-50 target without planning ids.
- [x] `packs/game/app/models/game/reward_draw.rb` -- comment only if it still names the bonus odds; no logic change.
- [x] `test/packs/game/goal_reward_test.rb` (or `draw_test.rb`) -- pin the REWARD and EPIC_OR_BETTER tables; a seeded draw of 50,000 reward packs (`Random.new(<fixed seed>)`, a pool built in memory with `Game::DrawPool::Snapshot`) holds a Légendaire in 1/50 of them within 4 sigma and every pack holds tier 4 or 5. `draw_test.rb` keeps pinning BONUS and REGULAR unchanged.

**Acceptance Criteria:**
- Given 50,000 reward packs drawn with a fixed seed, when their tiers are counted, then the packs holding a Légendaire are 1,000 ± 4σ (about one in 50) and every pack holds an Épique or better.
- Given the daily bonus and regular odds, then they equal their tables before this change (`BONUS` `{ 2 => 7_000, 3 => 2_400, 4 => 500, 5 => 100 }`, `REGULAR` unchanged).

## Implementation Notes

Oneshot: two constants and one test, well under 100 lines.
- `packs/game/app/models/game/draw_odds.rb`: REWARD and EPIC_OR_BETTER as in the Approach; the REWARD comment loses its planning id. `reward_draw.rb` unchanged (its comment already names REWARD, not the bonus odds).
- `test/packs/game/draw_test.rb`: the two tables pinned; 50,000 reward packs drawn with `Random.new(20_261_013)` from a pool built in memory (`Game::DrawPool::Snapshot`, 20 cards per tier), no database; the seed gives 969 packs with a Légendaire (expected 1,000, 4σ ≈ 125); the old tables give about 17.8 % per pack, so the test fails on them. The existing BONUS and REGULAR pins stay as they were.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none (the quick lens re-derived the 2.0 % per pack and re-ran the seeded draw; its notes on a public test helper and a duplicated sum check were not defects)

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: clean

## Auto Run Result

- Summary: reward packs get their own odds in `Game::DrawOdds`: REWARD `{ 2 => 7_000, 3 => 2_400, 4 => 588, 5 => 12 }` per card, and EPIC_OR_BETTER `{ 4 => 9_809, 5 => 191 }` for the card forced when none of the five is an Épique or better, so a reward pack holds a Légendaire with probability ≈ 2.000 % (one in 50, down from about one in 6). Daily bonus (`BONUS`) and regular odds are unchanged.
- Files changed: `packs/game/app/models/game/draw_odds.rb` (the two tables); `test/packs/game/draw_test.rb` (tables pinned, seeded 50,000-pack draw).
- Review findings: 0 patches, 0 deferred, 0 rejected.
- Follow-up review recommended: false (nothing patched).
- Verification: `bin/rails test`: 2365 runs, 0 failures; `npm run test:js`: 225 passed (24 files); `bin/rails zeitwerk:check`: all good; `bundle exec packwerk check`: no offenses; `bin/rubocop`: 695 files, no offenses.
- Residual risks: none in code. Reward packs already granted keep the cards drawn at the old odds. Whether the daily bonus (one Légendaire in about 34 packs) comes down too is still the author's open question in pending-approvals.md, untouched here.
