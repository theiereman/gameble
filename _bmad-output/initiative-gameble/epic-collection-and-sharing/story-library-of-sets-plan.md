---
title: 'Library of sets'
type: 'feature'
ticket: '1'
created: '2026-10-02'
status: 'built'
baseline_revision: '9fcb676c45d10de4d706ceabb328a3c241be06f8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/epic-collection-and-sharing.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Players collect cards but cannot see their collection or its sets; the attic's lectern leads nowhere (CAP-6; epic 4, R1, R6, R7).

**Approach:** The lectern opens the library: the published season's sets as tomes on a shelf, in three tabs (tomes, publishers, best rated of the year), each with its localised name and the viewer's owned / total distinct cards; a visitor sees every set at 0 / total. Catalog answers the sets and their sizes, Game answers a player's progress per set with one join, the web layer pages, labels and joins them.

## Boundaries & Constraints

**Always:**
- `Catalog::SeasonShelf.relation(kind:)`: the published season's sets of that kind as an ungrouped, ordered `Catalog::Set` relation — publisher by `key`; tome by `params->>'genre'`, `(params->>'volume')::int`; best of year by `key DESC` — (tomes follow the English genre keys in every locale; accepted). `Catalog::SetTotals.call(set_ids)` → `{ set_id => member count }`.
- `Game::SetProgress.call(player, set_ids)` → `{ set_id => owned }`: one grouped query joining `catalog_set_memberships` to the player's `game_holdings` with `quantity > 0` (Game may read Catalog's tables, AD-2); any player, never `current_player` implicitly (4.4 passes another player); `{}` with no query for nil. A card in several sets counts in each; copies count once.
- `LibraryController#show` (`include Pagy::Method`, `@pagy, sets = pagy(:offset, relation, limit: 50)`; Pagy added at the Stack's 43.6.3; `Pagy::I18n.locale` set from `I18n.locale` on every request, with `pagy.*` overrides in `fr`/`en` in the Brotherhood's voice; out-of-range page → the empty shelf text, a non-integer page → page 1); `kind` from a whitelist, anything else (blank, array, unknown) → `tome`. Policy: the existing `PagePolicy#show?` (everyone).
- Labels: `SetLabel` in the web layer (`app/components/set_label.rb`, beside `CardStrings`): a publisher set shows `params["publisher"]`; a tome `catalog.sets.tome` ("%{genre} · Tome %{volume}"); best of year `catalog.sets.best_of_year` ("Best rated of %{year}" / "Les mieux notés de %{year}"); genres from `catalog.genres.<key>` for Steam's whole genre list (action, adventure, casual, indie, massively_multiplayer, racing, rpg, simulation, sports, strategy, free_to_play, early_access, violent, gore, nudity, sexual_content, utilities, education, design_illustration, animation_modeling, audio_production, video_production, photo_editing, software_training, web_publishing, game_development, accounting, movie, documentary, episodic, short, tutorial, 360_video) in `fr` and `en`, an unknown key humanised (English in `fr`; accepted). Tab names `library.show.tabs.*` ("Tomes", "Publishers"/"Éditeurs", "Best rated of the year"/"Les mieux notés de l'année").
- Page: `GET /<locale>/library?kind=…&page=n`; a shelf partial `library/_shelf` (tabs, spines with label and "owned / total", Pagy's `series_nav` styled in `library.css`), reusable by 4.2 and 4.4; spines are not links yet (4.2 adds its route and links them); per-tab empty text when the season has no set of that kind; no-season empty text; the layout's `content_for(:back_button)`. The decorated room per DESIGN.md and `key-screens.html`.
- Attic: the lectern's art and name are wrapped in `<a class="attic__link">` (figure classes kept, focus outline in ink, `data-turbo-prefetch="false"`); `pages_controller_test.rb` changes from "no object holds a link" to "only the lectern holds one"; the view comment is updated.
- Queries per library request, asserted exactly with `assert_queries_count` on 2.7's published `seed_sets_draft`: player — player lookup, published season, Pagy count, set page, totals, progress (6); visitor — the same without the lookup and progress (4).
- AD-11's reading role is not configured yet; deferred.

**Never:** no tome contents or links (4.2); no card detail (4.3); no profile (4.4); no status-band counts; no id of a set or card-season in the page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player | owns 3 of a tome's 25 cards, one twice | that tome shows 3 / 25 | — |
| Several sets | a card in a publisher set and a tome | counted in both | — |
| Quantity 0 | a holding at 0 (after a trade) | not counted | — |
| Visitor / banned | signed out, or a banned player | every set 0 / total; no ownership query | — |
| Tabs | `kind=publisher`; unknown, blank or array kind | publisher sets; the tome tab | — |
| Empty tab | no publisher set in the season | the per-tab empty text | — |
| Labels | `free_to_play` tome 2 in `fr`; unknown genre `xyz`; best of 2011 | French genre label · Tome 2; "Xyz · Tome 1"; "Les mieux notés de 2011" | — |
| Order | tomes action-2, action-10, adventure-1 | action 2, action 10, adventure 1 | — |
| Pages | 120 tomes; `page=9`; `page=abc` | 50 / 50 / 20; empty shelf text; page 1 | — |
| No season | nothing published | empty-state text | — |
| Queries | player / visitor | 6 / 4 | — |
| Lectern | the attic | the lectern links to the library; other objects hold no link; six names | — |

## Code Map

- `packs/catalog/app/models/catalog/{set,set_builder}.rb`, `app/queries/catalog/{published_season,season_summaries}.rb` -- sets, params, kinds.
- `packs/game/app/models/game/holding.rb`, `app/queries/game/*` -- holdings.
- `app/views/pages/home.html.erb` (lectern figure), `app/frontend/styles/attic.css`, `app/controllers/packs_controller.rb` (controller pattern), `app/policies/*`, `config/routes.rb`, `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml`.
- `test/support/catalog_seeds.rb` (`seed_sets_draft`), `test/support/game_packs.rb`.
- `_bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html` (`library()`, `.shelf`, `.tome`, `.tabs`).

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile` -- `pagy` at the Stack's version.
- [x] `packs/catalog/app/queries/catalog/{season_shelf,set_totals}.rb`, `packs/game/app/queries/game/set_progress.rb`, `app/components/set_label.rb`, `config/initializers/pagy.rb`.
- [x] `app/controllers/library_controller.rb`, route, `app/views/library/{show,_shelf}.html.erb`, `app/frontend/styles/library.css`, lectern link and its test, locales.
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a player who owns cards of a published season, when they click the lectern, then the library lists the season's tomes with their names and owned / total, the other tabs work, and a visitor sees the same sets at 0 / total.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Catalog::SeasonShelf.relation(kind:)` returns nil when no season is published (one query); the shelf partial shows the no-season text for nil spines.
- `LibraryController` clamps `page` to 1..`MAX_PAGE` (100 000) before Pagy, so a huge page cannot overflow PostgreSQL's OFFSET; past the last page the shelf shows `library.show.past_the_end`, distinct from the per-tab empty text (count 0).
- Pagy's dictionary lives in `config/locales/pagy/{en,fr}.yml` (plural rule and page-link words in the Brotherhood's voice), read by `Pagy::I18n` from that folder only; `i18n-tasks` ignores `pagy.*` and `catalog.genres.*` as unused (looked up dynamically).
- `library.show.progress` is pluralised on the owned count; `fr` adds a `zero` form, as the app's plural rule does not treat 0 as singular.
- `SetLabel` raises ArgumentError on a malformed set (unknown kind, tome without genre).
- The lectern's name is a `<span class="attic__name">` inside the link (a figcaption cannot sit inside `<a>`).
- `LibraryController::Spine` (label, owned, total) carries no id; 4.2/4.4 render `library/_shelf` with `kind`, `spines`, `pagy`, `tab_url`.
- Query counts are asserted after clearing the test connection's query cache, which otherwise survives between integration requests; a banned player costs the lookup plus the visitor's four, with no `game_holdings` query.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 1, low 5, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | A huge `page` raised a PG bigint overflow (500) | Reproduced. Page clamped to 1..100,000; past-the-end shelf shown; test. |
| 2 | low | patch | Pagy safe-loaded the whole app locale files (would fail on any Symbol) | Dictionary moved to `config/locales/pagy/`; Pagy reads that folder only. |
| 3 | low | patch | Progress text had no plurals | one/other (+ French zero) forms with `count:`; test in both locales. |
| 4 | low | patch | A tome without a genre rendered " · Tome " | `SetLabel` raises `ArgumentError`; test. |
| 5 | low | patch | Banned-player row's "no ownership query" untested | Asserts no `game_holdings` query; 5 queries (the session lookup finds the ban). |
| 6 | low | patch | Attic comment not re-wrapped | Re-wrapped. |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
