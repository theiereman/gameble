---
title: "The deck editor sorts by stat, shows the week's moves and fills the gaps"
type: 'feature'
ticket: '4'
created: '2026-11-15'
status: 'built'
baseline_revision: 'd067ac33c9fe8e021e76eb4749421f0e066a70db'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/duel-rules.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The deck editor lists the collection by title only: a player cannot sort it by a stat, filter it by trump, see which calls the deck covers, fill its gaps in one step, or see which deck cards moved since the last weekly run.

**Approach:** One domain object `Game::DeckCoverage` gives a deck's ten calls (five stats × high/low) with the deck's best percentile and the fill list; one operation `Game::FillDeckGaps` adds that list in one transaction under the deck rules; the editor gains the COUVERTURE strip, COMPLÉTER LES MANQUES, a sort select and a trump filter (state module), and per-slot week arrows with a hidden sentence.

## Boundaries & Constraints

**Always:**
- A call is `(stat, direction)`, stat in `Game::DuelStat::STATS` order, direction `"high"` (the stat's first direction: most popular, best rated, most recent, discovered first, most widespread) or `"low"`; the strip and the fill go stat by stat, high then low. A card's percentile in a call is `percentile` for high and `100 - percentile` for low; a nil percentile counts as no value.
- A call's best = the max over the deck's cards; a gap = no card at ≥ 90 (exact stored value) in that call. Shown value = `best.round.clamp(0, 99)` as the duel profile rounds.
- The fill: candidates are the player's owned editions (`HeldCopies`) that are `ranked?`, whose game is not in the deck, and that have a free copy or are in another deck of the player (`DeckedEditions(except: deck)`). For each call still a gap (counting cards already picked by this fill), pick the candidate with the best percentile in that call; then, while slots remain, the remaining candidates by trump strength (`max(p, 100 - p)` of the trump stat) descending. Ties: lower `card_season_id`. Each pick removes every edition of its game. Stop at the empty-slot count. Never pick a candidate with no value in the call.
- `Game::FillDeckGaps(player:, token:)`: `require_player`; one `transaction`: `lock_bank`, the deck `FOR UPDATE`, its cards `FOR UPDATE`, then `DeckCoverage` picks, then the picked editions' other-deck cards `FOR UPDATE` (`decked_elsewhere`), then their holdings (`TradeLocks.holdings`); re-check each pick with the same rule steps as `AddCardToDeck` (owned → ranked → same game → room → free copy, extracted to `DeckSteps`); any refusal → that `Failure(code)` and nothing written. Slots: the lowest free ones in pick order. `reserved` +1 for each pick not in another deck. One event `Game::DeckGapsFilled` (`player_id`, `deck_id`, `card_season_ids`), none when nothing is picked (success, no write).
- Week arrows: a stat moved when both `percentile` and `weekly_percentile` exist and `|percentile − weekly_percentile| ≥ 5`. Under each filled slot (outside the card art), `aria-hidden` text arrows "▲"/"▼" + the stat's short name, `{colors.text}`, ≥ 10px; the slot button's accessible name ends with one sentence per moved stat ("Popularité en hausse : 62, contre 55 lundi dernier", integers rounded). Computed in Ruby, passed to the client as data on each entry.
- Sort and filter live in `app/frontend/lib/` pure functions used by the state module: sort by title (default, server order) or any call (entries with no value in it last, then server order); filter by trump stat or all. Filtered-out entries are `hidden`; the roving tab stop and arrow keys move over the visible order; the active entry moves to the first visible one when it is filtered out. Reordering moves the existing server-rendered `<li>`s; no markup is built in script.
- The strip comes from `DeckCoverage` only: server-rendered on load, and every card add/remove/fill JSON answer carries `coverage` (`[{ call: "popularity-high", best: 99|null, gap: bool }]`) that the client writes into the cells. Each cell holds both its value span and its gap button (`hidden` toggled), so the client never builds markup.
- Choosing a gap button sorts the collection by that call, sets the sort select to it, and posts a polite status; focus stays on the button. COMPLÉTER LES MANQUES is a secondary `ButtonComponent` under the strip, before the slots; it queues a `fill` change (after a create when the deck has no token yet); on save the client puts the returned `slots` in place and posts "<n> cartes ajoutées, <total> sur 12" (zero form: none added); a refusal posts its message.
- Copy (sentence case, capitals by CSS) in `en.yml` and `fr.yml`, French narrow no-break spaces before `:`; plural keys with `zero`. No planning ids; no `style` attributes; no DB ids in the DOM or JSON (refs `slug:season`).

**Never:** no client-side computing of percentiles, coverage or the fill; no change to `DuelProfiles`' public shape beyond adding a move helper on `Stat`; no change to stats computation, the Duels screen, trade/sale/entrust screens; no migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Best per call | deck: A popularity 95, B popularity 30 | popularity-high best 95 (no gap); popularity-low best 70 (gap) | — |
| Threshold | best exactly 90.0 / 89.9 | 90.0 covered; 89.9 gap | — |
| Empty deck | no cards | ten gaps, best nil | — |
| Fill order | 3 empty slots, gaps rating-low and release-high, candidates X (rating 5), Y (release 97), Z (trump 99) | X, then Y, then Z (trump) in the lowest free slots | — |
| Gap closed by a pick | X picked for popularity-high also has release 95 | release-high not filled again | — |
| Skips | an edition of a game in the deck; an unranked edition; an edition fully reserved by a trade and in no deck | never picked | — |
| Decked elsewhere | owned ×1, reserved by deck B | can be picked; `reserved` unchanged | — |
| Full deck | 12 cards | success, nothing written, no event | — |
| Refused pick | a rule refuses one pick (e.g. `no_free_copy` after a race, forced in a test) | no card, no `reserved`, no event | `Failure(:no_free_copy)`; editor reverts nothing, posts the message |
| Arrow | popularity 62.0, weekly 55.0 | "▲ Pop." under the slot; name ends "Popularité en hausse : 62, contre 55 lundi dernier" | — |
| No arrow | moved 4.9, or weekly nil | no arrow, no sentence | — |
| Sort | "La plus ancienne" | entries by `100 − release` desc; unranked entries last | — |
| Filter | trump "Sortie" | only entries whose trump stat is release visible | — |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/deck_coverage.rb` (new) -- `Game::DeckCoverage`: `CALLS`, `GAP_BELOW = 90`, `Call = Data.define(:stat, :direction, :best) { gap? }`; `new(player, deck)` (deck may be nil); `#calls`; `#fill(room:)` → ordered card_season_ids. Inputs: `DeckSlots.call(deck)`, `HeldCopies.call(player)` (`Row#free`), `DeckedEditions.call(player, except: deck)`, `DuelProfiles.call(ids)` (`Profile#ranked?`, `#trump`, `Stat#percentile`), `Catalog::CardSeason.where(id:).pluck(:id, :card_id)` for games. Allow `FillDeckGaps` to pass the locked deck cards in (avoid a second unlocked read diverging).
- `app/domains/game/app/queries/game/duel_profiles.rb` -- add `Stat#weekly_move` (amount or nil) and a `MOVE_AT = 5` threshold helper (`moved?`).
- `app/domains/game/app/operations/game/add_card_to_deck.rb`, `deck_steps.rb` -- move `owned`, `ranked`, `game_not_in`, `room_in`, `free_copy` into `DeckSteps` unchanged; `AddCardToDeck` behaviour and tests unchanged.
- `app/domains/game/app/operations/game/fill_deck_gaps.rb` (new), `events/game/deck_gaps_filled.rb` (new, empty event class; nothing to register). Returns `Filled = Data.define(:placed, :count)` with `placed` `[[slot, card_season_id]]`.
- `config/routes.rb:94-95` -- `post "duels/decks/:token/fill" => "deck_fills#create", as: :deck_fill` with the same token constraint.
- `app/controllers/deck_fills_controller.rb` (new) -- `include DeckChanges`, `limit_deck_changes only: :create` (shared `deck_changes` scope), `owned_deck(:update?)`; answer `{ slots: [{ slot:, ref: }], count:, coverage: }`. `app/controllers/deck_cards_controller.rb` -- add `coverage:` to the JSON. Coverage JSON built in one place (`DeckEditorHelper#deck_coverage_json(coverage)` or a method on the PORO) using `Game::Market::EntrustableCopies.ref` for refs.
- `app/models/deck_editor.rb` -- `coverage` (`DeckCoverage.new(player, deck)`); `Entry` gains `percentiles` (stat → Float|nil) and `moves` (moved stats with from/to); keep < 400 lines.
- `app/helpers/deck_editor_helper.rb` -- entry data: `percentiles` (JSON), `trump`, `moves-text`, `moves-sentence`; root data: `fill_url` value (`deck_fill_path` or "" until created — the client derives `${url}/fill` like `/cards`), strings for sort/filter/fill/coverage notices; helpers for call labels.
- `app/views/decks/_editor.html.erb` -- render `decks/_coverage` (new) + fill button between the name field and `decks/_slots`; `decks/_filled_slot.html.erb` -- add the moves line under the art/name (aria-hidden) and append the sentences to the aria-label; `decks/_collection.html.erb` -- a filter row above the list, no `<select>` (no player screen has one): the sort is the shared `SortComponent` (prefix "Trier", options "Par titre" + the ten call words, each `href` the editor's own address with `?sort=<key>`, `link_data: { action: "deck-collection#sort" }`, "Par titre" current on load); the trump filter is a group (`fieldset` + visually hidden legend "Atout") of `filter-chip` radios named `trump` ("Toutes" checked + the five stat names), as the market's filter chips. `decks/show.html.erb` and `decks/new.html.erb` -- `turbo_exempts_page_from_cache`, as every other stateful screen, so a restored snapshot never keeps a sorted list under a "Par titre" state. Slots template gets the moves span for the client to fill.
- `app/frontend/lib/deck_collection_order.ts` (new, + `.test.ts`) -- `sortRefs(entries, order, sort)`, `visibleRefs(entries, order, trump)`; `deck_editor.ts` -- state gains `sort`, `trump`, `coverage`; reducers `sortBy`, `filterBy`, `fill` (queue), `saved` handles `fill` (place returned slots, notice) and stores `coverage` from any answer; `move` uses the visible order; `collectionView` gives order + hidden; `slotsView` adds moves text/sentence; `Entry` gains `percentiles`, `trump`, `movesText`, `movesSentence`. Keep each file < 400 lines (split more pure helpers out if needed).
- `app/frontend/controllers/deck_coverage_controller.ts` (new child: renders cells, dispatches `chooseGap` and `fill`), `deck_collection_controller.ts` (render order/hidden by moving `li`s; `sort` prevents the link's navigation, reads the key from its `href`'s `sort` parameter, closes the sort menu's `<details>` and dispatches it; `filter` dispatches the checked radio's value; render writes `.sort__current` and moves `aria-current="true"` to the current option, and checks the current trump radio), `deck_slots_controller.ts` (write moves text and label), `deck_editor_controller.ts` + `app/helpers/deck_editor_helper.rb` `DECK_EDITOR_ACTIONS` (new outlet `deck-coverage`). Patterns: existing children, `lib/dom_writes.ts`, `lib/templates.ts`.
- `app/frontend/styles/deck-editor.css` (352 lines) or a new `deck-coverage.css` imported beside it in `entrypoints/application.css:110` -- strip per DESIGN: two rows of five on desktop (DOM order stat pairs → `grid-auto-flow: column` with two rows), one pair per row on the phone, wrapping; cell short name `{typography.label}` `--color-muted`, value `{typography.number}` `--color-text`; gap "Manque" `--color-alert` on a dashed `--color-dim` frame, drawn on a `span.deck-coverage__gap` wrapper (which carries `hidden`) around a `ButtonComponent` (`variant: :secondary`, default size, so it keeps the 44px phone target), never a hand-made `<button>`; the strip heading "Couverture" in the design system's heading style (`--font-kicker`, accent colour, uppercase, `--tracking-kicker`); `.deck-slots__slot` aligns its child to the start so an empty slot keeps its aspect ratio when a neighbouring filled slot grows a moves line; moves line ≥ 10px `--color-text`; tokens only.
- `app/models/deck_editor.rb` -- an entry whose profile is not `ranked?` (it shows "Stats lundi") carries no percentiles (every stat nil) and no trump in its data, so the sort puts it last and no trump filter shows it.
- `app/frontend/lib/deck_editor.ts` `reverted` -- a refused add clears its ref wherever it now sits (a fill may have moved it), not only at its queued slot.
- Comments: none beyond the house rule (one line, an external constraint only): no class header or method comments in the new domain classes.
- `config/locales/en.yml`, `fr.yml` -- see Design Notes.
- Tests: `test/domains/game/deck_coverage_test.rb` (new), `test/domains/game/fill_deck_gaps_test.rb` (new; lock order recorded with `ActiveSupport::Notifications` as `deck_card_operations_test.rb` does), `test/domains/game/duel_profiles_test.rb` (move threshold), `test/controllers/decks_controller_test.rb` / new `deck_fills_controller_test.rb` (owner only 403, JSON answer, throttle shares the counter, coverage in the card answer, arrows/sentence in the HTML, no `[style]`), `test/system/deck_editor_test.rb` (new test per verify), vitest `deck_collection_order.test.ts` and `deck_editor.test.ts` additions. Helpers: `test/support/decks.rb` (`ranked_cards`, `rank`, `ref_of`); set percentiles directly with `Game::DuelStat.where(card_season_id:).update_all(...)` after `rank` (keep the together checks and 0–100 range). Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [x] `duel_profiles.rb`, `deck_steps.rb`, `add_card_to_deck.rb` -- move helper on `Stat`; rule steps shared
- [x] `deck_coverage.rb` -- calls, gaps, fill order and skips
- [x] `fill_deck_gaps.rb`, `deck_gaps_filled.rb` -- the fill under the lock order, refused as a whole
- [x] `config/routes.rb`, `deck_fills_controller.rb`, `deck_cards_controller.rb` -- fill address and coverage in the JSON answers
- [x] `deck_editor.rb`, `deck_editor_helper.rb`, `views/decks/*` -- strip, fill button, sort menu and trump chips, slot arrows and sentences, cache exemption
- [x] `lib/deck_collection_order.ts`, `lib/deck_editor.ts`, the four controllers + new `deck_coverage_controller.ts` -- state, rendering, focus, status
- [x] CSS -- strip and its heading, gap wrapper, filter row, slot alignment, moves line
- [x] `en.yml`, `fr.yml` -- copy
- [x] tests per Code Map -- every matrix row, the 90 threshold, the 5-point threshold, the fill refused as a whole, lock order, vitest sort and trump filter

**Acceptance Criteria:**
- Given a signed-in player with a draft deck of a few cards whose deck has a gap, when they choose that gap in the strip, then the collection is ordered by that call and the sort menu shows it as current; when they choose COMPLÉTER LES MANQUES, then every empty slot fills, the count reads "12 / 12" and the strip updates; and a deck card whose popularity moved 5 points since the last weekly run shows "▲" under it (`test/system/deck_editor_test.rb`).
- Given the trump filter on one stat, when the player presses the arrow keys in the collection, then focus moves only over visible entries and the collection stays one tab stop (vitest on the state module).

## Implementation Notes

- Resumed after the branch was rebased onto develop: `baseline_revision` is the rebased commit of the previous one (`94752424`).

## Plan Change Log

- **Review loop 1 (2026-11-16).** Trigger: the quick review found the collection's sort and trump filter built as `<select>`s and the gap as a hand-made `<button>` of about 22px, against `docs/design-system.md` ("Same job, same component": `SortComponent` for sorting, `ButtonComponent` for every button) and the 44px phone target; the plan's Code Map had asked for the `<select>`s. Amended: Code Map (`_collection` filter row with `SortComponent` and trump `filter-chip` radios, the collection controller's sort and filter, the gap `ButtonComponent` in a wrapper, the strip heading style, slot alignment, cache exemption, unranked entries without percentiles or trump, `reverted` by ref, no explanatory comments), Tasks, the first acceptance criterion and a Design Note. Known-bad state avoided: native `<select>`s and a hand-made undersized button on a player screen; unranked editions sorted and filtered as ranked ones; a sorted list kept by a Turbo snapshot under a "Par titre" state; a refused add left on screen after a fill moved it; empty slots stretched by a neighbour's moves line; class and method comments the house rule forbids.
  KEEP (the first derivation passed every check; its full diff is at `/tmp/claude-1000/-home-teyermann-projets-gameble/9e3d8823-2ac1-4a98-bb05-4c492626c3d1/scratchpad/deck-editor-derivation-1.diff` — re-derive from it and change only what this entry names): the whole server side as it was (`DeckCoverage` calls, gaps and fill order, `FillDeckGaps` lock order and refusal as a whole, `DeckSteps` extraction, `Stat#weekly_move`/`moved?`, the fill route and `DeckFillsController`, `coverage` in every card answer, `deck_coverage_json`), minus the comments; the pure modules `lib/deck_collection_order.ts` and `lib/deck_editor_answers.ts`; the state module's `sortBy`, `chooseGap`, `filterBy`, `fill`, `filledBy`/`placedByFill` and visible-order `move`/`activateFirst`; the strip markup where each cell holds its value span and its gap control toggled by `hidden`; the strip grid CSS; every test and the `set_percentiles` support helper (update the HTML and system assertions that named the `<select>`s); the copy in both locales.

## Review Triage Log

| # | Finding | Verdict | Route | Evidence |
|---|---------|---------|-------|----------|
| 1 | Unranked editions carry real percentiles and a trump, so they sort among ranked ones and show under a trump filter | medium | bad_plan (folded into loop 1) | `Profile#ranked?` reads only `discovery`; `DuelStatRows` writes popularity, rating and release percentiles and a trump for every published edition; `DeckEditor#percentiles` ignores `ranked?`; matrix row "Sort" wants unranked last. |
| 2 | A Turbo snapshot keeps the sorted `<li>` order while the state restarts at "Par titre" | medium | bad_plan (folded into loop 1) | `decks/show` and `decks/new` lack `turbo_exempts_page_from_cache`, which trades, friends, boosters and home carry; `start` takes `order` from the DOM order `reorder` changed. |
| 3 | A refused add that a fill moved stays on screen | low | bad_plan (folded into loop 1) | `reverted` only clears `slots[change.slot - 1]`, while `placedByFill` can move the queued ref to another slot. |
| 4 | A fill can place an edition acquired after page load, drawn as an empty slot | low | rejected | Needs a card gained in another tab between load and fill; the fix would add card data to the fill answer, more than a direct correction. |
| 5 | Empty slots stretch in a row where a filled slot has a moves line | low | bad_plan (folded into loop 1) | `.deck-slots__slot` is a stretching flex row and `.deck-slot` has an `aspect-ratio`, which a stretched height overrides; moves lines appear every Monday. |
| 6 | The "Couverture" heading uses label style in muted colour | low | bad_plan (folded into loop 1) | `docs/design-system.md` Headings: one style, `--font-kicker`, accent, uppercase. |
| 7 | The sort is a native `<select>`, not `SortComponent` | medium | bad_plan | `docs/design-system.md`: "Same job, same component"; no player screen uses `<select>`; the Code Map asked for one. `SortComponent` renders links, so the change is more than a direct correction. |
| 8 | The gap control is a hand-made `<button>` about 22px high | medium | bad_plan | `docs/design-system.md`: `ButtonComponent` for every button; EXPERIENCE.md: 44 × 44px phone targets; `.deck-coverage__gap` has `--space-1`/`--space-2` padding around an 11px label. |
| 9 | Class and method comments in `DeckCoverage` and `FillDeckGaps` | low | bad_plan (folded into loop 1) | AGENTS.md allows only one-line external-constraint comments; 64 of 71 operations carry none and recent commits drop such comments. |
| 10 | The gap label in `--color-alert` on the secondary button's `--color-line` fill is 3.58:1, under WCAG AA for 13px text | medium | patch (fixed) | Computed from the tokens (#e8833a on #2a475e); the button now takes the panel's background, 6.45:1, as DESIGN.md draws the gap on the panel. |
| 11 | The sort options' `?sort=` addresses are not read by the server, so a middle click opens the editor by title, and on a new deck the address stays `/new` | low | rejected | Needs a middle click or "open in new tab" on a sort option; honouring `sort` on the server is more than a direct correction. |
| 12 | The sort prefix "Trier" runs into the current option with no separator ("TRIER LA PLUS ANCIENNE") | low | patch (fixed) | The market's `SortComponent` uses "Tri :"/"Sort:" and the design system shows "Sort: Ending soon"; a `decks.editor.sort.prefix` key now carries "Tri :"/"Sort:", checked in the controller test. |
| 13 | `DeckEditor`'s class comment grew a description of percentiles, moves and coverage | low | patch (fixed) | AGENTS.md comment rule; the comment is back to its text before this change. |

## Design Notes

Decisions the ticket leaves open (assumptions, record them in the result):
- The trump filter filters by trump stat (five options + all), matching the entries' "Atout · <stat>".
- A gap already closed by a card this fill picked is skipped, so the fill does not spend two slots on one call.
- Only gap cells are buttons (each a `ButtonComponent`); covered cells are plain text.
- The strip updates from the server's answers, not optimistically: one source, `DeckCoverage`.

Copy (fr / en):
- Call words (`duel_stats.directions.<stat>.high|low`, sentence case, used by sort options and hidden cell text): "La plus populaire"/"Most popular", "La plus confidentielle"/"Most obscure", "La mieux notée"/"Best rated", "La moins bien notée"/"Worst rated", "La plus récente"/"Newest", "La plus ancienne"/"Oldest", "Découverte en premier"/"First discovered", "Découverte en dernier"/"Last discovered", "La plus répandue"/"Most widespread", "La plus introuvable"/"Hardest to find".
- Strip short names (`decks.editor.coverage.short.<stat>.high|low`, visible, `aria-hidden`, from board 8): "Populaire"/"Popular", "Confid."/"Obscure", "Mieux notée"/"Best rated", "Moins notée"/"Worst rated", "Récente"/"Newest", "Ancienne"/"Oldest", "Découv. tôt"/"Found first", "Découv. tard"/"Found last", "Répandue"/"Widespread", "Introuvable"/"Hard to find".
- `decks.editor.coverage`: heading "Couverture"/"Coverage"; gap "Manque"/"Gap"; covered cell hidden "%{call}, %{best}"; gap button label "%{call}, manque, trier la collection"/"%{call}, gap, sort the collection"; fill "Compléter les manques"/"Fill the gaps".
- Sort/filter: "Trier"/"Sort", "Par titre"/"By title", "Atout"/"Trump", "Toutes"/"All"; status "Collection triée : %{call}"/"Collection sorted: %{call}".
- Fill status (plural with zero): zero "Aucune carte à ajouter, %{total} sur 12"/"No card to add, %{total} of 12", one "%{count} carte ajoutée, %{total} sur 12"/"%{count} card added, %{total} of 12", other "%{count} cartes ajoutées, %{total} sur 12"/"%{count} cards added, %{total} of 12".
- Moves: short stat names (`duel_stats.short.<stat>`) "Pop."/"Pop.", "Note"/"Rating", "Sortie"/"Release", "Déc."/"Disc.", "Circ."/"Circ."; sentences `decks.editor.moves.up|down` "%{stat} en hausse : %{to}, contre %{from} lundi dernier"/"%{stat} up: %{to}, against %{from} last Monday", "… en baisse …"/"… down …" (stat from `duel_stats.names`).

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers/deck*_test.rb test/models test/helpers test/config test/policies` -- green
- `bin/rails test test/system/deck_editor_test.rb` -- green
- `npm run test:js`; `bin/rails zeitwerk:check`; `bundle exec packwerk check`; `bundle exec rubocop`; `bundle exec i18n-tasks missing`; `npm run typecheck` (or the bin/ci typecheck step); `npm run format:check`; `npm run lint:css`; `script/check_planning_references`; `script/check_file_sizes` -- green
- `bin/rails test` (in parts if Postgres reports too many clients) -- green except the known `library_controller_test.rb:119`
