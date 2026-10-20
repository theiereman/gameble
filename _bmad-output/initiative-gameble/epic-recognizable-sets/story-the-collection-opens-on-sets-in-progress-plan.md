---
title: 'The collection opens on sets in progress'
type: 'feature'
ticket: '7'
created: '2026-10-17'
status: done
baseline_revision: 'f0769610adc54b9e9568edd7264c031c9db2623b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The public profile's "complete sets" figure (Game::CollectionSummary) still counts only the published season's exact editions, while the set rows beside it count a game held in any edition.
    evidence: |-
      A set completed partly with earlier-edition copies shows COMPLET in the profile's rows but is left out of the header's count; the figure predates this change and entry 15 replaces every collection read of the published season only.
    location: >-
      packs/game/app/queries/game/collection_summary.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The collection opens on a grid of every card beside a shelf of sets by kind, the hub lists sets by share owned, and a public profile opens on tabs of sets; none shows what the player is close to completing, and set progress counts only the published season's exact edition.

**Approach:** One Game query measures every started set of the published season for a player, counting games held in any edition (Game::HeldGames), with each set's size, its tier thresholds (`catalog_set_tiers`), the latest gain touching it (holdings' `last_gained_at`) and whether a tier row (`game_set_tiers`) was written at the player's latest gain. A board ranks them into "EN COURS" and "À DÉCOUVRIR" (filled with popular sets), which the collection's new entry screen (`/library`), a public profile and the hub ("SETS EN COURS", four rows) render as set progress rows, beside a search over every set; the grid moves to `/library/cards` behind "TOUTES LES CARTES ▸".

## Boundaries & Constraints

**Always:**
- A set's progress (`held`) = its published-season members whose game (`card_id`) the player holds in any season with `quantity > 0`. No migration.
- Standing of a set, from `held`, `total` (member count) and its `catalog_set_tiers` (`required` per tier; a set with no tier rows is complete at `total`): reached tier = the highest of bronze/silver/gold/complete whose `required <= held`; next = the lowest tier whose `required > held`; missing = next's `required - held`; complete = `held >= total > 0`; tiered = it has a bronze row.
- "Just progressed" = the set holds a game whose latest `last_gained_at` equals the player's latest `last_gained_at` over all their holdings; "reached now" = a `game_set_tiers` row of the player for that set has `reached_at` equal to that latest time.
- In progress = started and (`held >= 2` or a tier reached), and not complete unless reached now. EN COURS = the in-progress sets ordered: just progressed first (reached now before the rest), then missing ascending, share `held/total` descending, set id; at most 10.
- À DÉCOUVRIR = started sets not in progress and not complete (one game held), by latest gain descending then set id, then filled with popular sets the player has not started; 4 rows. Popular = the published season's sets by average `review_count` of their members (null as 0) descending, then id.
- Hub "SETS EN COURS" = the first four of EN COURS, filled from À DÉCOUVRIR to four; a visitor gets four popular sets.
- Search (EXPERIENCE.md, Set search): a GET form `role="search"` on the entry and the profile, labelled by its h2 "CHERCHER UN SET"; matches the query (accent- and case-insensitive, stripped, at most 100 characters) inside the set's localized name or its kind's name, over every set of the published season; names starting with the query first, then by name; at most 50 rows shown under the h2 "RÉSULTATS" with the count in a polite status line; "Aucun set trouvé pour « … »." when none; blank query shows no results section. Applied 300 ms after typing stops into a Turbo frame (the field is never replaced, so focus stays), URL replaced; Esc clears a non-empty field and the results. Works without JavaScript (a submit button in `<noscript>`).
- Set progress row (DESIGN.md Collection, "Set progress row" and "Tier marks"): name (wraps, never truncates), kind in muted label (THÈME, FRANCHISE, STUDIO, PALMARÈS, OVNI), the reached tier's name with 1–3 filled notches in its colour (bronze `--color-tier-bronze`, silver `--color-tier-silver`, gold `--color-gold`), or the small COMPLET mark (frame beside the word, lime) for a complete set, then "owned/total" and a `<progress>` bar; a tiered set's bar carries three ticks at 10 %, 25 %, 50 % with 1, 2, 3 notches below (reached: solid, risen 4 px; not reached: dashed `--color-line-deep`); untiered rows have no ticks. Bar, ticks and visible parts `aria-hidden`; the link's text is the sentence "{set}, {kind}, {owned} cartes sur {total}[, palier {tier}][, {next} à {threshold}][, complet]" (next only when it is bronze, silver or gold; a complete set reads only ", complet"). Phone (< 720 px): kind and tier mark on a second line. Positions by CSS classes: no `style` attribute.
- Entry layout: one centred column, max 880 px: visually-hidden h1 "Collection"; h2 "EN COURS" (section omitted when empty), h2 "À DÉCOUVRIR", then the search h2 with "TOUTES LES CARTES ▸" on the same line (entry only, not on a profile), then RÉSULTATS. The top bar keeps the unique-cards status.
- Public profile (`brothers/:token`): the summary, then the same EN COURS, À DÉCOUVRIR and search with the owner's progress, never the viewer's; rows lead to `brother_set_path`. Friends see a friends-only profile through it as `Game::Visibility` already decides; the friend profile dialog is unchanged.
- Fixed query counts whatever the number of sets or holdings (no per-set query); every GET writes nothing; no database id in HTML or URLs (sets by kind and key); every string in `en.yml` and `fr.yml`, French plurals with `zero`; code without planning ids or explanatory comments beyond external constraints.

**Never:**
- No album (entry 8), no `aria-current` "last album opened" marking, no change to the grid's filters or the set filter (entry 9), no one-card-per-game grid (entry 15), no public profile redesign (screen walkthrough), no friend profile change, no change to the tier pass or the celebration.
- No new table, column or index; no caching layer for popularity.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Closest first | Franchise 2/3, theme 29/62 silver (gold 31), studio 3/5, theme 40/77 gold, none just progressed | EN COURS: franchise (1 missing), then the two missing 2 by share desc (studio .6, theme .47), then gold theme (37) | — |
| Just progressed | Latest opening added a card to a theme at 12/62 and reached its bronze | that theme leads EN COURS, its row shows BRONZE | — |
| One game held | Theme 1/18 touched by the latest gain | in À DÉCOUVRIR, not EN COURS | — |
| New player | No holding | no EN COURS section; À DÉCOUVRIR shows 4 popular sets at 0/total | — |
| Earlier edition | Player holds a game only in season 1; published season 2's theme has it | counts 1 in season 2's theme | — |
| Complete set | Franchise 3/3, completed earlier | not in EN COURS; search shows it with COMPLET | — |
| Search | `q=souls` | RÉSULTATS lists Souls-like; status "1 set trouvé" | — |
| Search none | `q=zzz` | "Aucun set trouvé pour « zzz »." | — |
| Visitor on profile | signed out, public owner with progress | owner's EN COURS rows | hidden owner → unavailable 404 as today |
| No season | none published | entry shows the no-season line; hub no panel | — |

</intent-contract>

## Code Map

- `packs/game/app/queries/game/held_games.rb` -- add `MAX(game_holdings.last_gained_at) AS gained_at` to `SQL`; `call` keeps answering `{ card_id => rarity }` (select the two columns explicitly). `SetTier::RECORD_SQL` embeds `SQL` and only reads `card_id`.
- `packs/game/app/queries/game/sets_in_progress.rb` (new) -- one statement: `WITH held AS (HeldGames::SQL), latest AS (SELECT MAX(gained_at) …), progress AS (members of the season's sets joined through `catalog_card_seasons.card_id` to held, grouped by set: held count, MAX(gained_at))` then per started set: total (member count subquery), tiers (`json_object_agg(tier, required)` from `catalog_set_tiers`), `just` (gained_at = latest), `reached_now` (EXISTS `game_set_tiers` row of the player, set, `reached_at` = latest). Answers `{ set_id => Game::SetStanding }`; `{}` for nil player or season, no query.
- `packs/game/app/models/game/set_standing.rb` (new) -- `Data.define(:set_id, :held, :total, :tiers, :just, :reached_now)` with `reached_tier`, `next_tier`, `next_required`, `missing`, `complete?`, `tiered?`, `in_progress?`, `share`; tier order `Catalog::SetTier::TIERS`.
- `packs/game/app/queries/game/set_board.rb` (new) -- `call(player, season:, in_progress: 10, discover: 4)` → `Board(in_progress:, discover:, standings:)` of `SetStanding`s (popular fill at held 0 with their figures), per the ranking rules; `hub(player, season:)` → four standings. Uses `SetsInProgress`, `Catalog::PopularSets`, `Catalog::SetFigures`.
- `packs/catalog/app/queries/catalog/popular_sets.rb` (new) -- `call(season:, limit:, exclude: [])` → set ids by average member `review_count` desc, id; one grouped query; `[]` for limit ≤ 0 without a query.
- `packs/catalog/app/queries/catalog/set_figures.rb` (new) -- `call(set_ids)` → `{ set_id => Figures(total:, tiers:) }` in one query.
- `packs/game/app/queries/game/hub_sets.rb` + `test/packs/game/hub_sets_test.rb` -- delete (replaced by `SetBoard.hub`).
- `packs/game/app/queries/game/set_progress.rb`, `started_sets.rb` -- count/started by game in any edition (join through `catalog_card_seasons.card_id` and HeldGames' rule), so the remaining shelves agree with the rows; adapt their tests.
- `app/models/set_search.rb` (new, web layer since names come from `SetLabel`) -- `call(season:, query:, locale:)` over `Catalog::SeasonShelf.every_kind(season:)` (one query): normalized match (`I18n.transliterate(...).downcase`) on `SetLabel.for(set)` and the kind name; returns `Result(sets:, count:)`, sets capped at 50.
- `app/controllers/concerns/set_board_loading.rb` (new) -- builds `@in_progress`, `@discover`, `@results`, `@results_count`, `@query` as `SetRow`s (`Data.define(:set, :standing)`): loads the shown `Catalog::Set`s with `Catalog::SetsById` (one query), `Catalog::SetFigures` for search results not started (one query).
- `config/routes.rb` -- `get "library/cards" => "library#cards", as: :library_cards` (the grid); `library` stays the entry; rewrite the touched route comments without planning ids.
- `app/controllers/library_controller.rb` -- `show` = entry (season, unique and season cards for the top bar, board, search); `cards` = today's `show` body; `set` unchanged. Rewrite the header comment, no planning ids.
- `app/helpers/collection_helper.rb` -- `collection_season_path` → `library_cards_path`; `app/controllers/cards_controller.rb:132` grid back → `library_cards_path`.
- `app/controllers/public_profiles_controller.rb` -- `show`: board for `@owner` + search instead of the shelf; keep `set` and `STARTED` for the set page. `app/views/public_profiles/_profile.html.erb` renders the summary then the entry sections (no TOUTES LES CARTES).
- `app/controllers/pages_controller.rb#set_rows` -- `Game::SetBoard.hub`, rows named via `SetsById`; `app/views/pages/_set_progress.html.erb` -- title "SETS EN COURS", the new row partial, "TOUT VOIR ▸" to `library_path`.
- Views (new): `app/views/library/show.html.erb` (entry), `cards.html.erb` (old show), `_entry.html.erb` (sections + search, locals: rows, search url, show_all_cards), `_set_search.html.erb`, `_set_progress_row.html.erb` (the row, locals: href, set, standing). `library/_set_row.html.erb` and `public_profiles/_set_row.html.erb` stay for the old shelves.
- `app/helpers/set_rows_helper.rb` (new) -- the row's sentence, kind name, tier mark.
- `app/frontend/controllers/set_search_controller.ts` (new) -- 300 ms debounce `requestSubmit`, IME guard, Esc clear + submit, copies the frame's result summary into the status line on `turbo:frame-load`; pure parts in `app/frontend/lib/set_search.ts` with `set_search.test.ts`.
- `app/frontend/styles/collection.css` (entry column, sections, search line, results) and `hub.css` (`.set-row` grows kind, tier mark, ticks, notches, COMPLET mark, phone second line; reuse `feed.css` tier visuals as reference: `feed.css:132-190`).
- `config/locales/{en,fr}.yml` -- `library.entry.*` (in_progress "En cours"/"In progress", discover "À découvrir"/"To discover", search "Chercher un set"/"Find a set", all_cards "Toutes les cartes"/"All cards", results "Résultats"/"Results", found zero/one/other "Aucun set trouvé"/"1 set trouvé"/"%{count} sets trouvés", none "Aucun set trouvé pour « %{query} »."/"No set found for “%{query}”.", search_button), `library.set_kinds.*` (Thème, Franchise, Studio, Palmarès, OVNI / Theme, Franchise, Studio, Hall of fame, UFO), `library.set_progress.*` (sentence parts with zero/one/other "%{owned} carte sur %{total}" …, tier "palier %{tier}", next "%{tier} à %{required}", complete "complet"; tier names Bronze/Argent/Or/Complet), `pages.home.sets.title` → "Sets en cours"/"Sets in progress". Remove keys left unused (`i18n-tasks unused`).
- Tests: `test/packs/game/sets_in_progress_test.rb`, `set_board_test.rb`, `test/packs/catalog/popular_sets_test.rb`, `set_figures_test.rb`, `test/models/set_search_test.rb`; `test/controllers/library_controller_test.rb` (grid tests move to `library_cards_path`; new entry tests), `library_set_test.rb`, `cards_controller_test.rb`, `public_profiles_controller_test.rb` (shelf/tab tests on `show` replaced by entry tests; set page tests kept), `pages_controller_test.rb` (hub rows, query count), `test/integration/shell_test.rb`, `content_security_policy_test.rb`, `card_preview_tags_test.rb` as needed. Fixtures/helpers: `test/support/catalog_seeds.rb` (`publish_sets_draft`), `test/support/game_sets.rb` (`insert_set`), `test/support/library_requests.rb` (`hold`, `set_members`). System tests: update only obvious `library_path` → `library_cards_path` grid visits; do not run them.

## Tasks & Acceptance

**Execution:**
- [ ] `held_games.rb`, `set_standing.rb`, `sets_in_progress.rb`, `set_board.rb`, `popular_sets.rb`, `set_figures.rb`, `set_progress.rb`, `started_sets.rb`; delete `hub_sets.rb` -- measure and rank.
- [ ] `config/routes.rb`, `library_controller.rb`, `collection_helper.rb`, `cards_controller.rb`, library views -- entry at `/library`, grid at `/library/cards`.
- [ ] `set_search.rb`, `set_board_loading.rb`, `set_rows_helper.rb`, `_entry`, `_set_search`, `_set_progress_row` -- entry sections, rows, search.
- [ ] `public_profiles_controller.rb`, `_profile.html.erb` -- the owner's entry on the profile.
- [ ] `pages_controller.rb`, `_set_progress.html.erb` -- hub "SETS EN COURS".
- [ ] `set_search_controller.ts`, `lib/set_search.ts`(+test), CSS, locales.
- [ ] Tests covering every matrix row, the query counts, no ids, GET writes nothing, both locales; adapt moved tests.

**Acceptance Criteria:**
- Given a player with progress in several sets, when they open `/en/library`, then EN COURS lists their sets closest to their next tier or completion first, each row's link text is the full sentence, and the request costs the same number of queries with 3 or 40 started sets.
- Given a player who holds no card, when they open the collection, then À DÉCOUVRIR shows four popular sets at 0 and there is no EN COURS heading.
- Given a season with a Souls-like theme, when `GET /fr/library?q=souls`, then RÉSULTATS lists "Souls-like" and the status reads "1 set trouvé".
- Given a public owner with progress, when a signed-out visitor opens their profile, then the owner's EN COURS rows show and lead to the owner's set pages.
- Given a player with at least four started sets, when they open the hub, then "Sets in progress" shows four rows in EN COURS order and "See all" leads to `/library`.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass (unused: only the pre-existing `rate_limit.*`).

## Implementation Notes

- `Game::SetStanding` carries a seventh field, `gained_at` (the latest gain in the set), which À DÉCOUVRIR needs for its "latest gain descending" order; `SetStanding.unstarted` builds the popular fill and the search's unstarted sets at 0.
- "Held in any edition" is one shared relation, `Game::HeldCards` (new), used by `SetProgress` and `StartedSets`.
- The hub hides "SETS EN COURS" when it has no row (a player whose only sets were completed before their latest gain); a visitor's hub shows four popular sets under that title.
- The hub's player request drops from 20 to 19 queries, a visitor's rises from 6 to 7 (popular sets, their figures, the sets named). The entry costs 11 queries for a player with a search, whatever the sets started; a visitor's profile 7.
- The search status line sits inside the form (a Stimulus target must be inside the controller's element); the frame carries a hidden count line the controller copies on `turbo:frame-load`.
- Layout checked in headless Chromium on a scratch database (desktop 1280, phone 390): profile entry with search, French phone profile, visitor hub. Not checked: the collection entry signed in, the grid at `/library/cards`.

## Plan Change Log

## Review Triage Log

### 2026-10-17 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A profile set page's kind tabs linked to `brother_path(kind:)`, which `show` no longer reads, so every tab landed on the profile entry — fixed: `set` opens the tab named by `tab` among its tabs, `profile_shelf_links` takes the open set and links each tab to that set's page; a request test covers the UFOs, Started and Themes tabs.
  - `[low]` `[patch]` `SetSearch.normalize` used `I18n.transliterate`, which turns every non-Latin character into "?", so a Japanese or Korean studio could not be found and "?" matched unrelated sets — fixed: NFKD decomposition and removal of combining marks; tests find a set by a Japanese and a Korean name and nothing for "?".
  - `[low]` `[defer]` The profile header's complete-sets count still reads the published season's exact editions while the rows count any edition — pre-existing figure, which entry 15 moves to every edition; recorded in `deferred`.
  - `[low]` `[patch]` No request test showed the hub's four sets in progress in board order — added: five themes in progress, four rows on `/en` in order with their links, "See all" to `/en/library`.
  - `[low]` `[patch]` The new files carried explanatory comment headers against AGENTS.md's no-comment rule — deleted; only the one-line IME constraint remains.
  - `[low]` `[patch]` Deleted tests left double blank lines in `public_profiles_controller_test.rb` — collapsed.

## Design Notes

- **Reached from the counts, not the rows:** a row's tier comes from `held` against `catalog_set_tiers`, so a new season's grown sets show the progress kept, less what they add (the staging check). `game_set_tiers` only says which sets the latest opening celebrated, so they lead EN COURS as the celebration promises.
- **One game held is "touched", not "in progress":** the mock puts Pirates 1/18 in À DÉCOUVRIR while Dark Souls 2/3 leads EN COURS; without this, every card's three or four sets at 1 would flood EN COURS (bronze often one card away).
- **Caps:** EN COURS 10, À DÉCOUVRIR 4 ("a few"), results 50; the search reaches every set.
- **Grid route:** the entry takes `/library` (the mock's URL), so the grid moves to `/library/cards` now; entry 9 reworks its filters.

## Verification

**Commands:**
- `bin/ci` -- expected: green (revert any stray `package-lock.json` "license" line it writes)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (unused: pre-existing `rate_limit.*` only)

**Manual checks (if no CLI):**
- System tests are disabled; the row's layout at phone width was not viewed in a browser unless the implementer can.

## Auto Run Result

- **Summary:** the collection's entry (`/library`) opens on "En cours" (the player's sets with two games or more, or a tier reached, closest to their next tier or completion first, those the latest gain touched leading and those it raised a tier of first; at most ten), "À découvrir" (sets touched by one game, the latest first, filled with the season's most popular sets to four) and a search over every set of the published season (names and kinds, accents and case ignored, 300 ms debounce into a Turbo frame, Esc clears, works without JavaScript). Rows show the kind, the reached tier or COMPLET, owned/total and a bar with the tier ticks, and read as one sentence. A public profile shows the same sections with the owner's progress, leading to the owner's set pages; the hub's panel is "Sets en cours", four rows. Progress counts a game held in any edition (`Game::HeldGames`, now with the latest gain); the grid moved to `/library/cards`.
- **Files:**
  - `packs/game/app/queries/game/{sets_in_progress,set_board,held_cards}.rb`, `packs/game/app/models/game/set_standing.rb`, `held_games.rb` — the measure, the standing, the ranking.
  - `packs/catalog/app/queries/catalog/{popular_sets,set_figures}.rb` — popular sets by average review count, set sizes and tiers.
  - `set_progress.rb`, `started_sets.rb` — any edition counts on the remaining shelves; `hub_sets.rb` and its test deleted.
  - `config/routes.rb`, `library_controller.rb`, `collection_helper.rb`, `cards_controller.rb` — entry at `/library`, grid at `/library/cards`.
  - `app/models/set_search.rb`, `set_board_loading.rb`, `set_rows_helper.rb`, `library/{show,_entry,_set_search,_set_progress_row}`, `library/cards` (the old show) — the entry and its rows.
  - `public_profiles_controller.rb`, `shelves_helper.rb`, `public_profiles/{_profile,show,set}` — the profile's entry; the set page's tabs stay on it.
  - `pages_controller.rb`, `pages/_set_progress` — the hub panel.
  - `set_search_controller.ts`, `lib/set_search.ts` (+ test), `collection.css`, `hub.css`, `profile.css`, locales.
  - Tests: new Game, Catalog and SetSearch tests; library, profile, hub, cards, card preview tests adapted; system tests' grid visits moved to `library_cards_path` (not run).
- **Review:** 5 patches applied (1 medium, 4 low); 1 deferred (low: the profile header's complete-sets figure, to entry 15); 0 rejected.
- **Follow-up review:** false — one medium patched (on first pass `true` needs a high or two mediums).
- **Verification:** `bin/ci` green (2681 runs, 0 failures; rubocop, brakeman, audits, seeds); `npm run test:js` 345 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing` green, `unused` only the pre-existing `rate_limit.*`. `bin/ci` wrote the stray `package-lock.json` "license" line, reverted.
- **Residual risks:** the signed-in collection entry and `/library/cards` were not viewed in a browser (profile, French phone profile and visitor hub were, in headless Chromium); system tests that reach the collection through the hub menu or tab bar and expect the grid now land on the entry; "just progressed" counts a duplicate gained at the latest gain as touching its sets; the popular-sets aggregate runs over the season's memberships on each hub view of a player with fewer than four sets and each visitor hub; the staging check after a new season (progress kept, less what grown sets add) is the author's.

