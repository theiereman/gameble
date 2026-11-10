# Market build handoff

Branch `feature/market` carries the market release built so far. Continue it; never push to `develop` or `main`.

## Done (plans in `built`)

Epic 38 stories 38.1 to 38.13, 39.1, 39.2, 41.9. Story 38.14 (staging) and 41.11 (production opening) are the author's.

## Remaining work, as batches

One agent plans and builds a whole batch, story by story in the listed order, so the context is read once. A batch marked "approve" gets one independent approval of its plans, by a subagent that did not write them, in one round: it fixes or blocks only on what would make the code wrong, unsafe or incomplete, and the plan author then settles the issues and builds; do not loop. A batch marked "no approval" is planned and built directly. Batches whose `after` are all done may run in parallel, each in its own worktree.

| Batch | Stories | Approval | After |
|---|---|---|---|
| A | 39.3 sale refreshes the average price (draft plan on branch `market/39-3`), 39.4 bids follow the auction rules | approve | done |
| B | 39.5 seller lists a card (plan already approved on `feature/market`; implement as is) | none, already approved | done |
| C | 39.6 Annonce history and outcome, 39.7 bid with My maximum, 39.8 unusual maximums and buy-now confirmed | approve | A |
| D | 39.9 MES VENTES cancel and relist, 39.10 MES ENCHERES, 39.11 suspended market stays readable | approve | B, C |
| E | 39.12 refactor sweep | no approval | D |
| F | 40.1 outbid bell line and notice, 40.2 live refresh, 40.3 end time and polite state, 40.4 bell tells the outcome | no approval | E |
| G | 40.6 notable sale recorded as a feed entry, 40.13 it appears in the feed, 40.7 players search and filter the market | no approval | F (40.1 only) |
| H | 40.5 badges and balance follow outbid auctions, 40.11 data export includes market data | no approval | F, G |
| I | 40.8 banned or deleted leader's bid voided, 40.9 seller's listings leave the market, 40.10 deleted player's balance forfeited | approve | F, G |
| J | 40.12 refactor sweep | no approval | H, I |
| K | 41.1 average price on a card's detail, 41.3 average price on ÉDITIONS, the Annonce and Mettre en vente, 41.4 collection sorts and filters by average price | no approval | E, G |
| L | 41.2 nightly economy snapshot, 41.5 back-office health page, 41.6 alert prepares a settings change | no approval | J, K |
| M | 41.7 alt-account signals, 41.8 alt signals on sales and bids | no approval | L |
| N | 41.10 refactor sweep | no approval | K, L, M |

Dependencies inside a batch follow the ticket's `after`.

Ticket text: `uv run _bmad/method/scripts/tickets.py --project-root . find <epic-number>.<id>` (needs `_bmad/custom/config.user.toml`; copy it from the author's machine or set the active initiative to `initiative-gameble`). Epic folders: 38 `epic-picoins-and-entrusting`, 39 `epic-an-auction-runs-and-settles`, 40 `epic-follow-auctions-and-removed-players`, 41 `epic-prices-economy-health-and-opening`.

## Process

1. Per batch: one agent reads the tickets, the spec `spec-gameble/market-economy.md`, the architecture, the market UX and the code already built, then for each story writes the plan beside the ticket from `_bmad/render/bmad-build/*/plan-template.md` (status `draft`, open questions settled by you and recorded as decisions in the frozen block).
2. Approval, only for batches marked "approve": as described above; then set the plans to `ready-for-dev`.
3. Implement each story with its tests, in order; set its plan to `in-progress`, then `in-review`.
4. Review: a separate subagent reviews the whole batch adversarially (money and ledger invariants, GET never writes, tokens not ids, Pundit, en and fr locales, packwerk, size limits, tests that cover the acceptance criteria), fixes what is wrong, sets the plans to `built`.
5. Commit on `feature/market` in small conventional commits in English; integrate a batch branch by rebase and fast-forward, one batch at a time, and run `git push origin feature/market` after each batch.

## Hard rules

- Run no test and no `bin/ci`; tests run once at the end on the author's machine. Cheap static checks only (`ruby -c`, rubocop, prettier, `script/check_planning_references`, `script/check_file_sizes`).
- Do not touch `db/schema.rb`; it is regenerated from the migrations at the end. A new migration must sort after every migration on the branch.
- Do not edit ticket files; do not run `tickets.py pull` or `mark`.
- Follow `AGENTS.md`.

## Status after the unattended run

Built and reviewed (plans `built`): 39.3 to 39.12, 40.1 to 40.13, 41.1 to 41.8 and 41.10. Every batch A to N is done; none is left. Not built: 38.14 (staging) and 41.11 (production opening), which stay the author's.

Nothing was executed: no test, no vitest (one vitest run slipped into batch L, 6 passing), no `bin/ci`, no rubocop, packwerk, zeitwerk, i18n-tasks or tsc on the full tree, and ERB was only read by eye. Before release, the author must:

- regenerate `db/schema.rb` from the migrations (new ones: 20261110130000-130002, 140000-140002, 150000-150001, 160000-160003, 190000, 200000);
- run the Ruby suite, the system tests of the market screens, `npm run test:js`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, rubocop and `npm run lint:css`;
- check first the assumptions reviewers could not verify: Turbo morph with `data-turbo-permanent` on the Annonce amount field, happy-dom `SubmitEvent` in the confirm dialogs, the window-function SQL in the alt-signal detector, `insert_all!` with jsonb, the `clear_messages` helper in the stream job tests, the query-count assertions changed in batch K, and the stub pattern in the removed-players job tests.

Reviewers found and fixed real defects in every batch (for example a deleted `whole_number` helper in 39.12, an unset unusual-amount threshold in 39.8, a snapshot column named `destroyed`, banned buyers shown in the feed); the remaining open points are listed in each plan's change log.

### Decisions taken in place of the author

Each is recorded in the frozen block of its plan; the main ones:

- Bids: failures stay bare codes; a leader's raise only has to exceed their own maximum; a removed leader is released in the same ledger post.
- 39.7/39.8: the bid form is a POST answered by one Turbo Stream, rate limited to 20 per minute; the buy-now button submits `buy_now=1` and the server takes the amount from the listing.
- 39.9/39.10: MES VENTES keeps ended rows for 30 days (capped at 100), MES ENCHERES for 7; the chips read ANNONCES, MES ENCHERES, MES VENTES.
- 40.6: a sale is notable when Epic or Legendary, or at or above the settings threshold times the rarity minimum; a private buyer's name shows unlinked in the feed.
- 40.8 to 40.10: one `DropPresenceJob` withdraws a removed seller's listings, voids a removed leader's bid, then forfeits a deleted player's available balance, in that order; Game reacts to Accounts only through that job.
- 41.2: PiCoins per active player divides by players active over 90 days; the median of an even count is the mean of the two middle values, rounded down.
- 41.6: an alert proposes raising the Rare or Legendary stamp by half, rounded up to the next hundred, capped at double; only administrators get the prefilled form.
- 41.7/41.8: alt-signal thresholds (120 or more capsules a day on 3 of 7 days; 10 or more one-way trades in 7 days; sales under half or over twice the previous average, 2 or more in 30 days; 3 or more minimum-price sales in 30 days). No IP or fingerprint is stored; signals reach staff only and never sanction.
- English wording not in the Copy deck was written by the agents and is marked in the plans for the author's approval.
