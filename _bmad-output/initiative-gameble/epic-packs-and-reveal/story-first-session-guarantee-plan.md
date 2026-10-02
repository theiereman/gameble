---
title: 'First-session guarantee'
type: 'feature'
ticket: '3'
created: '2026-10-02'
status: 'built'
baseline_revision: '3577e96d9e1792047be46235aaa7b8a59c5cb65a'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A new player's first ten packs are drawn with the regular odds, so some players open ten packs without a sapphire or better, against the spec's first-session guarantee (CAP-4; `catalog-and-rarity.md`, Draw; epic 3, R3).

**Approach:** When `Game::FillBank` draws a bank, it checks the first nine packs in opening order; if none holds a card of tier 3 or above, it replaces one card of the tenth pack, at a random position, with a card drawn from tiers 3–5 in the regular odds' proportions. Nothing marks the guarantee.

## Boundaries & Constraints

**Always:**
- Opening order is insertion order (the bank's packs share `available_at`; `OpenPack` orders by `available_at, id`, and `insert_all!` assigns ids in row order) — the check uses the drawn array in that order.
- The forced card's tier comes from `Game::DrawOdds::GUARANTEE = { 3 => 8_600, 4 => 1_300, 5 => 100 }` (430 : 65 : 5 scaled to 10,000, sum tested); its position from `random.random_number(Pack::SIZE)`; its card from `Draw.card(tier:, pool:)`. The tenth pack is left alone when it already holds a tier ≥ 3 card.
- `Game::DrawPool` exposes `tier_of(card_season_id)` from the snapshot, built once with the snapshot.
- `FillBank` takes an injectable `random:` (default `SecureRandom`) so tests can seed it. The regular draw is unchanged for every other pack and for every later pack (replacements, bonuses).
- Applies wherever `FillBank` runs (sign-up and `FillEmptyBanksJob`).

**Never:** no visible sign, flag, event or column for the guarantee; no change to the regular odds or to packs beyond the first fill.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Guarantee | 2,000 fills with seeded randomness | every bank's first ten packs hold a card of tier ≥ 3 | — |
| Forced only when needed | a fill whose first nine packs hold a sapphire | the tenth pack exactly as drawn | — |
| Forced | a stubbed draw with no tier ≥ 3 in packs 1–9 | pack 10 holds one tier ≥ 3 card; the other 49 cards unchanged | — |
| Forced tier split | 20,000 forced draws | tiers 3, 4, 5 within 4 σ of 86 %, 13 %, 1 % | — |
| Regular odds | the existing 200,000-draw test | still passes | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/fill_bank.rb` -- `insert_packs`; add the check before the insert.
- `packs/game/app/models/game/{draw,draw_odds,draw_pool,pack}.rb`.
- `test/packs/game/{fill_bank_test,draw_test}.rb`, `test/support/game_packs.rb`.

## Implementation Notes

Oneshot: about 40 lines in three files plus tests; no schema, web or copy change.

## Plan Change Log

## Review Triage Log

- medium, patch: the FillBank test passed without the guarantee (seed 3 draws a sapphire in pack 1) — now `Draw.pack` is overridden to all-steel and the test asserts pack 10, in opening order, holds the forced card.
- medium, patch (same root cause): the 2,000-fills row ran on the module only — the FillBank test above now covers the wiring and the opening order.
- false: position from `tenth.size` instead of `Pack::SIZE` — equal for every bank pack; not a defect.
- Implementation: `Game::FirstSessionGuarantee` (pure), `DrawOdds::GUARANTEE`, `DrawPool::Snapshot#tier_of`, `FillBank#initialize(random:)`; Minitest 6 has no `minitest/mock`, so the test overrides `Draw.pack` and restores it.

## Verification

**Commands:**
- `bin/rails test test/packs/game` then `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop` -- expected: no offence.
