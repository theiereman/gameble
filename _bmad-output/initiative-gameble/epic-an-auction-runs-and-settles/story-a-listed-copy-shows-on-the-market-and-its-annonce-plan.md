---
title: 'A listed copy shows on the market and its Annonce'
type: 'feature'
ticket: '39.1'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '5d682a406943ae1e57fc601b31d6b9082883e929'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/story-the-balance-shows-available-and-committed-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** PiCoins can be minted but nothing can be sold: no listing exists, the market address still shows the teaser after the first opening, and no screen shows a copy for sale. The ledger's `listing_id` points at nothing and nothing stops a second settlement of one listing. Epic requirements R1, R2, R4, R13, R14, R15, R17, R22 (the listing half).

**Approach:** A tracer through every layer: the `game_market_listings` table and the ledger's listing foreign key and settlement index (expand migrations), `Game::Market::ListCard` (stamp, reservation, `CardListed`), the pure `AuctionMath.commission`, two queries (open listings, one listing by token), then the web: the market screen in place of the teaser once a first opening is recorded, the listing tile, a read-only Annonce by token, the shared `PlayerNameComponent` and a development seed.

## Boundaries & Constraints

**Always:** `ListCard` is the only writer of a listing, under the seller's bank lock, then the holding lock, then one `Ledger.post` of the `stamp`, in that order (AD-10, AD-44), and publishes one `CardListed` inside its transaction; the settings version in force is read from the database and its token compared to the one the form drew (AD-42), the listing stores that version; every refusal is a `Failure(:code)` with an `errors.game.<code>` key in both `en.yml` and `fr.yml`, added by hand; `market_busy` answers `ActiveRecord::Deadlocked`; a card-season with no rarity can be neither listed nor stamped; reads go through queries on the reading role and a GET never writes; no database id in a URL, the HTML, a DOM id or a stream name (the Annonce is `/market/listings/:token`, a card is its slug, a player their token); every amount goes through `PicoinAmountComponent` (compact on tiles, exact on the Annonce); every Pundit action has a policy; server HTML carries no `style` attribute, no script builds markup; all repo text in English, French only in `fr.yml`; no planning id in code, tests, config or migrations; the ledger stays written only by `Ledger`; migrations are expand/contract (concurrent indexes each in their own migration, the foreign key added not valid then validated in a second one); `db/schema.rb` is never hand-edited or committed in this run.

**Never:** bidding, history, outcomes, "Clôture en cours…", live refresh, the My maximum form, Mettre en vente, MES ENCHÈRES, MES VENTES, the suspended banner on the market screen, the average price row, sort or filter by average price, search, FILTRES, the Bourse link and the bell and notice lines (stories 2 to 12, epics 40 and 41); a listing created anywhere but `ListCard`; a controller, job or component that writes a model; a second PiCoin amount component or a markup-building script; a React island; a planning id in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List a copy | Open market, current settings token, a free copy of a card-season with a rarity, start and optional buy-now at or above the rarity minimum, buy-now above start, one of the version's three durations, `available` at least the stamp | One `open` listing (token, seller, card-season, settings version, start, buy-now, duration, `ends_at` = now + duration, `current_price` = start, no leader); one `stamp` entry of that listing (`available_delta` = -stamp); `reserved` + 1; one `CardListed` | `Success(listing)` |
| Market closed or never opened | No settings, or `open` false | Nothing written | `Failure(:market_closed)` |
| Form is stale | Token is not the current version's | Nothing charged or reserved | `Failure(:amounts_changed)` |
| No rarity | Card-season rarity is null | Nothing written | `Failure(:no_rarity)` |
| Copy not free | No holding, or `quantity - reserved` is 0 (including a copy already listed, traded or promised in a trade) | Nothing written | `Failure(:copy_not_free)` |
| Price rules | Start under the rarity minimum / buy-now under it / buy-now not above start / a non-integer or non-positive amount | Nothing written | `Failure(:start_below_minimum)` / `:buy_now_below_minimum` / `:buy_now_not_above_start` / `:invalid_price` |
| Amount out of range | A start or buy-now above the bigint maximum (9_223_372_036_854_775_807), e.g. 99999999999999999999 | Nothing written, no `ActiveRecord::RangeError` | `Failure(:invalid_price)` |
| Duration | Not one of the version's three | Nothing written | `Failure(:invalid_duration)` |
| Stamp too high | `available` below the rarity's stamp | Nothing written | `Failure(:stamp_not_covered)` |
| Deadlock | `ActiveRecord::Deadlocked` | Transaction rolled back | `Failure(:market_busy)` |
| Reserved copy elsewhere | After a listing, a trade offer or an entrustment of the same copy | Refused by `quantity - reserved` | Existing `:not_enough_copies` |
| Second settlement | Insert of a second `sale` (or `stamp`, `purchase`, `commission`) entry for the same listing and player | Database refuses | `ActiveRecord::RecordNotUnique` |
| Teaser until opened | `first_opened_at` empty | `GET /market` renders the teaser, unchanged | — |
| Market screen | First opening recorded (open or suspended) | Open listings as tiles, ending soonest first; four sorts; "Charger plus"; empty line when none | — |
| Visitor | Signed out | Reads the market and any Annonce; CONFIER DES CARTES greyed; no Balance chip | — |
| Annonce | Known token | Card, seller by `PlayerNameComponent`, PRIX ACTUEL, FIN DANS per minute with the end time, buy-now when set; h1 focused; "◀ MARCHÉ" way back | — |
| Unknown token | No such listing | 404 | `ActiveRecord::RecordNotFound` |
| Player names | Visible profile / private or friends-only for this viewer / banned or deleted | Linked name / bare name / anonymous key, no link | — |

**Decisions (settled without a checkpoint, from the spec, architecture and UX):**
- The `commission` argument is the settings' `commission_basis_points`, not a whole percent: `AuctionMath.commission(price, basis_points)` is `price * basis_points / 10_000` floored, the same integer floor as AD-41's `price * percent / 100` for a whole percent and exact for 2.5 %; the settings table stores basis points and story 2's settlement passes `settings.commission_basis_points`.
- A listing page is addressed `/:locale/market/listings/:token` (route name `market_listing`), a sibling of `market/entrust`; any status shows the same read-only facts, outcomes being story 6's.
- "n offres" comes from `Game::Market::OfferCounts.call(listing_ids)`, a hash defaulting to 0 and reading no table yet; story 4 makes it count the public validated bids, so tiles and their accessible text never change shape.
- The four sorts are `ending` (default, "se termine bientôt"), `price_asc`, `price_desc`, `newest`, each tie-broken by listing id; an unknown value falls back to `ending`. "Charger plus" is offset paging (`page`, 24 tiles per page, capped like the collection grid) answered as a Turbo Stream appending tiles, as the feed's older pages are; a page is a snapshot, so a tile may repeat across pages when listings change between loads and nothing else is guaranteed ("refreshes on arrival, not live").
- The Copy deck's "Vendue par <name>" reads as past tense on a running auction: the seller fact is a labeled row "Vendeur" / "Seller" holding the name; "En tête : <name>" renders only when a leader exists, so never before story 4.
- The end time beside FIN DANS uses the existing local-time `datetime` style (`10 nov., 22h14`): a relative "aujourd'hui à" would need a second wording on the server and in the browser for the same fact; the French clock keeps the app's existing `22h14` form.
- The countdown needs its own controller: the existing `countdown_controller` is the capsule clock (HH:MM:SS, gauge segments, a refresh at zero). `listing_clock_controller.ts` counts down from `seconds` rendered by the server (as the capsule clock does, so a skewed device clock cannot move it), re-rendering only when the minute label changes; at or under zero it keeps "moins d'une minute" (the closing state is story 6's). Its words are the server's: the same three locale keys feed the tile and, as data values, the controller.
- Time-left wording: 1 h or more "2 h 14" (minutes padded), under an hour "18 min", under a minute "moins d'une minute" / "under a minute"; the tile and the Annonce use the alert colour (a modifier class) when under an hour.
- The suspended banner on the market screen, the greyed actions behind it and "Connectez-vous pour enchérir" are stories 7 and 11's; here a suspended market simply keeps showing the open listings and the CONFIER link, which leads to Confier's own banner. METTRE EN VENTE, MES ENCHÈRES and MES VENTES chips are stories 5, 9 and 10's, so the chip row holds ANNONCES and the actions that exist.
- The rate limit on listing is the throttle of story 5's POST (the only caller from the web); `ListCard` has no web caller in this story.
- The existing `errors.game.market_closed` text says "Nothing was entrusted" and is shared with listing: both locales get a neutral sentence ("The market is closed for now." / "Le marché est suspendu pour le moment."), and the entrust controller test asserting the old text is updated.
- The pioneer row moves to `PlayerNameComponent` (R17, epic note): a visible pioneer is linked, a private or friends-only one shows as a bare name, a banned or deleted one as the anonymous key; `Game::Visibility.visible?` is asked with its default (staff see all), as AD-49 words it. The Chattomètre stays as built.
- Amounts are refused above the bigint maximum: the normalise step answers `Failure(:invalid_price)` for a start or buy-now that is not an integer in `1..9_223_372_036_854_775_807`, before any minimum check, so no oversized amount reaches an insert (`starting_price`, `buy_now_price`, `current_price` and the wallet are bigint) and no `ActiveRecord::RangeError` can surface as a 500.
- The development seed code goes after the existing development opening block of `db/seeds.rb` (which already opens the market when no first opening exists; this story does not reopen it). It lists a few copies through `ListCard` for fake development players, only in development and idempotently (nothing is listed twice). Fake players have no wallet, and `ListCard` reads a missing wallet row as `available` 0, so such a seller gets `Failure(:stamp_not_covered)` rather than a nil error; the seed therefore funds each chosen seller first through an existing writer, `EntrustCards` on a spare copy (`Mint` is only called by `EntrustCards`), reads the stamp and the minimum price from the current settings (`CurrentSettings`, `stamp(rarity)`, `minimum_price(rarity)`) instead of hard-coding them, and skips a seller whose `available` still cannot cover the stamp, never calling `.value!` on a refusal.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/ledger.rb`, `ledger_entry.rb` -- `Ledger.post(Entry.new(player_id:, kind:, available_delta:, listing_id:, settings_id:))` is the only writer; `KINDS` already holds `stamp`, `purchase`, `sale`, `commission`; `listing_id` has no foreign key yet.
- `app/domains/game/app/operations/game/market/entrust_cards.rb` -- the model: `Operation`, `step require_player`, `transaction do ... lock_bank ... TradeLocks.holdings ...`, `publish(event, stream_name:)`, `rescue ActiveRecord::Deadlocked`, `current_settings(token)` returning `market_closed` / `amounts_changed`, `enough_copies` on `quantity - reserved`; `private` steps, `Failure(:code)` strings in `errors.game`.
- `app/domains/game/app/operations/game/operation.rb`, `lib/application_operation.rb` -- `call` must take `player:`; `failure_message(code)` reads `errors.game.<code>`.
- `app/domains/game/app/models/game/market/settings.rb`, `market_state.rb`, `queries/game/market/current_settings.rb`, `balance.rb` -- `minimum_price(rarity)`, `stamp(rarity)`, durations `duration_short_hours`..`duration_long_hours`, `token`; `MarketState.call.first_opened?`; wallet `available` read by `Balance`.
- `app/domains/game/app/models/game/trade_locks.rb`, `models/game/bank_lock.rb`, `holding.rb` -- bank lock then `TradeLocks.holdings(player_id, ids)` (ordered `lock`); `reserved` is raised by one here.
- `app/domains/catalog/app/queries/catalog/card_views.rb`, `card_view.rb` -- `CardViews.call(card_season_ids, locale:)` keyed by card-season id, `CardView` has `id` (slug), `title`, `rarity`, `season_number`, `image_url`; Game may call Catalog.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- `ref` is `"slug:season"`, `resolve(refs)` gives card-season ids: how a web caller names a copy without a database id.
- `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb`, `app/helpers/balance_chip_helper.rb`, `app/views/shell/_balance_chip.html.erb` -- `BALANCE_EVENTS`, `balance_notice(player_id)`, the chip redraw; `render "shell/balance_chip", placement: :header` is how a market screen shows the chip (Confier does it in `.market-entrust__header`).
- `app/controllers/markets_controller.rb`, `app/policies/market_policy.rb`, `app/views/markets/show.html.erb` -- the teaser; `include PublicRead`; `authorize :market, :show?` (true); `app/controllers/market/entrustments_controller.rb` and `app/policies/market/entrustment_policy.rb` -- model of a nested market controller and policy.
- `app/controllers/feeds_controller.rb`, `app/views/feeds/show.turbo_stream.erb`, `_pages.html.erb` -- "next page" as a link answered by a Turbo Stream append; `app/views/market/_suspended_banner.html.erb` (not used here).
- `app/components/picoin_amount_component.rb`, `app/helpers/picoins_helper.rb`, `app/frontend/lib/picoins.ts` -- the amount, compact or exact, `size: :large` for the big figures; `app/components/card_component.rb` (`card:, size: :m`) and `panel_component.rb`, `button_component.rb` (`variant: :link`, `disabled: true`).
- `app/domains/game/app/models/game/visibility.rb`, `app/domains/accounts/app/models/accounts/persona_name.rb`, `app/controllers/cards_controller.rb` (`pioneer_line`, `PioneerLine`), `app/views/cards/_detail.html.erb`, `_public.html.erb` -- the name rules and the pioneer row to move; `brother_path(token:)` links a profile; `t("shell.player.fallback_name")` for a player with no name.
- `app/frontend/controllers/countdown_controller.ts`, `local_time_controller.ts`, `app/frontend/lib/i18n.ts` (`t(template, vars)`), `lib/local_time.ts`, `app/helpers/local_time_helper.rb` (`local_time_tag`, `local_time_text`) -- the capsule clock (not reusable), the end time tag, the template helper.
- `app/helpers/shell_helper.rb` (`SCREEN_LABELS`, `phone_back_link`, `shell_top_level_screen?` already lists `markets`), `config/routes.rb` (market routes at lines 34-38, inside the locale scope), `app/frontend/entrypoints/application.css` (imports), `app/frontend/styles/market-teaser.css`, `market-suspended.css`, `balance-chip.css` -- placement, header and tokens.
- `db/migrate/20261110090000_create_game_market_tables.rb`, `20261110100012_create_game_market_archive_stocks.rb` -- the migration style; `db/seeds.rb` -- the development block style; `test/support/market.rb` (`open_market!`, `close_market!`), `test/support/holdings.rb` (`hold`), `test/domains/game/market/entrust_cards_test.rb`, `ledger_write_guard_test.rb`, `test/system/market_suspension_test.rb`, `test/models/player_stream_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/controllers/cards_controller_test.rb` (pioneer), `test/controllers/market/entrustments_controller_test.rb` line 163 -- the tests to follow or update.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (Marché rows, Listing tile, Annonce, Copy deck "Annonce", "Market accessible text", "Market feed and lists", Names, State Patterns, Focus after each step) and `DESIGN.md` (Marché: Market screen, Listing tile, Annonce, History row for the name colours) -- the copy and look; `mockups/market-screens.html` for layout.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261110120000_create_game_market_listings.rb` -- create `game_market_listings`: `token` string not null with a unique index, `seller_id` (FK accounts_players), `card_season_id` (FK catalog_card_seasons), `settings_id` (FK game_market_settings), `starting_price` bigint, `buy_now_price` bigint null, `duration_hours` integer, `ends_at` datetime, `current_price` bigint, `leader_id` (FK accounts_players, null), `leader_maximum` bigint null, `sold_at` datetime null, `final_price` bigint null, `status` string default `open`, timestamps; checks: status among `open sold unsold cancelled withdrawn`, `starting_price > 0`, `buy_now_price IS NULL OR buy_now_price > starting_price`, `current_price >= starting_price`, `(leader_id IS NULL) = (leader_maximum IS NULL)`, `(sold_at IS NULL) = (final_price IS NULL)`, `duration_hours > 0` -- the listing's own table, no concurrent index needed on a new table beyond the unique token one created with it.
- [ ] `db/migrate/20261110120001_add_open_ends_at_index_to_game_market_listings.rb`, `20261110120002_add_seller_status_index_to_game_market_listings.rb` -- each `disable_ddl_transaction!` and one concurrent index: `ends_at` where `status = 'open'` (the market screen and later the close job), and `(seller_id, status)` -- each concurrent index alone in its migration.
- [ ] `db/migrate/20261110120003_add_listing_foreign_key_to_game_market_ledger_entries.rb`, `20261110120004_validate_game_market_ledger_entries_listing_foreign_key.rb` -- `add_foreign_key :game_market_ledger_entries, :game_market_listings, column: :listing_id, validate: false`, then `validate_foreign_key` in the second; the epic 38 ledger's pointer now points -- expand then validate.
- [ ] `db/migrate/20261110120005_add_one_settlement_entry_per_player_to_game_market_ledger_entries.rb` -- `disable_ddl_transaction!`, a unique index on `(listing_id, player_id, kind)` concurrently, `where: "kind = 'stamp' OR kind = 'purchase' OR kind = 'sale' OR kind = 'commission'"`, named explicitly -- the database refuses a second settlement.
- [ ] `app/domains/game/app/models/game/market/listing.rb` -- create `Listing < ApplicationRecord` on `game_market_listings`: `STATUSES`, `has_secure_token :token, length: 24`, `belongs_to :seller` (Accounts::Player), `scope :open_now`; no behaviour beyond what queries and `ListCard` need -- the row.
- [ ] `app/domains/game/app/models/game/market/auction_math.rb` -- create `AuctionMath.commission(price, basis_points)` (integer floor of `price * basis_points / 10_000`), pure, no loop -- the only computation, extended by story 4.
- [ ] `app/domains/game/app/events/game/market/card_listed.rb` -- create `CardListed < RubyEventStore::Event`, data `listing_id`, `seller_id`, `card_season_id` -- identifiers only.
- [ ] `app/domains/game/app/operations/game/market/list_card.rb` -- create `ListCard < Operation`, `call(player:, card_season_id:, starting_price:, buy_now_price:, duration_hours:, settings_token:)` as in the matrix: `require_player`, normalise the amounts to integers and refuse with `Failure(:invalid_price)` any start or buy-now that is not an integer between 1 and the bigint maximum 9_223_372_036_854_775_807 (`MAX_AMOUNT` constant), then in one transaction `lock_bank`, the settings (`market_closed`, `amounts_changed`), the card-season's rarity (`no_rarity`), `TradeLocks.holdings` and the free copy (`copy_not_free`), the price, buy-now and duration rules, the wallet's `available` against the stamp (`stamp_not_covered`), create the listing, raise `reserved` by one, one `Ledger.post` of the `stamp`, publish `CardListed` on the seller's stream, return the listing; `rescue ActiveRecord::Deadlocked` -> `market_busy`; split steps into private methods so the file stays under 120 lines -- the write.
- [ ] `app/domains/game/app/queries/game/market/offer_counts.rb` -- create `OfferCounts.call(listing_ids)` returning `Hash.new(0)` -- the seam story 4 fills.
- [ ] `app/domains/game/app/queries/game/market/open_listings.rb` -- create `OpenListings.call(sort:, page:, locale:)` returning `Page = Data.define(:rows, :more)` of `Row = Data.define(:token, :card, :current_price, :buy_now_price, :ends_at, :offers)`; the four sorts, 24 per page, one extra row read to know `more`; cards through `Catalog::CardViews`, a listing whose card-season has no view is left out -- the market screen's one reader.
- [ ] `app/domains/game/app/queries/game/market/listing_by_token.rb` -- create `ListingByToken.call(token, locale:)` returning nil or `Detail = Data.define(:token, :status, :card, :seller, :leader, :current_price, :starting_price, :buy_now_price, :ends_at, :created_at)` (players as `Accounts::Player`, `leader_maximum` never selected) -- the Annonce's one reader.
- [ ] `app/models/player_stream.rb` -- add `Game::Market::CardListed` to `BALANCE_EVENTS` and a `when Game::Market::CardListed` notice `balance_notice(data[:seller_id])` ahead of the `*BALANCE_EVENTS` branch -- the seller's chip refreshes after commit; other epic stories add their events the same way.
- [ ] `config/routes.rb` -- `get "market/listings/:token" => "market/listings#show", as: :market_listing` beside the entrust routes -- the Annonce by token.
- [ ] `app/controllers/markets_controller.rb`, `app/views/markets/screen.html.erb`, `_tile.html.erb`, `_tiles.html.erb`, `_sorts.html.erb`, `screen.turbo_stream.erb` -- `show`: authorize, and when `Game::Market::MarketState.call.first_opened?` read `OpenListings` (`sort` and `page` from params, whitelisted, page clamped) and `render :screen` (HTML and Turbo Stream), else the unchanged teaser view; the screen has the h1 "Marché", the Balance chip (`placement: :header`), the chip row (ANNONCES current), CONFIER DES CARTES as a secondary link to `new_market_entrustment_path` (a disabled button for a visitor), the four sorts as a nav of links with `aria-current`, the tiles in a list, "Charger plus" as a `ButtonComponent` `:link` variant link (`rel="next"`) replaced by the stream, and "Aucune annonce pour le moment." when empty; the tile is one link to `market_listing_path(token)` with the Market accessible text as its `aria-label`, `CardComponent` size m, the compact price, "n offres", the time left (alert modifier under an hour), "Achat immédiat" when set -- the market screen.
- [ ] `app/controllers/market/listings_controller.rb`, `app/policies/market/listing_policy.rb`, `app/views/market/listings/show.html.erb` -- `show`: `include PublicRead`, `ListingByToken` or `RecordNotFound`, `authorize [:market, :listing], :show?` (true, visitors included); the view has `phone_back_link` "MARCHÉ" to `market_path`, the Balance chip (`placement: :header`), the h1 (card title) with `tabindex="-1"` and `autofocus`, `CardComponent` size l and the facts (seller through `PlayerNameComponent`, "En tête" when a leader exists), PRIX ACTUEL (`PicoinAmountComponent` large, exact), FIN DANS with the `listing-clock` controller and a `local_time_tag` end time, the buy-now price when set; layout three columns on desktop with the history column left to story 6, stacked on the phone -- the read-only Annonce.
- [ ] `app/helpers/market_helper.rb` -- create: `listing_time_left(seconds)` and `time_left_soon?(seconds)` using the locale keys, `listing_tile_label(row)` for the accessible text, `sort_options` -- the markup helpers, kept out of `shell_helper.rb`.
- [ ] `app/components/player_name_component.rb`, `.html.erb` -- create `PlayerNameComponent.new(player:, viewer:)`: the cleaned persona name or `shell.player.fallback_name`; a link to `brother_path(token:)` only when `Game::Visibility.visible?(viewer, player)`; the anonymous key (`player_name.anonymous`) as plain text with no link for a banned or deleted account; a bare name otherwise; class modifiers per case, a 44px hit area on the phone from the stylesheet -- one component names a player.
- [ ] `app/controllers/cards_controller.rb`, `app/views/cards/_detail.html.erb`, `_public.html.erb` -- `PioneerLine` carries the player and the viewer's component replaces the three-way markup; drop the now-unused anonymous branch and key use there -- the pioneer row moves to the component.
- [ ] `app/helpers/shell_helper.rb` -- add `"market/listings" => :market` to `SCREEN_LABELS` -- the Annonce's screen title.
- [ ] `app/frontend/lib/time_left.ts`, `app/frontend/controllers/listing_clock_controller.ts` -- create the pure `timeLeft(seconds)` (`{ kind: "hours" | "minutes" | "under", hours, minutes }`) and `msToNextChange(seconds)`, and the controller: values `seconds` and the three templates, `deadline` from `performance.now()`, a timer that fires when the minute label changes, `connect`/`disconnect` clearing it, the label written to its target only when it differs; `t()` from `lib/i18n.ts` fills `%{hours}` and `%{minutes}` -- the per-minute countdown; answers the story's unknown.
- [ ] `app/frontend/styles/market-screen.css`, `market-tile.css`, `market-listing.css`, `player-name.css`, `app/frontend/entrypoints/application.css` -- create and import: tokens only (`--color-alert`, `--color-gold`, `--font-number`, `--space-*`); six tiles a row on desktop and two on the phone with 18 to 20px gaps, price bold 17px, alert colour modifier, accent "Achat immédiat"; the Annonce's grid (card and facts, price and time at 30px mono, history column reserved) stacking under 720px with the two figures stacking under 400px; the name's three looks (linked accent underlined, bare and anonymous bright bold, never underlined), 44px hit area on the phone; each file under 500 lines, `npm run lint:css` clean.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- add `markets.screen.*`, `markets.tile.*` (offers with `zero`, `one`, `other`; label; buy-now tag), `markets.sorts.*`, `markets.time_left.*`, `market.listings.show.*`, `player_name.anonymous` and `errors.game.copy_not_free`, `start_below_minimum`, `buy_now_below_minimum`, `buy_now_not_above_start`, `invalid_price`, `invalid_duration`, `stamp_not_covered` (the Copy deck's words, "Il vous manque <amount> PiCoins pour le timbre." for the stamp); reword `errors.game.market_closed` neutrally; alphabetical order, French plurals with a `zero` form, `bundle exec i18n-tasks` clean (dynamic `errors.game` keys added by hand and noted in `config/i18n-tasks.yml` if its ignore list needs it) -- all copy in both languages.
- [ ] `db/seeds.rb` -- in the development block, add a block after the existing development opening block (do not reopen the market): for a few fake development players with holdings, fund the seller through `EntrustCards` on a spare copy (a copy beyond the one to list), read the stamp and minimum price from the current settings, skip the seller when `available` cannot cover the stamp, then `ListCard` (idempotent: skip a card-season the player already has an open listing for); no `.value!` on a refusal -- the development seed.
- [ ] `test/domains/game/market/list_card_test.rb` -- every refusal of the matrix leaves holdings, listings and ledger untouched, including a start and a buy-now of 99999999999999999999 each answering `Failure(:invalid_price)` (never `RangeError`) and the exact bigint maximum passing normalisation to then fail the buy-now or stamp rules as a Failure; the happy path checks the listing's fields, the version, `ends_at`, the `stamp` entry and the wallet, `reserved` + 1, one `CardListed`, `PlayerStream` enqueuing its job only after commit, an only copy listable, and `EntrustCards` and `ProposeTrade` then refusing the reserved copy; a `Deadlocked` stub answers `market_busy` -- the operation.
- [ ] `test/domains/game/market/auction_math_test.rb`, `listing_test.rb` -- the commission floor at several prices and 0, 250, 1000 and 2500 basis points; a second `sale` entry for one listing and player raises `RecordNotUnique` while a `stamp` of another listing and a second `mint` pass, and the table's checks refuse a buy-now not above the start and a bad status -- the math and the database guarantees.
- [ ] `test/domains/game/market/open_listings_test.rb`, `listing_by_token_test.rb` -- the four sorts and their ties, paging and `more`, only open listings, no database id nor `leader_maximum` in the rows, nil for an unknown token -- the queries.
- [ ] `test/components/player_name_component_test.rb` -- linked, bare and anonymous cases, the visitor viewer, the fallback name -- R17.
- [ ] `test/controllers/markets_controller_test.rb`, `test/controllers/market/listings_controller_test.rb`, `test/helpers/market_helper_test.rb` -- teaser before the first opening and screen after (open and suspended), the tile is one link with its accessible text and the alert modifier under an hour, sort and "Charger plus" in HTML and Turbo Stream, a GET writes nothing, a visitor reads both pages with CONFIER greyed and no chip, the Annonce's facts, the focused h1 attributes, 404 on an unknown token, no database id in any markup; the time-left wording at 59 s, 60 s, 59 min and 134 min in both locales -- the web layer.
- [ ] `test/models/player_stream_test.rb`, `test/controllers/cards_controller_test.rb`, `test/controllers/market/entrustments_controller_test.rb`, `app/frontend/lib/time_left.test.ts` -- a `CardListed` yields the seller's balance notice; the pioneer row's three cases; the reworded closed text; the time-left functions -- the touched tests.
- [ ] `test/system/market_test.rb` -- before the first opening the market address shows the teaser; after it, a visitor sees a listing created through `ListCard` as a tile, sorts by price, opens its Annonce and reads its price, end time and seller, with the h1 focused (retrying matchers only; a window-size change restored) -- the end-to-end check.

**Acceptance Criteria:**
- Given the market never opened, when anyone loads `/market`, then the teaser shows; given a first opening is recorded, when anyone loads it, then the market screen shows, also while the market is closed again.
- Given a free copy, when `ListCard` succeeds, then the listing exists once, `reserved` is raised by one, exactly one `stamp` entry for the listing posted, and the seller's Balance chip is redrawn after commit.
- Given a listing, when anything inserts a second `stamp`, `purchase`, `sale` or `commission` entry for the same player and listing, then the database refuses it.
- Given open listings, when a visitor opens the market, then tiles show ending soonest first, the four sorts reorder them, "Charger plus" appends the next page, and with none the line "Aucune annonce pour le moment." shows.
- Given a tile, when read by assistive technology, then the whole tile is one link named by the accessible text, and the time left is in the alert colour under an hour.
- Given an Annonce, when it opens, then the h1 is focused, PRIX ACTUEL and the countdown (per minute) read from the server's end time with the end time beside it, the seller's name is linked, bare or anonymous by `PlayerNameComponent`, and "◀ MARCHÉ" leads back.
- Given no database id anywhere, when the market pages render, then URLs, HTML and DOM ids carry tokens and slugs only.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

`PlayerNameComponent` cases, one look each:

```ruby
if Game::Visibility.visible?(viewer, player) then link_to(name, brother_path(token: player.token), class: "player-name player-name--linked")
elsif player.removed?                         then tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous")
else                                               tag.span(name, class: "player-name")
end
```

`ListCard` skeleton of the lock order (stamp posted last, after every other lock):

```ruby
transaction do
  step lock_bank(player)
  settings = step current_settings(settings_token)
  holding = step free_copy(TradeLocks.holdings(player.id, [ card_season_id ])[card_season_id])
  step rules(settings, rarity, starting_price, buy_now_price, duration_hours, available_of(player))
  listing = create_listing(...); reserve(holding)
  Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :stamp, available_delta: -stamp, listing_id: listing.id, settings_id: settings.id))
  step publish(CardListed.new(data: { listing_id: listing.id, seller_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
  listing
end
```

The wallet's `available` is read after the seller's bank lock: only the seller's own operations lower it, all under that lock, so the check and the post cannot disagree.

## Verification

**Commands:**
- `bundle exec rubocop` on every touched Ruby file and migration -- expected: no offense
- `ruby -c` on each new Ruby file -- expected: Syntax OK
- `bundle exec packwerk check` -- expected: no violation (Game reads Catalog and Accounts only; the web layer reads Game)
- `script/check_planning_references`, `script/check_file_sizes` -- expected: clean
- `/home/teyermann/projets/gameble/node_modules/.bin/prettier --write` on the touched frontend files, `npm run lint:css` -- expected: formatted, clean
- run once at the end of the market run: `bin/rails test test/domains/game/market test/components/player_name_component_test.rb test/controllers/markets_controller_test.rb test/controllers/market test/controllers/cards_controller_test.rb test/models/player_stream_test.rb test/helpers/market_helper_test.rb`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `bin/rails test test/system/market_test.rb`, then regenerate `db/schema.rb` from the migrations as AGENTS.md describes

**Manual checks (if no CLI):**
- With the market never opened `/en/market` shows the teaser; after an administrator opens it, the same address lists the seeded copies as tiles, the sorts reorder them, and an Annonce opens with its h1 focused, a countdown that changes once a minute and the seller's name linked.
