---
title: 'Copies over the daily cap stay in the collection and the result names them'
type: 'feature'
ticket: '38.3'
created: '2026-11-10'
status: 'draft'
baseline_revision: 'a159c212dc2bd7ff6358b8173105d7665bb8a19c'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `EntrustCards` has no daily cap: a player can mint without limit in a day, and a copy that does not fit has no way to stay behind and be named.

**Approach:** The operation reads the cap of the current settings version and the player's `mint` entries of the current UTC day, applies the batch in the order received (the Confier page sends it most valuable first), whole copies only, skips what does not fit so a cheaper copy may still pass, and returns what was entrusted and what stayed with the cap that was left when the player validated (before the batch); `nothing_fits` when no copy fits. The result page names each skipped card with its value and the cap that was left ("Il vous restait <amount> de plafond aujourd'hui"). Epic requirements R4 (cap, skip order, refusal) and R8.

## Boundaries & Constraints

**Always:** the cap is read under the player's bank lock, from `mint` ledger entries with `created_at` inside the current UTC day (`Time.current.utc`), never from a stored counter; a line asking for `n` copies of value `v` entrusts `min(n, remaining / v)` copies and the rest stay; copies that stay are never lowered, deposited or minted; one `mint` entry and one `CardsEntrusted` listing only the entrusted copies; checks keep their order (player, empty batch, market closed, stale version, enough free copies, no rarity, then the cap); `cap_left` is `max(daily_cap - MintedToday, 0)` computed before the batch, never after it; the controller orders resolved lines by their position in the page's `EntrustableCopies` list, and a line that resolves but is absent from that list (a card no longer free) goes last, keeping the posted order, so the operation answers `not_enough_copies` instead of the controller raising on a nil index; a batch where no copy fits fails with `nothing_fits` and moves nothing; the operation honours the order of `lines` (the hash keeps insertion order), the controller sends them most valuable first, ties by the page order; no database id in HTML; both locales for every string, `errors.game.nothing_fits` by hand, French plural keys with a `zero` form; GET writes nothing.

**Never:** the live cap gauge, the recap, the "will stay" preview before validation and the disabled validation on a full cap (stories 5 and 6); the PiCoin mark component (story 4); a stored daily counter or any new column or migration; sorting inside `Ledger` or `Mint`; blocking a batch because part of it exceeds the cap; a cap in settings changes (story 9).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Under the cap | cap 1,200,000, nothing minted today, 2 Commons | both entrusted, nothing stays, cap left reported as 1,200,000 | — |
| Flow 8 | 1,150,000 minted today (50,000 left); Legendary 100,000, 2 Uncommon 2,000, Common 1,000, sent most valuable first | Legendary skipped and stays; the three others entrusted, mint 5,000, cap left reported as 50,000 (the figure before the batch, which explains why the Legendary stays) | — |
| Skip then fit | 3,000 left; Rare 5,000 first then Uncommon 2,000 | Rare stays, Uncommon entrusted | — |
| Partial line | 2,500 left; 3 Commons at 1,000 | 2 entrusted, 1 stays | — |
| Nothing fits | 500 left; any copy | nothing moves, no entry, no event | `nothing_fits` |
| Cap reached | minted today equals the cap | nothing moves | `nothing_fits` |
| Yesterday's mints | cap minted before 00:00 UTC, now after it | the full cap is available again | — |
| Only mint counts | a `sale` entry of today with large available delta | not counted | — |
| Another player's mints | other player minted the cap today | own cap untouched | — |
| Cap lowered | current version has a lower cap than the minted total today | remaining is zero, never negative | `nothing_fits` |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/entrust_cards.rb` -- the operation: `normalise` today sorts lines by id (must keep the received order), `minted_for` sums everything, `deposit` lowers every line; add the cap step and the split into entrusted and stayed.
- `app/domains/game/app/models/game/market/ledger_entry.rb`, `ledger.rb`, `mint.rb` -- `mint` entries carry `available_delta`; the table has no `created_at` default but `Ledger.post` stamps `Time.current`; index on `player_id` exists, no migration needed.
- `app/domains/game/app/models/game/market/settings.rb`, `starting_settings.rb` -- `daily_cap` (1,200,000) and `entrustment(rarity)`.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- the page's copies sorted most valuable first (`-value, season, title, ref`), `resolve(refs)`; the order the controller reuses.
- `app/controllers/market/entrustments_controller.rb` -- `create` builds `lines` from `ticked` order; `load_page`.
- `app/views/market/entrustments/create.html.erb`, `new.html.erb` -- the result and the page that re-renders on failure.
- `app/frontend/styles/market-entrust.css` (97 lines) -- result styles; no `style` attribute in HTML.
- `config/locales/en.yml`, `fr.yml` -- `market.entrustments.create.*` (en 2193, fr 1884) and `errors.game.*` (en ~1343, fr ~3184).
- `test/domains/game/market/entrust_cards_test.rb`, `test/support/market.rb`, `test/support/holdings.rb` -- operation tests, `open_market!`, `hold`; `travel_to` for the UTC day.
- `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb` -- controller and system coverage of the result.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- copy deck "Confier" (result wording) and "Market refusals" (nothing fits); Flow 8.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/minted_today.rb` -- new query `Game::Market::MintedToday.call(player_id, now: Time.current)`: sum of `available_delta` of the player's `mint` entries with `created_at` from the UTC day start to the next -- the single reading of the cap, testable at the day boundary.
- [ ] `app/domains/game/app/operations/game/market/entrust_cards.rb` -- keep the received order in `normalise`; after `minted_for`'s rarity check compute per line the copies that fit from `settings.daily_cap - MintedToday`, floor at zero, skipping and continuing; fail `nothing_fits` when no copy fits; lower, deposit and mint only the entrusted copies; publish `CardsEntrusted` listing only them; return `Entrusted.new(minted:, copies:, stayed:, cap_left:)` where `stayed` is a list of `Stayed(card_season_id, copies, value)` and `cap_left` the cap remaining BEFORE the batch (`max(daily_cap - MintedToday, 0)`, read once under the bank lock). Keep the file under 400 lines and the lock order bank lock, holdings, ledger.
- [ ] `app/domains/game/app/queries/game/market/card_names.rb` -- new query `Game::Market::CardNames.call(card_season_ids, locale:)` returning id => `Name(title, season_number)` with the same locale fallback as `EntrustableCopies` -- the result page names the stayed cards, which are still held and no longer all free.
- [ ] `app/controllers/market/entrustments_controller.rb` -- order the resolved lines by their position in the page's copies (most valuable first) before calling the operation; resolved lines absent from the page's copies (a card no longer free) go last in the posted order, so the operation returns `not_enough_copies` and the controller never indexes nil; on success set `@entrusted` and `@stayed_names` from `CardNames`; the `nothing_fits` failure re-renders `new` with the alert and the ticks, like the other failures.
- [ ] `app/views/market/entrustments/create.html.erb` -- after the total and the count, when `@entrusted.stayed` is not empty, a `role="status"` list: the heading "<n> card was not entrusted", one line per stayed card with its value saying it stays in the collection, then "Il vous restait <amount> de plafond aujourd'hui" with the cap left before the batch, and the 00:00 UTC renewal; wording of the Copy deck, Confier.
- [ ] `app/frontend/styles/market-entrust.css` -- classes for the stayed block, same tokens as the result panel.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `market.entrustments.create.stayed.{heading,line,line_many,cap_left}` with one/other (and fr `zero`) forms, and `errors.game.nothing_fits` ("Aucune carte ne tient dans votre plafond du jour. Il se renouvelle à 00:00 UTC." and its English twin) in alphabetical position; run `i18n-tasks` normalize check mentally for key order.
- [ ] `test/domains/game/market/minted_today_test.rb` -- only `mint` entries, only this player, only today (UTC), summed.
- [ ] `test/domains/game/market/entrust_cards_test.rb` -- the matrix: under the cap, Flow 8 order, skip then fit, partial line, nothing fits, cap reached, cap renewing across 00:00 UTC with `travel_to`, only mint entries and own entries counted, lowered cap never negative, the event lists only entrusted copies, stayed holdings and deposits untouched, existing tests still pass with the received order.
- [ ] `test/domains/game/market/card_names_test.rb` -- locale title with English fallback and season number.
- [ ] `test/controllers/market/entrustments_controller_test.rb` -- the POST sends lines most valuable first whatever the form order; a ticked ref that resolves but is no longer a free copy is sent last in posted order and the response is the `not_enough_copies` failure, not an error; the result names a stayed card with its value and the cap left before the batch; `nothing_fits` answers 422 with the French line naming 00:00 UTC and keeps ticks.
- [ ] `test/system/market_entrust_test.rb` -- Flow 8: a player with 1,150,000 minted today entrusts a Legendary and three cheaper copies; the result shows 5,000 minted, names the Legendary as staying, states the cap left as 50,000, and the collection still holds it. Use retrying matchers only.

**Acceptance Criteria:**
- Given 50,000 left under today's cap, when a batch holds a Legendary and three cheaper copies, then the three are entrusted, the Legendary stays and is named with its value, and the cap left is stated.
- Given every copy exceeds what is left, when the batch is validated, then it is refused with the 00:00 UTC line and nothing changes.
- Given the cap was used before 00:00 UTC, when the player entrusts after it, then the full cap is available.
- Given a GET of Confier, then nothing is written.

## Design Notes

Decisions are recorded in Implementation Notes. Skeleton of the split:

```ruby
left = settings.daily_cap - MintedToday.call(player.id)
lines.each do |card_season_id, copies|
  fits = [ copies, [ left, 0 ].max / value(card_season_id) ].min
  left -= fits * value(card_season_id)
end
```

## Verification

**Commands:**
- `bin/rails test test/domains/game/market test/controllers/market` -- pass (run at the end of the market run)
- `bin/rails test test/system/market_entrust_test.rb` -- pass
- `bundle exec rubocop <touched files>`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `npm run lint:css`, `script/check_file_sizes`, `script/check_planning_references` -- clean

## Implementation Notes

Decisions settled in planning (no human checkpoint in this run):

- The operation applies lines in the order received (AD-43 and the epic's decision) and the controller sends them most valuable first; the story text "applies most valuable first" is met end to end, and a hand-made POST in another order only changes which copy fits.
- `cap_left` is the cap remaining before the batch (daily cap minus MintedToday, floored at zero): the Copy deck line is in the imperfect ("Il vous restait <amount> de plafond aujourd'hui"), Flow 8 speaks of the 50,000 left under the day's cap, and the ticket says the result gives the cap that was left; that figure is what explains why the Legendary stays (Flow 8 reads 50,000, the Under-the-cap row 1,200,000).
- Resolved lines missing from the page's copies sort last in posted order; the operation then reports `not_enough_copies`, so the controller never raises on a nil index.
- A line is split by copies, not skipped whole: `min(n, remaining / value)` entrust, the rest stay, since the spec says whole cards and a copy is a card.
- `nothing_fits` is checked after the rarity and free-copy checks, so a malformed batch keeps its own error.
- The cap is read from `mint` entries with `created_at` in the UTC day and nothing is stored, so renewal at 00:00 UTC needs no job.
- Skipped cards are named by a separate `CardNames` query, since they may no longer be free copies and `EntrustableCopies` lists only free ones.
- No cap-aware UI before validation: the grid, gauge and recap are stories 5 and 6; this story only changes the server result page.

## Plan Change Log

## Review Triage Log
