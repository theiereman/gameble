---
title: 'The automatic showcase shows a card the player holds'
type: 'bugfix'
ticket: 8
created: '2026-10-19'
status: done
baseline_revision: '32fee1d122754f42610d4e35418a8912af0ef370'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred:
  - summary: >-
      Game::Holding's comment says last_gained_at is set only by Game::OpenPack, though Game::AcceptTrade sets it too, and the showcase now relies on both.
    evidence: |-
      packs/game/app/operations/game/accept_trade.rb:63 and :66 write last_gained_at; the model comment predates that.
    location: >-
      packs/game/app/models/game/holding.rb:6
    severity: low
  - summary: >-
      index_game_packs_opened may have lost its only reader now that the showcase no longer reads opened packs.
    evidence: |-
      The removed Game::NotablePull read game_packs through it; check other readers before dropping it in an expand/contract migration.
    location: >-
      db/migrate/20261006050000_index_game_packs_opened.rb
    severity: low (unverified)
---

<intent-contract>

## Intent

**Problem:** The hub's automatic showcase (« DERNIÈRE OBTENTION ») is read from the opened capsules' history (`Game::NotablePull`), so a card traded away stays on the hub, and a card received by trade never shows; « REPOSTER » hides when the card is no longer held.

**Approach:** Replace `Game::NotablePull` with a query over the player's holdings: the card of Épique rarity or better (tier 4+) of the published season that they still hold (quantity > 0), most recently gained (`last_gained_at`), so capsules and trades both count. Since the card is always held, « REPOSTER » always shows beside it. EXPERIENCE.md's Showcase line says so.

## Boundaries & Constraints

**Always:** One query for the card id; nil without a query for a visitor or no season. Order: `last_gained_at DESC NULLS LAST`, then rarity DESC, then card-season id. A card reserved in an open trade still counts (quantity > 0, `reserved` ignored). The hub GET writes nothing. English repo text, no planning ids in code; code reads without comments beyond a one-line role note.

**Never:** The player-chosen showcase (16.4) — no VITRINE kicker, no new table. No migration (`last_gained_at` and the unique `(player_id, card_season_id)` index exist). No change to `Game::ShowcaseCards` (friend profile).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Latest held | Two tier-4+ holdings, gained at t1 < t2 | the t2 card | — |
| Traded away | The t2 card's quantity falls to 0 (trade concluded) | the t1 card | — |
| Received by trade | A tier-4+ card gained by `AcceptTrade` after a capsule card | the traded card | — |
| Same moment | Tier 4 and tier 5 gained at the same time | the tier 5 card | — |
| No gain date | A NULL `last_gained_at` holding and a dated one | the dated one; the undated only when alone | — |
| Below tier / other season | Only tier ≤ 3 held, or tier 4+ of another season | nil (empty showcase) | — |
| Visitor / no season | nil player or nil season | nil, zero queries | — |

</intent-contract>

## Code Map

- `packs/game/app/queries/game/notable_pull.rb` -- current pack-history query; delete. Only caller: `PagesController#showcase`.
- `packs/game/app/queries/game/showcase_cards.rb` -- reference pattern: `Holding` joined to `catalog_card_seasons`, `quantity > 0`, season filter, `pluck`. Do not change.
- `packs/game/app/models/game/holding.rb` -- `last_gained_at` set by `OpenPack` and `AcceptTrade` on gain; a traded-away holding stays at quantity 0.
- `Catalog::Rarity::TIERS` / `catalog_card_seasons.rarity` -- integer column, tier 4 = Épique (see old `NotablePull::TIER`).
- `app/controllers/pages_controller.rb` -- `#showcase` calls the query, then `Game::Quantities` for `@showcase_repostable`, then `Catalog::CardViews`; header comment names the pull.
- `app/views/pages/_showcase.html.erb` -- header comment and the `repostable` local around the repost button; `app/views/pages/home.html.erb:40` passes `repostable: @showcase_repostable`.
- `test/packs/game/notable_pull_test.rb` -- replace with the new query's test (setup with `publish_sets_draft` and tier ids is reusable).
- `test/controllers/pages_controller_test.rb` -- `PLAYER_HUB_QUERIES`, "offers no repost once traded away" test, the query-count test using `Game::NotablePull::RECENT`, tests building the showcase from `create_pack(opened_at:)` without holdings (must now hold the card).
- `test/support/game_trades.rb` -- `conclude_trade` for a real trade; `test/support/game_packs.rb` -- `fixture_tier_ids`, `create_pack`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md:208` -- Showcase row, « latest pull » wording.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/latest_notable_card.rb` -- new `Game::LatestNotableCard.call(player, season:)` returning a card-season id or nil, per the matrix -- replaces the pack history read.
- [x] `packs/game/app/queries/game/notable_pull.rb`, `test/packs/game/notable_pull_test.rb` -- delete.
- [x] `test/packs/game/latest_notable_card_test.rb` -- one test per matrix row, the traded-away and received-by-trade rows through `conclude_trade`; one query for a player, zero for visitor/no season.
- [x] `app/controllers/pages_controller.rb` -- `#showcase` uses the new query and drops `Game::Quantities`/`@showcase_repostable`; update the header comment.
- [x] `app/views/pages/_showcase.html.erb`, `app/views/pages/home.html.erb` -- repost button always shown with the card; drop the `repostable` local; update the header comment.
- [x] `test/controllers/pages_controller_test.rb` -- showcase tests hold their card; replace the "no repost once traded away" test with one where the traded-away card gives way to the previous one held, « Repost » shown, and the GET writes nothing; lower `PLAYER_HUB_QUERIES` as measured and drop the RECENT history part.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- Showcase row: the automatic card is the latest gained card of Épique or better the player still holds, from a capsule or a trade (author, 2026-10-16).

**Acceptance Criteria:**
- Given a signed-in player who held an Épique card and traded it away, when they open the hub, then the showcase shows the previous Épique-or-better card they hold, with « REPOSTER », and the request writes no row.
- Given a player holding no Épique-or-better card of the published season, when they open the hub, then the empty showcase shows.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` test/system/hub_test.rb desktop test still built the showcase from an opened pack with no holding, so its showcase would be empty — the player now holds Portal with a gain date, plus the Valve completion row so the set row still shows.
  - `[low]` `[patch]` en.yml kicker "Latest pull" is wrong for a card received by trade (fr « Dernière obtention ») — now "Latest acquisition".
  - `[low]` `[patch]` French "Épique" in English comments and test names — now "Epic".
  - `[low]` `[defer]` Game::Holding's comment names only OpenPack as setting last_gained_at — pre-existing (AcceptTrade already set it); deferred.

## Auto Run Result

- **Summary:** the hub's automatic showcase now reads the player's holdings (`Game::LatestNotableCard`): the Epic-or-better card of the published season still held, latest gained first (capsule or trade), rarer first at the same moment, undated last. « REPOSTER » always shows with it. `Game::NotablePull` is gone; the hub costs one query less.
- **Files:** `packs/game/app/queries/game/latest_notable_card.rb` (new query), `notable_pull.rb` and its test (deleted), `test/packs/game/latest_notable_card_test.rb` (matrix), `app/controllers/pages_controller.rb` (uses it, no repostable flag), `app/views/pages/_showcase.html.erb` and `home.html.erb` (repost always), `test/controllers/pages_controller_test.rb` (holdings, traded-away request test with no write, 18 queries), `test/system/hub_test.rb` (holds its card), `config/locales/en.yml` (kicker "Latest acquisition"), EXPERIENCE.md Showcase row.
- **Review:** 3 patches (1 medium, 2 low), 1 deferred (holding comment), 0 rejected. Follow-up review: false (no high, one medium patched).
- **Verification:** focused tests green (57 runs); `bin/ci` green before the patches (2827 runs, 0 failures); `npm run test:js`, `npm run typecheck`, `zeitwerk:check`, packwerk green. Rerun after rebase before push.
- **Residual risk:** the old index on opened packs may be unused now (deferred).

## Verification

**Commands:**
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1608 bin/rails test test/packs/game/latest_notable_card_test.rb test/controllers/pages_controller_test.rb` -- expected: green
- `DATABASE_URL=... bin/rails test`, `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green
