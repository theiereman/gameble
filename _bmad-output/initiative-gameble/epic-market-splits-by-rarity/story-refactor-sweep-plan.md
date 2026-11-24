---
title: 'Refactor sweep'
type: 'refactor'
ticket: '5'
created: '2026-11-24'
status: 'built'
baseline_revision: '735e59fccbf6f39c15f257c9c33d73979d2640cc'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Several copies of one edition in one Confier wanted line: the first auction takes every order that reaches it and the beaten orders are refunded, though they could have led the second copy's auction.
    evidence: |-
      ApplyWantedChoices calls convert_orders once per copy; a beaten order ends and does not reopen (epic decision), so it is consistent but costs those owners a lead.
    location: >-
      app/domains/game/app/operations/game/market/apply_wanted_choices.rb
    severity: low
  - summary: >-
      OrderConversion locks the order owners after the seller's bank and holdings, outside the sorted set every other operation locks, so two sellers holding orders on each other's cards can deadlock.
    evidence: |-
      The Deadlocked rescue answers market_busy and nothing is lost; a fix gathers the reaching owners before the transaction and locks them with the sorted set.
    location: >-
      app/domains/game/app/operations/game/market/order_conversion.rb
    severity: medium (unverified)
  - summary: >-
      PlayerOrders finds a converted order's auction only through its order_leads or order_beaten notice, so a bulk delete of notices (ReleasePlayer) drops the row and its link.
    evidence: |-
      Order has no listing reference; auctions_of and shown read the notices.
    location: >-
      app/domains/game/app/queries/game/market/player_orders.rb
    severity: low
  - summary: >-
      Migrations 110004 and 110005 drop then recreate the unique end-notice index in two deploys; Notice.record raises between them.
    evidence: |-
      No order or notice exists in production before release 1.4.0, so no deploy window is open; creating the new index under another name first would close it.
    location: >-
      db/migrate/20261124110004_remove_order_end_index_from_game_market_notices.rb
    severity: low
  - summary: >-
      Buying one capped copy leaves the other tiles of that rarity on the open page drawing the old count until reload.
    evidence: |-
      archive_purchases/create.turbo_stream.erb replaces only the bought tile; the confirmation recomputes the standing when opened, so nothing is overbought.
    location: >-
      app/views/market/archive_purchases/create.turbo_stream.erb
    severity: low
  - summary: >-
      The cap date renders in server time, and the opening line's live region re-announces at every keystroke.
    evidence: |-
      archive_cap_date formats next_at.to_date server-side; listing-fields rewrites the polite region on each typed event without a debounce.
    location: >-
      app/helpers/archive_shop_helper.rb
    severity: low
  - summary: >-
      An order that expires while ListCard or ApplyWantedChoices waits on the order locks can still be converted: the clock is read before that wait.
    evidence: |-
      Both operations read now before lock_reaching_orders takes the order row locks; a window of the lock wait.
    location: >-
      app/domains/game/app/operations/game/market/order_conversion.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The four entries of the market-splits epic left what a closing sweep must settle: a system test that serves a Rare through `SellToOrder` and others the epic may have broken, a flaky system test, the shop's rarity chips without the cap line, test gaps, copy that may still imply a direct sale above Uncommon, readers of `converted` that must tolerate old events, an unmeasured conversion size, and duplicated checks.

**Approach:** Cleanup only, nothing that adds a rule: fix what the cross-entry review of the whole epic diff finds real, fix the broken and flaky system tests at their cause, add the missing cap line and its tests, measure the conversion, extract named methods for duplications, and correct one line of AD-60 in its own docs commit. Scope pushed out of another story is reported as a new story, not built.

## Boundaries & Constraints

**Always:** Follow AGENTS.md (operations write, tokens in URLs, both locales, no planning ids in code or tests, no comments but external constraints, files under the size limits). System tests one file at a time at 2 workers, never the whole suite. A flaky test is fixed by finding its race, never by skip or retry.

**Never:** Add a rule, a screen or a setting. Edit anything under `_bmad-output` but this plan (and, in a separate docs commit, the one AD-60 bullet). Push or merge.

</intent-contract>

## Code Map

- `test/system/market_orders_test.rb` -- the test "served, expired and cancelled orders show under RECENTLY ENDED" serves a Rare through `SellToOrder` (about line 104); fixtures hold one card season per rarity (`common_card_one`, `uncommon_card_one`, `rare_card_one`, `legendary_card_one`, `portal_one` Epic), so serve the Uncommon, cancel the Rare, rewrite the three row assertions to match.
- `test/system/market_feed_test.rb` -- "a direct sale to a buy order shows in the feed" serves an Epic (`portal_one`) through `SellToOrder`: fails since the direct sale is Common and Uncommon only. Baseline run of the 25 `market_*_test.rb` files found it; the log is in the Implementation Notes.
- `test/system/market_order_backed_auction_test.rb` -- flaky at its second sign-in (`.top-bar .top-bar__end a[href*='/sign-in']` not found). It calls `Capybara.reset_sessions!` between two sign-ins. `test/application_system_test_case.rb` `after_teardown` documents the cause: a request the last page left in flight re-sends the session cookie after the reset, so the browser is still signed in; its fix is a second `Network.clearBrowserCookies`. Extract that pair into one named helper there, used by `after_teardown` and by the test (and by `market_entrust_test.rb:360`, the other caller of the bare reset).
- `app/views/market/shops/_filters.html.erb` (the rarity chips, `market-shop__rarities`), `app/views/market/shops/show.html.erb` and `show.turbo_stream.erb` (already pass `caps:` to `_offers`), `app/helpers/archive_shop_helper.rb` (`archive_cap_line(card, caps)` builds the cap line from a card's rarity), `app/domains/game/app/queries/game/market/archive_caps.rb` (`ArchiveCaps.call(player:, settings:)` returns a `Standing` per capped rarity, `{}` for a visitor), `app/controllers/market/shops_controller.rb` (`@caps`), `config/locales/en.yml` and `fr.yml` (`market.archive_cap.*`), `app/frontend/styles/market-shop.css`.
- `app/domains/game/app/events/game/market/card_listed.rb`, `wanted_choices_applied.rb` -- events carry `converted`; readers: `handlers/order_notices.rb`, `wanted_notices.rb`, `wanted_refresh.rb`, `app/models/player_stream.rb`, `app/models/market_push_notice.rb` (six `data.fetch(:converted, [])`-style reads; extract one named reader per event or one shared reader so none can forget the default). `grep -rn converted app` lists them all; every one must tolerate a stored event with no `converted` key.
- `app/domains/game/app/operations/game/market/order_conversion.rb` (`convert_orders`), `list_card.rb`, `apply_wanted_choices.rb` -- the conversion: per order a bid insert, an order update, a ledger entry, wallet update and notice delete; measured linear, about 4.6 ms an order, 0.63 s for 100 orders and 2.3 s for 500 (before this sweep; recorded, not optimised unless the review finds a defect).
- `app/domains/game/app/queries/game/market/wanted_copies.rb`, `app/views/markets/_wanted_panel.html.erb`, `app/helpers/market_wanted_helper.rb`, `app/views/cards/show.html.erb` and what it renders for `@wanted` (the card detail), locale keys `markets.wanted.*` -- "Vos cartes voulues" and the card detail show the best order of a Rare copy; the order stays (it backs an auction), only copy or links implying a direct sale above Uncommon change.
- `test/domains/game/market/archive_caps_test.rb`, `test/system/market_shop_cap_test.rb`, `test/controllers/market/shops_controller_test.rb`, `test/controllers/markets_controller_test.rb` (market grid), `test/helpers/archive_shop_helper_test.rb` if present -- where the cap line tests live or belong: the market grid tiles, the shop panel, the shop chips, and the date fallback in `archive_cap_date` when `next_at` is nil.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` AD-60 -- the rule bullet says the balance check comes before the cap check; `BuyFromArchives` checks the cap first. One line, own commit.

## Tasks & Acceptance

**Execution:**
- [ ] Whole-epic review findings (see Implementation Notes, "Whole-epic review"): fix each one routed `fix`; the rest are listed in `deferred` or the report.
- [ ] `test/system/market_orders_test.rb`, `test/system/market_feed_test.rb` -- serve an Uncommon, never a Rare or Epic -- the direct sale is for Common and Uncommon only.
- [ ] Run every `test/system/market_*_test.rb` one file at a time (`PARALLEL_WORKERS=2`) after all changes; fix each breakage at its cause and record the list.
- [ ] `test/application_system_test_case.rb`, `test/system/market_order_backed_auction_test.rb`, `test/system/market_entrust_test.rb` -- one named helper that resets the session and clears the cookies again; run the order-backed auction file five times alone, all green.
- [ ] Shop rarity chips -- show the cap line (what is left, or the date it reopens) on each capped rarity's chip through `ArchiveCaps`, en and fr, with a test (controller or system) and CSS as needed.
- [ ] Tests -- the cap line on the market grid tiles and on the shop panel, and `archive_cap_date`'s fallback to today when `next_at` is nil.
- [ ] "Vos cartes voulues" and the card detail -- check every string and link for a direct-sale wording above Uncommon; change to the auction wording or leave, and record what was found.
- [ ] `converted` readers -- one reader that defaults to `[]`; a test replaying a stored event without the key through every handler and the stream and push readers.
- [ ] Duplications, file sizes (`script/check_file_sizes`), leftovers in the four entries' tests and copy -- extract named methods or objects, no comments.
- [ ] Time a listing under hundreds of open orders on one game in a throwaway test (not committed); the figures above are the start; record them.

**Acceptance Criteria:**
- Given the 25 `market_*_test.rb` system files, when each runs alone at 2 workers, then each passes.
- Given `market_order_backed_auction_test.rb`, when it runs five times alone, then five passes.
- Given a signed-in player in the shop, when a capped rarity's chip is drawn, then it shows what is left or the date, in the page's language; a visitor sees no cap line.
- Given an event stored without `converted`, when any handler, stream or push reader reads it, then it reads no converted orders and raises nothing.
- Given `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, the format, CSS, planning-id and size checks, then all pass.

## Auto Run Result

- Summary: the market epic's closing sweep. A whole-epic review ran first (four lenses over the epic's code, tests, config and db), then: the two system tests the epic broke are fixed (an Uncommon is served instead of a Rare or an Epic), the flaky second sign-in is fixed at its race, the shop's rarity chips draw the cap line, the cap line and the nil `next_at` fallback have tests, every reader of `converted` goes through one tolerant reader, duplicated plumbing is extracted, a real bug in the bid history of converted orders is fixed, and AD-60 is corrected in a docs commit of its own.
- Files: see Implementation Notes (the sweep log).
- Review: thorough, four lenses on the sweep. Patches applied: 2 (low): the server prefill raised to the edition minimum with a controller test, a positive-path test of `ConvertedOrders`. Deferred: 7 (see `deferred`). The other findings are rejected with their reasons in the triage log. No follow-up review recommended; patched counts: high 0, medium 0, low 2.
- Verification: `bin/ci` passes (after the last patch), `npm run test:js` 1613 passed, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` pass; every `test/system/market_*_test.rb` and `back_office_market_*_test.rb` file passes alone at 2 workers, and `market_order_backed_auction_test.rb` passes five runs alone in a row.
- Residual risks: the flake's cause is read from the code and the teardown's own comment (a request in flight re-sends the session cookie after the reset), not caught on a failing run; the lock-order inversion in the conversion is deferred.

## Implementation Notes

Route full: the change spans tests, views, helpers, events and handlers, well over 100 lines. The whole-epic review (item 1 of the scope) ran before any change, as four lenses over `3aabe792..735e59fc` (code, tests, config, db; not the plans).

System baseline of the 25 `test/system/market_*_test.rb` files at `735e59fc` (one file at a time, 2 workers): 23 pass; `market_orders_test.rb` ("served, expired and cancelled orders", `value!` on `Failure(:direct_sale_not_for_rarity)`) and `market_feed_test.rb` ("a direct sale to a buy order shows in the feed", same cause, an Epic served) fail. `market_order_backed_auction_test.rb` passed this run (the flake is intermittent). The unit suite baseline is in the final report.

Whole-epic review (lenses: blind, edge case, verification gap, intent alignment), triaged. Routes: fix (in this sweep), test (a gap this sweep fills), report (deferred, not cleanup).
- fix: `.sale-orders-slot:empty` never matches because `_fields.html.erb` writes the slot over three lines; put it on one line like its sibling.
- fix: two sources for "above Uncommon" (`DirectSale::RARITIES` and `SettingsRules::CAPPED_RARITIES`); derive one from the other.
- fix: `PlayerOrders` sorts in-progress rows by the order's own `expires_at` while a `bid` row shows the auction's end; sort the displayed end.
- fix: `listing_form.ts` prefills the lowest order's price unclamped to the edition minimum, `wanted_table.ts` clamps it; clamp both alike. The "still validates the starting price" vitest case was moved from `alpha` to `beta` to dodge the prefill: restore a case on the edition that has orders.
- verify, then fix if real: `OrderConversion#convert_orders` creates the bid rows in order-age order, so a beaten order older than the leader gets its row first: check `BidHistory.covering_leaders` and the Annonce history, and create the leader's row first if the history then shows the beaten bidder as an ordinary bid (add a test either way).
- verify, then fix if real: `market_wanted_choices_helper.rb` result row (around lines 46-48) for a line with several copies, some converted: "received" from the starting price and one "led by a buy order at" figure from the first led listing; correct the figure only if it states a wrong amount.
- fix if one line: `ApplyWantedChoices` reads `now` before its transaction and passes it to the conversion; read it inside the transaction after the locks, as `ListCard` does, so an order that expired during a lock wait is not converted.
- test: push for a converted owner end to end (`MarketPushNotice::EVENTS`, `ORDER_KINDS`): a listing over an order enqueues the push job; the job delivers `order_leads` and `order_beaten`.
- test: the cap line on the market screen's shop panel, mixed grid and the shop's next-page stream; `archive_cap_date` with a nil `next_at`.
- test: a converted order whose auction ends cancelled or withdrawn reads outbid with its PiCoins returned.
- report: several copies of one edition in one Confier wanted line: the first auction takes every reaching order, the rest are beaten and refunded (consistent with "a beaten order ends"); lock order in `OrderConversion` (owners locked after the seller and the holdings, a deadlock is rescued as `market_busy`); `PlayerOrders` finds an order's auction through its notice, so a bulk delete of notices would drop the row; migrations 110004 and 110005 drop then recreate the unique end-notice index in two deploy steps (nothing runs between them before release 1.4.0); the cap date renders in server time; French "prochaine le" and the feminine chips are the author's copy awaiting approval; the opening-line live region announces at every keystroke; buying one capped copy leaves the other tiles of the rarity stale until reload (the dialog recomputes); `openingPrice` in script mirrors `AuctionMath` (pinned by shared figures); the signal derivation of tied accounts is not exercised end to end.
- reject: `WantedCopies` keeps the best order of a Rare copy (a real demand signal for the auction); its copy is checked in the task below.
- reject: Common and Uncommon editions also show the orders block and the prefilled start (R4 says whatever the rarity).

Sweep log (what was done, in the order of the scope):
- Fixed from the whole-epic review: `.sale-orders-slot` written on one line so `:empty` matches; `SettingsRules::CAPPED_RARITIES` derived from `DirectSale::RARITIES` (one source for "above Uncommon"); `PlayerOrders` sorts in-progress rows by the end they show (the auction's for a bid), with a test; `listing_form.ts` `lowestOrder` clamps the prefill to the edition minimum like `wanted_table.ts` (a vitest case for it, the fixture edition given a realistic minimum, and a controller case that a start under the minimum on an edition with orders is still refused); `ApplyWantedChoices` reads `now` inside the transaction after the locks.
- Verified real, fixed: `OrderConversion` created the older beaten order's bid row before the leader's, so `BidHistory.covering_leaders` found no covering leader and drew the beaten bidder as an ordinary bid. The leader's row is now created first, the others in age order; the test fails without the fix.
- Verified, not changed: the wanted-choices result row for a line with several copies. `led_price` is the current price of the first led listing, `received` sums the starting prices; the first auction takes every reaching order, so only it is led and the amount is correct. No wrong figure.
- System tests: `market_orders_test.rb` serves the Uncommon and cancels the Rare; `market_feed_test.rb` serves an Uncommon at 400 (above ten times its minimum, so the feed counts it as notable; an Uncommon at 300 left the feed). The reset-and-clear-cookies pair is one `reset_browser_session` in `ApplicationSystemTestCase`, used by `after_teardown`, `market_order_backed_auction_test.rb` and `market_entrust_test.rb`.
- Cap line: `ArchiveShopHelper#archive_rarity_cap_line(rarity, caps)` is the rarity-keyed reader, `archive_cap_line(card, caps)` calls it; the shop's rarity chips draw it under their label (`market-shop__rarity-cap`), en and fr from the existing `market.archive_cap.*` keys, nothing for a visitor. Tests: chips (language, date, visitor) in `shops_controller_test.rb`; market grid tiles and shop panel in `market_shop_panel_test.rb`; `archive_cap_date` with a nil standing or a nil `next_at`, and a rarity without a standing, in `archive_shop_helper_test.rb`.
- Copy check, "Vos cartes voulues" and the card detail: the panel says "Order" / "ordre d'achat 400 PiCoins. Mettre en vente" and links to the sale page; the card detail says "best order X" / "no buy order". None says sell now or sold to the order, and the sale page offers SELL NOW only for Common and Uncommon (`sale_direct?`). Left as is.
- `converted` readers: one `Game::Market::ConvertedOrders` (`rows`, `owner_ids`, both defaulting to `[]`) read by the three handlers, `PlayerStream` and `MarketPushNotice`; `WantedChoicesApplied.converted_owner_ids` removed. `converted_orders_test.rb` replays a stored `CardListed` and `WantedChoicesApplied` without the key through every handler, the stream and the push reader. A job test lists over two orders and delivers `order_leads` to the leader and `order_beaten` to the beaten owner.
- A converted order whose auction was withdrawn (seller banned: the leader's PiCoins return) or ended cancelled reads outbid: two tests in `order_backed_auction_test.rb`.
- Duplications: `EligibleOrders.best` and `.prices` share `by_edition`; the sales controller's `best_orders` and `order_prices` share `orders_by_ref`. File sizes pass.
- AD-60: the rule bullet now says the cap check comes before the balance check, as `BuyFromArchives` does (one line, for a docs commit of its own).
- Conversion timing, throwaway test, after the leader-first change: 100 orders 0.46 s, 300 orders 1.26 s (about 4.2 ms an order, linear); the earlier 0.63 s and 2.3 s figures stand for 100 and 500.
- Review of the sweep (below) found the server-side prefill `fill_start` unclamped while the script now clamps: patched, `lowest_order_start` raises it to the edition minimum, with a controller test (an order placed under an older minimum). The rest of the whole-epic review's `report` list above stays as written and is in `deferred`.
- Verification after all changes: each of the 25 `test/system/market_*_test.rb` files alone at 2 workers, 0 failures; `market_order_backed_auction_test.rb` five more runs alone, all green; unit run of test/domains, controllers, models, helpers, jobs: 6137 runs, 0 failures; vitest 1613 passed; format, CSS, planning-id, file-size, packwerk, zeitwerk and rubocop clean. `bin/ci` and the full unit suite are left to the caller.

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Whole-epic review (before any change)
- verdicts: see the routed list under Implementation Notes (blind 14, edge case 7 plus 3 claims, verification gap 3 plus 2 other, intent alignment descriptive); fixed or tested: slot `:empty`, two rarity sources, in-progress sort, prefill clamp, leader-first bid rows, the `now` read, push, market-screen cap and converted-order standing tests; reported: the `report` list.

### 2026-11-24 - Review pass on the sweep
- verdicts: 18 findings across four lenses - high 0, medium 0, low 4, false 7, maybe-false 0, rejected-low 7
- findings:
  - `[low]` `patch` (verification gap, edge, blind) server `fill_start` prefills the lowest order's price unclamped while the script clamps - patched: `lowest_order_start` raises it to the edition minimum; controller test with an order placed under an older minimum.
  - `[low]` `patch` (blind) `ConvertedOrders` has no positive-path test - added: a `CardListed` with a converted row reads back rows and owner ids.
  - `[false]` `reject` (edge) `now` read after the locks does not cover a wait inside `lock_reaching_orders` - the claim is narrower than stated: the read moved to where `ListCard` reads it (after the bank and holding locks); a wait on the order locks stays in both operations, a deferred race of seconds against an order's expiry, recorded.
  - `[false]` `reject` (edge) a prefill at the minimum reaches no order, silently - the opening line says which orders stay open (the epic's own rule), nothing is silent.
  - `[false]` `reject` (edge) `converted: nil` raises - the events write an array through `with`; no stored event has a null.
  - `[false]` `reject` (edge) `caps: nil` raises - the one caller passes `@caps`, `{}` for a visitor.
  - `[false]` `reject` (edge, blind) `expires_at` or `ends_at` nil breaks the sort - both columns are `null: false`.
  - `[false]` `reject` (blind) `lowestOrder` can return NaN without a `minimum` - `Edition.minimum` is a required number of the type.
  - `[false]` `reject` (blind) the cap line inside the chip label breaks system tests - every `market_*` and shop system file passed with it.
  - `[low]` `reject` (blind) the helper test covers only fallbacks - the standing's present case is covered by the controller tests of the chip and tiles.
  - `[low]` `reject` (blind) the push job test names two devices but registers one - it asserts the two titles delivered; a device per owner adds no coverage of the code.
  - `[low]` `reject` (blind) `ConvertedOrders` lives under `events/` - it is the reader of two events' payload, beside them, like `WantedChoicesApplied.player_ids`.
  - `[low]` `reject` (blind) the stream test pins exact notice hashes, the controller test may pass for the wrong reason, `with_index` has no comment, one-line blocks over 150 characters - style and test-shape remarks without a defect.
  - `[low]` `reject` (blind) `CAPPED_RARITIES` depends on the element type of `DirectSale::RARITIES` - settings tests pin it to `rare epic legendary`.
  - `[low]` `reject` (intent) items 3, 4, 5 and 6 are exercised at response or unit level rather than in a browser - the flake is proved by repeated system runs; the chips, tiles and panel by `assert_select` on the rendered response, as the neighbouring cap tests do.
  - `[low]` `reject` (intent) item 6 has no diff - the check found no direct-sale wording; recorded in the notes.
  - `[low]` `reject` (intent) `by_edition` and `orders_by_ref` are plumbing, not rarity checks - the ticket names duplications and leftovers in general.


## Design Notes

Working rules for the implementer: work only in the git worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-a6cdef6360fcb917c` (branch `build/48-5`, baseline above), use `/usr/bin/git` if a git command is refused, never commit, push, merge, stash or `git add` (the caller commits), never edit `package-lock.json`, `_bmad/custom/config.user.toml` or anything under `_bmad-output` but this plan's Implementation Notes, and never run `bin/rails test:system` as a whole: one system file per command, 2 workers. Do not run `bin/ci` or the unit suite (the caller does); run only the unit and system files covering what you edit, plus `npm run test:js` for script changes. The baseline: the unit suite had 6764 runs, 0 failures, and vitest 1611 passed. Append what you did, every finding you verified and rejected, and the figures to Implementation Notes. The conversion timing (throwaway test, not committed) is already measured: 100 orders 0.63 s, 500 orders 2.3 s, linear (about 10 queries an order: 2 player reads, a wallet read and update, a notice delete, an order update, a bid insert, a ledger insert).

The cap line of a chip needs a rarity-keyed reader in `ArchiveShopHelper`; `archive_cap_line(card, caps)` should call it with `card.rarity` so tile and chip share one source and one wording.

## Verification

**Commands:**
- Environment for every test command: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w485 CHROME_BIN=/usr/bin/chromium PARALLEL_WORKERS=4` (`PARALLEL_WORKERS=2` for system tests).
- `bin/rails test` -- expected: pass (the unit suite in full is fine; not while `bin/ci` runs on the same database)
- Each `test/system/market_*_test.rb`, one file per command -- expected: pass; never `bin/rails test:system`
- `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bin/ci` -- expected: pass
