---
title: 'Collection season selector'
type: 'feature'
ticket: ''
created: '2026-10-08'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Season 2 is a real new season, but the collection only reads the published season: the season 1 cards players hold, which they keep and can trade, cannot be browsed anywhere except one card page at a time. Long-time players should see and show off what they gathered in earlier seasons.

**Approach:** The collection takes an optional earlier season in its path (`/library/seasons/:number`, `/library/seasons/:number/:kind/:key`), the published season staying the default at `/library`. A row of season chips above the sets switches between published seasons. Every figure and list of the screen (top bar status, sets and their progress, grid, filters, RAPPORT) reads the season shown, and an earlier season's card page links its sets and its phone "◀ Grille" to that season's collection. A player's public profile gets the same season chips (author's decision, 2026-10-08: friends see a veteran's earlier sets), its header counts, tabs and opened set reading the season shown.

## Boundaries & Constraints

**Always:** Seasons are addressed by number, never by id. Only published seasons are reachable; the draft never is. A GET writes nothing. The selector shows only when two or more seasons are published, the published season first. Strings in both `en.yml` and `fr.yml`. Card links keep their season (`/cards/:slug/seasons/:number`). The published season keeps its current URLs unchanged.

**Never:** No change to trades (they already list and swap held copies of every season), to draws, to the hub, the top bar's rarity counter outside the collection, or the friend profile dialog's showcase. No value, price or scarcity mark on older cards. No new `gameble:*` event, no `style` attribute.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Default | `/library`, seasons 1 and 2 published | Season 2, chip "Saison 2" current, URLs as today | No error expected |
| Earlier season | `/library/seasons/1` | Season 1's sets, grid, status, RAPPORT and filters; the player's season 1 copies | No error expected |
| Earlier season's set | `/library/seasons/1/tome/action-1` | That set of season 1, its row current | No error expected |
| Published season by number | `/library/seasons/2` | Same content as `/library` | No error expected |
| Unknown or draft season | `/library/seasons/9` or the draft's number | Not found | 404 |
| One season published | `/library` | No season chips | No error expected |
| Profile, earlier season | `/brothers/:token?season=1`, then a tab or a set | The owner's season 1 counts, started sets and set grid; tabs, pages and sets stay in season 1 | Unknown or draft season: the 404 unavailable page |
| Card page of season 1 | `/cards/:slug/seasons/1` | Its sets link to `/library/seasons/1/:kind/:key`; phone ◀ Grille leads there | No error expected |

</frozen-after-approval>

## Code Map

- `config/routes.rb` (l.22-28) -- `resource :library` and `library/:kind/:key` (kind constrained); add the two season routes, `number: /\d+/`.
- `app/controllers/library_controller.rb` -- `show`/`set` read `Catalog::PublishedSeason.call`; `load_summary` calls `Game::TierCounts.call(player)` (published season only). Resolve the season from `params[:number]` instead.
- `packs/catalog/app/queries/catalog/published_season.rb` -- the latest published season; add a sibling query listing published seasons (number desc) the controller uses for both the chips and the lookup by number, one query.
- `packs/game/app/queries/game/tier_counts.rb` -- `SQL` filters on `PUBLISHED_SEASON`; add an optional `season:` to `call`, default unchanged (booster and top bar keep it).
- `packs/game/app/queries/game/collection_summary.rb`, `packs/catalog/app/queries/catalog/{card_count,season_shelf,collection_grid}.rb` -- already take a season; reuse as is.
- `app/helpers/collection_helper.rb` -- `collection_season_path`/`collection_set_path`; thread the season shown so every link (kinds, set rows, clear, filters form via `request.path`, pagy `page_url`) stays in it. Published season → today's paths.
- `app/views/library/{_collection,_set_list,show,set}.html.erb` -- add the season chips (reuse `.collection-kinds`/`.collection-kind` look) above the kinds; pass the season and the seasons list down.
- `app/views/cards/show.html.erb` (l.18-24, l.39-40), `app/views/cards/_detail.html.erb` (l.26, l.121) -- `current_season` gates set links and ◀ Grille; link earlier seasons through the season paths instead of hiding them.
- `app/frontend/styles/collection.css` (l.142-186, phone l.628-700) -- season chip row layout only.
- `config/locales/{en,fr}.yml` -- `library.*`: the seasons nav label and chip text ("Saison %{number}").
- `app/controllers/public_profiles_controller.rb` -- `show`/`set` read `Catalog::PublishedSeason.call`; the shelf, `load_set` (`ShelfLoading`) and `Game::CollectionSummary.call(@owner, season:)` already take a season. The profile pages by query (`kind`, `page`, `tab`): carry the season as `season=<number>`, left out for the published season.
- `app/helpers/shelves_helper.rb` (`profile_shelf_links`), `app/views/public_profiles/{_profile,_set_list}.html.erb` -- tab and set URLs; add the season chips with the library's partial.
- Tests: `test/controllers/public_profiles_controller_test.rb`, `test/controllers/library_controller_test.rb`, `test/controllers/library_set_test.rb`, `test/controllers/cards_controller_test.rb`, `test/packs/game/tier_counts_test.rb`, `test/system/library_test.rb`; seeds via `CatalogSeeds#publish_sets_draft`.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/catalog/app/queries/catalog/published_seasons.rb` (+ test) -- published seasons, newest first -- chips and lookup in one query
- [ ] `packs/game/app/queries/game/tier_counts.rb` (+ test) -- optional `season:` -- RAPPORT per season
- [ ] `config/routes.rb` -- the two season routes -- earlier seasons addressable
- [ ] `app/controllers/library_controller.rb` -- season from the path, 404 for unknown, `@seasons` for the chips, season-aware summary -- one screen for every season
- [ ] `app/helpers/collection_helper.rb` -- season-aware paths -- links stay in the season
- [ ] `app/views/library/*`, `collection.css`, locales -- season chips, season threaded through -- the selector
- [ ] `app/controllers/public_profiles_controller.rb`, `app/helpers/shelves_helper.rb`, `app/views/public_profiles/*` -- season from `season`, 404 page for an unknown one, chips, links carrying it -- the veteran's profile
- [ ] `app/views/cards/show.html.erb`, `_detail.html.erb` -- earlier season's sets and ◀ Grille link to its collection -- the way back
- [ ] controller, card and system tests -- the matrix rows above

**Acceptance Criteria:**
- Given a player holding season 1 cards and season 2 published, when they pick "Saison 1", then the grid shows their season 1 copies with their season 1 rarity, and each face opens `/cards/:slug/seasons/1`.
- Given season 1 shown, when the player changes a filter, a kind, a set or a page, then they stay in season 1.

## Design Notes

The published season keeps `/library` so links from the hub, the booster and shared URLs need no change; `/library/seasons/:number` for the published number renders the same screen (no redirect needed, nothing links to it). The library carries the season in its path, like its kind and key; the profile in its query, like its kind and page. The chips are one partial both screens render. The chips sit in the aside above the kinds on desktop and in the strip on smaller layouts, the same chip look as the kinds. The planning docs say nothing on earlier seasons (seasons after the first were a later version; copies keep their minted rarity and season), so this is new UX. The pending card-series rework of the collection (`forge-card-series`) will rebuild this screen around series; the season chips sit outside the sets list so they carry over.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test:system test/system/library_test.rb test/system/card_detail_test.rb` -- expected: green
- `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bin/rails zeitwerk:check` -- expected: clean

## Implementation Notes

## Plan Change Log

## Review Triage Log
