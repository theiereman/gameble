---
title: 'A deleted player''s balance is forfeited and their market traces erased'
type: 'feature'
ticket: '40.10'
created: '2026-11-10'
status: 'draft'
baseline_revision: '7e2188be18f2ebdd2b1b019873346127609b6b3a'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-a-banned-or-deleted-seller-s-listings-leave-the-market-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-a-notable-sale-is-recorded-as-a-feed-entry-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A deleted player's PiCoins sit in a wallet nobody can use, their market notices stay in the table, and the delete dialog does not say what happens to their balance, listings and bids. Epic requirements R12, R15, R16 and R18.

**Approach:** A new `Game::Market::ForfeitBalance` operation, run by `DropPresenceJob` as its last step, posts one `forfeit` entry for a deleted player's remaining available PiCoins once no listing or lead of theirs is open; `Game::ReleasePlayer` also deletes their notices; the delete dialog names the balance, the purchases and the market consequences.

## Boundaries & Constraints

**Always:**
- `ForfeitBalance` takes `player:` (`require_account`) and publishes one `Game::Market::BalanceForfeited` (`player_id`, `amount`) on the player's stream. In one transaction: `TradeLocks.players(player.id)`, recheck the player is deleted (a banned or live player gives `Failure(:player_not_deleted)`), then refuse with the skipped constant `Failure(:market_pending)` when an open listing names them as seller or leader or the wallet's `committed` is above zero, then lock the wallet row, read `available`, give `Failure(:nothing_to_forfeit)` (skipped constant) when zero, and `Ledger.post` one entry of kind `forfeit` with `available_delta: -available`, `committed_delta: 0`, `listing_id: nil`, `settings_id` of `CurrentSettings.call`. The reconciliation already counts `forfeit` as destroyed, so it balances.
- `DropPresenceJob#perform` gains its last step, after withdrawals and voids, reading `RemovedPresence.wallets`: wallets with `available > 0` and `committed = 0` of deleted players (`deleted_at` set, so deletions by the retention job and the erasure of a banned player are found alike) with no open listing as seller or leader. A banned player's wallet is never listed. Same per-item error handling; benign constants skipped.
- `Game::ReleasePlayer` also runs `Notice.where(player_id: player.id).delete_all` inside its existing transaction, after the bank lock. Notices of others that name the deleted player as the other player stay: they render the anonymous name through `PlayerNameComponent`. Sale entries naming the buyer go with the feed entries `ReleasePlayer` already deletes; a test proves it. Bids, ledger entries and listings stay, without identity, as the privacy page says.
- The delete dialog: `accounts.dialog.note` (both locales) adds the purchases announced in the feed to its list of erased entries; a new paragraph `accounts.dialog.market_html`, rendered only for a player with a balance, an open listing or a lead (a new query `Game::Market::DeletionNote`, read by `SettingsController#show` into an instance variable and passed to the dialog partial), says in fr "Votre solde de %{balance} PiCoins est détruit sans remboursement une fois vos annonces en cours retirées et vos offres libérées." and in en "Your balance of %{balance} PiCoins is destroyed without refund once your running listings are withdrawn and your bids released." The amount is the available plus the committed PiCoins, through `PicoinAmountComponent`.

**Never:**
- No migration and no new index (the wallets scanned are those of deleted players with a positive balance, which the step empties), no forfeit for a banned player, no forfeit while a listing or lead is open, no edit of the ledger or wallet outside `Ledger.post`, no write from the dialog's GET, no database id in the page.

**Decisions (settled by the plan author, to approve):**
- The forfeit takes only `available`; `committed` is expected to be zero once leads are voided and the step waits otherwise, so no entry can break a hold.
- A deleted player's notices are erased with the rest of the game inside the deletion; a notice written in the same instant by a concurrent bid on another connection is not chased, as it holds no personal data beyond a card and an amount on a token-less row.
- The dialog's market paragraph is hidden for a player with no market activity, so the dialog does not change while the market is closed and unused.
- The order inside one job pass is the contract: withdraw, void, then forfeit; a wallet whose listing was just withdrawn is forfeited in the same pass because the finder runs last.
- No new error keys: the operation is reached only by the job.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Deleted with a balance | Deleted, available 5,000, nothing open | One `forfeit` of 5,000, wallet at zero, `BalanceForfeited` | No error expected |
| Listing still open | Deleted with an open listing or lead | Not listed by the finder; after withdrawal or void the same pass forfeits | No error expected |
| Banned wallet | Banned player with a balance | Untouched | No error expected |
| Retention deletion | Idle player deleted by the retention job with a balance | Forfeited like any deleted player | No error expected |
| Zero balance | Available zero | Not listed; the operation answers `Failure(:nothing_to_forfeit)` if called | Job ignores it |
| Committed funds | Committed above zero | `Failure(:market_pending)`, left for a later pass | Job ignores it |
| Second run | Forfeited wallet | Not listed | No error expected |
| Reconciliation | After a forfeit | Wallet equals its entries, circulation equals minted less destroyed | No error expected |
| Deletion | `ReleasePlayer` | Player's notices and sale entries gone, others' notices naming them kept | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/forfeit_balance.rb`, `app/domains/game/app/events/game/market/balance_forfeited.rb` -- new operation and event
- `app/domains/game/app/queries/game/market/removed_presence.rb`, `app/domains/game/app/jobs/game/market/drop_presence_job.rb` -- wallet finder, last step
- `app/domains/game/app/operations/game/release_player.rb` -- notice deletion
- `app/domains/game/app/queries/game/market/deletion_note.rb`, `app/controllers/settings_controller.rb`, `app/views/accounts/_dialog.html.erb`, `config/locales/en.yml`, `config/locales/fr.yml` -- the dialog

## Tasks & Acceptance

**Execution:**
- [ ] `balance_forfeited.rb`, `forfeit_balance.rb` -- event and operation
- [ ] `removed_presence.rb`, `drop_presence_job.rb` -- wallet finder and last step
- [ ] `release_player.rb` -- delete the player's notices
- [ ] `deletion_note.rb`, `settings_controller.rb`, `_dialog.html.erb`, both locales -- the dialog's note and paragraph
- [ ] Tests: operation (forfeit entry, wallet at zero, banned refused, open listing and committed refused, zero skipped, second run, concurrent void), job order (listing withdrawn and lead voided first, then wallets), banned wallet kept, retention deletion forfeited, reconciliation balanced after a forfeit, `ReleasePlayer` removing notices and sale entries and keeping others' notices, dialog query and view in both locales, one system test

**Acceptance Criteria:**
- Given a player with a balance and a running listing deletes their account from the settings, when the job runs, then their listing is withdrawn and their wallet is at zero, and the delete dialog had named the balance.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `bundle exec rubocop`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
- `bin/rails zeitwerk:check` -- expected: no finding
