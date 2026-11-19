---
title: 'Le Grand Inventaire: hub panel, collection tile, landing link, settings note'
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
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Le Grand Inventaire (the Brotherhood's collection screen, built in a parallel slice at `grand_inventory_path`) has no way in from the hub, the collection, the landing, and the settings do not say first discoveries stay signed.

**Approach:** Add four entry points reading only `Game::GrandInventory.new(seasons: :all)` (`#total`, `#found_count`, `#latest_discovery` → Data `card`, `player`, `discovered_at`, or nil), which the parallel slice creates together with the route; this slice creates neither.

## Boundaries & Constraints

**Always:** server HTML only, no `style` attributes; every string in both `en.yml` and `fr.yml` (French plurals with `zero`, French colon preceded by U+202F as in `pages.home.goal.reward`); new keys only in a `grand_inventory` group under the host screen's subtree; names through `PlayerNameComponent.new(player:, viewer: current_player)` (the Pioneer row's rule: link only when visible, banned/deleted "anonyme"); the see-more link is `ButtonComponent variant: :link` outside the panel frame; counts through `number_with_delimiter`.

**Never:** create `Game::GrandInventory`, the route, or keys under `grand_inventories.*`, `pioneer_rankings.*`, `brotherhood_sets.*`; card faces in the hub panel; new JS; planning ids in code; run test suites (they run after integration).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Latest discovery by a public player | newest FirstDiscovery by a visible player, 12 min ago | hub line "Dernière découverte : <card link>, par <profile link>, il y a 12 min" | — |
| Latest discoverer removed (banned/deleted) | newest FirstDiscovery by banned player | name reads the anonymous name, no profile link | — |
| Latest discoverer hidden from viewer | friends_only/private player, viewer not allowed | name as plain text, no link | — |
| Nothing found yet | no FirstDiscovery rows | count "0 / N", empty line instead of latest line | — |

</intent-contract>

## Code Map

- `app/controllers/pages_controller.rb#home` -- add `@grand_inventory = Game::GrandInventory.new(seasons: :all)` beside `@fortune_panel`.
- `app/views/pages/home.html.erb` -- render the new panel as the FIRST child of `.hub__aside` (before `pages/goal`). DOM order alone gives every width's order: grid area `aside` is the right column from 1180px and the left column under the menu from 720px (`hub-responsive.css`), and on the phone `.hub__aside` is `display: contents` after the (hidden) showcase.
- `app/views/fortune_panels/_panel.html.erb` -- model only (section + `PanelComponent` + `h2.hub-section-title`). Do NOT reuse its `hub-linked` stretched link: the new panel holds two inner links.
- `app/views/shell/_live_strip.html.erb` -- model for the see-more paragraph (`.live-strip__open` + `ButtonComponent variant: :link`).
- `app/helpers/set_rows_helper.rb#set_gained_ago(time)` -- reuse for "il y a 12 min" (public helper, lowercase copy matches the spec).
- `app/components/player_name_component.rb` -- reuse for the player name.
- Card link: `discovery.card` is assumed to be a `Catalog::CardView` (`id` is the slug, `title`, `season_number`): `link_to card.title, card_season_path(slug: card.id, number: card.season_number)` (as `feed_helper.rb:128`).
- `progress.set-row__bar` (`hub-daily-sets.css`) -- the gauge, as `library/_all_cards_tile.html.erb` uses it (`max` at least 1, `aria-hidden`).
- `app/views/library/_entry.html.erb`, `_all_sets_tile.html.erb`, `library_controller.rb#show`, `show.html.erb` -- the tile goes after `all_sets_tile` inside `.set-entry__shortcuts`, reusing the `all-cards-tile` classes exactly (no new CSS); icon `pixel_icon("achievement-ledger", ...)`.
- `app/views/landings/_live.html.erb` -- one more `ButtonComponent variant: :link` in `.landing-live__links` after the Chattomètre link.
- `app/views/settings/_profile_summary.html.erb` -- note under `.settings-summary__visibility` when visibility is `private` or `friends_only`; style in `app/frontend/styles/settings-summary.css` (reuse the existing muted body-small rule by adding the selector).
- `app/frontend/entrypoints/application.css` -- import the new `grand-inventory-panel.css` next to `fortune-panel.css`.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/pages_controller.rb` -- assign `@grand_inventory` in `home`.
- [x] `app/views/pages/_grand_inventory_panel.html.erb` -- `section.grand-inventory-panel[aria-labelledby=grand-inventory-panel-title]` holding `PanelComponent(class: "grand-inventory-panel__frame")` with: a head row (`h2#grand-inventory-panel-title.hub-section-title` "Le Grand Inventaire" + count `found / total` aria-hidden + visually-hidden spoken form), the gauge, then either the latest line (`t(".latest_html", card:, player:, ago:)`) or the empty line; after the frame `p.grand-inventory-panel__open` with the link to `grand_inventory_path`.
- [x] `app/views/pages/home.html.erb` -- render it first in `.hub__aside`.
- [x] `app/frontend/styles/grand-inventory-panel.css` + import -- panel low: compact 12px padding (`--space-4`), head row flex baseline space-between, count in `--font-number` `--color-text-bright`, latest line in `--font-label` `--color-text`, empty line muted; tokens only; phone: link button stretches as `.live-strip__open`.
- [x] `app/views/library/_grand_inventory_tile.html.erb`, `_entry.html.erb`, `show.html.erb`, `library_controller.rb` -- tile `a.all-cards-tile[href=grand_inventory_path]`: title "Le Grand Inventaire", count `found/total` (as All my cards' `count` + `total` spans), unit "découvertes"; controller passes `@grand_inventory`.
- [x] `app/views/landings/_live.html.erb` -- link "Voir le Grand Inventaire".
- [x] `app/views/settings/_profile_summary.html.erb` + `settings-summary.css` -- the note.
- [x] `config/locales/en.yml`, `fr.yml` -- `pages.home.grand_inventory.{title,spoken,latest_html,empty,open}`, `library.entry.grand_inventory.{title,unit}`, `landings.show.live.grand_inventory.open`, `settings.show.summary.grand_inventory.signed`; en.yml keeps its alphabetical order.
- [x] Tests: `test/controllers/hub_grand_inventory_panel_test.rb` (matrix rows + order: first in `.hub__aside`, before `#community-goal`; one see-more link outside `.panel`; no `.card`), `library_controller_test.rb` (tile after All sets), `landing_page_test.rb` (link), `settings_controller_test.rb` (note for friends_only/private, absent for public).

**Acceptance Criteria:**
- Given a signed-in player, when the hub renders, then the Grand Inventaire panel is the first block of `.hub__aside`, shows `found / total` with a gauge, and "Voir le Grand Inventaire" sits outside its frame.
- Given the collection opening, when it renders, then the third shortcut tile, after "Tous les sets", links to the Grand Inventaire with `found/total` "découvertes".
- Given a visitor on the landing, when 04 · En direct renders, then "Voir le Grand Inventaire" follows "Voir Le Chattomètre".
- Given a friends-only or private player, when the settings render, then the summary carries "Vos premières découvertes restent signées de votre nom dans le Grand Inventaire."; a public player sees no such note.

## Implementation Notes

- Partials use full i18n keys (`pages.home.grand_inventory.*`), since a lazy `.key` in `pages/_grand_inventory_panel` would resolve under `pages.grand_inventory_panel`.
- The hub now runs the inventory's queries: `PLAYER_HUB_QUERIES` in `test/controllers/pages_controller_test.rb` must be raised by however many queries `Game::GrandInventory` (`#total`, `#found_count`, `#latest_discovery`) costs, once the parallel slice lands.
- Untested here: `Game::GrandInventory` and `grand_inventory_path` do not exist in this slice; templates were syntax-compiled, rubocop, stylelint, prettier, i18n-tasks missing, planning-id and file-size checks pass.

## Plan Change Log

## Review Triage Log

## Design Notes

Copy (fr / en): title "Le Grand Inventaire" / "The Great Inventory"; spoken "%{found} cartes découvertes sur %{total}" / "%{found} cards discovered out of %{total}" (count-keyed zero/one/other); latest "Dernière découverte : %{card}, par %{player}, %{ago}" / "Latest discovery: %{card}, by %{player}, %{ago}"; empty "Aucune carte découverte pour l'instant." / "No card discovered yet."; link "Voir le Grand Inventaire" / "See the Great Inventory"; tile unit "découvertes" / "discoveries" (zero/one/other); note "Vos premières découvertes restent signées de votre nom dans le Grand Inventaire." / "Your first discoveries stay signed with your name in the Great Inventory."

Tests build real `Game::FirstDiscovery` rows: fixtures already sign every fixture card to the banned player two weeks ago; move one row to another player with `update_columns(player_id:, discovered_at: 12.minutes.ago)`, or `delete_all` for the empty state. Expected figures come from `Game::GrandInventory.new(seasons: :all)` (the parallel slice's query), so the tests stay true to its definition of total.

## Verification

**Manual checks (if no CLI):**
- Suites are not run in this slice (they run once in the main tree after integration). Inspect the diff: no `style` attribute, every new key in both locale files, no planning ids, files under 400 lines.
