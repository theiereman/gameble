---
title: 'The DUELS tab, the Duels screen with the player''s decks, and ÉCHANGES with its two sub-tabs'
type: 'feature'
ticket: '2'
created: '2026-11-15'
status: 'built'
baseline_revision: '50909e25e483d9462db146b5967be2c7375f63b0'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Decks exist but nothing leads to them: the phone's fifth tab is still MARCHÉ, the hub menu has no DUELS entry, and the player has no screen listing their decks. The market must become a sub-tab of ÉCHANGES to free that place.

**Approach:** Tabs become PONT · CAPSULE · SETS · ÉCHANGES · DUELS (web, iOS, Android), menu 03 ÉCHANGES / 04 DUELS. ÉCHANGES (tab and menu) leads to a new GET `/:locale/exchanges` that redirects to the sub-tab the player last used, kept on `game_player_states.exchanges_tab` by a housekeeping POST from the sub-tab bar. A `nav` "Échanges" with ENTRE AMIS (`/trades`) and MARCHÉ (`/market`) sits on both screens. A new Duels screen at `/:locale/duels` lists MES DECKS; the deck editor gets "◀ DUELS" and deletion lands on Duels.

## Boundaries & Constraints

**Always:**
- Tab list (`ShellHelper#shell_tabs`): `[key, icon, path, current]` with `current` `nil`, `"page"` or `"true"`: `:trades` (label "Échanges"/"Trades", icon `tab-trades`, path `exchanges_path`) is `"page"` on `trades#index` and on `markets`, `market/my_bids`, `market/my_sales`, `"true"` on every other `trades` action and on `market/listings`; `:duels` (icon `tab-duels`, `duels_path`) is `"page"` on `duels#show`, `"true"` on `decks`. PONT, CAPSULE, SETS and the visitor's two tabs keep their current rules and `"page"`.
- Badges: menu 03 and the ÉCHANGES tab show waiting trades + outbid auctions in one orange badge, hidden at zero as today, named "Échanges, 2 échanges et 1 enchère à voir" / "Trades, 2 trades and 1 auction to see", each part left out at zero, nothing beyond the label at zero. They keep the stream targets `menu-trades-badge` and `tab-trades-badge` (native reads `#tab-trades-badge .tab-bar__badge`, unchanged). ENTRE AMIS: own badge "Entre amis, 2 échanges en attente"; MARCHÉ: "Marché, 1 enchère dépassée" (targets `subtab-friends-badge`, `subtab-market-badge`). `menu-market-badge`/`tab-market-badge` disappear; `market-bids-badge` stays. French plural keys with `zero`.
- `PlayerStreamJob`: when the topics include `trades` or `market`, compute both counts and update all five targets (sum targets, both sub-tab targets, `market-bids-badge`). `top_bars/show.turbo_stream.erb` and `_native_tab_badges` render the sum in `tab-trades-badge`.
- Sub-tab bar `app/views/exchanges/_tabs.html.erb` (locals `current:` `:friends|:market`), rendered for a signed-in player only, at the top of `trades/_screen` (every view; hidden by CSS on the phone's board view like the list) and of the market screen, my bids, my sales and the teaser, outside the `market-tab` frame. `<nav aria-label="Échanges">`, two links each with its pixel icon (`tab-friends`, `tab-market`, hidden), label, badge; the current one `aria-current="page"`; `data-turbo-action="replace"` on both links (native: a sub-tab switch replaces the screen, no back). Stimulus `exchanges-tabs`: on connect (not a Turbo preview) POSTs `{ tab: current }` to `exchanges_tab_path` only when it differs from the kept value rendered by the server; after a click on the other sub-tab, the next screen focuses `#main h1` (the three h1s get `tabindex="-1"`).
- Kept sub-tab: column `game_player_states.exchanges_tab` (string, null = ENTRE AMIS), check `exchanges_tab IN ('friends','market')` added `validate: false` then validated in a second migration. `Game::KeepExchangesTab` (`call(player:, tab:)`, `Failure(:unknown_tab)`, no write and no event when unchanged, else upsert with `PlayerState.markers_at_published_season` on insert and publish `Game::ExchangesTabKept` with ids only, no subscriber). Read through `Game::ExchangesTab.call(player)` → `"friends"|"market"`. `ExchangesController#show` redirects (302) to `trades_path` or `market_path`; a visitor to `market_path`. `ExchangeTabsController#create` JSON 204, rate-limited like `CollectionSeenController`.
- Duels screen (`DuelsController#show`, `DuelPolicy#show? = player?`, a visitor is sent to the landing by the normal Pundit refusal): tab root, top-level (`shell_top_level_screen?`, so the player menu shows on the phone), `back_button` on desktop, title "Duels". `<h1>` "Duels"; section MES DECKS whose `<h2 tabindex="-1">` shows "Mes decks · 3 / 5" (hidden from AT) with visually hidden "Mes decks, 3 sur 5"; up to five deck rows in creation order, each one `<a>` to `deck_path`: visible name, "9 / 12" for a draft (aria-hidden), visually hidden ", 12 cartes" or ", brouillon, 9 sur 12", then twelve cover cells in slot order inside an `aria-hidden` box (`<img alt="" loading="lazy">` of the card's image, an empty slot a dashed cell); "+ NOUVEAU DECK" (`ButtonComponent variant: :link`, `new_deck_path`) while fewer than five; at five the line `Game::CreateDeck.failure_message(:too_many_decks)` and no button; no deck: the heading and "+ NOUVEAU DECK" alone.
- Deck editor (`decks/new`, `decks/show`): `content_for :back_button` and a phone back "◀ DUELS" (`phone_back_link t("shell.tabs.duels"), duels_path`). `DecksController#destroy` redirects `see_other` to `duels_path` with the toast `decks.deleted` and focus on the deck list's heading (reuse `row-focus`: `landing` value `""` + `heading` target, from a flash flag).
- Hub menu: 03 ÉCHANGES → `exchanges_path` with the summed badge; 04 DUELS → `duels_path`, key `4`, no badge (a duel in progress comes with live duels).
- Native: iOS `Tabs.swift` and Android `Tabs.kt` (+ `activity_main.xml` host id, `strings.xml` en/fr, drawables): fifth tab "Duels" at `/duels` with icon `tab-duels`; ÉCHANGES starts at `/exchanges`; `destination` maps `/exchanges`, `/trades…` and `/market…` to tab 3 and `/duels…` to tab 4 (`atRoot` for `/exchanges`, `/trades`, `/market`, `/duels`). Code only; do not build or submit apps.
- Crossed-blades icon: `"tab-duels"` grid in `script/pixel_art/export.mjs` (11 × 11, `c` text colour, rows from DESIGN.md Duel pixel grids: `c.........c`, `.c.......c.`, `..c.....c..`, `...c...c...`, `....c.c....`, `.....c.....`, `....c.c....`, `.c.c...c.c.`, `..c.....c..`, `.c.c...c.c.`, `c.........c`) and its description line; run `node script/pixel_art/export.mjs`; never hand-edit `app/frontend/images/pixel/`.
- Copy in both locales, labels sentence case and capitals by CSS; no DB ids in URLs, DOM or JSON (decks by token); no `style` attribute; every action has a Pundit policy.

**Never:** no DÉFIER UN AMI, EN LIGNE, record, DERNIERS DUELS or duel badge (epics 43, 44); no change to market or trade addresses or to the visitor's tabs and market chrome (a visitor's market page keeps no tab bar, as today: "a visitor's navigation is unchanged"); no write from a GET; no React or script-built markup; no planning ids in code; do not touch 42.5's files (`Game::ReservedCopies`, card picker, Confier, Mettre en vente) beyond what this story needs.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First ÉCHANGES | no kept tab | `/exchanges` → `/trades` | — |
| MARCHÉ last used | player opened `/market` (POST kept `market`) | `/exchanges` → `/market`; MARCHÉ `aria-current=page` | — |
| Unknown tab POST | `tab=foo` | 422 JSON `unknown_tab` | — |
| Visitor | `/exchanges`, `/duels`, `/market` | market; landing; market without sub-tab bar and without tab bar | Pundit refusal → landing |
| Summed badge | 2 trades waiting, 1 outbid | tab & menu "3", named "Échanges, 2 échanges et 1 enchère à voir"; ENTRE AMIS "2", MARCHÉ "1" | — |
| One part | 0 trades, 1 outbid | "Échanges, 1 enchère à voir" | — |
| Zero | nothing | no badge on tab, menu or sub-tabs; name "Échanges" | — |
| No deck | 0 decks | "Mes decks · 0 / 5" + "+ NOUVEAU DECK" alone | — |
| Draft row | deck "Brouillon" with 9 cards | link named "Brouillon, brouillon, 9 sur 12"; 9 covers, 3 dashed cells | — |
| Five decks | 5 decks | no "+ NOUVEAU DECK"; "Cinq decks au plus : …" | — |
| Deck deleted | destroy from editor | Duels screen, toast "Deck supprimé.", focus on MES DECKS heading | — |
| Deck editor | any deck | DUELS tab `aria-current="true"`; "◀ DUELS" on the phone | — |

</intent-contract>

## Code Map

- `app/helpers/shell_helper.rb` -- `SCREEN_LABELS` (+ `"duels" => :duels`), `shell_top_level_screen?` (+ `duels`), `shell_tabs` (keys, paths, three-state current), `shell_trades_waiting`; `app/helpers/outbid_badge_helper.rb` `shell_outbid_count`. Put the badge naming in a small helper (e.g. `app/helpers/exchanges_badge_helper.rb`: `exchanges_badge_name(waiting:, outbid:)`) used by tab, menu and stream partials.
- `app/views/shell/_tab_bar.html.erb`, `_tab_trades_badge.html.erb` (sum), delete `_tab_market_badge.html.erb`; `_native_tab_badges.html.erb`; `app/views/top_bars/show.turbo_stream.erb`; `app/views/player_streams/_update.turbo_stream.erb`; `app/jobs/player_stream_job.rb`.
- `app/views/pages/_menu.html.erb`, `_menu_trades.html.erb` (→ `exchanges_path`), `_menu_trades_badge.html.erb` (sum), `_menu_market*.html.erb` → `_menu_duels.html.erb`.
- `app/views/exchanges/_tabs.html.erb` (new), rendered from `app/views/trades/_screen.html.erb`, `app/views/markets/screen.html.erb`, `markets/show.html.erb` (teaser), `market/my_bids/show.html.erb`, `market/my_sales/show.html.erb`; h1s `trades__title` (`trades/_screen`), `market-desk__title` (`markets/_desk`), `market-teaser__title` get `tabindex: -1`. Phone board view hides list and title in `app/frontend/styles/trades-responsive.css:20`; hide the bar the same way.
- `app/frontend/controllers/exchanges_tabs_controller.ts` (+ `.test.ts`) -- POST pattern `collection_seen_controller.ts`; focus by a module-level flag set on click; register as the app registers controllers.
- `config/routes.rb` -- near `get "market"`: `get "exchanges" => "exchanges#show", as: :exchanges`, `post "exchanges/tab" => "exchange_tabs#create", as: :exchanges_tab`, `get "duels" => "duels#show", as: :duels` (before the `duels/decks` resources is fine).
- `app/controllers/{exchanges,exchange_tabs,duels}_controller.rb`, `app/policies/{exchange,exchange_tab,duel}_policy.rb` -- patterns `collection_seen_controller.rb`, `collection_seen_policy.rb`, `deck_policy.rb`.
- `db/migrate/20261115180000_add_exchanges_tab_to_game_player_states.rb`, `20261115180001_validate_game_player_states_exchanges_tab.rb` (templates `20261115160001`/`160002`); regenerate `db/schema.rb` from the migrations on the test DB per AGENTS.md (never the development DB).
- `app/domains/game/app/operations/game/keep_exchanges_tab.rb` (template `mark_trade_seen.rb`), `events/game/exchanges_tab_kept.rb`, `queries/game/exchanges_tab.rb`; `queries/game/player_decks.rb` -- add a listing (decks in creation order with `slot → card_season_id`), keep `count`/`room_left?`.
- `app/models/deck_list.rb` (PORO like `app/models/deck_editor.rb`) -- rows `Data(token, name, count, covers[12])`, covers via `Catalog::CardViews.call(ids, locale:)` `image_url`; `room_left?`, `count`.
- `app/views/duels/show.html.erb` (+ partials) and `app/frontend/styles/duels.css` (import in `app/frontend/entrypoints/application.css` beside `deck-editor.css`) -- DESIGN.md Duels › Deck list and Desktop, board 1 and 11: panel with kicker heading, rows ≥ touch-min on `--color-panel`, a draft's "<n> / 12" outlined `--color-dim` in `--color-muted` as `.deck-editor__count`; covers two rows of six on the phone, one row of twelve from `--space-breakpoint-two-columns`, and from `--space-breakpoint-three-columns` a 1120px column with three deck tiles per row, each 4 × 3; dashed `--color-dim` empty cell. Tokens only, < 500 lines.
- `app/views/decks/new.html.erb`, `show.html.erb`, `app/controllers/decks_controller.rb` (`destroy` redirect + flash flag).
- `script/pixel_art/export.mjs` (`tab-duels` near `tab-market` ~line 1148, description ~line 1785); `script/pixel_art/app_icons.mjs:119` loop → `["hub", "capsule", "sets", "trades", "duels"]` (drop the retired `friends`, whose Android drawable is gone) after writing `mobile/android/app/src/main/res/drawable/ic_tab_duels.xml` in the format of `ic_tab_market.xml` from `tab-duels.svg`'s path data; run it and check only the expected files change; remove `ic_tab_market.xml` and `tab-market.imageset`.
- `mobile/ios/Gameble/Tabs.swift`, `mobile/android/app/src/main/java/net/gameble/app/Tabs.kt`, `res/layout/activity_main.xml` (`market_host` → `duels_host`), `res/values{,-fr}/strings.xml` (`tab_market` → `tab_duels`).
- `config/locales/en.yml`, `fr.yml` -- `shell.tabs.duels`, `shell.screens.duels`, `pages.home.menu.duels`, the sum's parts, sub-tab labels and badge names, `duels.*`; drop `shell.tabs.market*`/`pages.home.menu.market*` keys left unused.
- Tests to update (ids and names change): `test/integration/phone_tabs_test.rb`, `test/helpers/shell_helper_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/controllers/{trades,pages,markets,top_bars,hotwire_native,decks}_controller_test.rb`, `test/integration/{shell,player_stream_tag}_test.rb`, `app/frontend/lib/native_top_bar.test.ts` if needed, system `test/system/market_badges_test.rb`, `deck_editor_test.rb` (deletion now lands on Duels). Grep for `market_path` in tab/menu assertions and `menu-market-badge`/`tab-market-badge`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs`, `app/frontend/images/pixel/tab-duels.svg` (generated), `script/pixel_art/app_icons.mjs`, native drawables -- the crossed-blades icon -- `--check` passes
- [x] migrations, `db/schema.rb`, `keep_exchanges_tab.rb`, `exchanges_tab_kept.rb`, `exchanges_tab.rb`, `player_decks.rb` -- kept sub-tab and deck listing
- [x] `config/routes.rb`, three controllers, three policies, `decks_controller.rb` -- addresses, redirect, POST, Duels, deletion landing
- [x] `shell_helper.rb`, badge helper, shell and menu partials, stream partial and job, top bar stream -- tabs, menu, summed and sub-tab badges
- [x] `exchanges/_tabs.html.erb`, trade and market views, `exchanges_tabs_controller.ts`, CSS -- the sub-tab bar, keep and focus
- [x] `app/models/deck_list.rb`, `duels/*`, `duels.css`, `decks/new|show` -- Duels screen and "◀ DUELS"
- [x] `mobile/ios/...`, `mobile/android/...` -- five native tabs
- [x] `en.yml`, `fr.yml` -- copy
- [x] tests: `KeepExchangesTab` (write, unchanged no-op, unknown tab), `ExchangesController` (first time, market kept, visitor), `ExchangeTabsController` (204, 422, visitor 401, throttle), `DuelsController` (rows' names, draft, no deck, five decks, visitor to landing, no `[style]`, no ids, DUELS current), policies, shell helper (player and visitor tab lists, three-state current, the badge names en/fr: both, one part, zero), stream job, vitest for the sub-tab controller, `test/system/duels_test.rb` (the verify scenario at phone width via `resize_to`, restoring the size; then desktop hub menu 03 ÉCHANGES / 04 DUELS), updated existing tests

**Acceptance Criteria:**
- Given a signed-in player at phone width with two decks, when they tap DUELS, then the Duels screen lists both decks and "+ NOUVEAU DECK", and a deck row opens its editor showing "◀ DUELS" with DUELS `aria-current="true"`.
- Given a player who never opened MARCHÉ, when they tap ÉCHANGES, then ENTRE AMIS opens; after they follow MARCHÉ (focus on the market's h1) and come back to PONT, ÉCHANGES opens MARCHÉ; an old `/market` link still opens the market.
- Given a visitor, when they open the site at phone width, then the tab bar holds ACCUEIL and TOUTES LES CARTES, and `/market` shows no sub-tab bar.
- Given a desktop width, when a player opens the hub, then the menu reads 03 ÉCHANGES and 04 DUELS.

## Implementation Notes

- The badge naming and markup live in `app/helpers/exchanges_helper.rb` (`exchanges_badge_suffix`, `count_badge`, `kept_exchanges_tab`), not a separate `exchanges_badge_helper.rb`. The hidden suffix follows the label with no whitespace, so the link reads "Échanges, 2 échanges et 1 enchère à voir".
- The ÉCHANGES tab keeps the stream targets `menu-trades-badge` / `tab-trades-badge` ("Trades" is its English name); the sub-tabs use `subtab-friends-badge` / `subtab-market-badge`. The tab bar CSS now lights any `[aria-current]`, so `"true"` shows as current too.
- The sub-tab bar is rendered on every trades view (hidden with the list on the phone's board view) and on the market, my bids, my sales and the teaser, outside the `market-tab` frame; its links replace the screen (`data-turbo-action="replace"`).
- The check is written `exchanges_tab = 'friends' OR exchanges_tab = 'market'`, as the other value checks are, and `db/schema.rb` is regenerated from the migrations and round-trips (a stale `tmp/migrated_schema.rb` had first been loaded instead of migrating).
- Native: the ÉCHANGES tab starts at `/exchanges`; `/exchanges…`, `/trades…` and `/market…` choose it, but only `/exchanges` counts as its root, so a sub-tab link from another tab is visited. `app_icons.mjs` now loops over the five live tabs (the retired `friends` had no drawable); the market tab's drawable, imageset and string are gone. Not compiled: no Swift or Kotlin toolchain here.
- A filled slot whose card has no catalog view (no rarity, no text in the locale) shows as a dashed cell and still counts as filled.
- `test/controllers/market/my_sales_controller_test.rb:138` asserted the old MARCHÉ tab address and now expects `/exchanges`.

## Plan Change Log

## Review Triage Log

### 2026-11-15 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 3, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` `db/schema.rb` held the round-trip form of the check, not the migrations' output, so CI's schema-from-migrations job would fail — regenerated from the migrations after removing the stale `tmp/migrated_schema.rb`; the migration's check written with `OR`; a load-and-dump round trip is identical.
  - `[medium]` `[patch]` Native `Tabs.swift` / `Tabs.kt` reported `/trades` and `/market` as tab 3's root, so a sub-tab link from another tab only popped to whichever sub-tab tab 3 showed last — only the start path `/exchanges` counts as the root now; `/trades…` and `/market…` still choose tab 3 and are visited. The plan's `atRoot` line had asked for the wrong mapping.
  - `[low]` `[patch]` `exchanges_badge_name` was used by no view, so its en/fr tests covered dead code — method deleted; the tests check `exchanges_badge_suffix`, which every badge renders.
  - `[low]` `[reject]` The sub-tab focus flag stays set after a modifier-click or a cancelled visit and moves focus on a later unrelated connect — needs a modifier-key or visit-cancel guard for a rare gesture; the stray focus lands on the page's own h1.
  - `[low]` `[patch]` A filled slot whose card has no `CardView` rendered `<img>` with no `src` — the cover is built only with an image URL, otherwise the dashed cell; controller test added.
  - `[false]` `[reject]` Two deletions (`pages/_menu_market.html.erb`, `tab-market.imageset/Contents.json`) missing from the reviewed diff — both files are deleted in the working tree; the gap came from the diff file's staging, and the commit stages every deletion.

## Design Notes

- ÉCHANGES goes through `/exchanges` rather than an href rendered from the kept value: the market page is rendered before its own POST lands, so a rendered href would point to the previous sub-tab, and the native tab needs one fixed start address.
- The deck editor is reached only from Duels, so it always shows "◀ DUELS".
- Until epic 43 adds the 400px left column, the decks fill the 1120px column.
- Copy (fr / en): tab and menu "Duels"; sub-tabs "Entre amis"/"Between friends", "Marché"/"Market", nav "Échanges"/"Trades"; sum name suffix ", %{trades} et %{auctions} à voir" / ", %{trades} and %{auctions} to see" with parts "%{number} échange(s)" / "%{number} trade(s)", "%{number} enchère(s)" / "%{number} auction(s)", one part ", %{part} à voir" / ", %{part} to see"; ENTRE AMIS ", %{number} échange(s) en attente" / ", %{number} trade(s) waiting"; MARCHÉ ", %{number} enchère(s) dépassée(s)" / ", %{number} auction(s) outbid"; Duels h1 "Duels"; "Mes decks"/"My decks", "%{count} / 5", hidden "Mes decks, %{count} sur 5"/"My decks, %{count} of 5"; "+ Nouveau deck"/"+ New deck"; row ", 12 cartes"/", 12 cards", ", brouillon, %{count} sur 12"/", draft, %{count} of 12".

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- clean
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- only the new column and check in the diff
- `bin/rails test` (in parts if "too many clients") -- green except `library_controller_test.rb:119`
- `bin/rails test test/system/duels_test.rb test/system/deck_editor_test.rb test/system/market_badges_test.rb` and any other system test file whose assertions this story changes -- green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `npm run typecheck` (or bin/ci's equivalents, one by one, never its setup step) -- green

## Auto Run Result

**Summary:** the phone's tabs are PONT · CAPSULE · SETS · ÉCHANGES · DUELS on the web and in the native tab code, and the hub menu reads 03 ÉCHANGES and 04 DUELS. ÉCHANGES (tab and menu 03) goes to `/exchanges`, which redirects to the sub-tab the player last used: ENTRE AMIS the first time, the market for a visitor. A housekeeping POST from the sub-tab bar keeps that sub-tab on `game_player_states.exchanges_tab`. The bar is a `nav` named "Échanges" with ENTRE AMIS (`/trades`) and MARCHÉ (`/market`), each with its own badge, on the trades screen and every market root screen. The ÉCHANGES tab and menu carry the sum of the trades waiting and the auctions outbid, named with both parts. The new Duels screen at `/duels` lists MES DECKS · n / 5 with each deck's covers, "+ NOUVEAU DECK" while fewer than five, and the five-deck line at five. The deck editor shows "◀ DUELS" with DUELS current, and a deletion lands on Duels with its toast and the focus on the deck list's heading. The crossed-blades tab icon is exported through `export.mjs`.

**Files changed**
- `db/migrate/20261115180000_*`, `20261115180001_*`, `db/schema.rb`: the kept sub-tab column and its check, added then validated.
- `app/domains/game/app/operations/game/keep_exchanges_tab.rb`, `events/game/exchanges_tab_kept.rb`, `queries/game/exchanges_tab.rb`, `queries/game/player_decks.rb`: keeping and reading the sub-tab; the deck listing.
- `config/routes.rb`, `app/controllers/{exchanges,exchange_tabs,duels}_controller.rb`, `app/policies/{exchange,exchange_tab,duel}_policy.rb`, `decks_controller.rb`: the redirect, the POST, the Duels screen, the deletion landing.
- `app/helpers/shell_helper.rb`, `exchanges_helper.rb`, `app/jobs/player_stream_job.rb`, `app/views/shell/*`, `pages/_menu*`, `player_streams/_update`, `top_bars/show`: tabs with three-state current, menu 03/04, summed and sub-tab badges, live and native updates.
- `app/views/exchanges/*`, trade and market views, `app/frontend/controllers/exchanges_tabs_controller.ts`, `styles/exchanges-tabs.css`, `trades-responsive.css`, `shell-status.css`: the sub-tab bar, its keep and focus.
- `app/models/deck_list.rb`, `app/views/duels/*`, `styles/duels.css`, `decks/new|show`: the Duels screen and "◀ DUELS".
- `script/pixel_art/export.mjs`, `app_icons.mjs`, `app/frontend/images/pixel/tab-duels.svg`, `mobile/ios/...`, `mobile/android/...`: the icon and the five native tabs.
- `config/locales/en.yml`, `fr.yml`: copy, French plurals with `zero`.
- Tests: the operation, the three controllers, the three policies, the shell helper, the stream job, vitest for the sub-tab controller, `test/system/duels_test.rb`, and the existing tests updated for the new addresses and badges.

**Review (quick, pinned):** 6 findings.
- Patched, 2 medium: the schema regenerated from the migrations; native sub-tab links no longer pop to the wrong sub-tab.
- Patched, 2 low: the dead badge-name helper; a cover with no image.
- Rejected: the focus flag after a modifier-click (rare, needs a guard); the deletions missing from the diff file (false, a staging artefact).

**Follow-up review recommended:** true. Two medium entries were patched. The unverified risk is the native tab code: the Swift and Kotlin changes, the `atRoot` fix included, were never compiled or run on a device.

**Verification:** run on the main checkout after the patches.
- `bin/rails test`: 5683 runs, 1 failure, the known `library_controller_test.rb:119`.
- System: `duels_test.rb`, `deck_editor_test.rb`, `market_badges_test.rb`, `live_updates_test.rb`, `hub_test.rb`: green (17 runs); `duels_test.rb` again after the patches: 4 runs, green.
- `npm run test:js`: 135 files, 1414 tests passed.
- Also green: rubocop, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing`, typecheck, `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `export.mjs --check`.
- Schema built from the migrations, then a load-and-dump round trip: no diff.

**Residual risks:**
- The native tab code is uncompiled until the author builds the apps.
- The market pages keep their own top padding, so a gap shows between the sub-tab bar and the market panel.
- The kept value on a cached market page can be stale; the worst case is one extra POST that writes nothing.
- The worktrees building 42.5 may add migrations; `db/schema.rb` is regenerated after combining them.
