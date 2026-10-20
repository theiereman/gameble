---
title: 'A showcase chosen from the card detail'
type: 'feature'
ticket: 4
created: '2026-10-20'
status: 'built'
baseline_revision: 'b5b07dfce867b3cfacb62f87adb7cd514fdf4319'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
commit: '317bd69f85984e7ce4cdd0c9f975893f5148b460'
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The personal data export (Game::ExportOf) and the privacy page's deletion list do not mention the player's chosen showcase.
    evidence: |-
      The delete dialog note now lists the showcase as erased player data, but packs/game/app/queries/game/export_of.rb is unchanged, so a player's export omits it; the plan did not ask for the export.
    location: >-
      packs/game/app/queries/game/export_of.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A player cannot choose the cards that show them off: the public profile has no VITRINE section and the hub always shows the automatic card (« DERNIÈRE OBTENTION »).

**Approach:** A new Game table of chosen cards (player, card-season, position), written by two operations: add (owned card, at the end, five at most) and remove. The card detail offers « METTRE EN VITRINE » / « RETIRER DE LA VITRINE » (disabled with the showcase-full line at five); the public profile shows a VITRINE section in the chosen order, each card opening its detail with the back « ◀ PROFIL »; the hub shows the first chosen card under the kicker « VITRINE », else the automatic one under « DERNIÈRE OBTENTION ».

## Boundaries & Constraints

**Always:** Writes only through `Game::AddToShowcase` / `Game::RemoveFromShowcase` (each publishes one event in its transaction); controllers read through Game queries. Policy for every new action. No database id in URLs, HTML or DOM ids (cards addressed by slug + season number). Every string in en.yml and fr.yml, including `errors.game.<code>` by hand. GETs write nothing. No `style` attribute. A card is « owned » when the player holds at least one copy of that card-season (`quantity > 0`, reserved copies count), as for « REPOSTER ». A card traded away (quantity falls to 0 in `Game::AcceptTrade`) leaves the showcase in the same transaction (follows the author's 2026-10-16 rule for the automatic card; see Design Notes). A deleted player's showcase is erased (`Game::ReleasePlayer`, delete dialog note). Migration version `20261020130000`; regenerate `db/schema.rb` from the migrations as AGENTS.md says.

**Never:** Reorder buttons ◀ ▶ on the profile and the settings summary (16.5); the friend profile dialog and `Game::ShowcaseCards` (16.7); the relation action (16.6). No rays on VITRINE cards. No change to the automatic card's rule (`Game::LatestNotableCard`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Add | Player holds the card-season, showcase has 2 | Joins at position 3; one event | — |
| Add sixth | Showcase has 5 | Nothing written | `Failure(:showcase_full)`, message = the showcase-full line |
| Add not owned | quantity 0 or no holding | Nothing written | `Failure(:card_not_owned)` |
| Add twice | Card already in showcase | Nothing written | `Failure(:card_already_showcased)` |
| Remove | Card in showcase at position 2 of 4 | Row deleted, later cards move up one place; one event | — |
| Remove absent | Card not in showcase | Nothing written | `Failure(:card_not_showcased)` |
| Visitor / banned / deleted | — | Nothing written | `Failure(:player_required)` |
| Traded away | Showcased card's quantity falls to 0 by an accepted trade | Its row is deleted, later cards move up | — |
| Card detail, holder | Card-season held, not showcased, < 5 | « METTRE EN VITRINE » button (POST) | — |
| Card detail, showcased | Card-season in showcase | « RETIRER DE LA VITRINE » button (DELETE) | — |
| Card detail, full | 5 showcased, this one not | Disabled « METTRE EN VITRINE » with the showcase-full line beside it | — |
| Card detail, not owned / visitor | — | Neither button | — |
| Profile with chosen cards | 1–5 rows | h2 « VITRINE » after the identity band, cards in position order, each linking to its detail with `brother=<token>` | — |
| Profile with none | 0 rows | No VITRINE section | — |
| Hub with chosen cards | ≥ 1 row | First card, kicker « VITRINE », « VOIR LA FICHE » to its season page, « REPOSTER » | — |
| Hub with none | 0 rows | Automatic card, kicker « DERNIÈRE OBTENTION » (or the empty showcase) | — |

</intent-contract>

## Code Map

- `db/migrate/20261020130000_create_game_showcase_entries.rb` -- new table `game_showcase_entries`: `player_id` (FK accounts_players), `card_season_id` (FK catalog_card_seasons), `position` integer not null, timestamps; unique index `(player_id, card_season_id)`, index `card_season_id`; check `position >= 0`. No unique index on position (16.5 swaps positions).
- `packs/game/app/models/game/holding.rb`, `trade_locks.rb`, `bank_lock.rb` -- model style (`self.table_name`); lock order: bank lock (`BankLock.acquire(player.id)`) then holdings (`Holding...lock`).
- `packs/game/app/operations/game/repost_card.rb` -- the pattern for a held-card operation (`require_player`, `Quantities`, `publish(... stream_name(player.id))`). `packs/game/app/events/game/card_reposted.rb` -- event style; new events `ShowcaseCardAdded`, `ShowcaseCardRemoved` (data: player_id, card_season_id).
- `packs/game/app/operations/game/accept_trade.rb#move` -- after the holdings move, delete the showcase rows of the card-seasons each player gave whose quantity is now 0, and close the gaps in position.
- `packs/game/app/operations/game/release_player.rb` -- delete the player's showcase rows.
- New query `packs/game/app/queries/game/chosen_showcase.rb` -- `Game::ChosenShowcase.call(player)` → card-season ids in position order (nil player → `[]`, no query). Do not confuse with `Game::ShowcaseCards` (friend profile; leave it).
- `config/routes.rb` (near `card_repost`, line ~61) -- `post`/`delete "cards/:slug/seasons/:number/showcase"` → `showcases#create` / `#destroy`, `as: :card_showcase`.
- `app/controllers/reposts_controller.rb` + `app/policies/repost_policy.rb` -- the controller pattern: `Catalog::PublishedCardSeasonId.call(slug:, season_number:)`, turbo_stream toast on failure / html `redirect_back_or_to card_season_path(...)` with flash, JSON. New `ShowcasesController` + `ShowcasePolicy` (`create?`/`destroy?` = `player?`). On success redirect back (303) to the card detail; no success toast (copy deck has none).
- `app/controllers/cards_controller.rb#show` -- load the showcase state for a signed-in holder of this card-season (`@editions` already says which season numbers are held). Also a profile context: `brother` alone (no `set_kind`) with a visible owner → browse the card's first set like `set_browse(..., owner: album_owner)` but `back` = `Back.new(label: t("cards.show.profile"), path: brother_path(token))`; the card shows its face.
- `app/views/cards/_detail.html.erb` -- actions row: after « REPOSTER », the showcase button via `ButtonComponent` (`method: :post` / `:delete`, `variant: :secondary`), or `disabled: true` plus the showcase-full line (`card-detail__showcase-full`, muted body-small). New local, e.g. `showcase:` (`:add`, `:remove`, `:full`, nil). Update its header comment.
- `app/controllers/public_profiles_controller.rb#show`, `app/views/public_profiles/_profile.html.erb` -- load chosen cards (`ChosenShowcase` + `Catalog::CardViews.call(ids, locale:)`) and render a new `public_profiles/_showcase.html.erb` right after `_summary`, outside the season branch. Keep the profile's fixed query count (update the budget in the test by the measured amount).
- `app/frontend/styles/profile.css` -- `.profile-showcase` row: centred, wrapping, each slot over a flat ground shadow (mock `ux-gameble/mockups/key-public-profile.html` `.vit__row`/`.vit__slot`). Use `CardComponent size: :grid` inside a slot with `container-type: inline-size`, 208px wide on desktop and 100px under 720px (card-xs), so one face serves both widths; three over two on the phone.
- `app/controllers/pages_controller.rb#showcase`, `app/views/pages/_showcase.html.erb`, `app/views/pages/home.html.erb:40` -- chosen first id, else `LatestNotableCard`; pass `chosen:` to pick the kicker key (`pages.home.showcase.kicker` stays the automatic one; add `pages.home.showcase.chosen_kicker`). « VOIR LA FICHE » must open the card's own season: `card_detail_path(card.id, card.season_number)`.
- `config/locales/{en,fr}.yml` -- copy deck « Profile showcase » (EXPERIENCE.md line 127): add/remove labels, the showcase-full line, hub kicker « VITRINE »/« SHOWCASE »; profile h2 « VITRINE »/« SHOWCASE »; `cards.show.profile` « Profil »/« Profile »; `errors.game.showcase_full`, `card_not_showcased`, `card_already_showcased` (`card_not_owned` exists); the account delete note gains « votre vitrine » / « your showcase » after the collection.
- Tests: `test/packs/game/repost_card_test.rb` (operation test style, `fixture_tier_ids`), `test/controllers/reposts_controller_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `test/controllers/pages_controller_test.rb` (`PLAYER_HUB_QUERIES = 18`), `test/controllers/cards_controller_test.rb`, `test/controllers/accounts_controller_test.rb` (`ERASED_OR_CANCELLED` must list `game_showcase_entries`), trade tests in `test/packs/game/` with `test/support/game_trades.rb#conclude_trade`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261020130000_create_game_showcase_entries.rb`, `db/schema.rb` -- table and indexes; schema regenerated from migrations.
- [x] `packs/game/app/models/game/showcase_entry.rb`, `events/game/showcase_card_added.rb`, `events/game/showcase_card_removed.rb` -- model (`SIZE = 5`) and events.
- [x] `packs/game/app/operations/game/add_to_showcase.rb`, `remove_from_showcase.rb` -- per matrix; add takes the bank lock, locks the holding row and checks `quantity > 0`, counts, inserts at `max(position)+1`; remove deletes and moves later cards up.
- [x] `packs/game/app/queries/game/chosen_showcase.rb` -- ordered ids, one query.
- [x] `packs/game/app/operations/game/accept_trade.rb`, `release_player.rb` -- traded-away cards leave the showcase; deletion erases it.
- [x] `test/packs/game/add_to_showcase_test.rb`, `remove_from_showcase_test.rb`, `chosen_showcase_test.rb`, trade test -- every matrix operation row, events published, nothing written on failure.
- [x] `config/routes.rb`, `app/controllers/showcases_controller.rb`, `app/policies/showcase_policy.rb`, `test/controllers/showcases_controller_test.rb` -- add/remove from html, turbo_stream and json; failures with their message; visitor refused; unknown card 404.
- [x] `app/controllers/cards_controller.rb`, `app/views/cards/_detail.html.erb`, `app/views/cards/show.html.erb`, card detail CSS, `test/controllers/cards_controller_test.rb` -- the four button states; the `brother` profile context with « ◀ Profil ».
- [x] `app/controllers/public_profiles_controller.rb`, `app/views/public_profiles/_profile.html.erb`, `_showcase.html.erb`, `app/frontend/styles/profile.css`, `test/controllers/public_profiles_controller_test.rb` -- VITRINE with chosen cards, absent with none, links carry no id, GET writes nothing, query budget.
- [x] `app/controllers/pages_controller.rb`, `app/views/pages/_showcase.html.erb`, `home.html.erb`, `test/controllers/pages_controller_test.rb` -- hub with chosen cards (kicker « VITRINE », first by position) and none (automatic).
- [x] `config/locales/en.yml`, `fr.yml`, `test/controllers/accounts_controller_test.rb` -- strings; delete note and table map.
- [x] `test/system/*` -- only if a selector changed; do not run system tests.

**Acceptance Criteria:**
- Given a signed-in player holding a card-season with four cards in their showcase, when they press « METTRE EN VITRINE » on its detail, then the detail comes back with « RETIRER DE LA VITRINE », their profile shows five cards in VITRINE, and another card they hold shows the disabled button with the showcase-full line.
- Given a player with chosen cards, when they open the hub, then the first chosen card shows under « VITRINE »; when they remove them all, the automatic card shows under « DERNIÈRE OBTENTION ».

## Implementation Notes

- Card detail opened with `brother=<token>` alone browses the card's first set as the album does and backs to the profile (« ◀ Profil »); without a set, a one-card browse with only the back.
- VITRINE uses `CardComponent size: :grid` in an inline-size container (208px desktop, 100px phone), one face for both widths.
- Query budgets rise by one: card detail 10, public profile 10 visitor / 15 signed in (16 with a showcase), hub 19.
- A trade's removal runs under the holdings' locks only (no bank lock, to keep the lock order), so places are renumbered from the rows rather than shifted.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` AcceptTrade's showcase removal shifted positions outside the bank lock, so a concurrent add/remove could leave duplicate places — `ShowcaseEntry.remove`/`remove_unheld` now renumber from the current rows (ROW_NUMBER over position, id), `ChosenShowcase` orders by position then id; test from a gapped, duplicated state.
  - `[low]` `[patch]` No policy test for `ShowcasePolicy` — added `test/policies/showcase_policy_test.rb`.
  - `[low]` `[patch]` `CardsController#showcase_state` read the model constant `Game::ShowcaseEntry::SIZE` — now `Game::ChosenShowcase.full?`.
  - `[low]` `[patch]` Phone scroll padding did not count the showcase-full line in the pinned bar — `html:has(.card-detail__showcase-full)` adds its height.
  - `[low]` `[patch]` `card_detail_path` and `CardsController` header comments did not name the `brother`-only context — updated.
  - `[medium]` `[defer]` The data export omits the showcase while the delete note lists it — not asked by the intent; deferred.

## Design Notes

EXPERIENCE.md lists as open « whether a showcased card the player no longer owns leaves the showcase ». This plan removes it when a trade gives the last copy away, the same rule the author set for the hub's automatic card on 2026-10-16 (a traded-away card leaves it); the owner sees no hidden or stale card and the five-card limit stays honest. To confirm with the author.

## Verification

**Commands:**
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w16_4 bin/rails test` -- expected: green
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- expected: clean

## Auto Run Result

- **Summary:** a player chooses up to five held cards for their profile showcase from the card detail (« METTRE EN VITRINE » / « RETIRER DE LA VITRINE », disabled with the showcase-full line at five). The public profile shows VITRINE after the identity band, in order, each card opening its detail with « ◀ Profil »; no section with none. The hub shows the first chosen card under « VITRINE », else the automatic card under « DERNIÈRE OBTENTION ». A trade giving away the last copy removes the card from the showcase; account deletion erases it.
- **Files:** migration `20261020130000_create_game_showcase_entries` and `db/schema.rb`; `Game::ShowcaseEntry`, `ShowcaseCardAdded`/`Removed` events, `Game::AddToShowcase`, `Game::RemoveFromShowcase`, `Game::ChosenShowcase`; `AcceptTrade` and `ReleasePlayer`; `ShowcasesController`, `ShowcasePolicy`, routes; `CardsController` (showcase state, profile context), `PublicProfilesController`, `PagesController` and their views; `card-detail.css`, `profile.css`; en/fr strings and the delete note; tests (operations, query, controller, policy, trade, deletion, cards, profile, hub).
- **Review:** 5 patches (1 medium, 4 low), 1 deferred (data export), 0 rejected. Follow-up review: false (one medium patched, no high).
- **Verification:** `bin/rails test` 2878 runs, 0 failures; `npm run test:js` 486 passed; `npm run typecheck`, `zeitwerk:check`, packwerk, rubocop (846 files), i18n-tasks missing and unused, brakeman: clean. System tests not run.
- **Residual risks:** removing a traded-away card from the showcase answers an open question of EXPERIENCE.md on the author's 2026-10-16 rule for the automatic card, to confirm; the implementer saw one unrelated `Game::OpenPackTest` error on a first full run (a card-season id gone, likely a cached draw pool across tests), not reproduced in two later full runs.
