---
title: 'The custom set editor picks 3 to 50 published games, at most 10 sets'
type: 'feature'
ticket: 4
created: '2026-11-01'
status: 'built'
baseline_revision: 'ded021fb11ba64766b8b94ed5924bd3ab41808de'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A custom set is built in a minimal server form (text rows, a CHERCHER round trip, the published season only), its games cannot be changed after creation, and SUPPRIMER is a browser confirm; the design's editor and delete dialog are missing.

**Approach:** Replace the minimal picker and the rename page with the design's Custom set editor (option B, modelled on the trade card picker): a `<dialog>` on the collection entry (NOUVEAU SET) and on a custom set's album (MODIFIER LE SET, filled), whose game grid is served page by page by a reading GET over every published game, with picks held by one Stimulus root controller and its state module; save goes through `Game::CreateCustomSet` or a new `Game::EditCustomSet` (name and games), refusals come back inline; SUPPRIMER opens the design's Delete-set dialog.

## Boundaries & Constraints

**Always:**
- Games offered: every catalog game with a rated card-season in a published season (`Catalog::PublishedCardIds`' set), one card per game, its face the card-season of the latest published season holding it (`card-s` = `CardComponent size: :s`); a game not held keeps `owned: false` (grey face, lock) and can be picked. Order: face's season number descending, then card number, then id.
- Search by title (current locale) or studio as the player types (debounced), combined with one chip of the radio group TOUT (default), POSSÉDÉES, MANQUANTES, SÉLECTIONNÉS · n (only the picked games, in pick order). Owned means held in any edition (`Game::CollectionStates` owned/missing on the faces relation).
- Limits stay in the operations under `lock_bank`: name required after cleaning, 40 characters, unique among the player's custom sets (renaming to its own name succeeds); 3 to 50 games; 10 `custom` sets per player on create; games must be published (`game_not_in_catalog`). Editing goes through `Game::EditCustomSet(player:, token:, name:, card_ids:)` (one `Game::CustomSetEdited` event, data `player_id` and `custom_set_id`), which replaces `Game::RenameCustomSet` / `Game::CustomSetRenamed` (no stream reader exists; removing an unreleased event class has precedent).
- The 51st pick is refused in the browser: nothing is added, the card flashes a 3px alert frame for an instant (none under reduced motion), the 50-games refusal shows in the foot. Every other refusal comes from the server on ENREGISTRER, inline in the foot, nothing saved, the editor and its picks kept.
- Refusal copy (both locales, `errors.game.<code>`, U+202F in French before `:` `;` `?` `!` and inside « »): FR from the copy deck — `name_required` "NOM REQUIS · Donnez un nom à votre set.", `name_taken` "NOM DÉJÀ PRIS · Un autre de vos sets porte ce nom.", `too_few_games` "3 JEUX AU MOINS · Ajoutez encore 1 jeu pour enregistrer le set." / "… encore 2 jeux …" (plural on the missing count, `zero` form included), `too_many_games` "50 JEUX AU PLUS · Retirez un jeu pour en ajouter un autre.", `too_many_sets` "10 SETS AU PLUS · Retirez un set pour en créer un autre."; EN in the same form ("NAME REQUIRED · Give your set a name.", "NAME TAKEN · Another of your sets has this name.", "3 GAMES AT LEAST · Add 1 more game to save the set." / "Add 2 more games …", "50 GAMES AT MOST · Remove a game to add another.", "10 SETS AT MOST · Remove a set to create another."); `name_too_long`, `game_not_in_catalog`, `custom_set_not_found` keep their wording.
- Editor copy from the copy deck: titles "NOUVEAU SET" / "MODIFIER LE SET"; "NOM DU SET" with a live "n / 40" counter (the field takes no more than 40); search label "RECHERCHER UN JEU", placeholder "Rechercher un jeu du catalogue"; chips; foot counter "n jeux" + "3 à 50" ("0 jeu", "1 jeu"); a picked card's accessible name ends with ", dans le set"; "ANNULER", "ENREGISTRER" (primary, the only lime button); "✕" named "Fermer"; no-match line "Aucun jeu trouvé pour « … »."
- Behaviour: first focus on the name field; the grid is one tab stop with roving focus and arrow keys; click, Enter or Space toggles a game; ANNULER, ✕, Esc or the scrim close and discard every change (name and picks back to what the editor opened with, refusal cleared), focus back to the opener. Saving a new set lands on the collection (MES SETS lists it); saving an edit lands on the album showing its new games and name.
- Delete-set dialog (modelled on `friends/_remove_dialog.html.erb`): title "Supprimer « name » ?", text "Le set disparaît de vos sets, avec son objectif s'il en est un. Vos cartes restent dans votre collection.", SUPPRIMER (primary, DELETE form), ANNULER (closes, nothing changes); the toast "SET SUPPRIMÉ · « name » ne fait plus partie de vos sets." stays.
- Only the set's author sees the editor, MODIFIER and SUPPRIMER; a Steam library set's album has none. The games GET is a policy-checked read (signed-in player), on the reading role, writing nothing; tokens and slugs only in HTML and URLs. Desktop: a wide modal; phone (< 720px): a full-height sheet, the refusal line above ANNULER / ENREGISTRER sharing the row, 48px tall.
- No `style` attribute; no markup built in script (clone `<template>`s); new strings in en.yml and fr.yml.

**Never:** tiers, rewards, goals, the goal button, MES SETS tiles or the new-set tile (entry 5), the Steam library set's creation or sync or its delete text; a browser `confirm` for deletion; the full catalog rendered into the page; React; keeping the old `new` / `edit` / `picker` pages.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | name "Mes favoris", 3 picked games | set created, redirect 303 to the collection, listed in MES SETS | No error expected |
| Edit | album's MODIFIER: rename, remove 1 game, add 2 | name and games replaced in pick order, one `CustomSetEdited`; redirect to the album | No error expected |
| Edit keeps own name | same name, other games | saved | No error expected |
| 51st pick | 50 picked, toggle another | nothing added, card flashes, 50-games refusal shown | browser-side refusal |
| Too few | 2 picked, ENREGISTRER | 422 inline "3 GAMES AT LEAST · Add 1 more game…" | `Failure(:too_few_games)` |
| Empty name | "" or spaces, ENREGISTRER | 422 inline name refusal | `Failure(:name_required)` |
| Name taken | another set's name, any case | 422 inline | `Failure(:name_taken)` |
| 11th set | 10 sets exist (another tab), create | 422 inline 10-sets refusal; nothing written | `Failure(:too_many_sets)` |
| Forged 51 / unknown slug | POST/PATCH | 422 inline | `too_many_games` / `game_not_in_catalog` |
| Edit others' or library set | PATCH another token / a library set | 403 / 404 as today | policy / RecordNotFound |
| Games GET | q "port", state owned/missing/picked, page | the matching published games, owned flags, "CHARGER PLUS" when more | visitor: sign-in refusal |
| Game only in an earlier published season | search its title | found, its face that season's | No error expected |
| Delete | SUPPRIMER → dialog SUPPRIMER | set gone, collection with toast | ANNULER: nothing changes |

</intent-contract>

## Code Map

- `app/controllers/custom_sets_controller.rb`, `concerns/custom_set_picking.rb` -- today's actions; replace `new`/`edit`/`picker` with a `games` GET (results frame) and keep `show`/`create`/`update`/`destroy`; `authorize_custom_set`/`editable_custom_set`, `album_members`, the throttle stay. Replace `CustomSetPicking` with an editor concern (picked slugs → card ids via `Catalog::PublishedCardIds.by_slug`, keep the 51-slug cap).
- `app/policies/custom_set_policy.rb` (+ its test) -- `games?` a player; drop `new?`/`edit?`/`picker?` if unused.
- `config/routes.rb:46-47` -- custom set routes; add `get "library/custom-sets/games"` before the resources, drop `new edit picker`.
- `app/domains/game/app/operations/game/{create,rename,delete}_custom_set.rb`, `custom_set_steps.rb` -- move `games_in_range`/`in_catalog` into the steps; `EditCustomSet` = require player, clean name, games in range, in catalog, then `lock_bank`, `locked_custom_set`, `name_free(except:)`, update name, delete the set's game rows and insert the new ones in order, publish. Delete `rename_custom_set.rb` and `events/game/custom_set_renamed.rb`; add `custom_set_edited.rb`.
- `app/domains/catalog/app/queries/catalog/latest_published_card_seasons.rb` -- add a relation of each published game's latest published card-season (filterable by card ids and by text, ordered as the Always rule says); `collection_grid.rb` `text_match` (private) is the title/studio match to share, not copy.
- `app/domains/game/app/queries/game/collection_states.rb` -- `call(player, relation, states: ["owned"|"missing"])` filters the faces relation; `held_games.rb` `call(player_id, card_ids:)` gives owned flags; `Catalog::CardViews.call(ids, locale:)` the card views.
- `app/views/custom_sets/*` -- replace `new`, `edit`, `_picker`, `_games`, `_name_field`, `_actions` with the editor partial, the games frame (`games.html.erb` with `turbo_frame_tag`), the delete dialog; `show.html.erb` holds the album actions (MODIFIER `ButtonComponent(opens:)`, SUPPRIMER `opens:` the dialog) and renders the editor filled and the dialog.
- `app/views/library/_custom_sets.html.erb` -- "+ NOUVEAU SET" opens the editor (`ButtonComponent(opens: …)`) and the empty editor renders there, below 10 sets.
- `app/views/trades/_picker.html.erb`, `_pick.html.erb`, `app/frontend/styles/trades-picker.css` (`.trade-pick__toggle` overlay button, `--picked` lime ring, `.trade-picker__refusal` hidden through `:has(> [hidden])`), `trades-responsive.css:30-35` (full-height sheet), `shell-controls.css:189-280` (`.modal`, `.modal--wide`, `__panel`, `__head`, `__title`, `__close`, `__handle`) -- the look to model; chips: `label.filter-chip > input.filter-chip__box + span.filter-chip__text` (`collection-filters.css`).
- `app/views/friends/_remove_dialog.html.erb`, `dialog_controller.ts`, `dialog_opener_controller.ts`, `lib/dialog.ts` -- the delete dialog's markup and focus return; the editor's opener is `ButtonComponent(opens:)` too and the editor controller resets on `close`.
- `app/frontend/lib/trade_board.ts`, `trade_board_views.ts`, `lib/grid_keys.ts` (`columnsOf`, `nextIndex`), `lib/templates.ts` (`cloneContent`), `lib/i18n.ts` (`t`, plural templates), `app/helpers/screen_wiring_helper.rb` (`screen_strings`) -- state-module, strings and template patterns. Controllers register by glob (`custom_set_editor_controller.ts` → `custom-set-editor`).
- `app/frontend/styles/collection-custom-sets.css` (201 lines) -- drop the picker rules; the editor's CSS may go in a new `collection-custom-set-editor.css` imported in `app/frontend/entrypoints/application.css`.
- `app/views/library/_set_tile_page.html.erb` -- the "CHARGER PLUS" nested `turbo_frame_tag` pattern for the games frame's next page.
- Tests to change: `test/domains/game/custom_set_operations_test.rb` (rename rows → edit rows), `test/controllers/custom_sets_controller_test.rb` (picker/new/edit tests → games GET, editor rendering, turbo-stream refusals), `test/policies/custom_set_policy_test.rb`, `test/system/custom_sets_test.rb`, `test/system/library_test.rb` (tabs from "+ New set"), `test/controllers/library_controller_test.rb` (MES SETS markup). Models: `test/system/trades_test.rb:185-236` (picker toggles, refusal), `test/system/friends_test.rb:248-275` (dialog cancel, focus, confirm, toast).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/operations/game/edit_custom_set.rb`, `custom_set_steps.rb`, `create_custom_set.rb`, `events/game/custom_set_edited.rb` -- edit operation and shared steps; remove the rename operation and event -- games become editable.
- [x] `app/domains/catalog/app/queries/catalog/latest_published_card_seasons.rb`, `collection_grid.rb` -- the faces relation with shared text match -- every published game is findable.
- [x] `app/controllers/custom_sets_controller.rb` + editor concern, `app/policies/custom_set_policy.rb`, `config/routes.rb` -- `games` GET (48 per page, state all/owned/missing/picked, `q`, `games[]`, `page`; "CHARGER PLUS" frame); `create` → 303 to the collection, `update` → `EditCustomSet` then 303 to the album; a refusal answers 422 with a turbo stream replacing the editor's refusal line (HTML fallback: redirect back with the alert); `too_few_games` interpolates the missing count.
- [x] `app/views/custom_sets/_editor.html.erb`, `games.html.erb` (+ a game partial), `_delete_dialog.html.erb`, `show.html.erb`, `app/views/library/_custom_sets.html.erb` -- the editor dialog (form with name + counter, search, chips, lazy games frame, a `<template>` for one `games[]` hidden input and one for the 50-games refusal, the initial `games[]` inputs of an edited set, foot), the delete dialog, the openers; delete the old views.
- [x] `app/frontend/lib/custom_set_editor.ts` (+ `.test.ts`), `app/frontend/controllers/custom_set_editor_controller.ts` -- state: picks (ordered slugs), initial picks and name, chip, query, active toggle, refusal; transitions toggle (cap 50 → refused), setFilter, move, reset; the controller loads the games frame (`src` from a server URL + params, 250ms debounce on typing), reflects picks on loaded cards (`aria-pressed`, picked class, accessible name suffix), rewrites the hidden inputs, the counters and the chip count, flashes the refused card, focuses the name on open and resets on `close`.
- [x] `app/frontend/styles/collection-custom-set-editor.css`, `collection-custom-sets.css`, `entrypoints/application.css` -- editor look (wide modal, 26px check box, lime check and 3px lime frame 9px out, alert flash keyframes under `prefers-reduced-motion: no-preference`, foot), phone sheet; remove dead picker rules.
- [x] `config/locales/en.yml`, `fr.yml` -- editor, dialog and refusal strings; remove unused picker/edit keys (`i18n-tasks unused` clean).
- [x] Tests: `test/domains/game/custom_set_operations_test.rb` (edit matrix: rename, games replaced in order, own name kept, every refusal writes nothing, event, other player's / library set `custom_set_not_found`); `test/domains/catalog/latest_published_card_seasons_test.rb` (relation: earlier-season-only game, latest face, text by title and studio, order); `test/controllers/custom_sets_controller_test.rb` (games GET states, query, picked order, paging, owned flags, no db id, GET writes nothing, visitor refused; editor and dialog rendered for the author only and not on a library set; create/update success redirects; each refusal row as a turbo stream in en and fr; throttle kept); `test/policies/custom_set_policy_test.rb`; `test/system/custom_sets_test.rb` (create from the collection through search and chips; edit from MODIFIER adding/removing a game and renaming; ANNULER discards; delete dialog cancel then confirm with the toast; 51st game flash refusal, 2 games, empty name, 11th set refused with messages; one refusal in French); `test/system/library_test.rb` if its tab order changes.

**Acceptance Criteria:**
- Given a signed-in player on the collection, when they press "+ NOUVEAU SET", type a name, search "Seed", pick three games (one not owned) and press ENREGISTRER, then the editor closes on the collection and MES SETS lists the set with its owned / total.
- Given the author on a custom set's album, when they press MODIFIER, the editor opens titled "MODIFIER LE SET" with the name and the set's games picked (SÉLECTIONNÉS · 3); after removing one, adding two and renaming, ENREGISTRER lands on the album with the new name and 4 slots.
- Given the editor open with changes, when the player presses ANNULER (or Esc), then reopening shows the name and picks it opened with.
- Given the author on the album, when they press SUPPRIMER, a dialog asks "Delete “name”?"; ANNULER keeps the set and returns focus to SUPPRIMER; SUPPRIMER deletes it and lands on the collection with the toast.
- Given 50 picked games, when the player picks another, then it is not added, the 50-games refusal shows and the counter stays at 50; given 2 games, an empty name or a tenth set already saved elsewhere, ENREGISTRER shows the matching refusal and saves nothing, in English and in French.
- Given another player or a visitor, then no editor, MODIFIER or SUPPRIMER is rendered for them and the games GET refuses a visitor.

## Implementation Notes

Decisions:
- `Catalog::LatestPublishedCardSeasons.faces(query:, locale:, picked:)` is the faces relation: a `DISTINCT ON (card_id)` subquery of rated card-seasons in published seasons, latest season first; ordered season number desc, number, id, or, given `picked` card ids, in their order (`in_order_of`). `CollectionGrid.text_match` is now public and shared, not copied. `Catalog::PublishedCardIds.slugs(card_ids)` gives the edited set's picks as slugs.
- `CustomSetSteps` now holds `games_in_range`, `in_catalog` and `insert_games`; `Game::EditCustomSet` deletes the set's game rows and reinserts them in pick order inside the `lock_bank` transaction and publishes `Game::CustomSetEdited`. `RenameCustomSet` and `CustomSetRenamed` are gone (no handler or stream reader used them).
- Controller: `CustomSetPicking` became `CustomSetEditing` (`GAMES_PAGE = 48`, states all/owned/missing/picked, the 51-slug cap kept). `games` answers a frame request only (a plain GET goes to the collection), after `authorize :custom_set, :games?`. Refusals answer 422 with `turbo_stream.update("custom-set-editor-refusal", …)`; the HTML fallback redirects (303) with the alert. `too_few_games` interpolates the missing count (`GAMES.min - distinct picks`).
- Editor markup: one `<dialog id="custom-set-editor">` with the `dialog` controller (scrim, close, focus return to the opener, close on `turbo:before-cache`) and `custom-set-editor`. The form (`#custom-set-editor-form`) holds only the name and the hidden `games[]` inputs; the search and the chip radios sit outside it, so they are never submitted and Enter in them submits nothing; ENREGISTRER reaches the form through `form=`. First focus is the name field's `autofocus`. The title is a `<p class="modal__title">`, as in the remove-friend dialog, so the collection's heading outline (asserted by library tests) is unchanged.
- Games frame: `turbo-frame#custom-set-games` (lazy, `src` the games URL); the controller rewrites `src` from its state (250ms debounce on typing, immediate on a chip). Each next page is a nested `turbo-frame#custom-set-games-page-N` whose `ul` is a `page` target: the controller moves its cards into the first grid, so the grid stays one list with one roving tab stop, and focuses the first new card when CHARGER PLUS took the focus with it.
- Picked state on cards: `custom-set-game--picked` class, `aria-pressed`, and the accessible name `data-label` + ", in the set"/", dans le set". The check box and the 3px lime frame (9px out) are CSS; the 51st toggle adds `custom-set-game--refused` for 400ms, animated only under `prefers-reduced-motion: no-preference` and not `data-motion="reduced"`.
- The refusal line is cleared by any toggle, typing in the name, or closing; a server refusal stays until then.
- Delete-set dialog: `#delete-custom-set`, DELETE form with `data-turbo=false` like the remove-friend dialog; the album's SUPPRIMER is now a secondary small button (the danger variant stays for account deletion).
- Card accessible base names: "%{title}, owned" / "%{title}, not owned" ("possédé" / "non possédé"); no-results copy "Aucun jeu à afficher." / "No game to show." for an empty chip without a search; chip legend "Afficher" / "Show" (visually hidden). These strings were not in the copy deck.
- Phone grid columns are `card-s` + 12px wide so two columns fit a 390px sheet with room for the picked frame.

Files touched: `app/controllers/custom_sets_controller.rb`, `app/controllers/concerns/custom_set_editing.rb` (new, replaces `custom_set_picking.rb`), `app/policies/custom_set_policy.rb`, `config/routes.rb`, `app/domains/game/app/operations/game/{create_custom_set,custom_set_steps,edit_custom_set}.rb`, `app/domains/game/app/events/game/custom_set_edited.rb` (rename operation and event deleted), `app/domains/catalog/app/queries/catalog/{latest_published_card_seasons,collection_grid,published_card_ids}.rb`, `app/views/custom_sets/{_editor,_game,games,_delete_dialog,show}.html.erb` (old `new`, `edit`, `_picker`, `_games`, `_name_field`, `_actions` deleted), `app/views/library/_custom_sets.html.erb`, `app/frontend/lib/custom_set_editor.ts` (+ test), `app/frontend/controllers/custom_set_editor_controller.ts`, `app/frontend/styles/collection-custom-set-editor.css` (new), `collection-custom-sets.css`, `entrypoints/application.css`, `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` (ignore `custom_sets.editor.strings.*`, read only by script), tests listed in the plan.

Surprises:
- `assert_select` treats `?` in a selector as a substitution placeholder: hrefs with a query go through `[href=?]`.
- A primary button's hover lifts it 3px, so the phone test compares the two buttons' rows with a tolerance.
- A pick clicked while the debounced search reload is landing could be lost in a system test; the tests wait for the searched grid before picking.

Verification: targeted Ruby tests, full `bin/rails test` (3822 runs, green), `test/system/custom_sets_test.rb` (3 consecutive green runs), `library_test.rb`, `collection_set_test.rb`, `npm run test:js`, `tsc`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `format:check`, `lint:css`, `i18n-tasks missing/unused`, `rubocop`: all clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 5, false 0, maybe-false 1
- findings:
  - `[low]` `[patch]` Quick: `custom_sets.deleted.text` in fr.yml lost its U+202F inside « » (bytes checked against the baseline) and the controller test was changed to expect plain spaces — both restored to the narrow no-break space; the line no longer differs from the baseline.
  - `[low]` `[patch]` Quick: Stimulus runs `gameTargetConnected` before `connect()`, so cards present at connect (a Turbo cache restore of the album) were reflected against the empty state and showed as unpicked while counted — `connect()` now reflects every game target and the roving tab stop after reading the picks.
  - `[low]` `[patch]` Quick: `typed()` ignores composing input events and nothing listened to `compositionend`, so a search finished through an IME never loaded — `compositionend->custom-set-editor#typed` added, as the other search fields do.
  - `[low]` `[patch]` Quick: the refused-card flash was gated on `prefers-reduced-motion: no-preference`, ignoring a player's forced full motion (`lib/motion.ts` rule) — the flash now runs by default and is off for `html[data-motion="reduced"]` and under `prefers-reduced-motion: reduce` without `data-motion="full"`.
  - `[low]` `[patch]` Quick: the "add N more" count counted unresolved slugs (nil ids) as games — `refusal_values` now counts `card_ids.compact.uniq`.
  - `[maybe-false]` `[reject]` Quick: the `turbo:before-cache` close resets the editor only on the asynchronous `close` event, so a cached snapshot might keep abandoned picks as the ones it "opened with" — would need a browser test of Back with the editor open; if true it is low (nothing is saved without ENREGISTRER, and the restored editor shows the picks it holds), so rejected.

## Design Notes

The catalog is about 12,000 games a season, so the grid is never rendered whole: the dialog's games frame loads lazily on open and reloads on each search or chip change through a GET, a page of 48 at a time. Picks live only in the browser until ENREGISTRER, so a page reload of the frame never loses them: the controller re-applies the picked state to whatever cards arrive, and the SÉLECTIONNÉS chip sends the picked slugs to the GET. The form is not inside a frame: a success redirect is a Turbo Drive visit (the dialog goes with the page), and a refusal is a 422 turbo stream that only updates the refusal line, so the picks survive.

Delete-and-reinsert of an edited set's game rows keeps the album in pick order (`game_custom_set_games.id`); a set has at most 50 rows.

## Verification

**Commands:**
- `bin/rails test test/domains/game/custom_set_operations_test.rb test/domains/game/custom_set_standings_test.rb test/domains/catalog test/policies test/controllers/custom_sets_controller_test.rb test/controllers/library_controller_test.rb test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb` -- expected: pass
- `bin/rails test test/system/custom_sets_test.rb test/system/library_test.rb test/system/collection_set_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rubocop` -- expected: clean

## Auto Run Result

Status: built.

**Change.** The minimal picker and the rename page are replaced by the design's Custom set editor (option B): a wide modal (a full-height sheet on the phone) opened by "+ NOUVEAU SET" on the collection and by MODIFIER on a custom set's album, filled with the set there. It has a name field with its live "n / 40" counter, a search by title or studio as the player types, the TOUT / POSSÉDÉES / MANQUANTES / SÉLECTIONNÉS · n chips, and a grid of `card-s` cards over every published game, one per game on its latest published face, not-owned ones grey with their lock. The grid is served 48 at a time by a reading `GET library/custom-sets/games` frame with CHARGER PLUS. Picks live in the browser (state module `lib/custom_set_editor.ts`, root controller `custom-set-editor`): one tab stop with arrow keys, toggle by click, Enter or Space, ", dans le set" in the accessible name, the 51st pick refused with a flash and the 50-games refusal. ENREGISTRER creates the set (back to the collection, listed in MES SETS) or edits it through the new `Game::EditCustomSet` (name and games in pick order, one `Game::CustomSetEdited`; the rename operation and event are gone), and every server refusal (empty name, name taken, under 3 games with the missing count, 10 sets, forged input) comes back inline as a 422 turbo stream, in the copy deck's wording in both languages. ANNULER, ✕, Esc or the scrim discard every change. SUPPRIMER opens the Delete-set dialog (title naming the set, the design's text, SUPPRIMER / ANNULER) instead of a browser confirm.

**Files.**
- `app/domains/game/app/operations/game/{edit_custom_set,create_custom_set,custom_set_steps}.rb`, `events/game/custom_set_edited.rb`: the edit operation and the steps shared with create (rename operation and event deleted).
- `app/domains/catalog/app/queries/catalog/{latest_published_card_seasons,collection_grid,published_card_ids}.rb`: the faces relation over every published game, the shared title/studio match, slugs by card id.
- `app/controllers/custom_sets_controller.rb`, `concerns/custom_set_editing.rb` (replaces `custom_set_picking.rb`), `app/policies/custom_set_policy.rb`, `config/routes.rb`: the games frame, create/update with inline refusals; `new`, `edit` and `picker` removed.
- `app/views/custom_sets/{_editor,_game,games,_delete_dialog,show}.html.erb`, `app/views/library/_custom_sets.html.erb`: the editor, its games, the delete dialog and their openers (six old views deleted).
- `app/frontend/lib/custom_set_editor.ts` (+ test), `app/frontend/controllers/custom_set_editor_controller.ts`: state and controller.
- `app/frontend/styles/collection-custom-set-editor.css` (new), `collection-custom-sets.css`, `entrypoints/application.css`: the editor's look and phone sheet; old picker rules removed.
- `config/locales/en.yml`, `fr.yml`, `config/i18n-tasks.yml`: editor, dialog and refusal strings.
- Tests: `test/domains/game/custom_set_operations_test.rb`, `test/domains/catalog/latest_published_card_seasons_test.rb`, `test/controllers/custom_sets_controller_test.rb`, `test/policies/custom_set_policy_test.rb`, `test/system/custom_sets_test.rb`, `test/system/library_test.rb`.

**Review (quick).** 6 findings: 5 patched (all low), none deferred, 1 rejected (maybe-false, if true low: a cached snapshot taken with the editor open might keep abandoned picks).

Follow-up review recommended: false. This pass patched 5 entries, all low (high 0, medium 0).

**Verification** (all pass, after the patches):
- `bin/rails test`: 3822 runs, 0 failures.
- `bin/rails test test/system/custom_sets_test.rb test/system/library_test.rb test/system/collection_set_test.rb`: 27 runs, 0 failures.
- `npm run test:js` (768), `tsc`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing` / `unused`, `bin/rubocop`: clean.
- The new French strings pass the check of `test/config/french_typography_test.rb` (on local `develop`, not yet in this branch's base); the remaining offenders in fr.yml are older lines that commit fixes.

**Copy the UX did not specify.** The whole English editor and refusal copy (modelled on the French copy deck); card accessible names "%{title}, owned" / "not owned" ("possédé" / "non possédé"); the empty-chip line "No game to show." / "Aucun jeu à afficher."; the visually hidden chip legend "Show" / "Afficher"; "Loading the games…" / "Chargement des jeux…"; "Load more" / "Charger plus" for the games frame; the delete dialog's English text.

**Residual risks.**
- Creating a set now lands on the collection, as the design says, instead of the album as in the previous entry.
- The phone placeholder "Rechercher un jeu" is not used: the field keeps "Rechercher un jeu du catalogue" at every width.
- The editor's game grid reads a `DISTINCT ON` over every published card-season per page: fine on the test data, unmeasured on staging's catalog size.
- A click on a card exactly while a debounced search reload replaces the grid can miss (the system tests wait for the grid before picking).
- The refused-card flash (400ms) is not asserted by a test.
- The previous entry's staging check by the author is not recorded in `pending-approvals.md`.
