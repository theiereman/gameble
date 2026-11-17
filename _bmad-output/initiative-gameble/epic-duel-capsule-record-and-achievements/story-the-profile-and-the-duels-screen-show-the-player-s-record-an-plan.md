---
title: 'The profile and the Duels screen show the player''s record and last duels'
type: 'feature'
ticket: '2'
created: '2026-11-17'
status: 'built'
baseline_revision: '5f7eca4580f96c82d65a812f2887051e70a14a88'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: DERNIERS DUELS reads each row's opponent with its own query, up to ten per Duels screen load, because the accounts domain has no query for several players at once.
    evidence: `DuelHistory#rows` calls `Accounts::PlayerById` per result; `Accounts::PlayersById` does not exist.
---

<intent-contract>

## Intent

**Problem:** A finished duel leaves no trace a player can read: no record on the profile or the Duels screen, no list of last results, and Comment ça marche says nothing about duels.

**Approach:** One query reads wins, losses and draws, another the last ten results; the profile's ACTIVITÉ stats, the Duels screen (phone and desktop) and a new duels section of Comment ça marche show them, every number read from the constants the game applies.

</intent-contract>

## Implementation Notes

Oneshot route: a read-only feature over existing tables, built in the main session. The ticket entry is the contract.

- `Game::DuelRecord` and `Game::RecentDuels` read finished duels through the player's own seat; `Game::ProfileActivity` embeds the record's SQL, so the profile shows Duels wins, losses and draws in its ACTIVITÉ stats and a private owner's page, which does not render them, hides them with the other stats.
- The Duels screen has the record panel and the link to `#how-it-works-duels` under the decks, and DERNIERS DUELS in the desktop left column, both beside the existing panels, through `DuelHistory`.
- Each row is named by `duels.board.result_spoken` and shows `duels.board.result`; a removed or departed opponent reads anonymous through `PlayerNameComponent` and `duel_plain_name`.
- Comment ça marche gains a duels section whose numbers come from `Game::Deck`, `Game::DuelStat`, `Game::DuelRules`, `Game::DuelClock`, `Game::Pack::DUEL_SIZE` and `Game::DrawOdds::DUEL`.

## Auto Run Result

- Review: none, the author reviews the whole duel diff at the end.
- Verification: the query, controller, profile and how-it-works tests, the new system test and the existing Duels and desktop system tests (one file at a time), `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing`, rubocop.

## Verification

**Commands:**
- the query, policy, controller and one system test of the ticket; `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing`
