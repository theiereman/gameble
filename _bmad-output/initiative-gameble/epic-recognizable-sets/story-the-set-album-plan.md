---
title: 'The set album'
type: 'feature'
ticket: '8'
created: '2026-10-17'
status: 'built'
baseline_revision: 'b1dcf6e5f91e81f2dd031179a2df4b031dbdddff'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A set opens today as the collection grid scoped to it (`/library/:kind/:key`, beside a shelf of sets with filters) or, on a public profile, as a grid beside tabs of shelves; neither shows the set's tiers or completion, and both count only the published season's exact edition.

**Approach:** Both set pages become the set album (DESIGN.md Collection "Set album", "COMPLET stamp", "Tier marks", "Missing-card slot"; EXPERIENCE.md "Set album"; mock `ux-gameble/mockups/key-collection-sets.html` panels 2 and 3): a header panel (name, kind, owned/total, progress bar with tier ticks, the BRONZE · ARGENT · OR gauge, the COMPLET stamp), then the set's members in set order, each slot filled by the player's best held edition of that game (any season) or a missing-card slot naming the game. The back button names its origin through the existing history trail; the collection's rows mark the album last opened.

## Boundaries & Constraints

**Always:**
- Routes unchanged: `library_set_path` (`/:locale/library/:kind/:key`, LibraryController#set) is the viewer's album; `brother_set_path` (`/:locale/brothers/:token/library/:kind/:key`, PublicProfilesController#set) is the owner's album, read-only, signed out included, behind the existing `load_owner` visibility check (private / friends-only / banned → the unavailable 404 exactly as today). Unknown kind/key or no published season → 404 as today. Each action keeps `authorize :page, :show?`.
- Members = the published season's set memberships in slot order (position, then id). A member is filled when the owner holds its game (`card_id`) in any season with `quantity > 0` (Game::HeldGames' rule). The face shown is the best held edition: highest rarity, then the published season's own card-season, then the highest card-season id. Copies on the badge = quantity summed over every held edition of that game, shown from x2 (a single copy has no badge; EXPERIENCE Copy badge), visually-hidden copy count from x1 as today. NOUVEAU (any held edition of the game gained after the player's watermark, `Game::CollectionSlots::NEW` rule) only on the viewer's own album, never on a profile; the album never posts the watermark.
- Standing: `held` = filled members, `total` = members, tiers from `catalog_set_tiers` → `Game::SetStanding` (reached tier from counts, as the set progress rows do).
- Header (PanelComponent `brackets: true`): h1 = the set's name (`SetLabel.for`), on a profile "Roguelike · Léa" (`public_profile_title(owner)`); the h1 has `tabindex="-1"` and takes focus when the album opens. Kind in muted label; "31/62" (aria-hidden); a `<progress>` named by the h1 (`aria-labelledby`) with `aria-valuetext` "31 cartes sur 62, palier or" (no tier reached: "2 cartes sur 62"; complete: "3 cartes sur 3, complet"); a tiered set's bar has the three ticks with notches (reuse `set_tier_ticks`, aria-hidden). Tiered set: an `<ol>` gauge labelled "Paliers"/"Tiers", three items Bronze/Argent/Or, each showing notches, a pixel ✓ (`pixel_icon("check")`) when reached, the name and its threshold `required` in VT323; reached = tier colour frame and name, filled notches; not reached = `line-deep` frame, hollow notches, muted name; visible parts aria-hidden and a visually-hidden "Bronze, 7 cartes, atteint" / "Or, 31 cartes, pas encore atteint". COMPLET stamp when `standing.complete?`: plain text "Complet" (uppercase by CSS) in VT323 ≥ 24px, a 3px lime frame with stepped corners, rotated −6°, in the kind and count row with ≥ 6px clear each side; an untiered set shows only the stamp, never a gauge or ticks. Phone (< 720px): the three gauge cells share the width, name over threshold; below 360px they stack; name line-height ≥ 1.2.
- Grid: `card-m` faces in the existing `.collection-grid` / `.collection-slot` look (6 columns at desktop widths come from the grid's own sizing), missing slots as the existing `.missing-slot` (lock icon, title, year, visually-hidden "Missing card"), 60 slots a page (EXPERIENCE Large grids) with the collection's page navigation below (extract the `<nav class="collection-pages">` of `library/_grid.html.erb` into a `library/_pages` partial, reused by both). The `<ol>` is one tab stop: roving tabindex over its links, ←/→ one slot, ↑/↓ one row whatever the column count, Home/End first/last; without JavaScript every link stays tabbable.
- Card links (`link_to_card_detail`, class `card-link`): on the viewer's album, a slot showing the published member links to it with `set_kind`/`set_key` (the detail walks the set); a slot showing an earlier edition links to that edition's own page (its season number), no context. On a profile album every slot links to the card's own page with no context, as the profile set page does today. The card detail's set back (`CardsController#set_browse`) leads to the album page holding the card (`page` from `SetNeighbours` position, omitted on page 1).
- Back button (EXPERIENCE Set album): the desktop `previous-screen` button already names the previous screen from the history trail; the collection entry's screen label becomes "Sets" (`shell.screens.sets`), the grid (`library#cards`) gets "Collection", so the album reads "◀ SETS" from the entry or its search, "◀ FICHE" from a card detail, "◀ PROFIL" from a profile, "◀ CAPSULE" from a capsule, nothing from the hub (unlabelled). On the phone the album shows that same previous-screen button in place of "◀ PONT" when it has a label, else "◀ PONT".
- Back from an album through history focuses the set progress row that opened it (extend `history_back_controller.ts`'s return-link lookup from `a.card-link` to `a.card-link, a.set-row`). The album records its pathname in sessionStorage; wherever set progress rows show (collection entry incl. search results after a frame load, profile, hub), the row whose link pathname matches gets `aria-current="true"` and a 5px accent bar on its left (CSS on `[aria-current="true"]`).
- Top bar on the viewer's album: screen title "Collection" (a `<p>`, not a heading) and the unique-cards status as on the entry. Page title: "Roguelike · Collection · gameble"; on a profile "Roguelike · Léa · gameble"; the profile album keeps `noindex`.
- Fixed query count whatever the set's size or the holdings (no per-slot query); every GET writes nothing; no database id in HTML or URLs; every string in `en.yml` and `fr.yml`, French plurals with `zero`; no `style` attribute; no planning ids; new code without explanatory comments (only an external constraint, one line).

**Never:**
- No per-season tier marks ("Or · 12 saisons", "à reconquérir"): epic-seasons-carry-over entry 3 owns them.
- No change to the set celebration (ticket 13.17 rebuilds it and links it to the album) and no restoring of a capsule's results on coming back.
- No change to the card grid at `/library/cards`, its filters or its set filter (entry 9), no one-card-per-game grid (entry 15), no arrow keys on the collection grid.
- No new table, column, index or migration; no watermark post from the album.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Theme at silver | Horror (16 members, tiers bronze 2 / silver 4 / gold 8) with 5 games held | h1 "Horror", 5/16, gauge Bronze and Silver reached (✓, "atteint"), Gold "pas encore atteint"; valuetext "5 cards out of 16, silver tier"; 11 missing slots naming their games and years | — |
| Completed franchise | Franchise 3/3 | "Complete" stamp text, no gauge, no ticks; valuetext "3 cards out of 3, complete" | — |
| Earlier edition | Player holds a member's game only in season 1 (Rare) | slot filled with the S1 face, its link to the S1 card page without context; counts 1 | — |
| Two editions | Same game held S1 Rare ×1 and S2 Epic ×2 | the Epic face, badge "x3" | — |
| Visitor | Signed out on `/library/theme/horror` | every slot missing, 0/16, no NOUVEAU | — |
| Profile signed out | Public owner with 5/16 | the owner's faces and copies, h1 "Horror · Owner", no NOUVEAU, no top-bar status | private / friends-only / banned owner → unavailable 404 as today |
| Large set | 752 members, 400 held | page 1 holds 60 slots and the page nav; the request costs the same queries as a 3-member set | — |
| Unknown | `/library/theme/nope`, `/library/studio/horror`, no published season | 404 | — |
| Last album | Album opened then the entry shown | that set's row has `aria-current="true"` | storage unavailable → no row marked |

</intent-contract>

## Code Map

- `config/routes.rb:24-41` -- album routes already exist (`library_set`, `brother_set`); rewrite their comments (no planning ids).
- `app/controllers/library_controller.rb#set` -- replace the set-scoped grid with the album: season, `load_set_album(season, owner: current_player, with_new: true)`, `load_unique_cards`. Rewrite the class header comment (it narrates the set grid).
- `app/controllers/public_profiles_controller.rb#set` -- the owner's album: `load_set_album(Catalog::PublishedSeason.call, owner: @owner, with_new: false)`. Drop `ShelfLoading`, `STARTED`, `shelf_relation` (dead once the tabs go); rewrite the header comment.
- `app/controllers/concerns/set_album_loading.rb` (new) -- `ALBUM_SIZE = CollectionGridLoading::GRID_SIZE` (60) or its own constant; loads `@set`, `@standing`, `@album_pagy`, `@album_slots` (`Slot = Data.define(:card, :copies, :new, :member)`: card = Catalog::CardView shown, copies nil when missing, member = true when the face is the published member) using `Catalog::SetAlbum`, `Game::HeldGames.editions`, `Catalog::CardViews` (page ids only), pagy `:offset` over the members array (`page` param, clamp like `page_param`).
- `packs/catalog/app/queries/catalog/set_album.rb` (new) -- `call(season:, kind:, key:)` → `Album(set: Catalog::Set, members: [[card_season_id, card_id], …] in slot order, tiers: { "bronze" => 2, … })` or nil; at most three queries whatever the size (reuse `SetFigures.tier_hash`-style parsing or `SetTier` pluck). Test in `test/packs/catalog/set_album_test.rb`.
- `packs/game/app/queries/game/held_games.rb` -- add `HeldGames.editions(player, card_ids:, season:)` → `{ card_id => Edition(card_season_id:, copies:, new:) }`: one query (`DISTINCT ON (card_id)` ordered rarity DESC, `season_id = :season_id` DESC, id DESC; copies `SUM(quantity) OVER (PARTITION BY card_id)`; new `BOOL_OR(CollectionSlots::NEW) OVER (…)` with the `game_player_states` LEFT JOIN); `{}` without a query for nil player or no ids. `call` unchanged. Test in `test/packs/game/held_games_test.rb` (exists? else create).
- `packs/game/app/models/game/set_standing.rb` -- optional constructor for a measured set (held, total, tiers; `just`/`reached_now` false).
- `packs/game/app/queries/game/started_sets.rb` + `test/packs/game/started_sets_test.rb` -- delete if nothing else uses them after the profile tabs go (grep first). `app/controllers/concerns/shelf_loading.rb#load_set` -- delete; fix its header comment. `app/helpers/shelves_helper.rb`, `app/views/public_profiles/_set_list.html.erb`, `_set_row.html.erb` -- delete when unused.
- Views: `app/views/library/set.html.erb` (rewrite: titles, top-bar status, `content_for :phone_previous`, renders `library/album`), `app/views/public_profiles/set.html.erb` (rewrite: noindex, title, renders `library/album`), `app/views/library/_album.html.erb` (new: header, gauge, stamp, grid; locals set, standing, heading, slots, pagy, with_new, slot_context lambda or nil), `app/views/library/_pages.html.erb` (extracted from `_grid.html.erb`).
- `app/helpers/set_rows_helper.rb` -- add the album's valuetext and gauge item sentences beside `set_progress_sentence`; reuse `NOTCHES`, `set_tier_ticks`, `set_notches`.
- `app/controllers/cards_controller.rb#set_browse` -- back path with the album page of the card (`page` when > 1).
- `app/helpers/shell_helper.rb` `SCREEN_LABELS` -- `"library#show" => :sets`, `"library#cards" => :collection`; `test/helpers/shell_helper_test.rb` follows.
- `app/views/shell/_top_bar.html.erb` -- `top-bar__start--phone-previous` modifier when `content_for?(:phone_previous)`; `app/frontend/controllers/previous_screen_controller.ts` toggles `top-bar__start--has-previous` on its parent in `sync`; `app/frontend/styles/shell.css` phone block (`@media` near line 1340): with both modifiers show `.top-bar__previous` and hide `.top-bar__bridge`.
- `app/frontend/controllers/history_back_controller.ts:54` -- return link selector `a.card-link, a.set-row`.
- New Stimulus: `set_album_controller.ts` (focus heading target on connect unless `html[data-turbo-preview]`; remember pathname), `last_album_controller.ts` (on connect and `turbo:frame-load` inside it, mark the matching `a.set-row`), `grid_keys_controller.ts` (roving tabindex). Pure parts with vitest tests: `app/frontend/lib/last_album.ts` (+ `.test.ts`; storage errors swallowed like `history_trail.ts`), `app/frontend/lib/grid_keys.ts` (+ `.test.ts`: next index for each key, columns, edges). Register as the other controllers are (check `app/frontend/controllers/index.ts` or the entrypoint's glob).
- `app/views/library/_entry.html.erb`, `app/views/pages/_set_progress.html.erb` -- `data-controller="last-album"` on their wrappers.
- CSS: `app/frontend/styles/collection.css` -- `.set-album*` (header panel layout, VT323 name 44px / 40px phone, count, gauge cells, stamp with stepped corners via `clip-path` and box-shadows, phone and < 360px rules, grid spacing); `hub.css` -- `.set-row[aria-current="true"]` accent bar (5px, `--color-accent`, inset box-shadow so layout does not shift). Tier colours: `--color-tier-bronze`, `--color-tier-silver`, `--color-gold`, lime `--color-lime`. Reuse `.set-row__tick` styles for the header bar (or a sibling class).
- Locales `config/locales/{en,fr}.yml`: `shell.screens.sets` ("Sets"/"Sets"); `library.album.*` (title "%{set} · Collection · gameble", tiers label "Paliers"/"Tiers", slots label "Cartes du set"/"Cards in the set", gauge item reached/not reached with zero/one/other on the threshold, valuetext parts reuse `library.set_progress.*`); `public_profiles.set.title` "%{set} · %{name} · gameble", `public_profiles.set.heading` "%{set} · %{name}"; remove keys left unused (`bundle exec i18n-tasks unused`; only the pre-existing `rate_limit.*` may remain).
- Tests: rewrite `test/controllers/library_set_test.rb` as album tests; replace the profile set-page tests in `test/controllers/public_profiles_controller_test.rb` (tabs, shelves, Started) with album tests, keep the visibility tests and add the album to them; `test/controllers/cards_controller_test.rb` (set back with page); `test/helpers/shell_helper_test.rb`; `test/integration/shell_test.rb` if it reads the labels. Helpers: `test/support/catalog_seeds.rb#publish_sets_draft`, `test/support/game_sets.rb` (`insert_set`, `insert_theme`, `published_cards`, `hold_all`), `test/support/library_requests.rb` (`hold`, `set_members`, `assert_request_queries`). System tests: only obvious selector updates, never run.

## Tasks & Acceptance

**Execution:**
- [ ] `set_album.rb`, `held_games.rb` (`editions`), `set_standing.rb` -- read the album's members, tiers and best editions in a fixed number of queries, with their unit tests.
- [ ] `set_album_loading.rb`, `library_controller.rb`, `public_profiles_controller.rb`, `cards_controller.rb` -- load the album for the viewer and for a profile owner; the detail's set back to the album page.
- [ ] `library/_album`, `library/_pages`, `library/_grid`, `library/set`, `public_profiles/set`, `set_rows_helper.rb` -- the header, gauge, stamp, slots and paging.
- [ ] Delete what the profile tabs leave dead (`ShelfLoading#load_set`, `ShelvesHelper`, `public_profiles/_set_list`, `_set_row`, `Game::StartedSets` if unused) with their tests.
- [ ] `shell_helper.rb`, `_top_bar.html.erb`, `previous_screen_controller.ts`, `shell.css` -- origin-named back on desktop and phone.
- [ ] `set_album_controller.ts`, `last_album_controller.ts`, `grid_keys_controller.ts`, `lib/last_album.ts`, `lib/grid_keys.ts` (+ tests), `history_back_controller.ts`, `_entry`, `_set_progress` -- focus, last album marked, grid keys, back focus.
- [ ] `collection.css`, `hub.css`, locales -- the album's look and strings in both languages.
- [ ] Request tests for every matrix row, both locales, no `[style]`, no ids, GET writes nothing (existing read-only harness), and a query-count test comparing a 3-member and a 752-member album (same count, stated exactly).

**Acceptance Criteria:**
- Given a player with 5 of Horror's 16 games, when they open `/en/library/theme/horror`, then the h1 is "Horror", the gauge reads "Bronze, 2 cards, reached", "Silver, 4 cards, reached", "Gold, 8 cards, not reached yet", the progress bar's value text is "5 cards out of 16, silver tier", and the 11 missing slots name their games.
- Given a completed franchise, when its album opens in French, then the header shows the "Complet" stamp and no gauge.
- Given a public owner, when a signed-out visitor opens `/en/brothers/:token/library/theme/horror`, then the owner's faces and copies show under the h1 "Horror · <name>"; given a private or friends-only owner, the same URL answers the unavailable page with a 404.
- Given a set of 752 members, when the album opens, then it shows 60 slots and page navigation, and the request costs exactly as many queries as for a 3-member set.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass (unused: only the pre-existing `rate_limit.*`).

## Implementation Notes

- Query counts, exact and independent of the set's size: the viewer's album 10 (752 members with 400 held, or 3 members), a visitor's 6; the owner's profile album 12 for a signed-in viewer, 7 signed out.
- `Catalog::SetAlbum` reads the set, its members with their games and its tiers in 3 queries; `Game::HeldGames.editions` the best held edition per game in one (`DISTINCT ON` with window sums); `Game::SetStanding.measured` builds the header's standing.
- The h1's focus box is hidden (it is focused by script, never by Tab); phone gauge names no longer break mid-word; the album grid is capped at six card columns (without the grid's side column, seven fit at 1280px).
- Dead code removed with the profile tabs: `ShelfLoading#load_set`, `ShelvesHelper`, `public_profiles/_set_list` and `_set_row`, `Game::StartedSets`, `Catalog::SetSlots.call` (its `SetRef` stays), the profile set page's styles and locale keys, `library.show.tabs.started`.
- Viewed in headless Chromium on a scratch database at 1280, 390 and 340px (a profile album): gauge cells share the width at 390px and stack at 340px, the stamp clears the kind and the count. The viewer's album, the phone back label and the last-album mark were not viewed in a browser.
- While preparing that check, one `bin/rails db:create db:schema:load` probably reloaded the development queue database's schema (`gameble_development_queue`), clearing queued development jobs; the development and test databases were untouched.

## Plan Change Log

## Review Triage Log

### 2026-10-17 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The rewritten `.set-row[aria-current]` comment in `collection.css` named DESIGN.md, which AGENTS.md forbids in code — reference removed.
  - `[low]` `[patch]` The album grid fitted seven columns at desktop widths (no side column), DESIGN asks six — `.set-album__grid` capped at six card widths and five gaps.
  - `[low]` `[reject]` Album pages count every membership while the detail's position skips members without a text in the locale or a rarity, so the back could name the wrong page, and a slot whose best edition has no view disappears — a published season's cards always have both (CardViews and SetNeighbours skip only broken data); the fix adds a fallback branch for a state users do not meet.
  - `[low]` `[patch]` `Catalog::SetSlots.call` had no production caller after the profile set page went — deleted with its test; `SetRef` kept; `set_neighbours_test` compares against `SetAlbum`.
  - `[low]` `[patch]` `profile.css` kept rules for the deleted profile set page and set row — deleted.
  - `[low]` `[patch]` A row marked as the last album opened lost its hover frame and a complete set's lime count — `.set-row[aria-current]:hover` keeps the bar with the hover shadows; the accent count rule excludes `.set-row--complete`.

## Design Notes

- **The album replaces the set grid:** the design has no set-scoped grid any more (the grid's set filter is entry 9's); keeping the routes means every existing link (rows, hub, card detail's sets, the grid's shelf) now opens the album. The set-scoped grid support left in `Catalog::CollectionGrid`, `CollectionGridLoading#grid_context` and `CardsController#named_grid` stays for old detail links and is entry 9's to remove.
- **Origin through the trail, not a parameter:** the trail already records each screen's label and goes back through history (scroll and focus restored); a `from` parameter would need the origin's own path (which card, which capsule). Reload loses the trail: the back falls back to "◀ PONT" on the phone and nothing on desktop, as every other screen.
- **Stamp placement:** DESIGN.md puts the stamp in the header's kind and count row; EXPERIENCE's "after its OR cell" is read as reading order within the header.
- **Paging at 60:** EXPERIENCE "Large grids" pages beyond about 60 slots; a 62-card theme has two pages.

## Verification

**Commands:**
- `bin/ci` -- expected: green (revert any stray `package-lock.json` "license" line it writes)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (unused: pre-existing `rate_limit.*` only)

**Manual checks (if no CLI):**
- If a headless browser is available, view an album at 1280px and 390px on a scratch database (desktop gauge, phone gauge cells, stamp clearance, back label); system tests stay disabled.

## Auto Run Result

- **Summary:** a set opens as its album, for the viewer at `/library/:kind/:key` and read-only on a public profile at `/brothers/:token/library/:kind/:key` (signed out included, behind the same visibility 404): a bracketed header with the set's name as h1 (focused on opening; "Set · Owner" on a profile), its kind, the COMPLET stamp when every card is held, owned/total, a progress bar named by the h1 with its value text and tier ticks, and for a theme or hall of fame set the Bronze · Argent · Or gauge (threshold, ✓ and filled notches when reached, a spoken sentence per tier); then the set's cards in set order, sixty a page, each game shown at the best edition held in any season (copies summed over editions, badge from x2, New only on the viewer's own album), the rest as missing-card slots naming the game and year; the grid is one tab stop with arrow keys, Home and End. The back names its origin through the history trail: "◀ Sets" from the collection entry or its search, "◀ Fiche", "◀ Profil", "◀ Capsule", nothing (desktop) or "◀ Pont" (phone) from the hub; back through history focuses the row that opened the album, and the row of the album last opened carries the accent bar and `aria-current="true"` on the entry, the profile and the hub. The card detail's set back leads to the album page holding the card.
- **Files:**
  - `packs/catalog/app/queries/catalog/set_album.rb`, `packs/game/app/queries/game/held_games.rb` (`editions`), `set_standing.rb` (`measured`) — the album's members, tiers and best editions in fixed queries.
  - `app/controllers/concerns/set_album_loading.rb`, `library_controller.rb`, `public_profiles_controller.rb`, `cards_controller.rb` — loading the album; the detail's back to its page.
  - `app/views/library/{_album,_pages,set,_grid,_entry}`, `public_profiles/set`, `pages/_set_progress`, `shell/_top_bar`, `set_rows_helper.rb`, `shell_helper.rb` — the album, paging, origin-named back, last-album hooks.
  - `app/frontend/controllers/{set_album,last_album,grid_keys}_controller.ts`, `lib/{last_album,grid_keys}.ts` (+ tests), `history_back_controller.ts`, `previous_screen_controller.ts`; `collection.css`, `shell.css`, `profile.css`; locales.
  - Deleted: `shelves_helper.rb`, `public_profiles/_set_list`, `_set_row`, `game/started_sets.rb`, `ShelfLoading#load_set`, `SetSlots.call`, with their tests.
  - Tests: `library_set_test.rb` (rewritten), profile album tests, `set_album_test.rb`, `held_games_test.rb`, `set_standing_test.rb`, `set_neighbours_test.rb`, `cards_controller_test.rb`, `library_controller_test.rb`, `shell_helper_test.rb`; system tests' obvious selectors only (not run).
- **Review:** quick lens; 5 patches applied (all low), 0 deferred, 1 rejected (low: album page against detail position for members without text or rarity, which a published season never holds).
- **Follow-up review:** false — no high and no medium patched.
- **Verification:** `bin/ci` green after the patches (2672 runs, 0 failures; rubocop, brakeman, audits, schema round trip, seeds); `npm run test:js` 355 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing` green; `unused` only the pre-existing `rate_limit.*`. `bin/ci` wrote the stray `package-lock.json` "license" line, reverted.
- **Residual risks:** the viewer's album, the phone back label and the last-album mark were not viewed in a browser (a profile album was, at 1280, 390 and 340px); the grid keys and the mark are tested through their pure logic only; system tests that expected the set grid with filters (`test/system/library_test.rb`, maybe `card_detail_test.rb`) are stale; a reload loses the history trail, so the album's back then falls back to "◀ Pont" on the phone and nothing on desktop; per-season tier marks ("Or · 12 saisons", "à reconquérir") are left to epic-seasons-carry-over entry 3.
