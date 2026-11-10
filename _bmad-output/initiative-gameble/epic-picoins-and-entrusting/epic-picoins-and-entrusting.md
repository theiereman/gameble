---
tracker_id: ""
key: ""
type: epic
title: "PiCoins and entrusting"
parent: initiative-gameble
covers: ["CAP-29", "CAP-35"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# PiCoins and entrusting

## Description

Players can turn cards into PiCoins. A player entrusts copies to the Brotherhood's Archives from a card's detail or the Confier screen, in one batch within the daily cap, and receives PiCoins minted by the 100-6-Tron into a wallet split into available and committed. Every PiCoin movement is an insert-only ledger entry, reconciled every night. Administrators change every economy setting from the back-office as a new version announced by the Brotherhood, and can open or close the market. Production runs with the market closed behind the teaser.

## Outcome

For the players: their spare copies become a currency that will buy cards at auction. For the author: every value of the economy can be tuned without a deployment, and every PiCoin is accounted for.

## Requirements

- R1 — Any unreserved copy can be entrusted, an only copy included, at the entrustment value of its minted rarity read from the current settings version; only `quantity - reserved` can be entrusted and a card-season with no rarity cannot be. The PiCoins are minted by the 100-6-Tron: only `Game::Market::Mint.credit` posts `mint`, and only `Game::Market::EntrustCards` calls it. (CAP-29; `market-economy.md`, Money and Values by rarity; AD-40, AD-41, AD-43)
- R2 — `EntrustCards` takes one player and an ordered list of card-seasons and quantities, under the player's bank lock then their holdings, applies the batch in one transaction, posts one `mint` entry and publishes one `Game::Market::CardsEntrusted` listing the cards, heard by nobody at launch. Lowering a holding uses the step extracted from `AcceptTrade#move`, shared by trades, entrustment and later the settlement, and removes unheld showcase entries. (CAP-29; AD-6, AD-10, AD-43, AD-45 Costs)
- R3 — An entrusted card leaves the collection and is counted per card and edition in the Archives: `game_market_archive_deposits` holds one row per player and card-season, survives account deletion, and is never destroyed; `game_market_archive_stocks`, one row per card-season, is summed by `ArchiveStocksJob` every hour; nothing writes a stock row per entrustment. (CAP-29; AD-9, AD-43, AD-50)
- R4 — The daily cap is 1,200,000 PiCoins per account, read from the player's `mint` entries of the current UTC day. The batch applies most valuable first, whole cards only; a copy that does not fit is skipped and a cheaper one may still pass; what did not fit stays in the collection and the screen says so; a batch where nothing fits is refused. (CAP-29; `market-economy.md`, Values by rarity; AD-43; spec Assumptions; EXPERIENCE.md, Copy deck, Confier and Market refusals)
- R5 — The player selects several cards and validates one batch, with no per-card confirmation or warning; the recap names the copies from Rare upward and never blocks. (CAP-29; EXPERIENCE.md, Confier)
- R6 — The Confier screen shows the player's unreserved copies as a grid, one cell per card and edition with its rarity, season and value, with search, filters and the DOUBLONS chip; ticks, steppers and keys; the recap lists the copies most valuable first, "VOUS RECEVEZ" is what will really be received, the cap gauge previews the selection and the copies that will stay are named before validation; a full cap disables validation; ticked cards are a pending edit for Esc; empty, it says "Aucune carte à confier." with the way on. (EXPERIENCE.md, Confier, Market lists empty, Keyboard; DESIGN.md, Marché, Confier and Mettre en vente grids; Flow 8)
- R7 — On the phone the grid has three columns and only ticks; a bar holds the count, the total and "CONFIER ▸", which opens the recap in a sheet whose lines hold 44px steppers. (EXPERIENCE.md, Confier; DESIGN.md, Marché)
- R8 — The Confier result shows the total minted and the count, and names each copy that did not fit, which stays in the collection. (CAP-29; EXPERIENCE.md, Confier result; DESIGN.md, Confier result)
- R9 — Confier is reached by "CONFIER" in a card's detail, for an owned card once the market has opened, opening on that card's editions with DOUBLONS off and a single free edition ticked; greyed for a fully reserved card with "<n> exemplaires réservés"; absent while the market is suspended; and by its own address. The market screen's "CONFIER DES CARTES" links to that address. (EXPERIENCE.md, Navigation, Card detail and the market)
- R10 — PiCoin amounts are integers drawn by one shared component: the compact form (31,5k, 7,2M) from 1,000 up, always truncated, never rounded up, or the exact form where the UX says, with the PiCoin mark, the exact amount and "PiCoins" as accessible text, in the page's language, U+00A0 as separator, never a euro sign. One server `picoins` helper and one client `picoins` helper give the forms, tested against each other through a shared fixture. (CAP-29; `market-economy.md`, Money; AD-40, AD-51; EXPERIENCE.md, Market words; DESIGN.md, Marché, PiCoin mark)
- R11 — The Balance chip shows available and committed side by side: before the bell on every signed-in desktop page, on the phone only in the header of the market screens (Confier here); a visitor has none; hidden until the market's first opening; it updates after each action and on the player's private stream. (CAP-29; AD-13; EXPERIENCE.md, Balance chip, State Patterns, Market not yet open; DESIGN.md, Balance chip)
- R12 — `game_market_wallets` holds one row per player with `available` and `committed`, `bigint`, each checked `>= 0`, a player with no row having zero. `game_market_ledger_entries` is insert-only and holds the player, `kind`, both deltas, the listing when there is one and the time; its model raises on update and destroy. (AD-41)
- R13 — `Game::Market::Ledger.post(entries)` is the only writer of both tables, and a test refuses any other reference to their write methods. One transaction makes one call, after every other lock: it upserts missing wallets, locks them in ascending player id, nets the deltas per wallet, applies them, then inserts every entry. (AD-10, AD-41)
- R14 — `ReconcileWalletsJob`, every day at 00:10 UTC in the `development` and `production` blocks of `config/recurring.yml` on queue `default`, checks in one `REPEATABLE READ` read each wallet against its entries and the global sum against minted less stamps, commissions and forfeits, and reports any difference to the error tracker. (AD-41, AD-50; `market-economy.md`, Money)
- R15 — `game_market_settings` is insert-only, one row per version, holding every value of `market-economy.md` (per rarity the entrustment value, stamp and minimum price; commission; daily cap; the three durations and the preselected one; increment; soft close; the averaged sale count and the average-price window; the feed threshold; the unusual-maximum threshold; the indicators' alert thresholds and the day-of-income targets) and whether the market is open. Each row names the version it replaces, unique, so the second of two concurrent changes fails with `Failure(:settings_changed)`; the highest id is current, read from the database by each operation, never cached in process. (CAP-35; AD-42, AD-48, AD-51 Costs)
- R16 — A form drawing settings-derived amounts submits the version it drew; entrusting refuses a stale version with `Failure(:amounts_changed)`, paying nothing; the screen draws the new amounts and keeps the ticks. Entrustment values and the cap read the current version. (AD-42; EXPERIENCE.md, Settings behind an open form; Copy deck, Market refusals)
- R17 — Every deploy creates, idempotently, a first closed settings version with the starting values of `market-economy.md`. (AD-50)
- R18 — `Game::Market::ChangeSettings`, taking the administrator as `player:`, validates the whole candidate row: one change cannot more than double or halve an amount, a minimum or the cap; commission stays between 0% and 25%; percents, durations and thresholds have ranges of their own; a minimum price never goes below the no-loss floor `(entrustment + stamp) / (1 - commission)` rounded up to the next hundred. A change is recorded with its author and date and copies `open` from the version it replaces. (CAP-35; `market-economy.md`, Setting bounds and Values by rarity; AD-42)
- R19 — Every settings change, opening and closing carries the Brotherhood's announcement, typed by staff in both languages, published in the same transaction through `Accounts::CreateAnnouncement`, which replaces the announcement shown. (CAP-35; AD-42; EXPERIENCE.md, Back-office)
- R20 — The back-office settings page shows every value, per rarity where it applies, each with its bound and when it applies (stamp and minimum at listing, an auction's own rules at its creation, entrustment values and the cap at once); a value out of bounds is refused beside its field, naming the no-loss floor; saving requires the announcement in both languages; a save over another administrator's is refused with "Un autre administrateur vient de modifier les réglages."; fields are named by their row and column headers. (CAP-35; EXPERIENCE.md, Back-office; Accessibility Floor)
- R21 — `Game::Market::OpenMarket`, for administrators, opens the market and refuses unless the administrator confirms that the terms forbid real-money trading and that the draw odds are published; the confirmation is recorded on the version, and so is the first opening. `ChangeSettings` can close the market. The back-office shows the two confirmations then "Ouvrir le marché", once open "Fermer le marché", and "Rouvrir le marché" after, each with its announcement. (AD-50; EXPERIENCE.md, Back-office)
- R22 — While the market is closed, entrusting refuses with `Failure(:market_closed)`. Before the first opening there is no balance and no market action; after it, a closed market makes Confier's validation disabled with the suspended banner as its reason and leads back to the market. The teaser stays at the market's address whatever the state. (AD-50; EXPERIENCE.md, State Patterns, Market not yet open and Market suspended; Copy deck, Market suspended)
- R23 — The market lives in `Game` under `Game::Market`, in tables prefixed `game_market_`, inside the `game` package; back-office pages stay in the web layer and call `Game::Market` operations; every player-acting operation is a `Game::Operation` taking `player:`. Every market operation answers `ActiveRecord::Deadlocked` with `Failure(:market_busy)`, entrusting is rate limited per player with an explicit limit, and each failure code has its `errors.game.<code>` key in both locales. (AD-14, AD-18, AD-40; Consistency Conventions)

## Done when

1. On staging, after an administrator opens the market, a player entrusts a batch from a card's detail and from the Confier screen; copies over the daily cap stay in the collection and the screen says so; the balance shows available and committed.
2. The ledger reconciles against every wallet each night, and a deliberate mismatch is reported to the error tracker.
3. An administrator changes a setting within its bounds with the Brotherhood's announcement in both languages; a form drawn before the change is refused without charging anything.
4. An administrator opens and closes the market; while closed, entrusting is refused; the teaser stays at the market's address whatever the state.
5. Shipped to production with the market closed.

## Boundaries

No listing, bid, price or indicator. The market screen and the switch from teaser to market belong to epic 39. Every column of `game_market_settings` (amounts, minimums, cap, durations, increment, soft close, commission, average-price window, feed threshold, unusual-maximum threshold, alert thresholds and day-of-income targets) is created here so later epics only read it.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-29, CAP-35
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-10, AD-40, AD-41, AD-42, AD-43, AD-50 (first closed version at deploy, OpenMarket, closing, ArchiveStocksJob, ReconcileWalletsJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Confier, Confier result, Balance chip, Settings behind an open form, Back-office; Flow 8
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Contract with epic 41: this epic creates `ReconcileWalletsJob` at 00:10 UTC in `config/recurring.yml` running the reconciliation only; epic 41 adds the edition price refresh then `WriteDailySnapshot`, in that order, in the same job.
- Contract with epic 39: this epic extracts `AcceptTrade#move` for entrusting; epic 39 reuses it at settlement.
- Contract with epics 39 to 41: this epic builds the one component that draws a PiCoin amount (compact and exact, with its accessible text) and the client `picoins` helper.
- Contract with epic 39: this epic records the first opening on the settings version; epic 39 switches the market address from the teaser to the market screen once it exists.
- The Balance chip stays hidden until the first opening (State Patterns, Market not yet open).
- Decision (2026-11-10): the tracer is story 1, entrusting on a server-rendered Confier page through the schema, the ledger, the mint, the shared holding move, the operation, the controller and the locales, with tests opening the market through a test helper; story 2 opens it for real, so every later story can be seen running in development.
- Decision (2026-11-10): story 1 owns every table this epic needs except `game_market_archive_stocks` (story 12), and every column of `game_market_settings`, so no later story or epic migrates the settings.
- Decision (2026-11-10): `game_market_ledger_entries.listing_id` is created as a plain nullable `bigint`; epic 39 adds the foreign key and AD-41's partial unique index on listing, player and kind with its listings table, concurrently in their own migrations.
- Decision (2026-11-10): story 2 owns the announcement step (both languages through `Accounts::CreateAnnouncement`, replacing the one shown) and `Game::Market::MarketState` (open, first opened); stories 7 to 10 reuse them, and epic 39 switches the market address on first opened.
- Decision (2026-11-10): closing is a `ChangeSettings` with `open` false (AD-50); reopening is `OpenMarket` again, asking both confirmations each time and keeping the first opening time.
- Decision (2026-11-10): `EntrustCards` applies the batch in the order it receives (AD-43); the Confier page sends it most valuable first, so the result matches the recap (spec Assumptions).
- Decision (2026-11-10): the Balance chip's private-stream update goes through the existing `PlayerStream` mechanism (`AfterCommitBatch`, then `PlayerStreamJob`): story 8 adds a balance notice and wires `CardsEntrusted`; epic 39 wires `CardListed` (39.1), its close events (39.2) and `BidPlaced` (39.4); epic 40 wires `LeadVoided` (40.8) and `ListingWithdrawn` (40.9), and 40.5 extends the chip's rendering.
- Decision (2026-11-10): the few-sales threshold is the constant 3 of `EditionPrice` (AD-47), not a setting; `game_market_settings` has no few-sales column.
- Decision (2026-11-10): the ledger's `kind` check holds all eight kinds of AD-41 from story 1; story 10 owns the suspended banner partial reused by epic 39's story 11; `OpenMarket` and `ChangeSettings` both publish `SettingsChanged`, heard by nobody at launch.
- Decision (2026-11-10): sequencing. Stories 1 to 10 are one lane, each after the previous, since each touches the Confier page, the back-office Marché page or the locale files of the one before; stories 11 and 12 form a second lane after story 1, touching only the jobs and `config/recurring.yml`. Story 3, the cap and its skip order, comes right after the opening as the rule least settled.
- Decision (2026-11-10): story 14 is the epic's staging exercise and production delivery with the market closed, after the refactor sweep; the first opening in production stays epic 41's final story.
- Decision (2026-11-10): 14 entries, twelve to build plus the sweep and the hitl; no split, since opening and `MarketState` (story 2) are needed by the Confier stories and the settings stories need the Confier page, so a split would make the two epics depend on each other.
- High-risk checks: stories 1 and 12 (migrations) are checked by CI's schema drift job and the staging deploy of story 14; story 2 and 10 (opening and closing) by the author on staging in story 14; story 9 (bounds) by the author approving the ranges at its plan checkpoint.
- Assumption: moderators see the back-office Marché page (opening and settings) read-only, as AD-51 states for the chart switches; only administrators change it.
- Assumption: entrusting is rate limited at 10 POSTs a minute per player; the builder of story 1 states the limit in the controller.
- Open question: `market-economy.md` gives the day-of-income targets as words ("minutes", "a few hours", "1 to 2 days", "about 40 days"); their numeric starting values are needed before story 1 seeds them (nullable until set) and story 9 bounds them.
- Open question: the ranges of the durations, increment, soft close, average-price window, sale counts and thresholds are not in `market-economy.md` (AD-42 says "ranges of their own"); story 9's plan checkpoint settles them with the author.
