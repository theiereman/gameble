---
title: 'A player creates a custom set and opens it as an album'
type: 'feature'
ticket: 3
created: '2026-10-31'
status: 'built'
baseline_revision: '0070ff8893b8adf32c7d5632d55d3fc21d99c11d'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player can only follow the game's sets; they cannot gather the games they want into a set of their own and see which of them they still miss.

**Approach:** The tracer bullet of custom sets through every layer: the `game_custom_sets` / `game_custom_set_games` tables, `Game::CreateCustomSet`, `Game::RenameCustomSet` and `Game::DeleteCustomSet`, one `Game::CustomSetStandings` query read by the album and a minimal MES SETS list on the collection entry, the album (owned / total, a bar to COMPLET without ticks, a Card not owned face for each missing game), a minimal server-rendered game picker, and a policy refusing every custom set page to anyone but its author.

## Boundaries & Constraints

**Always:**
- Tables as the architecture states: `game_custom_sets` (player, public 24-character token, name, kind `custom` or `steam_library`, the library's sync state `synced_at` and `library_private_since`), `game_custom_set_games` (custom set with `ON DELETE CASCADE`, `catalog_cards` id), unique per set and game; one `steam_library` set per player by a partial unique index; a custom set's name unique per player, case-insensitively, by a partial unique index on `lower(name)`.
- A set lists games (card ids), never card-seasons, and only games with a rated card-season in a published season, checked through `Catalog::PublishedCardIds`.
- Limits checked in the operations under the bank lock (`lock_bank`): name required after squish, 40 characters at most, not another of the player's custom set names; 3 to 50 games; 10 `custom` sets per player. Each refusal is a `Failure(:code)` with an `errors.game.<code>` message in en.yml and fr.yml.
- Each operation publishes one event in its transaction (`Game::CustomSetCreated`, `Game::CustomSetRenamed`, `Game::CustomSetDeleted`, data `player_id` and `custom_set_id` only) on the player's stream.
- Owned / total counts a game held in any edition (`Game::HeldGames`); a missing game's slot shows its card-season of the latest published season holding it; an owned game shows its best edition.
- Custom sets are addressed by token in URLs, HTML and forms; games by card slug. Every action has a `CustomSetPolicy` decision; show, edit, update and destroy are allowed to the set's author only.
- Account deletion (`Game::ReleasePlayer`) erases the player's custom sets and their games; the player's data export lists them (name, kind, games), by token, never by id.
- New French strings put U+202F before `?`, `!`, `:`, `;` and inside « ».

**Never:** a `catalog_sets` row, tiers, `game_set_tiers` rows, titles, backs, celebrations, feed entries or allocations for a custom set; a custom set in EN COURS, COMPLÉTÉS, the hub, the card detail's sets, the grid's set filter, a public profile or a friend's view; goals, the Steam library set's creation or sync, the option-B editor modal, the delete dialog, the set tiles of MES SETS, game edits after creation; React or markup built in script.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | name "Mes favoris", 3 published games | set + 3 games rows, one `CustomSetCreated`; redirect to its album | No error expected |
| Name blank or spaces | "" / "   " | nothing written | `Failure(:name_required)` |
| Name too long | 41 characters | nothing written | `Failure(:name_too_long)` |
| Name taken | "MES FAVORIS" while "Mes favoris" exists (create or rename) | nothing written; renaming a set to its own name succeeds | `Failure(:name_taken)` |
| Too few / too many games | 2 games / 51 games (duplicates counted once) | nothing written | `Failure(:too_few_games)` / `Failure(:too_many_games)` |
| Eleventh set | player holds 10 custom sets | nothing written | `Failure(:too_many_sets)` |
| Unpublished game | a card id with no rated card-season in a published season, or unknown | nothing written | `Failure(:game_not_in_catalog)` |
| Banned / deleted / nil player | any operation | nothing written | `Failure(:player_required)` |
| Rename / delete another player's set or a library set | token not of this player's `custom` sets | nothing written | `Failure(:custom_set_not_found)` |
| Album, author | 3 games, one held in an earlier season's edition | header "1/3", bar max 3 without ticks, 1 owned face + 2 not-owned faces | No error expected |
| Album, other player | another player's token | 403 refusal page, no name shown | Pundit refusal |
| Album, visitor | any token | sent to the landing (sign_in_required) | Pundit refusal |
| Album, unknown token | random 24 base58 characters | 404 | `ActiveRecord::RecordNotFound` |
| Delete | author's set | set and games rows gone, one `CustomSetDeleted`, redirect to the collection with the toast | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/operation.rb` -- `require_player`, `lock_bank`, `stream_name`; `add_to_showcase.rb` is the shape of a locked, refusing, publishing operation.
- `app/domains/game/app/operations/game/release_player.rb` -- add the custom sets' deletion under its bank lock.
- `app/domains/game/app/queries/game/held_games.rb` -- `call(player_id, card_ids:)` (held card ids, any edition) and `editions(player, card_ids:, season:)` (best edition per card); reuse, do not change.
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- `call(source_keys:)` used by `Steam::OwnedGames`; keep it, add `within(card_ids)` and `by_slug(slugs)` sharing its published relation.
- `app/domains/catalog/app/queries/catalog/card_views.rb`, `collection_grid.rb` -- card views by card-season id; `CollectionGrid.call(season:, query:)` gives the published season's card-seasons matching a title or studio (the picker's search).
- `app/controllers/concerns/set_album_loading.rb` -- `filtered_faces`, `album_slots`, `Slot`, pagy; extract a shared slot loader taking `members` (`[face card_season_id, card_id]`) and `editions` so the custom set album reuses filters and paging; a slot's `number` falls back to the card view's season number.
- `app/views/library/_album.html.erb` -- the album partial (header, filters, grid, pages); give it an optional actions block rendered in the header beside the title. `Game::SetStanding.measured(set_id: nil, held:, total:, tiers: {})` gives a standing without ticks whose value text reads "1 card of 3".
- `app/views/library/set.html.erb`, `app/controllers/library_controller.rb` (`load_unique_cards`) -- the album page's chrome (back button, screen title, top-bar status).
- `app/views/library/_entry.html.erb`, `show.html.erb`, `app/frontend/styles/collection-set-tiles.css` (`.set-entry:has(.set-results) > ...` hides sections under results) -- where the minimal MES SETS section goes, on the player's own entry only (`public_profiles/collection.html.erb` must not get it).
- `app/controllers/showcases_controller.rb` -- toast pattern (`flash[:toast_title]`, `flash[:notice]`); `trades_controller.rb` -- `throttle_player`.
- `app/policies/pack_policy.rb`, `test/policies/pack_policy_test.rb` -- record-owner policy and its test.
- `config/routes.rb` -- the library routes; token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`.
- `db/migrate/20261020130000_create_game_showcase_entries.rb` -- table, FK and check style.
- Tests: `test/domains/game/add_to_showcase_test.rb` (operation, `game_events`), `test/support/game_sets.rb` (`published_cards`), `test/support/catalog_seeds.rb`, `test/support/holdings.rb`, `test/controllers/library_set_test.rb`, `test/system/collection_set_test.rb` (system sign-in), `test/domains/accounts/delete_player_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261031100000_create_game_custom_sets.rb` -- both tables, FKs (`game_custom_set_games.custom_set_id` `on_delete: :cascade`), unique token, unique `(custom_set_id, card_id)`, partial unique `player_id WHERE kind = 'steam_library'`, partial unique `(player_id, lower(name)) WHERE kind = 'custom'`, checks: kind in the two values, a `custom` set has a name of 1 to 40 characters, sync state null on a `custom` set; then regenerate `db/schema.rb` as AGENTS.md says.
- [x] `app/domains/game/app/models/game/custom_set.rb`, `custom_set_game.rb` -- models, `has_secure_token :token, length: 24`, constants for kinds, name limit, games range and per-player cap.
- [x] `app/domains/game/app/events/game/custom_set_{created,renamed,deleted}.rb` -- events.
- [x] `app/domains/game/app/operations/game/{create,rename,delete}_custom_set.rb` (+ a shared steps module if it keeps them small) -- per the matrix; rename and delete find the set by token among the player's `custom` sets with a row lock; delete returns the set's name.
- [x] `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- `within(card_ids)`, `by_slug(slugs)` (`{ slug => id }`).
- [x] `app/domains/catalog/app/queries/catalog/latest_published_card_seasons.rb` -- `{ card_id => card_season_id }` of the latest published season holding a rated card-season of each card.
- [x] `app/domains/game/app/queries/game/custom_set_by_token.rb`, `custom_set_standings.rb` -- by token (any owner, for the policy); standings of a player's sets (all or given sets), oldest first: token, name, kind, card ids in insertion order, held card ids, `held`, `total`, `complete?`, `to_set_standing`; one `HeldGames` call for all sets.
- [x] `app/policies/custom_set_policy.rb` -- `new?`/`create?`/`picker?` a player; `show?`/`edit?`/`update?`/`destroy?` the record's author.
- [x] `config/routes.rb` -- `library/custom-sets` (new, create, show, edit, update, destroy by token) and `POST library/custom-sets/picker`, before `library/:kind/:key`.
- [x] `app/controllers/custom_sets_controller.rb` (+ concern if over size) -- show the album (404 without a published season or set); new and picker render the minimal picker; create, update, destroy call the operations, throttled; a refusal re-renders the form with its message (422), keeping the name and selection.
- [x] `app/controllers/concerns/set_album_loading.rb` -- shared slot loader (above).
- [x] `app/views/custom_sets/{show,new,edit,_picker}.html.erb`, `app/views/library/_album.html.erb`, `_custom_sets.html.erb`, `_entry.html.erb`, `show.html.erb` -- album with MODIFIER (edit: name only) and SUPPRIMER (`button_to` delete with `turbo_confirm` naming the set); the picker is one `data-turbo="false"` POST form: name (maxlength 40), the selected games as checked `games[]` slug checkboxes ("SÉLECTIONNÉS · n", counter "n jeux · 3 à 50"), the search field with a CHERCHER button first in tree order whose `formaction` is the picker action, up to 24 unselected results as unchecked checkboxes, "Aucun jeu trouvé pour « … »." when none, ENREGISTRER and ANNULER; MES SETS on the player's own entry: kicker, "Visibles par vous seul · n / 10", one link per set with name and owned/total, "+ NOUVEAU SET" below 10 sets; no `style` attributes.
- [x] `app/frontend/styles/` (a collection stylesheet under its size limit) -- album actions, picker, MES SETS list; hide MES SETS under search results.
- [x] `config/locales/en.yml`, `fr.yml` -- every new string and the `errors.game.*` codes, both locales.
- [x] `app/domains/game/app/operations/game/release_player.rb` -- delete the player's custom sets.
- [x] `app/domains/game/app/queries/game/export_of.rb` and the export's web-layer assembly and rendering -- each custom set of the player (token, name, kind, its games by slug in the order picked) in the data export, read only; tests in `test/domains/game/export_of_test.rb` and the data export controller test.
- [x] Review fixes carried from the first pass -- a plain `player_id` index on `game_custom_sets` in its create migration; `clean_name` strips `Accounts::PersonaName::INVISIBLE` and normalises `SPACE` before squish, as `Accounts::BanReason` does; `destroy` goes through `editable_custom_set`; `show` answers 404 when the set is gone between the policy check and the standings read; tests for the throttle, a visitor's picker POST, a custom set album's filters, a library set kept out of MES SETS and the 10-set cap, 51 slugs reaching the 50-games refusal through the controller, and the forms' "Sets" screen label.
- [x] Tests: `test/domains/game/custom_set_operations_test.rb` (every operation row of the matrix, events, nothing written on refusal), `test/domains/game/custom_set_standings_test.rb`, `test/domains/catalog/published_card_ids_test.rb` (+ `within`, `by_slug`), `test/domains/catalog/latest_published_card_seasons_test.rb`, `test/policies/custom_set_policy_test.rb`, `test/controllers/custom_sets_controller_test.rb` (album rows of the matrix, create/rename/delete through HTTP, refusals rendered, GETs write nothing, no database id in the HTML), `test/domains/accounts/delete_player_test.rb` (sets erased), `test/system/custom_sets_test.rb`.

**Acceptance Criteria:**
- Given a signed-in player on the collection, when they follow "+ NOUVEAU SET", search, check three games and save with a name, then they land on the album titled with that name, showing owned/total and a not-owned face for each missing game, and the set appears in MES SETS.
- Given the author on the album, when they rename it through MODIFIER, then the album and MES SETS show the new name; when they delete it through SUPPRIMER and confirm, then they land on the collection with the "SET SUPPRIMÉ" toast and the set is gone.
- Given the collection with a typed set search, then MES SETS is hidden like EN COURS; given a public profile's collection, then no MES SETS appears.
- Given the pack draw, the hub, EN COURS and COMPLÉTÉS, then nothing reads custom sets: their existing tests pass unchanged, the collection entry's tests changing only for MES SETS's place.
- Given a player with custom sets, when they download their data export, then it lists each set's name, kind and games, with tokens and slugs and no database id.

## Implementation Notes

- The kind check is written `kind = 'custom' OR kind = 'steam_library'`: Postgres dumps an `IN` list differently after a schema load, which the CI round trip refuses.
- `game_custom_sets` names a player, so the settings' delete dialog note now names "your custom sets" / "vos sets perso" (`accounts.dialog.note`), and `accounts_controller_test` maps the table to it; that test fails for any new table naming a player.
- MES SETS sits between the set search results and EN COURS, so three entry tests of `library_controller_test` now expect its h2 and its place in the sibling chain, the entry's query count rises by one (the player's sets), and `system/library_test` tabs into the tiles from "+ New set" instead of "All cards".
- A Steam library set's album opens like a custom set's, without MODIFIER and SUPPRIMER; its edit form is a 404 and the operations refuse it (`custom_set_not_found`).
- The picker lists results only once a query is typed; a slug it does not know reaches the operation as a missing game (`game_not_in_catalog`).
- The custom set pages carry the screen labels "Set" (album) and "Sets" (forms).
- Second pass (after the author's decision): the attempt was re-applied with `git apply --3way` on `0070ff88` (the weekly mission rename); the `accounts.dialog.note` conflicts in en.yml and fr.yml keep the mission wording and add the custom sets.
- The export's `customSets` section lists each set's token, name, kind, creation time and games (slug and title, through `Catalog::LatestPublishedCardSeasons` and `CardViews`); `Game::ExportOf#custom_sets` reads the rows. The legal page's stored-data line and deletion paragraph name the custom sets too (`pages_controller_test` checks both lists).
- `game_custom_sets` gains its plain `player_id` index (`t.references ... index: true`), which the kind-free reads (standings, `ReleasePlayer`) use.
- `clean_name` strips `Accounts::PersonaName::INVISIBLE` and turns `SPACE` into plain spaces before squishing, so a NUL byte or a zero-width name is `name_required`.

## Plan Change Log

### 2026-10-31 — Author's decision after the intent-gap halt
- Trigger: the review's data-export finding (AD-14 lists custom sets in the export; the intent-contract's Never excluded it and no entry owned it).
- Amended: the author decided on 2026-10-31 that this entry owns the custom sets data export; "data export of custom sets" is dropped from Never, the Always rule on deletion names the export, an export task and acceptance criterion are added, and the first pass's carried review fixes become a task.
- Known-bad state avoided: custom sets erased with the account but missing from the player's export.
- KEEP: the first attempt, saved as the `.patch` beside this plan and applied with `git apply --3way` (locale conflicts with the weekly mission rename resolved keeping both); its tables, operations, queries, policy, album, picker, MES SETS list and tests stay as built.

## Review Triage Log

### 2026-10-31 — Review pass
- verdicts: 33 findings — high 0, medium 3, low 23, false 7, maybe-false 0
- attempted change saved as [story-a-player-creates-a-custom-set-and-opens-it-as-an-album-plan.patch](story-a-player-creates-a-custom-set-and-opens-it-as-an-album-plan.patch) (applies cleanly on the baseline with `git apply`), then reverted
- findings:
  - `[false]` `[reject]` Blind: the album header counts a game that has no slot when the game has no published face and is not held — a game enters a set only with a rated card-season in a published season (`in_catalog`), published seasons are never unpublished and every card has a text in each locale, so `album_members` never drops one.
  - `[low]` `[reject]` Blind: a Steam library set's album has an empty title and h1 (its name is nil) — no code creates a library set yet; naming it is the library-set entry's work (the design's "Ma ludothèque Steam"), noted in the Auto Run Result.
  - `[low]` `[reject]` Blind: the collection loads the library set's games and then drops them (`select(&:custom?)`) — no library set exists until the library-set entry, which should filter by kind in the query; fix adds a parameter; noted in the Auto Run Result.
  - `[medium]` `[intent_gap]` Blind: no index serves `CustomSet.where(player_id:)` without a kind filter (standings on every collection visit, `ReleasePlayer`) — real (both indexes on `player_id` are partial); a plain `player_id` index in the new table fixes it; moot under the intent gap, to carry into the re-run.
  - `[low]` `[reject]` Blind: the picker's search is a POST outside the reading role and the throttle, with a resubmit prompt on reload — deliberate (Design Notes), writes nothing, the collection's own search is unthrottled too, and the editor entry replaces the picker.
  - `[low]` `[reject]` Blind: refusal messages write 40, 3, 50, 10 instead of interpolating the constants — no named breakage until a constant changes; the editor entry rewrites these messages in the design's form.
  - `[low]` `[intent_gap]` Blind: a DELETE of the player's own library set answers "does not exist or is not yours" instead of the 404 edit and update give — real (`destroy` uses `authorize_custom_set`, not `editable_custom_set`); one-word fix, moot under the intent gap, to carry into the re-run.
  - `[low]` `[reject]` Blind: a throttled rename lands on the collection and drops the typed name — only after 20 writes in a minute; fix adds a branch.
  - `[low]` `[reject]` Blind: the picker does not say its 24 results are cut off — minimal picker the intent allows; fix adds copy and a branch.
  - `[low]` `[intent_gap]` Blind: untested paths: a visitor's picker POST, the throttle, the album filters on a custom set album — real gaps, test-only additions; moot, to carry into the re-run (grouped with the verification-gap throttle row).
  - `[low]` `[reject]` Blind: the album reads the set twice (authorize, then standings) — one indexed query by token; fix changes the query's signature.
  - `[low]` `[reject]` Blind: the picker's search runs `CollectionGrid`'s unused genre query — one extra query per search on a page the editor entry replaces.
  - `[low]` `[reject]` Blind: renaming to the identical name still writes and publishes — harmless; fix adds a branch.
  - `[false]` `[reject]` Blind: game order rests on ids with no `position` column — one multi-row INSERT takes its sequence values in VALUES order, and the design never reorders a custom set's games.
  - `[low]` `[intent_gap]` Edge: a set deleted between the policy check and the standings read makes `.sole` raise a 500 instead of a 404 — real race; direct fix (`first` or `RecordNotFound`); moot, to carry into the re-run.
  - `[medium]` `[intent_gap]` Edge: a NUL byte in the name raises in the Postgres adapter (500) — real; `clean_name` only squishes; reuse `Accounts::PersonaName::INVISIBLE` / `SPACE` as `Accounts::BanReason` does; moot, to carry into the re-run (grouped with the next row).
  - `[low]` `[intent_gap]` Edge: a name of zero-width or control characters only is saved and looks blank — same root cause and fix as the row above.
  - `[low]` `[reject]` Edge: more than 51 checked games across searches lose the extra ones silently — needs 52 picks; saving still shows the 50-games refusal.
  - `[low]` `[reject]` Edge: a game rated only in an earlier published season cannot be found by the picker — the intent allows the minimal picker; the full editor is entry 4 (Design Notes).
  - `[false]` `[reject]` Edge: the header counts more games than the grid shows — same refutation as the first Blind row.
  - `[medium]` `[intent_gap]` Edge: the data export holds no custom sets while account deletion erases them — real: AD-14 says "The data export is assembled in the web layer from `Accounts` and `Game` queries, custom sets, the Steam library list and active goals included", and `Game::ExportOf` has no custom sets; the intent-contract's **Never** lists "data export of custom sets (later entries)", yet no entry of the epic owns it (entry 8 exports the library list only), so the fix contradicts the contract. HALT.
  - `[low]` `[reject]` Edge (claim): the acceptance criterion says the EN COURS tests pass unchanged while the entry tests changed for MES SETS's place — the behaviour is the intended one; the fix edits this plan.
  - `[low]` `[intent_gap]` Verification gap: the custom set throttle is never exercised — test-only; moot, to carry into the re-run.
  - `[low]` `[intent_gap]` Verification gap: no test keeps a library set out of MES SETS, its count and the 10-set cap — test-only; moot, to carry into the re-run.
  - `[low]` `[intent_gap]` Verification gap: no controller test drives 51 picked slugs to the 50-games refusal — test-only; moot, to carry into the re-run.
  - `[low]` `[intent_gap]` Verification gap: the forms' "Sets" screen label is not asserted — test-only; moot, to carry into the re-run.
  - `[low]` `[reject]` Intent: the staging walkthrough is not covered — deploying is outward-facing; the author checks this high-risk entry on staging (epic decision), queued in pending-approvals.
  - `[low]` `[reject]` Intent: the other player's refusal is covered by HTTP tests, not a system test — the 403 page is server-rendered; a browser adds nothing to the controller test's assertions.
  - `[false]` `[reject]` Intent: the limits, the bank lock and the album's MODIFIER/SUPPRIMER reach into entry 4 — the limits are AD-35's operation rules and the controls are the minimal ones the verify line needs; not a defect.
  - `[false]` `[reject]` Intent: the minimal MES SETS list reaches into entry 5 — a deliberate tracer surface so the set can be reopened; not a defect.
  - `[low]` `[reject]` Intent: the album's slots read `HeldGames.editions` beside the standings query — both read holdings with `quantity > 0` in the same request; no divergence named.
  - `[false]` `[reject]` Intent: missing games without a slot — same refutation as the first Blind row.
  - `[false]` `[reject]` Intent: the tables carry the library kind and sync columns no surface uses — AD-35 defines the tables so; not a defect.

### 2026-10-31 — Review pass
- verdicts: 27 findings — high 0, medium 0, low 22, false 5, maybe-false 0
- findings:
  - `[low]` `[reject]` Blind: `visible` lacks the per-grapheme code-point cap of `PersonaName.clean` — the 40-character limit and the database check bound a stacked name; no player-facing harm beyond an odd-looking name of their own.
  - `[low]` `[patch]` Blind: a name of combining marks alone passes `name_required` and shows blank — `visible` now returns "" unless `PersonaName::VISIBLE` matches; operation test added.
  - `[low]` `[patch]` Blind: names are not NFC-normalised, so a decomposed accent duplicates a name past `lower(name)` — `visible` normalises to NFC first; operation test added.
  - `[low]` `[reject]` Blind: generic failure codes (`name_taken`, `too_few_games`…) in the shared `errors.game` namespace — no other Game operation returns them; a rename across operations, locales and tests is more than a direct correction for a collision nobody meets yet.
  - `[low]` `[reject]` Blind: the new `errors.game` keys break the en.yml order — the block was already unsorted before this change (`unknown_player` last; fr unsorted) and no CI step normalises it.
  - `[low]` `[reject]` Blind: the picker's counter and "Selected · n" legend do not update on check without a round trip — the minimal picker the ticket allows; the editor entry replaces it with the live counter; a Stimulus controller is more than a direct correction.
  - `[low]` `[reject]` Blind: `found_card_season_ids` and `album_members` compose Catalog query results in the web layer — both read through Catalog queries (`CollectionGrid`, `LatestPublishedCardSeasons`); the picker part goes with the editor entry; no rule named breaks (packwerk and the read role pass).
  - `[low]` `[reject]` Blind: `ExportOf.custom_sets` repeats the rows-and-games read of `CustomSetStandings` — both order by `CustomSetGame.id` in the same domain; extracting a shared reader is a refactor, and the extra empty query on a player without sets is negligible.
  - `[low]` `[reject]` Blind: the collection's query-count test pins only the case with no sets — `custom_set_standings_test` pins the three queries with sets; a per-row regression would show there.
  - `[low]` `[patch]` Blind: a complete custom set album is never rendered — controller test added: 3/3, `set-album__header--complete`, no ticks or tier header.
  - `[low]` `[patch]` Blind: the throttle test does not prove the 21st request wrote nothing — the test now checks the name stayed "Nom 19" and that a throttled create and delete write nothing (grouped with the verification-gap throttle row).
  - `[low]` `[reject]` Blind: `edit.html.erb` reads `params[:token]` although the record is loaded — the token is the one the policy just authorised; cosmetic.
  - `[low]` `[reject]` Blind: Enter in the name field runs the search instead of saving — the search re-renders with the name and picks kept and writes nothing; making Enter save would make Enter in the search field save instead, the common case; the editor entry replaces the form.
  - `[low]` `[reject]` Blind: the English copy is unidiomatic ("Search a game of the catalog", "1 / 10") — the strings follow the UX copy; wording is the author's call in the editor entry.
  - `[false]` `[reject]` Edge: a library set's album shows an empty heading — no flow in this change creates a library set; carried from the first pass: the library-set entry gives it its display name.
  - `[false]` `[reject]` Edge: count and slots diverge when a game loses its published card-season — a season has only `draft` and `published` statuses and is never unpublished; a set game passed `PublishedCardIds.within` when created, so it keeps a rated published card-season.
  - `[false]` `[reject]` Edge: the export drops a set game with no published card-season — same refutation as the row above; `CardViews` holds every published card's text in both locales.
  - `[low]` `[patch]` Edge: a deletion that finds the set already gone redirects to the deleted album, which 404s — `destroy` now redirects a refusal to the collection; controller test added.
  - `[low]` `[reject]` Edge: one valid plus two unknown slugs reads "too few games" instead of "not in catalog" — the picker submits only published slugs it rendered; both are refusals that write nothing.
  - `[low]` `[reject]` Edge (claim): a refusal re-render drops picks over 51 or unresolved slugs — only a forged request reaches it; the refusal message still names the problem.
  - `[low]` `[patch]` Edge (claim): the plan names the data export controller test, which the diff left untouched — controller test added: the downloaded file lists the set's token, name, kind and games by slug in order.
  - `[low]` `[patch]` Verification: the picker search test found nothing, so the results list, its exclusion of picked games and its 24 cap were unchecked — the test now seeds 30 matching published games, picks one, and asserts it is checked once and 24 other found games are unchecked.
  - `[low]` `[patch]` Verification: the custom album's NEW tags are not asserted — controller test added: only the game gained since the collection was last seen carries the tag.
  - `[low]` `[patch]` Verification: the throttle test covers renames only — the same test now sends a throttled create and delete and asserts nothing is written (grouped with the Blind throttle row).
  - `[low]` `[patch]` Intent: no test asserts a missing slot names its game — the album test now reads the not-owned faces' titles ("Portal", "Blue Depths").
  - `[false]` `[reject]` Intent: no system test covers another player's refusal — the verify clause asks the test kinds together to cover the story; controller and policy tests cover the refusal, and the staging walkthrough checks it on the URL.
  - `[false]` `[reject]` Intent: delete through a browser confirm, not the design's dialog — the editor entry owns SUPPRIMER's confirmation dialog by its own description; the alignment note is descriptive.

## Design Notes

The album's games are in the order they were picked (`game_custom_set_games.id`); a custom set has no other order yet. The card link from a custom set album carries no set context, so the card detail opens with its default browsing.

The picker posts its search to a separate `picker` action, so the CSRF token never lands in a URL and the typed name and checked games survive a search without script; it writes nothing. It searches the published season only; the full editor (a later entry) replaces it.

Limits live in the operations now because a tracer that writes 0-game or 200-set states would need a cleanup; the later editor entry only adds the design's refusal presentation.

## Verification

**Commands:**
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- expected: schema diff limited to the two tables
- `bin/rails test test/domains/game/custom_set_operations_test.rb test/domains/game/custom_set_standings_test.rb test/domains/catalog test/policies test/controllers/custom_sets_controller_test.rb test/controllers/library_controller_test.rb test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb test/domains/accounts/delete_player_test.rb test/domains/steam` -- expected: pass
- `CHROME_BIN=/usr/bin/chromium bin/rails test test/system/custom_sets_test.rb test/system/collection_set_test.rb test/system/library_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Change.** A player creates a custom set of 3 to 50 published games from a minimal server-rendered picker, opens it as an album with owned / total and a not-owned face naming each missing game, renames it, and deletes it. Only the author passes the policy. MES SETS on the player's own collection lists the sets. The data export lists each set by token with its name, kind, creation time and games by slug and title. Account deletion erases the sets. The second pass re-applied the first attempt on `0070ff88` (the weekly mission rename). It kept both changes in the `accounts.dialog.note` conflict in en.yml and fr.yml, then added the export, the carried fixes and this pass's patches.

**Files.**
- `db/migrate/20261031100000_create_game_custom_sets.rb`, `db/schema.rb`: the two tables, with their indexes (a plain `player_id` index included) and checks.
- `app/domains/game/app/models/game/custom_set{,_game}.rb`, `events/game/custom_set_{created,renamed,deleted}.rb`, `operations/game/{create,rename,delete}_custom_set.rb`, `custom_set_steps.rb`: the models, events and operations. `clean_name` normalises to NFC, strips invisible characters and requires a visible one.
- `app/domains/game/app/queries/game/custom_set_by_token.rb`, `custom_set_standings.rb`, `export_of.rb`: the reads, the export's custom sets among them.
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb`, `latest_published_card_seasons.rb`: the published games by id or slug, and each game's latest published face.
- `app/policies/custom_set_policy.rb`, `config/routes.rb`, `app/controllers/custom_sets_controller.rb`, `concerns/custom_set_picking.rb`, `concerns/set_album_loading.rb`, `library_controller.rb`, `app/helpers/shell_helper.rb`: the web layer.
- `app/views/custom_sets/*`, `app/views/library/{_album,_custom_sets,_entry,show}.html.erb`, `app/frontend/styles/collection-custom-sets.css`, `app/frontend/entrypoints/application.css`: the album, the picker, the forms and MES SETS.
- `app/models/player_export.rb`: the `customSets` section of the export file.
- `app/domains/game/app/operations/game/release_player.rb`: account deletion erases the sets.
- `config/locales/en.yml`, `fr.yml`, `config/i18n-tasks.yml`: the `custom_sets.*` and `errors.game.*` strings. The account deletion note and the legal page's stored-data line and deletion paragraph now name the custom sets.
- Tests:
  - `test/controllers/custom_sets_controller_test.rb`, `library_controller_test.rb`, `accounts_controller_test.rb`, `pages_controller_test.rb`, `data_exports_controller_test.rb`;
  - `test/domains/game/custom_set_{operations,standings}_test.rb`, `export_of_test.rb`;
  - `test/domains/catalog/{published_card_ids,latest_published_card_seasons}_test.rb`;
  - `test/domains/accounts/delete_player_test.rb`, `test/models/player_export_test.rb`, `test/policies/custom_set_policy_test.rb`, `test/support/custom_sets.rb`;
  - `test/system/custom_sets_test.rb`, `library_test.rb`.

**Review (second pass).** 27 findings: 10 rows patched in 9 entries (all low; the two throttle rows share one fix), none deferred, 17 rejected (each with its reason in the Review Triage Log above).
- Patched:
  - NFC names;
  - visible-character names;
  - a deletion that finds the set gone returns to the collection;
  - tests for a complete album, the NEW tags, the missing faces' titles, the picker's results and their cap, the throttle on create, rename and delete, and the export file through the controller.
- Rejected: the generic failure codes, the en.yml key order, the picker's live counter and its Enter key, the duplicated export read, the library set's heading, the reachability claims on unpublished games, and the copy wording.
- The patches were applied in this session, because the first pass's implementer was not continued across the intent-gap halt.

Follow-up review recommended: false. This pass patched 9 entries, all low (high 0, medium 0).

**Verification** (all pass):
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb`, on Postgres 18. The schema diff is the two tables only, and the schema load-then-dump round trip is identical.
- `bin/ci`: every step passed. The full Rails suite ran 3804 runs, 0 failures. The round-trip step compares the working tree against the index, so it flagged the index on the not-yet-staged schema; it passes once `db/schema.rb` is staged.
- `CHROME_BIN=/usr/bin/chromium bin/rails test test/system/custom_sets_test.rb test/system/collection_set_test.rb test/system/library_test.rb test/system/settings_test.rb`: 36 runs, 0 failures.
- `npm run test:js`: 756 tests.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`: all clean.

**Residual risks.**
- The staging walkthrough of the ticket's verify clause is the author's: create a set of three games, open its album, rename and delete it, and get refused on another player's URL.
- The library-set entry must give that set its display name ("Ma ludothèque Steam" / "My Steam library") and filter `CustomSetStandings` by kind on the collection.
- The picker is the minimal one; the editor entry replaces it.
