---
title: 'Grand Inventaire, pioneer boards and Classement des pionniers'
type: 'feature'
ticket: ''
created: '2026-11-19'
status: 'built'
baseline_revision: '6039d4a701321e163bea6cd4b18be6aa3e3d754b'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Le Grand Inventaire needs its pioneer side: two boards (top 3 + the viewer's place) on the screen another slice builds, and a public full ranking page, "Classement des pionniers", with paging and a pinned "Votre place" link. Nothing ranks players by first discoveries today.

**Approach:** One read query `Game::PioneerBoard` over `game_first_discoveries` (counts per active player, shared ranks, earlier-to-reach first, 50 per page, the viewer's place); a public `PioneerRankingsController#show` page built like Le Chattomètre's register and Tous les sets' paging; the boards partial `grand_inventories/_pioneer_boards`; one TypeScript Stimulus root controller for chips focus, status, address and the pinned bar.

## Boundaries & Constraints

**Always:**
- Shared contract with three parallel slices: route `get "inventory/pioneers" => "pioneer_rankings#show", as: :pioneer_ranking` inside `scope ":locale"`, placed right after `post "library/seen" ...` in `config/routes.rb`; query params `seasons=current` (absent = all seasons), `period=week|season` (absent = week), `page`. Partial `app/views/grand_inventories/_pioneer_boards.html.erb` with exactly the locals `inventory_scope:` (`:all|:current`) and `viewer:` (player or nil). i18n only under `pioneer_rankings.*` in both `config/locales/en.yml` and `fr.yml` (insert the subtree before `player_name:`; French plural keys get a `zero` form; French puts U+202F before `:`). Stylesheet `app/frontend/styles/pioneer_rankings.css`, imported in `app/frontend/entrypoints/application.css` right after `fortune-register.css`; it styles the partial too.
- Periods: Semaine = discoveries since this week's Monday 00:00 UTC, whatever the scope; second period follows the scope: `:season` (card_seasons of `Catalog::PublishedSeason.call`) under `seasons=current`, `:total` (every row) under all seasons. Banned or deleted players (`Accounts::Player.removed`) are neither ranked nor counted. Ties share a rank (`RANK()` on the count); within a tie the player whose last counted discovery is earlier comes first, then player id.
- Names through `PlayerNameComponent.new(player:, viewer:)`: link when the viewer may see the profile, bare name otherwise. Private and friends-only players ARE listed (unlike the Chattomètre).
- GET only, read-only, `authorize :page, :show?` (visitors allowed), `include PublicRead`. No db id anywhere in HTML/URLs.
- Every rule of AGENTS.md: no planning ids, no comments except external constraints, English repo text, files under 400 lines (CSS 500), no `style` attribute in server HTML, See-more links are `ButtonComponent variant: :link`.

**Never:**
- Create anything else under `app/views/grand_inventories/`, `Game::GrandInventory`, the grand inventory or brotherhood set routes/controllers, or touch `app/helpers/shell_helper.rb` (tab and screen label wiring is integration work).
- Run tests, suites or linters (they run once after integration).
- Add caching or rate limiting, React, markup built in script, or a new design token.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ranking | A 3 discoveries, B 2, C 2 (C's last earlier than B's) | A 1, C 2, B 2 in that order | none |
| Removed players | banned and deleted players with discoveries | absent from rows, ranks and counts | none |
| Week boundary | one discovery Sunday 23:59 UTC, one Monday 00:00 UTC | week counts only Monday's | none |
| Season vs total | discoveries on two seasons' editions | `:season` counts the published season's only, `:total` both | no published season: `:season` empty |
| Viewer place | viewer at position 51 | Place rank, count, page 2 | visitor, banned viewer, no discovery: nil |
| Board, viewer in top 3 | viewer ranked 2 | "VOUS" beside their name, no place line | none |
| Board, no discovery | viewer without discovery, board not empty | no-discovery line in place of the place | none |
| Empty board | nobody in the period | the period's empty line only | none |
| Visitor | no session | no place, no bar, sign-in line once under the boards / the list | none |
| Scroll page | turbo_stream GET page 2 | rows appended, status "Page 2 chargée", nav and address marker replaced | past the end: nothing appended |

</intent-contract>

## Code Map

- `app/controllers/fortune_registers_controller.rb`, `app/views/fortune_registers/show.html.erb`, `app/views/fortune_registers/_row.html.erb` -- the model page: `include PublicRead`, `include Pagy::Method`, `pagy(:offset, relation, limit:, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))`, `content_for :back_button/:title/:screen_title`, visually hidden h1, `.segmented` / `.segmented__option` chips (styled in `app/frontend/styles/settings.css`, `[aria-pressed="true"]` filled accent), `render "library/pages", pagy:, empty: false, label:`.
- `app/domains/game/app/queries/game/fortune_board.rb` -- query shape to mirror: window function in a subquery, `Fortune.from(numbered, :game_fortunes).order(...)` (Rails drops the order for pagy's count).
- `app/views/library/sets.html.erb`, `sets.turbo_stream.erb`, `app/views/library/_pages.html.erb`, `app/frontend/controllers/next_page_controller.ts` -- paging: a `turbo_frame_tag ..., target: "_top", data: { controller: "next-page", action: "focusout->next-page#focusLeft" }` wrapping the list and `library/pages` (nav `#collection-pages`, `data-next-page-target="pages"`, real links, `aria-current="page"`); next-page fetches `a[rel=next]` as turbo_stream when near the end and never on Tab; the stream appends, updates a status, replaces `collection-pages`.
- `app/frontend/controllers/copy_filters_controller.ts` -- precedent for `history.replaceState(history.state, "", url)` so the address follows a reload.
- `app/domains/game/app/models/game/first_discovery.rb` -- table `game_first_discoveries`: `card_season_id` (unique), `player_id`, `pack_id`, `discovered_at`.
- `Accounts::Player.in_good_standing` (`banned_at` and `deleted_at` nil) in `app/domains/accounts/app/models/accounts/player.rb`; `Catalog::PublishedSeason.call`; `catalog_card_seasons.season_id`. Game may depend on Accounts and Catalog.
- `app/components/player_name_component.rb` -- `PlayerNameComponent.new(player:, viewer:)`.
- `app/helpers/shell_helper.rb` `sign_in_button(label, origin:, class:)` -- visitor sign-in, as `app/views/cards/_public.html.erb:52` (`sign_in_button t("shell.top_bar.sign_in"), origin: request.path, class: "button button--primary"`).
- `ButtonComponent.new(variant: :link, href:, aria_label:)` -- See-more link.
- `PanelComponent.new(tag: :section, class:, aria: { labelledby: })` -- framed box.
- Tests: `test/domains/game/fortune_board_test.rb` (query test style, `Accounts::Player.create!(steam_id:)`), `test/controllers/fortune_registers_controller_test.rb` (`SteamSignIn#sign_in`, `assert_select`), `test/support/game_sets.rb` `published_cards(count)` (a new published season of `count` card-seasons, returns `[season, ids]`), fixtures `accounts_players(:player|:banned)`, `catalog_card_seasons(:common_card_one ...)` of published season `catalog_seasons(:one)`; view tests: `ActionView::TestCase` with `setup { controller.request.path_parameters[:locale] = "en" }` (`test/helpers/bell_helper_test.rb`); system tests: `test/system/library_test.rb` (`mock_steam_sign_in`, `click_steam_sign_in`, `assert_signed_in`, `resize_to`); vitest with happy-dom: `app/frontend/controllers/hub_fold_controller.test.ts`.
- Tokens: `--space-*`, `--space-touch-min`, `--tabbar-height` (phone tab bar, present when `body:has(.tab-bar)`), `--color-panel`, `--control-border`, `--color-accent`, `--color-gold`, `--color-muted`, `--color-text-bright`, `--color-line-soft`, `--font-label`, `--font-number`, `--font-menu`, `--page-width-regular`. Top 3 row look: `app/frontend/styles/fortune-panel.css` `.fortune-panel__row`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/pioneer_board.rb` -- `module Game::PioneerBoard`: `PAGE_SIZE = 50`, `TOP = 3`, `PERIODS = %i[week season total]`; `Row = Data.define(:rank, :player, :count)`, `Place = Data.define(:rank, :count, :page)`, `Board = Data.define(:period, :rows, :place)`; `period_for(choice, scope)` (`:week` stays, else `:season` for scope `:current`, `:total` otherwise); `ranked(period, now:)` = grouped counts of `of_period` restricted to `player_id: Accounts::Player.in_good_standing.select(:id)`, selecting `player_id`, `COUNT(*) AS discoveries`, `RANK() OVER (ORDER BY COUNT(*) DESC) AS pioneer_rank`, `ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, MAX(discovered_at), player_id) AS pioneer_position`, wrapped `FirstDiscovery.from(counts, :game_first_discoveries).order(:pioneer_position)`; `rows(standings)` loads players in one query; `place(viewer, period, now:)` via `ranked(...).find_by(player_id: viewer.id)`, page `(position - 1) / PAGE_SIZE + 1`, nil for nil viewer or no standing; `board(period, viewer:, now:)` top 3 + place; private `of_period` (`:week` `discovered_at >= now.utc.beginning_of_week(:monday)`, `:season` card_seasons of the published season (none without one), `:total` all, else ArgumentError).
- [ ] `test/domains/game/pioneer_board_test.rb` -- one test per matrix row on the query (ranking and ties, removed players, week boundary with a fixed `NOW`, season vs total with `published_cards`, place and page 2 with 51 ranked players, `period_for`).
- [ ] `config/routes.rb` -- the contract route after `post "library/seen"`.
- [ ] `app/controllers/pioneer_rankings_controller.rb` -- `show`: `authorize :page, :show?`; `@scope = params[:seasons] == "current" ? :current : :all`; `@choice = params[:period] == "season" ? :season : :week`; `@period = Game::PioneerBoard.period_for(...)`; pagy offset over `ranked`, limit `PAGE_SIZE`, page clamped to `1..10_000`; `@rows`; `@place` for a signed-in player; `respond_to` html and turbo_stream.
- [ ] `app/helpers/pioneer_rankings_helper.rb` -- `pioneer_boards(inventory_scope, viewer)` (the two `Board`s, week then the scope's second), `pioneer_rank(rank)` (`t("pioneer_rankings.rank", count: rank)`), `pioneer_place_words(place)`, `pioneer_ranking_params(period_choice, scope)` (omits defaults: no `period` for week, `seasons: "current"` only for current) so all links share one builder.
- [ ] `app/views/pioneer_rankings/show.html.erb` -- `content_for :back_button, true`, `:title`, `:screen_title`; root `section.pioneer-ranking.page.page--regular` with `data-controller="pioneer-ranking"`, `data-action="turbo:frame-load->pioneer-ranking#reloaded"`; visually hidden h1 "Classement des pionniers"; an empty `p#pioneer-ranking-status.visually-hidden[role=status]` (target `status`) OUTSIDE the frame; then `turbo_frame_tag "pioneer-ranking-results", target: "_top", data: { controller: "next-page", action: "focusout->next-page#focusLeft" }` holding: two GET forms of chips (`role="group"`, aria-label "Saisons du Grand Inventaire" / the periods label), each form `data: { turbo_frame: "pioneer-ranking-results", turbo_action: "advance" }`, a hidden field for the other dimension when not default, chips `button type=submit class="segmented__option" name= value= aria-pressed` with `data-action="pioneer-ranking#chose"`; the place partial; a panel with `ol#pioneer-ranking-rows` of the rows partial, or the period's empty line; the address marker `span#pioneer-ranking-address[hidden]` (target `address`, `data-url` = this page's URL); `render "library/pages", pagy: @pagy, empty: false, label: t(".pages_label")`; an element carrying the chip reading for the status (`data-pioneer-ranking-reading`: "<period>. <place words or no-discovery line>", the period alone for a visitor). After the frame, for a visitor only, the sign-in line and button.
- [ ] `app/views/pioneer_rankings/show.turbo_stream.erb` -- append the rows partial to `pioneer-ranking-rows` when any, update `pioneer-ranking-status` with "Page N chargée", replace `collection-pages` (library/pages) and `pioneer-ranking-address`.
- [ ] `app/views/pioneer_rankings/_rows.html.erb` -- `li.pioneer-row` per row: rank, `PlayerNameComponent`, "Vous" mark (gold, `.pioneer-row__you`) for the viewer's own row, count shown `aria-hidden` plus visually hidden "9 découvertes"; the viewer's row has `id="pioneer-ranking-me"`, `tabindex="-1"`, target `mine`.
- [ ] `app/views/pioneer_rankings/_place.html.erb` -- only with `@place`: `div.pioneer-place` (target `place`, keeps its height in the flow) holding one `a.pioneer-place__link` "Votre place : 14e, 1 découverte, aller à ma ligne" to `pioneer_ranking_path(..., page: place.page, anchor: "pioneer-ranking-me")`, `data-action="pioneer-ranking#go focusin->pioneer-ranking#barFocused focusout->pioneer-ranking#barLeft"`; never `role=status`/`aria-live`.
- [ ] `app/views/grand_inventories/_pioneer_boards.html.erb` -- `div.pioneer-boards` with two `section.pioneer-board` (PanelComponent, h2 "Pionniers · Semaine|Saison|Total"): `ol` of the top 3 (as rows partial look, "VOUS" beside the viewer's name), then outside the list per the matrix: place line `p.pioneer-board__place` (visible "14e · Vous · 1" `aria-hidden`, visually hidden "Votre place : 14e, 1 découverte"), or the no-discovery line, or the empty line; then `ButtonComponent variant: :link` "Voir tout le classement", aria-label per period, href `pioneer_ranking_path(**pioneer_ranking_params(choice, inventory_scope))`. For a visitor, once after both boards: `p.pioneer-boards__visitor` with the join line and `sign_in_button`.
- [ ] `app/frontend/controllers/pioneer_ranking_controller.ts` -- targets `status`, `address`, `place`, `mine`; `chose(event)` remembers the submitter's `name`; `reloaded(event)` (only for the results frame): focus the `button[name=<remembered>][aria-pressed=true]`, write the new reading into `status` (clear, then set on next frame); `addressTargetConnected` replaces the history entry when path+search differ; `mineTargetConnected/Disconnected` observe the row with an IntersectionObserver, and focus it when `location.hash` is `#pioneer-ranking-me`; `go(event)`: when the row is in the DOM, prevent default, scroll it into view (block center) and focus it, otherwise let the link load its page; pinned = row off screen or focus inside the bar, written as class `pioneer-place--pinned` on the place target; disconnect cleans the observer.
- [ ] `app/frontend/controllers/pioneer_ranking_controller.test.ts` -- happy-dom: the pinned class follows row visibility (stub IntersectionObserver) and focus inside the bar; `go` focuses an in-DOM row and prevents navigation.
- [ ] `app/frontend/styles/pioneer_rankings.css` + import -- chips rows wrap with `--space-2` gap; rows grid `rank | name | count`, `.fortune-panel__row` look, min 44px tall under 720px, count `--font-number` `--color-text-bright`; "Vous" mark `--font-label` `--color-gold`; board place in `--color-accent` under a dashed `--color-line-soft` rule; `.pioneer-boards { display: contents }`, `.pioneer-boards__visitor { grid-column: 1 / -1 }` (and `order: -1` under 720px); place bar: in-flow line with reserved `min-height`; `@media (min-height: 560px)` `.pioneer-place--pinned .pioneer-place__link` fixed at bottom 0 (`body:has(.tab-bar)`: above `--tabbar-height` + safe area), centred, `max-width: var(--page-width-regular)`, `--color-panel`, `--control-border`, `--color-accent` text, and `html:has(.pioneer-place) { scroll-padding-bottom: ... }` plus matching bottom padding on the rows panel.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `pioneer_rankings`: `show.title` ("Classement des pionniers" / "Pioneer ranking"), `show.pages_label` ("Pages du classement"), `show.page_loaded` ("Page %{page} chargée"), `show.reading`, `scopes.all|current` ("Toutes saisons"/"Saison en cours"), `scopes_label` ("Saisons du Grand Inventaire" / "Great Inventory seasons"), `periods.week|season|total` ("Semaine"/"Saison"/"Total"), `periods_label`, `rank` (fr one "%{count}er", other/zero "%{count}e"; en "#%{count}"), `discoveries` (plural "%{count} découverte(s)"), `place` ("Votre place : %{rank}, %{count} découverte(s)"), `place_link` ("…, aller à ma ligne"), `you` ("Vous"), `boards.title` ("Pionniers · %{period}"), `boards.empty.week|season|total` ("Aucune découverte cette semaine pour l'instant." / "… cette saison …" / "Aucune découverte pour l'instant."), `boards.none.week|season|total` ("Aucune découverte cette semaine." / "Aucune découverte cette saison." / "Aucune découverte à votre nom pour l'instant."), `boards.see_all` ("Voir tout le classement"), `boards.see_all_label.week|season|total` ("… de la semaine" / "… de la saison" / "… depuis toujours"), `visitor` ("Rejoignez la Confrérie pour découvrir les cartes manquantes."). English: Copy deck English where given, otherwise plain equivalents.
- [ ] `test/controllers/pioneer_rankings_controller_test.rb` -- visitor (h1, rows with names, private player listed unlinked, banned absent, no `.pioneer-place`, sign-in line); signed-in viewer (pressed chips, `#pioneer-ranking-me`, place link text and href page/anchor); `seasons=current&period=season` reads Saison and only the published season's discoveries; turbo_stream page 2 appends and says "Page 2 loaded".
- [ ] `test/helpers/pioneer_boards_test.rb` -- `ActionView::TestCase` rendering the partial for a viewer in the top 3, a viewer with a place, a viewer without discovery, an empty board and a visitor.
- [ ] `test/system/pioneer_ranking_test.rb` -- one browser test: 55 ranked players, the viewer on page 2; on page 1 the pinned link is visible and pinned; following it loads page 2 and focuses the viewer's row; pressing the Saison chip keeps focus on it with `aria-pressed="true"` and the address carries `period=season` (retrying matchers only).

**Acceptance Criteria:**
- Given a signed-in viewer ranked 14th this week, when they open the Grand Inventaire boards, then the Semaine board shows the top 3 and, outside its list, "14e · Vous · 1" read as "Votre place : 14e, 1 découverte".
- Given the viewer's row is off screen on Classement des pionniers at a viewport of 560px or taller, when they follow "Votre place …, aller à ma ligne", then the page holding their row shows and focus is on that row.
- Given a visitor, when they open Classement des pionniers, then rows are listed with names, no place link exists, and the join line with the sign-in button appears once.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The chips sit inside the results frame so the server redraws their pressed state and the second chip's label (Saison or Total); the root controller restores focus to the pressed chip after `turbo:frame-load`, and the status line lives outside the frame so it persists, empty at load. The place bar is one link that never leaves the DOM: unpinned it is the line above the list (its in-flow box keeps its height, so pinning causes no shift), pinned it is fixed at the viewport bottom; below 560px of height it is never pinned.

## Verification

**Manual checks (if no CLI):**
- Tests and suites are not run in this worktree (they run once after integration). Re-read the diff: every string in both locales, no planning id, no db id in markup, files under their size limits, only the contract's files touched.

## Auto Run Result

- **Summary:** `Game::PioneerBoard` ranks active players by first discoveries (week from Monday 00:00 UTC; season or total by scope; shared ranks, earlier-to-reach first; 50 per page; the viewer's place and page). `PioneerRankingsController#show` serves Classement des pionniers (public, read-only, scope and period chips in the results frame, numbered pages plus scroll loading, "Page N chargée" status, address following the page, the pinned "Votre place" link). `grand_inventories/_pioneer_boards` draws both boards for the Grand Inventaire screen.
- **Files:** query `app/domains/game/app/queries/game/pioneer_board.rb`; `app/controllers/pioneer_rankings_controller.rb`; `app/helpers/pioneer_rankings_helper.rb`; views under `app/views/pioneer_rankings/` and `app/views/grand_inventories/_pioneer_boards.html.erb`; Stimulus `app/frontend/controllers/pioneer_ranking_controller.ts` with its vitest; `app/frontend/styles/pioneer_rankings.css` and its import; route; `pioneer_rankings` in both locales; tests (query, controller, boards partial view test, one system test).
- **Review:** none, no lenses launched.
- **Verification:** per instruction no test, suite or linter was run in this worktree; `ruby -c` and ERB compilation passed; the diff was read in full. Each matrix row has a written test that has not run yet.
- **Residual risks:** tsc, vitest, rubocop, prettier, stylelint, i18n-tasks and packwerk not run; the boards view test is the repo's first partial rendered from `ActionView::TestCase`; `PlayerNameComponent` may query a friendship per friends-only row; the phone tab (SETS) and screen label for this page are not wired (shared `shell_helper.rb`, left to integration); no caching or rate limit on the public ranking.
