---
title: 'Market rarity deferred fixes'
type: 'bugfix'
ticket: ''
created: '2026-11-24'
status: 'built'
baseline_revision: 'e7b85ad767f9768959fb7fe2a9c23f825157d668'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The seven-day window of MES ORDRES for a converted order whose auction ended has no test (the condition is unchanged, only its join moved to the order's listing).
    evidence: |-
      Verification-gap lens: no test travels past seven days for a converted bid order; pre-existing logic.
    location: >-
      app/domains/game/app/queries/game/market/player_orders.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The market-splits-by-rarity epic left six deferred correctness defects (listed in `epic-market-splits-by-rarity/story-refactor-sweep-plan.md`, `deferred` and triage log): an order that expires during the conversion's lock wait is still converted; two sellers with orders on each other's cards can deadlock; MES ORDRES finds a converted order's auction only through a deletable notice; two unreleased migrations leave the table without its unique end-notice index; the cap date renders in server time and the sale form's opening line re-announces at every keystroke; buying one capped copy leaves the other tiles of that rarity on the old cap line.

**Approach:** Fix each at its cause with the smallest change and a test, adding no rule beyond what each fix says. Six fixes, one `fix(market): ...` commit each (or per coherent pair), the AD-44 text in its own `docs(market): ...` commit.

## Boundaries & Constraints

**Always:** Follow AGENTS.md. Operations write; controllers never write a model. No planning ids in code, tests, config or migrations; no comments but one-line external constraints; every string in en.yml and fr.yml; repo text in English; no database id in a URL, HTML or JSON; files under 400 lines (Ruby, TS). Strong-migrations style: expand/contract, concurrent index in its own migration, FK added NOT VALID then validated in a second migration. Regenerate `db/schema.rb` from the migrations on Postgres 18 exactly as AGENTS.md says, never hand-edit it.

**Never:** Touch the copy marked "to approve" in EXPERIENCE.md (French cap line wording, feminine chips). Decide several copies of one edition in one Confier wanted line. Fix anything else. Push, merge, stash, `git add` a directory or `-A`, commit `config/*.key`, `package-lock.json` changes or `_bmad/custom/config.user.toml`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|----------|--------------|----------|----------------|
| Order expires in the lock wait | `ListCard` / `ApplyWantedChoices` pre-read sees an order open; its `expires_at` passes before the locked recheck | Not converted: stays `open` for the expiry job, no bid, no ledger entry | none |
| Order ends or changes in the wait | Candidate cancelled/served/removed owner between pre-read and locks | Left out; the others convert | none |
| New order appears in the wait | A reaching order placed after the pre-read | Not converted, stays open | none |
| Crossed sellers | A (holds X, order on Y) lists X while B (holds Y, order on X) lists Y, concurrently | Both succeed, neither `market_busy`; locks taken in ascending player id in one set | none |
| Notices deleted | A converted order's `order_leads`/`order_beaten` notice deleted | Row still reads EN ENCHERE / GAGNEE / DEPASSEE with its listing link | none |
| Cap date in a viewer zone | `time_zone` cookie `Pacific/Auckland`, cap reached | `<time datetime=UTC ISO>` whose text is the cap instant in that zone; UTC text with no cookie | none |
| Typing in the sale start field | Several input events within 500 ms | The polite status region posts once, 500 ms after the last, only if its text changed | none |
| Purchase leaves tiles stale | Buy one copy of a rarity with cap N | Remaining tiles/chips/order-form offers of that rarity read the new cap; once none is left, their confirmation draws no form | none |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/market/order_conversion.rb` -- `convert_orders(listing, settings, now)` and `lock_reaching_orders`: `now` is read by callers before the order-row wait; owner bank locks are taken after the seller's, outside one sorted set. Recheck with `EligibleOrders.call(card_season_id, except:, now:)` (`app/domains/game/app/queries/game/market/eligible_orders.rb`).
- `app/domains/game/app/operations/game/market/list_card.rb` -- `lock_bank(player)` first, `now` read before `convert_orders`. `app/domains/game/app/operations/game/market/apply_wanted_choices.rb` -- already takes `TradeLocks.players(player.id, *drawn_owners)` before `lock_bank`, then `now`, then `open_auctions` -> `convert_orders` per copy; `Game::TradeLocks.players` (`app/domains/game/app/models/game/trade_locks.rb`) sorts and acquires `BankLock`; `Operation#lock_bank` also checks the player is not deleted (re-acquiring is harmless).
- `test/domains/game/market/order_backed_auction_test.rb` -- existing conversion tests (stubbing `Game::TradeLocks.players` via `stub_singleton` fires between the read and the locks: "an order ended between the read and the locks is left out"); `test/domains/game/market/apply_wanted_choices_test.rb`; `test/support/lock_races.rb` (`first_holding_the_lock`, `together`, `purge_market_race`: must also clear orders' `listing_id` / delete orders once fix 3 adds the FK), `test/support/market_orders.rb` (`order!(…, expires_at:)`).
- `app/domains/game/app/queries/game/market/player_orders.rb` -- `auctions_of` and `shown` read the auction from `order_leads`/`order_beaten` notices. Neither bid rows (`game_market_bids`: listing, player, no order) nor ledger entries (leader's `hold` carries listing_id but no order_id, beaten owners' `release` only order_id) identify the listing of an order: add a nullable `listing_id` on `game_market_orders`, set in `convert_orders` for the leader and the beaten alike; `Order` (`app/domains/game/app/models/game/market/order.rb`) gets `belongs_to :listing, optional: true`. Tests in `order_backed_auction_test.rb` ("a beaten order reads outbid with the auction linked", "the order reads in the auction while it leads, and won").
- `db/migrate/20261124110004_remove_order_end_index_from_game_market_notices.rb`, `…110005_add_order_end_index_covering_conversion_to_game_market_notices.rb`, `…110006_add_player_time_index_to_game_market_archive_withdrawals.rb` -- unreleased; index `index_game_market_notices_order_end` (unique `player_id, order_id`). The widened predicate is `(kind)::text = ANY (ARRAY[('order_served'::character varying)::text, ('order_expired'::character varying)::text, ('order_leads'::character varying)::text, ('order_beaten'::character varying)::text])`. Precedents for FK NOT VALID/validate: `20261123190000_add_order_to_game_market_notices.rb` + `…190001_validate_…`, index: `…100002_add_order_index_to_game_market_notices.rb`. `test/domains/game/market/order_conversion_contract_test.rb` pins the index behaviour; `bin/ci` runs the schema round-trip.
- `app/helpers/archive_shop_helper.rb` (`archive_cap_date`, `archive_rarity_cap_line`, `archive_cap_line`, `archive_offer_label`), `app/helpers/local_time_helper.rb` (`local_time_tag`, `local_time_text`, `local_time_sentence`: the `<time data-controller=local-time>` + `time_zone` cookie handling a listing's end time uses, `app/views/market/listings/_figures.html.erb:21`), `app/frontend/lib/local_time.ts`, `app/controllers/market/archive_purchases_controller.rb:67` (refusal text uses `archive_cap_date`), views `app/views/market/shops/_offer.html.erb`, `_filters.html.erb`, `app/views/market/orders/_available.html.erb`; tests `test/helpers/archive_shop_helper_test.rb`, `test/helpers/local_time_helper_test.rb`, `test/controllers/market/shops_controller_test.rb`, `market_shop_panel_test.rb`, `orders_controller_test.rb`, `archive_purchases_controller_test.rb`, `test/system/market_shop_cap_test.rb` (assert date text built with `day_month`: update).
- `app/views/market/sales/_fields.html.erb:30` (`.sale-opening aria-live=polite` holding `openingLine`/`leftLine`), `app/frontend/controllers/listing_fields_controller.ts` (`render` rewrites both lines at every typed event), `app/frontend/lib/annonce.ts` `LIVE_DELAY = 500`, precedent `app/frontend/controllers/order_form_controller.ts` (visible sentence `aria-hidden`, separate `role=status` region posted after `LIVE_DELAY`, `writeText` skips unchanged text; its vitest is `order_form_controller.test.ts`), tests `listing_form_controller.test.ts` (mounts `listing-fields`) and `test/controllers/market/sales_controller_test.rb:642`, system `market_order_backed_auction_test.rb:43`. The order form's own sentence is already debounced and deduplicated: the defect is the sale form's opening/left lines.
- `app/views/market/archive_purchases/create.turbo_stream.erb` -- replaces the bought tile by id, or `remove_all archive_offer_selector(@card)` when sold out (selector `[data-archive-offer='key']` reaches every screen). Surfaces draw the cap line: `market/shops/_offer` (shop grid `tile_id`, market grid `markets/_tiles`, panel `markets/_shop_panel`), `market/orders/_available` (`.archive-offer__cap`), the shop chips (`.market-shop__rarity-cap`). Tile `aria-label` embeds the cap line through `archive_offer_label`.

## Tasks & Acceptance

**Execution:**
- [x] Fix 1+2 (one commit): `order_conversion.rb`, `list_card.rb`, `apply_wanted_choices.rb` -- read the eligible reaching orders unlocked first (ids and owner ids, for the listing's edition, starting price and seller; for each auction line in `ApplyWantedChoices`, skipping lines whose price does not parse), take `TradeLocks.players(seller, *drawn owners, *candidate owners)` as one ascending set, then `lock_bank` check, holdings, then lock the candidate order rows ascending id, read `now = Time.current` once after those locks and recheck `EligibleOrders.call(..., now:)` restricted to the candidate ids and the starting price; convert only those; a candidate not eligible any more or a new order is left open. `convert_orders` no longer takes `now` from the caller (read it after the order locks). Tests in `order_backed_auction_test.rb` / `apply_wanted_choices_test.rb`: expiry between read and recheck (advance time inside a `Game::TradeLocks.players` stub or the order lock) leaves the order `open`, no bid, no entry, for `ListCard` and `ApplyWantedChoices`; a candidate ended/changed is left out (the existing test keeps passing); an order placed after the read is not converted; two crossed sellers racing (`LockRaces`, a hook after each thread's first lock so the old code deadlocks) both succeed with no `market_busy` and both auctions open, committed rows purged.
- [x] AD-44 (own commit `docs(market): ...`): `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` "Conversion of orders" bullet (line ~566) -- say the owners' bank locks are taken with the seller's in one ascending set, before the holdings and the order rows, from a first unlocked read, and that `now` is read after the order locks and a candidate no longer eligible is left out. Only that bullet.
- [x] Fix 3: three expand migrations (add nullable `listing_id` bigint on `game_market_orders` plus `add_foreign_key ... validate: false`; validate it in the next; `add_index` concurrently in its own with `disable_ddl_transaction!`), `Order` association, `convert_orders` sets `listing_id` on every converted order, `PlayerOrders.shown` and `auctions_of` read the listing from `orders.listing_id` instead of the notices (drop the `BID_KINDS` notice dependency; keep the row shape and standing logic), `lock_races.rb` purge clears the orders' listing. Test: for a leading, a beaten and a won order, delete every `order_leads`/`order_beaten` notice then `PlayerOrders` still gives EN ENCHERE (`bid` in progress with `listing_token`), DEPASSEE (`outbid`) and GAGNEE (`won`) with the link; add a system or controller assertion that MES ORDRES still shows the link row after the notice is deleted if cheap.
- [x] Fix 4: rewrite `…110004` to add the widened unique index concurrently under a temporary name, `…110005` to remove the old `index_game_market_notices_order_end` concurrently, add a new `…110006` that `rename_index`es the temporary one to `index_game_market_notices_order_end`, and renumber the withdrawals index migration after them (`…110007`, same class and content); fix 3's migrations take versions after it (`…110008` to `…110010`); do fix 4 before fix 3 so each commit's schema is consistent (commit order: 1+2, AD-44, 4, 3, 5, 6). Never leave the table without a unique end-notice index. Regenerate `db/schema.rb` on Postgres 18 per AGENTS.md; `order_conversion_contract_test.rb` still passes; `bin/ci` round-trip passes.
- [x] Fix 5: `archive_shop_helper.rb`, `_offer.html.erb`, `_available.html.erb`, `_filters.html.erb`, `archive_purchases_controller.rb` -- the cap date is the next-purchase instant drawn with `local_time_sentence`/`local_time_tag` (datetime style) in the cap line HTML, and `local_time_text` for plain text (the tile's aria text, the refusal message), no new locale string; update every test asserting the old `day_month` date and test with a non-UTC `time_zone` cookie (helper test and one controller test). `listing_fields_controller.ts` + `_fields.html.erb` -- the visible opening/left lines are not live; a visually hidden `role=status aria-live=polite` region gets their joined text after `LIVE_DELAY` ms without typing and only when it changed (timer cleared on each render and on disconnect); vitest in `listing_form_controller.test.ts` or a new test with fake timers (several events: one post after 500 ms; unchanged text: no new post), adjust server markup tests.
- [x] Fix 6: `create.turbo_stream.erb`, the cap line elements, `archive_offer_label` -- mark each cap line element with the rarity (`data-archive-cap`) on every surface; after a purchase stream `update_all` of `[data-archive-cap='<rarity>']` with the new cap line (the selector mechanism `remove_all` already uses); the tile's label must not keep a stale cap: move the cap out of `aria-label` into a visually hidden element the link points to with `aria-describedby` (unique id per render) updated by the same stream. Tests: stream assertion in `archive_purchases_controller_test.rb`; a system test in `market_shop_cap_test.rb` (two editions of one capped rarity, buy one, the other tile's cap line changes without reload and its dialog draws no form once none is left).
- [x] Run the checks below; commit per fix with exact files; the plan file with the last code commit.

**Acceptance Criteria:**
- Given the Matrix rows, when each runs, then the stated outcome holds in the named tests.
- Given `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, the format, CSS, planning-id and size checks, and the system files listed below each run alone at 2 workers, then all pass.

## Auto Run Result

- Summary: six fixes in six commits (and the AD-44 docs commit): conversion reads candidates unlocked, locks the seller and every candidate owner in one ascending set, and reads `now` after the order locks; the AD-44 bullet; the end-notice index is widened under a temporary name before the old one drops; a converted order carries its listing; the cap date is a local `<time>`, the sale form's opening lines post to a polite region after 500 ms; a purchase rewrites the cap line of every tile, chip and order-form offer of its rarity.
- Review: thorough, four lenses. Patched: 2 medium, 5 low. Deferred: 1. Others rejected with reasons in the triage log.
- Follow-up review recommended: true. Unverified risk: the Confier table's lock order has a race test that passes without proving the ascending order (it also passes with the owner locks removed); the ListCard race test fails on the old code.
- Verification: see the final report of the build.
- Residual risks: development databases that ran the old migration versions need a reset; no backfill of `orders.listing_id`.

## Implementation Notes

Route full: six independent fixes across operations, migrations, views, script and tests, far over 100 lines. Fix 5 targets the sale form's opening/left lines, not the order form: the order form's sentence already waits `LIVE_DELAY` and `writeText` skips unchanged text (the deferred item itself names `listing-fields`). The unconverted new order of the matrix gets no "listed above" notice (its price reaches the start; `orders_below` lists only orders under it): left as the code does.

Built as planned, with these decisions:
- Candidates are read before the transaction (`reaching_candidates`, in `OrderConversion`), the seller and owners' bank locks go through `TradeLocks.players` as one set, then `lock_bank`. `convert_orders(listing, settings, candidate_ids)` locks the candidate rows ascending, reads `now` once, and rechecks with `EligibleOrders.call(...)` restricted to the candidate ids and the starting price. `ApplyWantedChoices` reads candidates per auction line (a price that does not parse gives none).
- The crossed-sellers race test pauses each thread after its first `BankLock.acquire`; it fails on the old code (one seller gets `market_busy`). `purge_market_race` now takes one listing or a list, and clears `listing_id` on orders before deleting listings.
- Fix 4: the migrations are `…110004` (add the widened index as `index_game_market_notices_order_end_widened`), `…110005` (remove the old one), `…110006` (rename), `…110007` (withdrawals index, renumbered). Their files were renamed to match their classes. `db/schema.rb` differs from before only by the version.
- Fix 3: orders carry a nullable `listing_id` (migrations `…110008` to `…110010`); no backfill, as the conversion is unreleased. The notices still serve the bell; `PlayerOrders` no longer reads them.
- Fix 5: the cap line draws its date with `local_time_sentence` (datetime style); the refusal uses `local_time_text`. A flex `.archive-offer__cap` split the text and the `<time>` apart, so the cap line is `display: block` in `market-shop.css`. The system test emulates the browser zone (`Europe/Paris`) through CDP so the tile and the refusal read the same zone.
- Fix 6: the tile's `aria-label` no longer holds the cap; a visually hidden span (`id` unique per render, `data-archive-cap`) is its `aria-describedby`. `archive_rarity_cap_text` of fix 5 was dropped once nothing read it. The stream sends no `update_all` for a rarity without a cap.

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Review pass
- verdicts: 24 findings across four lenses - high 0, medium 2, low 5, false 10, maybe-false 0, rejected-low 7
- findings:
  - `[medium]` `patch` (verification gap) no test races the Confier table's lock set - added `order_conversion_race_test.rb` case for two sellers listing through `ApplyWantedChoices` (passes; it proves no deadlock, not the ascending order: it also passes with the owner locks removed, since nothing then locks across threads).
  - `[medium]` `patch` (blind) the shop cap system test builds the expected date from `1.hour.ago` at assertion time, a minute-boundary flake now the text carries the minute - the expectation uses the stored withdrawal's `created_at`.
  - `[low]` `patch` (blind) the system test leaves the CDP time zone override set - reset in a teardown.
  - `[low]` `patch` (blind) the live-region vitest hardcodes 200 and 300 ms - uses `LIVE_DELAY`.
  - `[low]` `patch` (blind) the stream test matches text that a plain-string escape would also match - asserts a `time[data-controller=local-time]` in the streamed template.
  - `[low]` `patch` (verification gap) the order form's `data-archive-cap` marker is not asserted - added to the existing orders controller test.
  - `[low]` `patch` (edge) `ApplyWantedChoices` also locked the holdings of every candidate owner - holdings stay locked for the drawn owners only.
  - `[low]` `defer` (verification gap) the seven-day window of MES ORDRES has no test - pre-existing condition, see `deferred`.
  - `[false]` `reject` (blind, edge) renumbered migrations break a database that ran the old versions - the intent states they are unreleased and only CI ran them (`git tag --contains` the first epic commit is empty); such a development database is reset.
  - `[false]` `reject` (blind, intent, gap) no backfill of `listing_id` - same reason: no converted order exists outside CI.
  - `[false]` `reject` (blind) the foreign key breaks listing deletion - no production path deletes a listing (grep of app and lib); only the race-test purge does, and it clears the orders first.
  - `[false]` `reject` (edge) a refused listing or Confier submission still takes the candidate owners' bank locks - the intent orders it so (read unlocked, then lock the seller and every candidate together); the transaction is short and ends on the refusal.
  - `[low]` `reject` (blind) random id in `_offer.html.erb` - uniqueness per rendering is the point (the same edition can sit in the panel and the grid); nothing caches or compares the markup.
  - `[low]` `reject` (blind) server-rendered opening lines hidden from assistive tech until typing - the product rule says the region is empty at load and the order form does the same.
  - `[low]` `reject` (blind) the race test's pause, global patch, `Thread.current` flag and the uncommon edition purge - the pause forces the interleaving the old code deadlocked on; the flag is per thread and the threads are new each run; no edition price is written for the uncommon.
  - `[low]` `reject` (blind) the cap line helper repeats `reached?` - the outer branch avoids the `<time>` wrapper, the inner picks the left or reached sentence.
  - `[low]` `reject` (blind) the `display: block` rule is unexplained - the flex line split the text from the `<time>`; the test of the shop passes with it.
  - `[low]` `reject` (edge) `day_month` locale keys lost their reader - date format keys of the locale files, harmless and used by the framework's date formats.
  - `[low]` `reject` (blind) nothing says the date format change is intended - the intent asks for the viewer's time zone through the app's time rendering, which writes a date and a time.
  - `[false]` `reject` (verification gap) the first `chosen` render in the vitest runs before the fake timers - its timer is a harmless real one, the assertion counts later posts.
  - `[false]` `reject` (intent) the accessible name of the tile moved to a description, and the order form is not exercised in a browser - the cap line is described through `aria-describedby`; the stream and the markup are asserted, the offer markup is shared.
  - `[false]` `reject` (intent) the late order gets no listed-above notice - an order at or above the start is not "below" it and the handler writes the wanted notice; unchanged rule.
  - `[false]` `reject` (intent) the withdrawals index renumbered, the date wording changed - requested by the intent.

## Design Notes

Working rules for the implementer: work only in the worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-ad4ef4b151dae62ea`, branch `fix/market-rarity-deferred` (baseline above). Use `/usr/bin/git`, one plain command at a time (no compound git commands). Commit per fix with exact files staged (`git add <file>...`, never a directory or `-A`), message `fix(market): ...` (or `docs(market): ...` for AD-44 only), each ending with the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; never push or merge. Never commit `package-lock.json`, `_bmad/custom/config.user.toml`, `_bmad-output` but the AD-44 bullet (own commit) and, last, this plan. Do not edit the `<intent-contract>`. Environment for tests: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w486 CHROME_BIN=/usr/bin/chromium PARALLEL_WORKERS=4` (`PARALLEL_WORKERS=2` for system tests); Postgres runs on 5433. Never run the whole system suite; run the unit files covering what you edit, and the system files one at a time. Do not run `bin/ci` or the whole unit suite (the caller does). Append decisions and surprises to Implementation Notes.

Fix 6 label design: the cap line is the same for every tile of a rarity, so one `update_all` by `[data-archive-cap='rare']` refreshes every visible copy (tile facts, hidden description, order-form offer, shop chip); the full tile never needs re-rendering and no list of the page's tiles is needed.

## Verification

**Commands:**
- Unit files touched, with the environment above -- expected: pass.
- System files, one at a time with `PARALLEL_WORKERS=2`: `market_order_backed_auction`, `market_wanted_table_rarity`, `market_orders`, `market_shop`, `market_shop_cap`, `market_archive_offers`, `market_confier_wanted`, `market_direct_sale` (`test/system/<name>_test.rb`), plus any system file a change touches -- expected: pass.
- `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bin/ci` -- expected: pass.
