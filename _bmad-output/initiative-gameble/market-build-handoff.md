# Market build handoff

Branch `feature/market` carries the market release built so far. Continue it; never push to `develop` or `main`.

## Done (plans in `built`)

Epic 38 stories 38.1 to 38.13, 39.1, 39.2, 41.9. Story 38.14 (staging) and 41.11 (production opening) are the author's.

## Remaining, in dependency order

- 39.3 A sale refreshes its edition's average price (after 39.2). Its draft plan is on branch `market/39-3`, not approved.
- 39.4 Bids follow the auction rules (after 39.3)
- 39.5 A seller lists a card from Mettre en vente (after 39.1). Plan approved and already on `feature/market`; implement it as is.
- 39.6 The Annonce shows its history and its outcome (after 39.4)
- 39.7 A player bids with My maximum (after 39.6)
- 39.8 Unusual maximums and buy-now are confirmed first (after 39.7)
- 39.9 A seller follows MES VENTES, cancels and relists (after 39.5, 39.8)
- 39.10 A bidder follows MES ENCHERES (after 39.9)
- 39.11 A suspended market stays readable (after 39.10)
- 39.12 Refactor sweep (after 39.11)
- 40.1 An outbid player sees a bell line and the notice on the Annonce (after 39.12)
- 40.2 The Annonce refreshes live (after 40.1); 40.3 end time and polite state (after 40.2); 40.4 bell tells the outcome (after 40.1)
- 40.6 A notable sale is recorded as a feed entry (after 40.1); 40.13 it appears in the feed (after 40.6); 40.7 Players search and filter the market (after 40.13)
- 40.5 Badges and the balance follow outbid auctions (after 40.3, 40.4, 40.7)
- 40.8 A banned or deleted leader's bid is voided (after 40.2, 40.4); 40.9 a banned or deleted seller's listings leave (after 40.8); 40.10 a deleted player's balance is forfeited (after 40.9, 40.6)
- 40.11 The data export includes market data (after 39.12)
- 40.12 Refactor sweep (after 40.5, 40.10, 40.11)
- 41.1 A card's detail shows the average price (after 39.12); 41.2 nightly economy snapshot (after 41.1, 40.12); 41.3 average price on ÉDITIONS, the Annonce and Mettre en vente (after 41.1); 41.4 collection sorts by average price (after 41.1, 40.7)
- 41.5 Back-office health page (after 41.2); 41.6 alert prepares a settings change (after 41.5); 41.7 alt-account signals (after 41.5); 41.8 alt signals on sales and bids (after 41.7)
- 41.10 Refactor sweep (after 41.3, 41.4, 41.6, 41.8)

Ticket text: `uv run _bmad/method/scripts/tickets.py --project-root . find <epic-number>.<id>` (needs `_bmad/custom/config.user.toml`; copy it from the author's machine or set the active initiative to `initiative-gameble`). Epic folders: 38 `epic-picoins-and-entrusting`, 39 `epic-an-auction-runs-and-settles`, 40 `epic-follow-auctions-and-removed-players`, 41 `epic-prices-economy-health-and-opening`.

## Process per story

1. Plan: write it beside the ticket, from `_bmad/render/bmad-build/*/plan-template.md`, status `draft`; settle open questions yourself and record them as decisions in the frozen block.
2. Approve: a separate subagent that did not write the plan checks it against the ticket, the spec `spec-gameble/market-economy.md`, the architecture, the market UX and the code already built; it approves (status `ready-for-dev`) or lists blocking issues; up to five rounds.
3. Implement the approved plan with its tests.
4. Review adversarially with another subagent (money and ledger invariants, GET never writes, tokens not ids, Pundit, en and fr locales, packwerk, size limits); fix; plan status `built`.
5. Commit on `feature/market` in small conventional commits. Independent stories may run in parallel subagents, each in its own worktree, integrated one at a time by rebase and fast-forward.

## Hard rules

- Run no test and no `bin/ci`; tests run once at the end on the author's machine. Cheap static checks only (`ruby -c`, rubocop, prettier, `script/check_planning_references`, `script/check_file_sizes`).
- Do not touch `db/schema.rb`; it is regenerated from the migrations at the end. A new migration must sort after every migration on the branch.
- Do not edit ticket files; do not run `tickets.py pull` or `mark`.
- Follow `AGENTS.md`.
