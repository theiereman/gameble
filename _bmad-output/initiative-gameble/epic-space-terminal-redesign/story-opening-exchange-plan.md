---
title: 'Opening exchange'
type: 'feature'
ticket: '10'
created: '2026-10-06'
status: 'built'
baseline_revision: '102a5f75ea22cbbd8cbd97001f353ead3ad5e187'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      A JSON opening with a missing or stale CSRF token answers Rails' 422 HTML page, not the `{ error: { code, message } }` envelope.
    evidence: |-
      ApplicationController keeps Rails' default `protect_from_forgery with: :exception` and rescues only Pundit's refusal; the test environment disables forgery protection, so no test sees it. Pre-existing for every POST; it matters once the booster island (8.11) sends the exchange: the island must send `X-CSRF-Token`, and decide whether a stale token (another tab signed out) answers the envelope or is handled as "any error" (EXPERIENCE.md, Opening protocol 4).
    location: >-
      app/controllers/application_controller.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The booster island (story 8.11) needs AD-23's opening exchange: today `POST /:locale/packs` only redirects to the pack page, a lost response or a double activation cannot be replayed, the pack keeps no card back, and nothing answers in JSON.

**Approach:** Add the JSON branch of `PacksController#create` beside the HTML one: an `Idempotency-Key` header stored with the active card back on the opened pack (unique per player), looked up under the bank lock before availability and exempting the request from the rate limit, and a response built from server-rendered faces, the bank, the server time and the per-tier counts before the opening; failures use the JSON error convention.

## Boundaries & Constraints

**Always:**
- The HTML form flow (hub menu 01, the pack page's "Open the next pack") keeps working unchanged: 303 to the pack page with the PackReveal island once, alert redirects on refusal. JSON is added with `respond_to`, not instead.
- Lock order AD-10: `Game::BankLock` first; the key lookup runs after it, before the availability check, so two requests with one key never open two packs nor hit the unique index.
- A replay opens nothing, credits nothing, tops up nothing and publishes no event (AD-10).
- No database id in the JSON (AD-15): packs by token, cards by slug. Faces come only from `CardComponent` (AD-16), `booster: true`, sizes `m` and `xl`.
- Migration is expand-only and passes `strong_migrations` (AD-21): nullable columns, the unique index built concurrently.
- Card backs: only `standard` exists (epic 9 adds the rest and the player's active back column); store its key. Packs opened before this story carry no back and read as `standard`.
- Copy in locale files only (AD-18), English and French.

**Never:**
- No change to the booster island, PackReveal or the pack page's reveal for the HTML flow (story 8.11 replaces them).
- No new error code for the opening outcome beyond `no_pack_available`, `throttled`, `sign_in_required`; the only other code is the protocol error `invalid_idempotency_key` (missing or malformed key).
- No stored per-tier counts: the counts before the opening are computed (current counts minus the pack's cards), the same way for the first answer and a replay.
- No `game_player_states` column, no card back catalogue beyond the `standard` key.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open, JSON | signed in, ≥1 available pack, new UUID key | 200 with the payload (Design Notes); the oldest available pack opened, its key and `standard` stored, holdings credited, `PackOpened` published | none |
| Replay | same key again (reserve now empty, or 30 posts already counted) | 200, same pack token, same cards in the same order, same faces; no pack opened, no holding or event change, rate limit not incremented | none |
| Concurrent same key | two requests with one key at once | one pack opened; both answer 200 with the same token | none |
| Key of another player | key stored on player A's pack, used by B | treated as a new key for B (opens B's pack) | none |
| Empty reserve | no available pack, new key | 422 `{ error: { code: "no_pack_available", message } }`; nothing written | none |
| Throttled | 31st JSON post within a minute, new key | 429 `throttled`, `Retry-After: 60`; nothing opened | none |
| Visitor | signed out (or banned), JSON | 401 `sign_in_required`; nothing written | existing `refuse` |
| Bad key | JSON with no `Idempotency-Key` header or not a UUID | 400 `invalid_idempotency_key`; nothing written | none |
| Daily bonus | oldest available pack is a bonus pack | `kind: "bonus"`, 3 cards with 3 faces each at m and xl | none |
| HTML | form post, no key | as today (303 to the pack page, reveal once); the pack still stores `standard` | as today |
| Last booster page | GET `/:locale/packs/:token` after a JSON opening | cards face up (`CardComponent` m), no reveal island | none |

</intent-contract>

## Code Map

- `app/controllers/packs_controller.rb` -- `create` (HTML, keep), `show` (face up unless `flash[:reveal]`, only set by the HTML branch: keep). `rate_limit` there: add `unless: :replayed_key?` (Rails passes extra options to `before_action`; `rate_limiting` in actionpack 8.1 increments the store only when the callback runs) and change `with:` to a method answering HTML (redirect + alert, as today) or JSON (429).
- `app/controllers/application_controller.rb` -- `refuse`/`refuse_with` already answer JSON `{ error: { code, message } }` (401 `sign_in_required` for visitors). Reuse `refuse_with`'s shape for the new JSON errors (a private `render_json_error(status, code, message)` in `PacksController` is enough).
- `app/helpers/packs_helper.rb` -- `pack_reveal_props` renders faces with `render(CardComponent.new(card:, size:, booster: true)).to_str` over `REVEAL_SIZES`; extract `pack_faces(card)` and reuse it in the new `pack_opening_json`. Call from the controller with `helpers.pack_opening_json(...)` (a view context, so components render).
- `packs/game/app/operations/game/open_pack.rb` -- add `idempotency_key: nil` keyword; under the lock, `Pack.find_by(player_id:, idempotency_key:)` before `next_pack` returns `Success(pack)` unchanged; on opening, `pack.update!(opened_at:, idempotency_key:, card_back: CardBacks.active_key(player))`. Validate the key format before the transaction (`Failure(:invalid_idempotency_key)`). Keep returning `Success(pack)` (callers: controller, benchmark, tests listed below).
- `packs/game/app/models/game/pack.rb` -- add `card_back_key` (stored key, or `CardBacks::STANDARD` when nil) and document the two columns.
- `packs/game/app/models/game/card_backs.rb` (new) -- `Game::CardBacks::STANDARD = "standard"`, `KEYS`, `active_key(player)` → `STANDARD` (comment: epic 9 reads the player's `game_player_states` column, AD-25).
- `packs/game/app/queries/game/tier_counts.rb` -- `TierCounts.call(player)` keys 1..5 over the published season. Add `before_opening(player, pack)`: `call` minus the pack's cards that belong to the published season, by tier, floored at 0 (one extra query: `unnest` of the pack's ids joined to `catalog_card_seasons`, duplicates counted, same published-season subquery).
- `packs/game/app/queries/game/reserve.rb` -- `count`, `full?`: the bank count in the answer.
- `packs/game/app/queries/game/bank_schedule.rb` (new) -- ascending `available_at` of the bank's packs not yet available (`Pack.bank(player_id).where.not(available_at: ..now)`), the answer's availability times (same rule as `BankSummary#next_available_at`). Leave `BankSummary` unchanged.
- `packs/catalog/app/queries/catalog/card_views.rb` -- `CardView` has `id` (slug), `rarity` (code name string), `image_url`; `rarity` nil card-seasons left out.
- `db/migrate/` -- examples: `20261005010000_add_number_to_catalog_card_seasons.rb`, `20261005010002_index_catalog_card_seasons_on_season_and_number.rb` (concurrently). Regenerate `db/schema.rb` with `bin/rails db:migrate` on the dev database then check only these changes.
- `packs/game/lib/tasks/game_benchmark.rake` -- `open_over_http` posts HTML and expects 303; switch it to the JSON exchange (fresh UUID key per post, expect 200, read `pack.url` for the GET) so the gate measures the booster's request; `check_rate_limit_ran` stays valid; keep `dust_tier` seeding as is (story 8.7 owns it).
- `config/locales/{en,fr}.yml` -- `errors.game.invalid_idempotency_key`; `packs.create.throttled` exists (reuse for JSON `throttled`).
- Tests: `test/controllers/packs_controller_test.rb` (helpers `sign_in`, `reveal_props`, `with_counting_rate_limit`, `create_pack`, `fixture_tier_ids`), `test/packs/game/open_pack_test.rb`, `open_pack_concurrency_test.rb` (thread pattern, own cleanup), `tier_counts_test.rb`, `queries_test.rb`, `test/support/game_packs.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261006000000_add_opening_key_and_card_back_to_game_packs.rb`, `db/schema.rb` -- `disable_ddl_transaction!`; `add_column :game_packs, :idempotency_key, :uuid`; `add_column :game_packs, :card_back, :string`; unique index `[player_id, idempotency_key]` `where: "idempotency_key IS NOT NULL"`, `algorithm: :concurrently`, name `index_game_packs_on_player_id_and_idempotency_key` -- AD-23, AD-21.
- [x] `packs/game/app/models/game/card_backs.rb`, `packs/game/app/models/game/pack.rb` -- the `standard` key and `card_back_key` reader -- AD-25.
- [x] `packs/game/app/operations/game/open_pack.rb` -- key format check (UUID, case-insensitive), lookup under the lock before availability, store key and back on opening; doc comment updated -- AD-23, AD-10.
- [x] `packs/game/app/queries/game/tier_counts.rb`, `packs/game/app/queries/game/bank_schedule.rb` -- `before_opening`, the schedule -- AD-23.
- [x] `app/helpers/packs_helper.rb` -- `pack_faces(card)` shared with `pack_reveal_props`; `pack_opening_json(pack, cards:, player:, now:)` building the payload (Design Notes) -- AD-16, AD-15.
- [x] `app/controllers/packs_controller.rb` -- `respond_to` in `create`: HTML as today; JSON: key from the `Idempotency-Key` header (blank → 400 `invalid_idempotency_key`), `OpenPack(player:, idempotency_key:)`, success → 200 payload, `:no_pack_available` → 422, `:invalid_idempotency_key` → 400, `:player_required` → 401 `sign_in_required`; `rate_limit ... unless: :replayed_key?` (JSON, well-formed key, signed-in player, a pack of theirs carries it); throttled → JSON 429 with `Retry-After` = the window in seconds, HTML as today; the class comment describes the exchange.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.invalid_idempotency_key` (en "The opening request was malformed. Reload the page and try again." / fr "La demande d'ouverture est mal formée. Rechargez la page et réessayez.").
- [x] `packs/game/lib/tasks/game_benchmark.rake` -- the timed POST is the JSON exchange (header comment updated).
- [x] Tests -- `test/packs/game/open_pack_test.rb`: key and `standard` stored; replay returns the same pack, writes nothing, publishes nothing, even with no available pack; bad key refused before any write; another player's key does not replay; no key opens as before (key nil, back stored). `open_pack_concurrency_test.rb`: two threads with one key → one pack opened, both succeed with the same pack id. `tier_counts_test.rb`: `before_opening` subtracts the pack's published-season cards (duplicates counted), ignores other seasons' cards, floors at 0. New `bank_schedule` test (in `queries_test.rb`). `packs_controller_test.rb`: every matrix row over HTTP (JSON payload shape and values, faces parsed with Nokogiri as the reveal test does, no `[style]`, no integer `id`/database id in the body, `serverTime` ISO 8601; replay with an emptied reserve and after the rate limit is reached; 422, 429 with `Retry-After`, 401, 400; bonus pack 3 faces; GET of `pack.url` after a JSON opening shows `.pack-result__card .card--m` and no reveal island); the existing HTML tests keep passing unchanged.

**Acceptance Criteria:**
- Given a signed-in player with available packs, when the same JSON request (one `Idempotency-Key`) is sent twice, then exactly one pack is opened and both answers carry the same pack token and the same card slugs, tiers and faces in drawn order.
- Given an opening refused for any reason, when the JSON answer arrives, then it is `{ "error": { "code", "message" } }` with its code and status, and the player's packs, holdings and event stream are unchanged.
- Given the hub's HTML form, when a player opens a pack, then the existing redirect-and-reveal flow and its tests still pass.
- Given `RAILS_ENV=test bin/rails game:benchmark_open_pack`, when it runs, then the worst JSON POST p95 is under 200 ms.

## Implementation Notes

- `replayed_key?` (the rate limit's `unless:`) calls `Game::OpenPack.replay?(player, key)`, a class method beside the key regex (`OpenPack::IDEMPOTENCY_KEY`), rather than reading `Game::Pack` from the controller: the web layer reads Game through its queries and operations only.
- `TierCounts.before_opening` unnests `game_packs.card_season_ids` by pack id (one query, `CROSS JOIN unnest`) instead of passing the ids as an array literal; the published-season subquery is shared as `PUBLISHED_SEASON`.
- The JSON failure map is `PacksController::FAILURES`; `player_required` answers with the `authorization.sign_in_required` message, as `refuse` does. A request in neither HTML nor JSON gets Rails' 406 (`UnknownFormat`).
- Review follow-up: the migration is split in two, as 20261005010000/…010002 were: `20261006000000` adds the columns in a transaction, `20261006000001_index_game_packs_on_player_id_and_idempotency_key.rb` builds the unique index concurrently, so a failed index build leaves a rerunnable state. `Game::BankSummary#next_available_at` is now `BankSchedule.call(player, now:).first`.
- `db/schema.rb` regenerated on the dev database; the dump's unrelated check-constraint rewording (local PostgreSQL 18) was reverted, leaving only the two columns, the index and the version.
- The concurrent-same-key row is covered at the operation level (`open_pack_concurrency_test.rb`), not over HTTP.
- Benchmark (dev machine): worst JSON POST p95 16.9 ms over 3 runs, 22 queries per POST.
- Verify (orchestrator): the benchmark's rate-limit check read every player's count after the whole run, but the count expires one window (60 s) after its first increment and a run with the JSON exchange lasts longer, so it refused with "counted 0 openings of 10". Each player's count is now checked right after their tenth post (`check_rate_limit_ran(player_id, count)`). Rerun after the review fixes: worst POST p95 17.1 ms, 22 queries per POST, exit 0.

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 29 findings — high 0, medium 0, low 19, false 10, maybe-false 0 (4 lenses: blind 11, edge-case 9, verification-gap 1, intent 8)
- findings:
  - `[low]` `[reject]` (blind) Replays skip the rate limit yet render the full answer, so one key can be resent in a loop — every GET of an opened pack's page renders comparable work with no limit at all; abuse is bounded at the edge (Cloudflare); a second limit adds a branch for no everyday case.
  - `[low]` `[reject]` (blind) `tierCountsBefore` drifts on a replay after a later opening — the documented rule (adversarial review H12: current counts minus the pack's cards); a later opening between a lost answer and its retry needs a second tab; storing a snapshot adds a column AD-23 does not name.
  - `[low]` `[patch]` (blind) The helper comment says the answer is the same for a first opening and a replay — reworded: the pack, back, cards and faces are as opened; bank and server time are current; counts recomputed; `unlockedCardBacks` empty until epic 9.
  - `[low]` `[defer]` (blind) A missing or stale CSRF token answers Rails' 422 HTML, not the JSON error envelope — pre-existing for every POST (`protect_from_forgery with: :exception`, test env disables it); the island (8.11) is where it bites; recorded in `deferred` and deferred-work.md.
  - `[false]` `[reject]` (blind) `render_failure` raises KeyError on an unmapped failure; `player_required` is dead — `Game::OpenPack` returns only the four mapped codes (`publish` returns Success or raises), so the KeyError is unreachable; `player_required` is a defensive mapping matching `refuse`.
  - `[low]` `[patch]` (blind) The migration is not rerunnable if the concurrent index fails after the columns; `card_back` unconstrained — split into `20261006000000` (columns, transactional) and `20261006000001` (index, concurrently), as 20261005010000/…010002; card back keys live in code by AD-25 (a check would need a migration per back).
  - `[low]` `[reject]` (blind) The benchmark no longer times the HTML form POST and the reveal GET — both leave with story 8.11; the JSON POST renders the faces the HTML POST does not, so it is the heavier gate (17.1 ms against the HTML's former 11.1 ms).
  - `[low]` `[patch]` (blind) No test of `nextAvailableAt: null` / `scheduledAt: []` or `reserveFull: true` — grouped with the verification-gap row: new JSON test leaving 10 available and nothing scheduled.
  - `[low]` `[patch]` (blind) `BankSchedule` duplicates `BankSummary`'s next-time query, so chip and answer could diverge — `BankSummary#next_available_at` is now `BankSchedule.call(player, now:).first` (benchmark GET unchanged at 10 queries).
  - `[low]` `[reject]` (blind) The replay check adds one query to every new JSON opening — one indexed `exists?`; measured p95 17.1 ms against 200 ms.
  - `[low]` `[reject]` (blind) `Retry-After` is always the full 60 s window — an upper bound is safe for a retry; the store gives no remaining time without reading internals.
  - `[low]` `[patch]` (edge) A duplicate in flight at the 30th post gets 429 instead of a replay — needs a retry before the first answer commits, at the limit; its retry after Retry-After replays the pack (throttled is retryable, H12), so no guard is added; grouped with the claim rows below: the class comment now states it.
  - `[low]` `[reject]` (edge) A request with a key but `Accept: */*` or HTML takes the form path and ignores the key — the island's own fetch (8.11) sets `Accept: application/json`, and its protocol tests read JSON, so a missing header fails there at once; the browser's form never sends a key.
  - `[false]` `[reject]` (edge) A drawn card without a CardViews row gives a 500 after commit — draws read only the published season, whose card-seasons all have a rarity and a text in every locale (Catalog refuses `missing_text`); the pack page has the same `fetch`.
  - `[low]` `[defer]` (edge) CSRF failure answers 422 HTML — same root cause as the blind CSRF row; deferred.
  - `[low]` `[patch]` (edge) Migration not rerunnable after a failed concurrent index — same as the blind migration row; split applied.
  - `[low]` `[reject]` (edge) The HTML form POST lost its p95 gate — same as the blind benchmark row.
  - `[low]` `[patch]` (edge, claim) The replay exemption only sees committed keys, so a concurrent duplicate can be throttled — comment patch: the class comment now says a duplicate sent before the first answer commits is counted and replays on its retry after Retry-After.
  - `[false]` `[reject]` (edge, claim) CSRF, UnknownFormat and KeyError are not enveloped — CSRF deferred above; a 406 for a request neither HTML nor JSON is not an opening refusal; the KeyError is unreachable (above).
  - `[low]` `[patch]` (edge, claim) The class comment's "even once the rate limit is reached" overstates — same comment patch as above.
  - `[low]` `[patch]` (verification-gap) `bank.reserveFull` is only ever asserted `false` — new test: a bonus pack opened while 10 regular packs stay available answers `{ available: 10, reserveFull: true, nextAvailableAt: null, scheduledAt: [] }`.
  - `[false]` `[reject]` (intent) No client sends the JSON request — the exchange is added beside the form by design; the booster island that sends it is story 8.11.
  - `[false]` `[reject]` (intent) Concurrent same-key posts are tested at the operation level only, and the replay recomputes bank and server time — the lock and the lookup that decide are in the operation, tested with two real threads; AD-23's "that pack as it was opened" is the pack; a countdown needs the current server time.
  - `[low]` `[patch]` (intent) In-flight duplicates count against the limit — same as the edge-case row; comment patched.
  - `[false]` `[reject]` (intent) A fourth error code, `invalid_idempotency_key` — the three codes are the opening's outcomes; a missing or malformed key is a protocol error the island never produces (a UUID per activation); no bad outcome.
  - `[false]` `[reject]` (intent) The bonus test builds a synthetic bonus row — `Game::CollectDailyBonus` creates the same row shape (`Pack.row`, kind bonus), and the database check forces 3 cards for that kind.
  - `[false]` `[reject]` (intent) "mon dernier booster" could mean a latest-pack route, or no reveal on the form path either — AD-23 says the token page "stays as" it; the form's reveal is kept on purpose until 8.11.
  - `[false]` `[reject]` (intent) The counts before are derived, not a snapshot — the same design choice as the blind row; AD-23 stores only the key and the back on the pack.
  - `[false]` `[reject]` (intent) Scheduled times cover regular packs only — bonus packs are created available at once (`collect_daily_bonus.rb:43`, `available_at: now`), so no other kind is ever scheduled.

## Design Notes

Success payload (camelCase like the islands' props; 200 for a first opening and a replay alike):

```json
{
  "pack": { "token": "…", "kind": "regular", "cardBack": "standard", "url": "/fr/packs/…" },
  "cards": [ { "slug": "portal", "tier": "epic", "coverUrl": "https://…", "faces": { "m": "<span class=\"card …\">…", "xl": "…" } } ],
  "bank": { "available": 9, "reserveFull": false, "nextAvailableAt": "2026-10-06T14:32:00.000Z", "scheduledAt": [ "2026-10-06T14:32:00.000Z" ] },
  "serverTime": "2026-10-06T14:22:00.123Z",
  "tierCountsBefore": { "common": 12, "uncommon": 4, "rare": 1, "epic": 0, "legendary": 0 },
  "unlockedCardBacks": []
}
```

- `tier` and the count keys are `Catalog::Rarity::TIERS` code names; times are UTC ISO 8601 with milliseconds; `nextAvailableAt` is `scheduledAt.first` (nil when none).
- The key travels in the `Idempotency-Key` request header (the island generates a UUID per activation with `crypto.randomUUID()`); the column is `uuid`, so the lookup compares UUIDs whatever their case.
- Replay before throttle: `replayed_key?` is one indexed `exists?` outside the lock; the authoritative lookup is inside `OpenPack` after `BankLock.acquire`, so an in-flight duplicate waits for the first to commit and then replays it.
- Counts before the opening = current published-season counts minus the pack's cards of that season, floored at 0 (adversarial review H12's rule); identical for a replay unless the player gained cards since.

## Verification

**Commands:**
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails db:test:prepare test` -- 0 failures, 0 errors
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- 0 failures, 0 errors
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- exits 0, worst POST p95 < 200 ms

## Auto Run Result

**Status:** built.

**Summary:** `POST /:locale/packs` answers AD-23's opening exchange in JSON beside the hub's HTML form, which is unchanged:
- the request carries an `Idempotency-Key` header (a UUID); the key and the card back (`standard`, the only one yet) are stored on the opened pack, the key unique per player;
- under the bank lock, before the availability check, a key already stored replays its pack: nothing opened, credited, topped up or published; a replay is also exempt from the rate limit;
- the answer gives the pack (token, kind, card back, page url), its cards in drawn order (slug, tier, cover URL, CardComponent faces at m and xl), the bank (count, full, availability times), the server time, the per-tier counts before the opening and an empty list of unlocked backs; no database id;
- refusals answer `{ error: { code, message } }`: 422 `no_pack_available`, 429 `throttled` with `Retry-After`, 401 `sign_in_required`, 400 `invalid_idempotency_key`;
- the pack's page stays face up after a JSON opening (the form's one-time reveal stays until 8.11).

**Files changed:**
- `app/controllers/packs_controller.rb`: the JSON branch, the error map, the replay-aware rate limit.
- `app/helpers/packs_helper.rb`: `pack_faces` (shared with the reveal) and `pack_opening_json`.
- `config/locales/en.yml`, `fr.yml`: `errors.game.invalid_idempotency_key`.
- `db/migrate/20261006000000_add_opening_key_and_card_back_to_game_packs.rb`, `db/migrate/20261006000001_index_game_packs_on_player_id_and_idempotency_key.rb`, `db/schema.rb`: the two columns and the unique partial index (built concurrently).
- `packs/game/app/models/game/card_backs.rb` (new): the `standard` key.
- `packs/game/app/models/game/pack.rb`: `card_back_key`.
- `packs/game/app/operations/game/open_pack.rb`: the key check, the replay under the lock, the stored key and back; `replay?`.
- `packs/game/app/queries/game/bank_schedule.rb` (new), `bank_summary.rb`: the availability times, shared with the chip's next time.
- `packs/game/app/queries/game/tier_counts.rb`: `before_opening`.
- `packs/game/lib/tasks/game_benchmark.rake`: the timed POST is the JSON exchange; the rate-limit count is checked per player before it expires.
- Tests: `test/controllers/packs_controller_test.rb`, `test/packs/game/{open_pack,open_pack_concurrency,tier_counts,queries}_test.rb`.

**Review (thorough, 4 lenses, 29 findings: 19 low, 10 false):**
- patched (all low): the helper and class comments (replay fields; in-flight duplicates and the rate limit), the migration split, the reserve-full / nothing-scheduled JSON test, `BankSummary` reading `BankSchedule`.
- deferred (1, low): the CSRF failure's HTML answer on the JSON path, for story 8.11 (frontmatter `deferred`, deferred-work.md).
- rejected: every other finding, with its reason in the Review Triage Log.

**Follow-up review recommended:** false. No high or medium entry was patched (0 high, 0 medium, 7 low entries patched).

**Verification** (default `gameble_test` database), all passing:
- `bin/rubocop`: no offenses; `packwerk validate` and `check`: clean; `i18n-tasks missing`: none.
- `npm run typecheck`; `npm run test:js`: 126 tests.
- `bin/rails db:test:prepare test`: 1155 runs, 0 failures, 0 errors.
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system`: 69 runs, 0 failures.
- `RAILS_ENV=test bin/rails game:benchmark_open_pack`: worst POST (JSON) p95 17.1 ms over 3 runs (limit 200 ms), 22 queries per POST; exit 0.

**Residual risks:**
- No client sends the exchange yet (story 8.11); CSRF on the JSON path is untested (test env disables it).
- The counts before the opening are recomputed on a replay and drift if the player gained cards meanwhile.
- The migrations have not run on the test LXC (they run with the next deploy, which is the author's).

