---
title: 'The complete-sets figure counts a game in any edition'
type: 'feature'
ticket: '2'
created: '2026-10-28'
status: done
---

## Intent

The public profile header figure and the set list must agree on which sets are complete when a game is held in another season's edition.

## Finding

`Game::CollectionSummary` already counts a game held in any edition, as does `Game::SetsInProgress` behind the set rows. No code change was needed.

## Done

- Added an agreement test in `test/domains/game/collection_summary_test.rb`: a set completed with one member held in another edition only, plus a partial set; the header figure equals the number of complete standings.
- Game suite 704 runs green, rubocop and the planning reference check clean.

## Review

Own diff review: one test added, no application code touched, no ids or comments in code.
