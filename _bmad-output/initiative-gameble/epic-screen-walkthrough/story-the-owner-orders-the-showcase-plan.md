---
title: 'The owner orders the showcase'
type: 'feature'
ticket: 5
created: '2026-10-20'
status: 'built'
baseline_revision: '63c56fa8d0a93cccf246d07ea823c8f32a6bfea2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The owner of a showcase cannot change its order (cards stay in the order they were added), so they cannot choose which card the hub shows; and Profil et paramètres has no public profile summary, so the chosen cards appear nowhere in the settings.

**Approach:** A new operation `Game::MoveShowcaseCard` moves one showcased card one place earlier or later (swapping it with its neighbour) and publishes one event; on their own public profile the owner sees « ◀ » / « ▶ » buttons under each VITRINE card (no ◀ on the first, no ▶ on the last), plain form buttons posting a PATCH, keyboard usable, with focus returned to the moved card's button after the page reloads. The hub already shows the first chosen card, so it follows. Profil et paramètres gains a public profile summary panel above its settings list: avatar, name (a link to the public profile), card count, « VITRINE » with the chosen cards (absent with none) and the visibility line.

## Boundaries & Constraints

**Always:** Write only through `Game::MoveShowcaseCard` (bank lock, one `Game::ShowcaseCardMoved` event in the transaction). Controller reads through Game queries. Pundit: `ShowcasePolicy#update?` = `player?`. No database id in URL, HTML, DOM ids or flash (cards addressed by slug + season number). Every string in en.yml and fr.yml, `errors.game.<code>` by hand; French plurals need `zero`. No `style` attribute. GETs write nothing (flash is fine). Pixel icons for ◀ ▶ (`pixel_icon("arrow-left"|"arrow-right")`), never typed glyphs. Accessible names from the copy deck: « Déplacer Portal 2 vers la gauche » / « Déplacer Portal 2 vers la droite », « Move Portal 2 left » / « Move Portal 2 right ». No migration.

**Never:** Drag and drop or any drag-only interaction. Do not touch what signed-out visitors can reach, the sign-in panel, or the greying of actions that need an account (another story builds that in parallel): leave `public_profiles/_summary.html.erb`, `_profile.html.erb`'s report dialog line, the shell and the landing alone. No change to `Game::ShowcaseCards` (friend profile), the relation action, `Game::LatestNotableCard`, add/remove behaviour. No reorder controls for anyone but the owner (not staff, not friends, not visitors). No back picker in settings.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Move later | Showcase A B C, move A later | B A C, positions 0..2; one `ShowcaseCardMoved` event (player_id, card_season_id, position: 1) | — |
| Move earlier to first | A B C, move B earlier | B A C; hub (`Game::ChosenShowcase.call(player).first`) is B | — |
| First moved earlier / last moved later | A B C, move A earlier | Nothing written | `Failure(:showcase_edge)` |
| Not showcased | card not in the player's showcase | Nothing written | `Failure(:card_not_showcased)` |
| Unknown direction | direction other than `:earlier`/`:later` | Nothing written | `Failure(:unknown_direction)` |
| Visitor / banned / deleted | — | Nothing written | `Failure(:player_required)` |
| Gapped / shared positions | rows at 0, 3, 3, 4 | Order read as (position, id), move applied, rows renumbered 0..n-1 | — |
| PATCH html/turbo_stream | owner, valid move | 303 back to the referrer (fallback the owner's profile); flash notes the moved card + direction | failure: alert flash / toast, as `ShowcasesController#refused` |
| PATCH json | — | 204 | `{ error: { code, message } }` 422 |
| PATCH visitor | signed out | refused by Pundit like create/destroy | — |
| PATCH unknown card | bad slug | 404 as create/destroy | — |
| Own profile, 3 cards | owner views | under card 1 only ▶, card 2 ◀ ▶, card 3 only ◀; each a `<button>` with its accessible name | — |
| Own profile, 1 card | owner views | no move buttons | — |
| Another viewer / staff / visitor | — | no move buttons | — |
| After a move | flash set | the moved card's button in the same direction carries `autofocus`; if that button no longer exists (card now at the edge), its other button does | — |
| Settings, chosen cards | 1–5 rows | summary panel shows « VITRINE » with the cards in order | — |
| Settings, none | 0 rows | summary panel without the VITRINE part | — |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/add_to_showcase.rb`, `remove_from_showcase.rb` -- operation pattern to copy (`require_player`, `transaction`, `lock_bank`, `publish(..., stream_name: stream_name(player.id))`). New `packs/game/app/operations/game/move_showcase_card.rb`: `call(player:, card_season_id:, direction:)`; `DIRECTIONS = { earlier: -1, later: 1 }` (accept symbol or string); entries = `ShowcaseEntry.where(player_id:).order(:position, :id).to_a`; swap with neighbour; write `position`/`updated_at` only on rows whose place changed (`update_all` per row or one statement).
- `packs/game/app/events/game/showcase_card_removed.rb` -- event style; new `showcase_card_moved.rb`.
- `packs/game/app/models/game/showcase_entry.rb` -- update its header comment to name the move under the bank lock.
- `packs/game/app/queries/game/chosen_showcase.rb` -- already (position, id) order; the hub (`app/controllers/pages_controller.rb#showcase`) uses its first id. No change expected.
- `config/routes.rb:64-66` -- add `patch "cards/:slug/seasons/:number/showcase" => "showcases#update"`; update the comment line.
- `app/controllers/showcases_controller.rb` -- add `update` (authorize `:showcase, :update?`); reuse `change`-style lookup; on success set `flash[:moved_showcase_card] = { "slug" => params[:slug], "number" => params[:number], "direction" => direction }` and redirect back (303) with fallback `brother_path(token: current_player.token)`; failures reuse `refused` (fallback path may stay the card path). Update the header comment. `app/policies/showcase_policy.rb` + `test/policies/showcase_policy_test.rb` -- `update?`.
- `app/views/public_profiles/_showcase.html.erb` -- add a local `movable:` (true only when `current_player == owner`, computed in `_profile.html.erb` or the controller as `@showcase_movable`) and `moved:` (the flash hash or nil). Under each slot's link, when movable and cards.size > 1: a `.profile-showcase__moves` row with `button_to card_showcase_path(slug: card.id, number: card.season_number), method: :patch, params: { direction: "earlier" }` holding `pixel_icon("arrow-left")`, `aria-label` from `t("public_profiles.show.showcase.move_left", title: card.title)` (and `move_right`), `class: "button button--secondary button--small"`, `form: { class: "profile-showcase__move" }`; an empty placeholder keeps ◀/▶ columns aligned when one is absent. `autofocus` per the matrix. `_profile.html.erb`: only the render line of the showcase gains the new locals.
- `app/controllers/public_profiles_controller.rb#show` -- pass `flash[:moved_showcase_card]` (read only) and movable; no new query.
- `app/frontend/styles/profile.css` (`.profile-showcase*`, lines ~207-253) -- moves row under the card (centred, gap 8px), the slot's ground shadow stays under the card; on the phone (100px slot) small buttons stay ≥ 44px hit area.
- `app/controllers/settings_controller.rb#show`, `app/views/settings/show.html.erb` -- new partial `app/views/settings/_profile_summary.html.erb` rendered above the settings `PanelComponent`, inside `.settings`: `PanelComponent` with `pixel_icon("avatar-default")`, the name (`Accounts::PersonaName.clean(current_player.persona_name) || t("shell.player.fallback_name")`) as a link to `brother_path(token: current_player.token)`, the card count (`Game::CollectionSummary.call(current_player, season: Catalog::PublishedSeason.call).distinct_cards`, plural « n cartes » with zero/one/other), « VITRINE » label + the chosen cards (`Game::ChosenShowcase` + `Catalog::CardViews.call(ids, locale: I18n.locale)`, as `PublicProfilesController#chosen_cards`) as `CardComponent size: :grid` in 100px inline-size slots linking with `link_to_card_detail(card, strings: CardStrings.new)`, absent with none; the visibility line from `@visibility` (« Visible par tous les joueurs » / « Visible par vos amis seulement » / « Profil privé : vous seul le voyez », phone « Vous seul le voyez » via two spans toggled in CSS). Styles in the settings stylesheet (`app/frontend/styles/settings.css` or wherever `.settings__panel` lives). Update the view's header comment.
- `config/locales/en.yml`, `fr.yml` -- `public_profiles.show.showcase.move_left`/`move_right` (« Déplacer %{title} vers la gauche » / « … vers la droite »; « Move %{title} left » / « … right »); `settings.show.summary.*` (heading for the panel e.g. « Profil public » / « Public profile », cards count, showcase « Vitrine »/« Showcase », visibility lines public/friends/private + private_short); `errors.game.showcase_edge` (« Cette carte ne peut pas aller plus loin. » / « This card cannot move any further. »), `errors.game.unknown_direction` (« Direction inconnue. » / « Unknown direction. »).
- Tests: `test/packs/game/remove_from_showcase_test.rb` (operation test style, `GamePacks`, `fixture_tier_ids`, `game_events`), `test/controllers/showcases_controller_test.rb`, `test/controllers/public_profiles_controller_test.rb` (showcase tests ~l.525-600; query budget test — keep the count, the owner case may not add queries), `test/controllers/settings_controller_test.rb`, `test/controllers/pages_controller_test.rb` (hub).

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/operations/game/move_showcase_card.rb`, `packs/game/app/events/game/showcase_card_moved.rb`, `packs/game/app/models/game/showcase_entry.rb` (comment) -- operation per matrix.
- [x] `test/packs/game/move_showcase_card_test.rb` -- every operation row of the matrix; event data; nothing written on failure; the hub's card (`ChosenShowcase.call(player).first`) changes after a move to first.
- [x] `config/routes.rb`, `app/controllers/showcases_controller.rb`, `app/policies/showcase_policy.rb`, `test/controllers/showcases_controller_test.rb`, `test/policies/showcase_policy_test.rb` -- PATCH update for html, turbo_stream, json; failure message; visitor refused; unknown card 404; flash set.
- [x] `app/controllers/public_profiles_controller.rb`, `app/views/public_profiles/_profile.html.erb` (render line only), `_showcase.html.erb`, `app/frontend/styles/profile.css`, `test/controllers/public_profiles_controller_test.rb` -- owner-only buttons with accessible names, edges, no buttons for another player / staff / visitor / a single card, autofocus after a move, GET writes nothing.
- [x] `test/controllers/pages_controller_test.rb` -- after a move to first, the hub shows that card under « VITRINE ».
- [x] `app/controllers/settings_controller.rb`, `app/views/settings/show.html.erb`, `app/views/settings/_profile_summary.html.erb`, settings CSS, `test/controllers/settings_controller_test.rb` -- summary with and without chosen cards, visibility line per setting, name links to the profile, no id in HTML.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- all strings above.

**Acceptance Criteria:**
- Given an owner with three chosen cards A B C on their public profile, when they press « ▶ » under A (or focus it and press Enter), then the profile comes back with B A C, focus on A's « ▶ », and the hub shows B under « VITRINE ».
- Given any viewer other than the owner, when they open the profile, then VITRINE shows no move button.
- Given a player with chosen cards, when they open Profil et paramètres, then the summary shows « VITRINE » with those cards in order; with none, the summary has no VITRINE part.

## Implementation Notes

- `movable` and `moved` are computed on the render line in `_profile.html.erb` (`current_player == owner`, `flash[:moved_showcase_card]`), not in the controller; no query added (the owner's profile stays at the 16-query budget, asserted).
- The chosen-cards lookup moved from `PublicProfilesController#chosen_cards` into a `ChosenCards` controller concern (`chosen_cards(player)`), shared with `SettingsController#show`.
- `ShowcasesController#change` takes the operation's extra keywords and an optional success block; `update` sets `flash[:moved_showcase_card]` (slug, number, direction; not for JSON) and redirects back with the owner's profile as fallback. Failures reuse `refused` (HTML fallback stays the card path).
- The VITRINE ground shadow moved from `.profile-showcase__slot::after` to the slot's `.card-link::after`, so it stays under the card when the move row sits below it. Move buttons are 44px squares at every width (two fit the 100px phone slot with the 8px gap); an absent button leaves a 44px `.profile-showcase__move--none` placeholder.
- Settings summary strings live under `settings.show.summary.*` (full keys in the partial); `cards` has zero/one/other in both locales (French « 0 carte »).
- Verified: full `bin/rails test` (2938 runs, green), `npm run test:js`, `npm run typecheck`, `zeitwerk:check`, `packwerk check`, `rubocop`, `i18n-tasks missing/unused`, `brakeman` all clean. Focus restoration after a Turbo visit relies on Turbo focusing the first `[autofocus]` element; checked only through the rendered attribute, not in a browser.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `MoveShowcaseCard` read the entries unlocked and wrote positions from that snapshot, while a trade's `remove_unheld` deletes and renumbers under the holdings' locks only, so a concurrent trade could leave two cards on one place — the entries are now read `FOR UPDATE`, so the trade's removal waits for the move; header comment says so.
  - `[low]` `[patch]` Move buttons were 44×34 on desktop (`.button--small` min-height) while their comment promised a touch-sized square — `min-height: var(--space-touch-min)` added.
  - `[low]` `[patch]` The settings view's edited header comment still named EXPERIENCE.md / DESIGN.md, forbidden by AGENTS.md — parenthetical dropped.
  - `[low]` `[patch]` `SettingsController#show` passed the published season that `Game::CollectionSummary` already defaults to — now `Game::CollectionSummary.call(current_player)`.

## Design Notes

Focus after a move: Turbo's morph refresh skips `autofocus`, so the profile keeps its normal (replace) rendering; Turbo Drive and a plain page load both focus the first `[autofocus]` element, which also scrolls it into view. The flash carries only slug, season number and direction, never an id.

Moving swaps with the neighbour in the (position, id) order and renumbers 0..n-1, so a gap or shared place left by a trade's removal heals on the next move.

## Verification

**Commands:**
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w16_5 bin/rails test` -- expected: green (no system tests)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- expected: clean

## Auto Run Result

- **Summary:** on their own public profile, with two chosen cards or more, the owner moves each VITRINE card one place with « ◀ » / « ▶ » buttons under it (plain PATCH forms, pixel icons, accessible names « Déplacer Portal 2 vers la gauche/droite », no ◀ on the first, no ▶ on the last); after a move the page reloads with focus on the button pressed (or the card's other button at the edge). `Game::MoveShowcaseCard` swaps the card with its neighbour under the bank lock and locked rows, renumbers 0..n-1 and publishes `Game::ShowcaseCardMoved`; the hub follows the first card. Profil et paramètres gains a public profile summary: avatar, name linking to the profile, card count, « VITRINE » with the chosen cards (absent with none), the visibility line.
- **Files:** `Game::MoveShowcaseCard`, `Game::ShowcaseCardMoved`, `ShowcaseEntry` comment; route `PATCH cards/:slug/seasons/:number/showcase`, `ShowcasesController#update`, `ShowcasePolicy#update?`; `ChosenCards` concern shared by `PublicProfilesController` and `SettingsController`; `public_profiles/_showcase`, `_profile` render line; `settings/_profile_summary`, `settings/show`; `profile.css`, `settings.css`; en/fr strings; tests (operation, controller, policy, profile, hub, settings).
- **Review:** quick lens, 4 findings: 4 patched (1 medium, 3 low), 0 deferred, 0 rejected. Follow-up review: false (one medium patched, no high).
- **Verification:** `bin/rails test` 2938 runs, 0 failures (PARALLEL_WORKERS=4: the default run hit Postgres "too many clients" from other sessions); `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (857 files), i18n-tasks missing and unused, brakeman: clean. System tests not run.
- **Residual risks:** focus restoration relies on Turbo focusing the first `[autofocus]` element after a normal (non-morph) render, checked only through the rendered attribute; the new CSS (move row, settings summary) has not been seen in a browser. The summary's heading « Profil public » / « Public profile » and the name as the link to the profile are not in the copy deck.

