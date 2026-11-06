---
title: 'The capsule screen carries the next capsule of each reserve and opening names it'
type: 'feature'
ticket: '2'
created: '2026-11-06'
status: 'built'
baseline_revision: '44fbaf5ceeec4dec47cbbee4618b66309777959b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The booster client cannot show a capsule's cards before the opening POST answers, so every touch waits on the network. Capsules are already drawn when they enter the bank, so their cards can be read before the touch.

**Approach:** Give the booster page and its bank JSON the "held capsule" of each reserve (the capsule an opening of that reserve takes next, with its cards and faces), let the JSON opening name that capsule by its token, and make the opening's answer carry the next held capsule of the same reserve so openings chain. This story is server-only; the client keeps its current behaviour until the next story uses the new data.

## Boundaries & Constraints

**Always:** The held capsule is read through a Game query, never written (a GET never writes). A held capsule is the first of `Game::Reserve.available(player_id, reserve)` (same order `Game::OpenPack` uses), and only when its `season_id` is the current draw pool's season; otherwise the reserve has no held capsule (`null`), since opening would redraw it. Opening by token opens exactly that capsule. Opening by a token of a capsule this player already opened answers that capsule again with no credit, like an idempotency replay. The existing key replay keeps working and wins over the token. Strings in en.yml and fr.yml (`errors.game.pack_not_available`, by hand). Tokens only, no database ids.

**Never:** Change the draw, the odds, the reserves, the reveal endpoint or the HTML form opening. No client (TypeScript) behaviour change beyond reading nothing new. No new table or migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Page with both reserves | player with standard and special capsules available | page root data and `GET booster.json` carry `held.standard` and `held.special`: token, kind, cardBack (the player's equipped back), cards with faces s/m/xl, firstCopy, goals words, and `tierCountsBefore` (the player's current counts) | No error expected |
| Empty reserve or stale season | no available capsule, or first capsule's season is not the draw pool's | that reserve's held is `null` | No error expected |
| Open by token | POST json with `pack=<held token>` and a fresh key | that capsule opens; answer as today plus `next` = the held capsule of the same reserve after this opening (or `null`) | No error expected |
| Token already opened by the player | POST with the token of an opened capsule of this player, new key | 200 with that capsule's answer, nothing credited again, no event published | No error expected |
| Unknown token, another player's, or not yet available | POST with such a token | 422 `{error: {code: "pack_not_available", message}}` | message from `errors.game.pack_not_available` |
| No token | POST json without `pack` | behaviour unchanged (next available, `reserve` honoured), answer gains `next` | unchanged |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/open_pack.rb` -- `call(player:, idempotency_key:, reserve:, time_zone:)`: add `token: nil`. Inside the transaction after the key replay: when `token` is present, an already-opened pack of the player with that token is returned as is (before ReceiveSeasonAllocation, no publish); else `Pack.where(player_id:, token:).available(now).first` or `Failure(:pack_not_available)`; then the existing redraw/credit/publish path. `next_pack` stays for the no-token path.
- `app/controllers/packs_controller.rb` -- `open_from_booster` passes `token: params[:pack]` (string only); `FAILURES` gains `pack_not_available: [ :unprocessable_content, "pack_not_available" ]`.
- `app/helpers/packs_helper.rb` -- `pack_opening_json` gains `next:` (the held capsule of the opened pack's reserve, via the new helper). Add `held_pack_json(pack, player:, goals:)`: `{ token, kind, cardBack, cards: [pack_card_json ... firstCopy], tierCountsBefore }`; cardBack from `Game::CardBacks.active_with_season(player)` rendered like `pack_card_back` (extract a shared method taking key and season). `goals` is a `GoalMarks` (see `GoalMarksLoading#goal_marks`, `goals_for(card.card_id)`). Keep each helper file under 400 lines; a new `app/helpers/held_packs_helper.rb` is fine.
- New `app/domains/game/app/queries/game/held_packs.rb` -- `Game::HeldPacks.call(player, now:)` → `{ "standard" => pack | nil, "special" => pack | nil }` using `Reserve::NAMES`, `Reserve.available(...).first` and `DrawPool.current&.season_id` (check DrawPool's API in `app/domains/game/app/*/game/draw_pool.rb`).
- `app/domains/game/app/queries/game/first_copies.rb` -- add `before_opening(player, pack)`: true for a card the player holds no copy of (quantity > 0), only its first occurrence in the pack.
- `app/domains/game/app/models/game/reserve.rb` or the query -- a way to name the reserve of a pack kind (`KINDS` maps names to kinds).
- `app/controllers/boosters_controller.rb` + `app/helpers/boosters_helper.rb` -- `booster_root_data` gains `booster_held_value` (JSON of both reserves); the JSON format gains `held`. `app/views/boosters/_booster.html.erb` passes what the helper needs. Load card views with `Catalog::CardViews` as `PackCards#cards_of` does.
- `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.pack_not_available` ("This capsule is no longer in your reserve." / "Cette capsule n'est plus dans votre réserve.").
- Tests: `test/domains/game/open_pack_test.rb`, a new `test/domains/game/held_packs_test.rb`, `test/controllers/packs_controller_test.rb`, `test/controllers/boosters_controller_test.rb` (support: `test/support/game_packs.rb`, `catalog_seeds.rb`). Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/held_packs.rb`, `first_copies.rb` -- held query and pre-opening first copies -- the data B needs
- [ ] `app/domains/game/app/operations/game/open_pack.rb` -- open by token, answer an opened token -- opening names the capsule shown
- [ ] `app/controllers/packs_controller.rb`, `app/helpers/packs_helper.rb` (+ held helper) -- token param, failure code, `next` in the answer
- [ ] `app/controllers/boosters_controller.rb`, `app/helpers/boosters_helper.rb`, `app/views/boosters/_booster.html.erb` -- `held` in page data and JSON
- [ ] `config/locales/en.yml`, `fr.yml` -- the failure message
- [ ] tests for every matrix row

**Acceptance Criteria:**
- Given the booster page is requested, when it renders, then no row is written (ReadOnlyRequestsTest stays green) and the held capsules' faces match what the opening answer would carry for the same cards.

## Verification

Ruby runs in Docker in this container: `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb '<command>'` runs a command in the app's Ruby image (Postgres is up on 5433). Frontend checks run on the host.

**Commands:**
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bin/rails test test/domains/game/open_pack_test.rb test/domains/game/held_packs_test.rb test/controllers/packs_controller_test.rb test/controllers/boosters_controller_test.rb'` -- expected: green
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bin/rails test'` -- expected: the full suite green
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bundle exec packwerk check && bin/rubocop && bin/rails zeitwerk:check && bundle exec i18n-tasks health'` -- expected: clean
- `script/check_planning_references && script/check_file_sizes` -- expected: clean

## Implementation Notes

- The held capsule and the answer's `next` mirror the opening answer's head (`{ pack: { token, kind, cardBack, url, revealUrl }, cards, tierCountsBefore }`) so the client reuses its validators (decided mid-build, 2026-11-06).
- `HeldPacks` checks the season with `Catalog::PublishedSeason` rather than `DrawPool.current`, which builds the pool and could raise on a read-only GET.
- `FirstCopies.before_opening` counts any holding row as held, like the opening answer does, so the "new" mark never flips at confirmation.
- `booster_next_steps_controller_test.rb` no longer forbids reading goals: the page marks the held capsule's goals.

## Review Triage Log

Pass 1 (quick): 1 medium, 3 low.

- medium, patch — the goals query ran on every booster GET even with nothing held: goals are read only when a reserve holds a capsule.
- low, patch — a non-string `pack` param fell back to opening the next capsule: it is now refused with `pack_not_available` (test added).
- low, rejected — a replay by an already-opened token with a fresh key counts toward the rate limit: the client's queue resends with the same key, which the limit already skips.
- low, rejected — computing `next` repeats a few reads on the opening POST: correct, a handful of indexed queries, and the client no longer waits on this POST.

Full suite: 4181 runs green; packwerk, rubocop, zeitwerk clean. System tests not run (no Chrome in the container).
