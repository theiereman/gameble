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
