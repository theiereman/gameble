---
title: 'Steam tells which catalog games a player owns'
type: 'feature'
ticket: '6'
created: '2026-10-30'
status: 'built'
baseline_revision: '4ce7ab9e9a7b81425a90f2c8917fcbba7926dd83'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      An answer whose `game_count` is positive while `games` is an empty list would be read as an empty library and answered `Success([])`.
    evidence: |-
      `get_owned_games` returns `[]` for `{"response":{"game_count":12,"games":[]}}` and nothing compares the count with the list. No source shows Steam sending that shape: the architecture review (review-versions-2026-10-30.md, F2) reports `{"response":{}}` for some public profiles, which is read as private. A recorded Steam answer with a positive count and an empty list would settle it; the library sync entry is where it would erase a set.
    location: >-
      app/domains/steam/app/clients/steam/web_api.rb get_owned_games
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The Steam library set (a later entry) needs to know which catalog games a player owns on Steam, and must never mistake a private, empty or failing Steam answer for an empty library, which would erase the set's games.

**Approach:** Add `get_owned_games` to the Steam Web API client (one attempt, bounded by a deadline, with the architecture's parameters), a `Catalog::PublishedCardIds` query that keeps the cards with a card-season in a published season, and `Steam::OwnedGames`, which maps the owned appids to those catalog card ids and returns `Success(ids)`, `Failure(:library_private)` or `Failure(:steam_unavailable)`.

## Boundaries & Constraints

**Always:**
- GetOwnedGames is `GET /IPlayerService/GetOwnedGames/v1/` with `key`, `steamid`, `include_appinfo=false`, `include_played_free_games=true`, `skip_unvetted_apps=false`, and nothing else.
- One Steam call per `Steam::OwnedGames` call: no retry middleware (the job retries a day later, and every retry spends the key's daily quota); a deadline bounds the whole request.
- `:library_private` only when Steam answers 200 with a `response` object that has no `games` key. `:steam_unavailable` on a timeout, a connection failure, a 429 or a 5xx.
- A 401/403 or a missing key still raises `Steam::WebApi::BrokenKey`; a malformed answer (no `response` object, `games` not a list) raises `Steam::WebApi::Error`. Neither is ever turned into a library, empty or not. Errors never carry the key.
- An appid maps to a card through `Steam::CardMapping.source_key`; `Catalog::PublishedCardIds` is the one filter (the custom set picker reuses it later). Returned ids are unique and sorted.
- `Steam` keeps nothing: no table, no stored response, no event.

**Never:** a job, a table, a migration, a UI, a locale string, `Game` code, playtime or appinfo reading, or a real Steam call in tests.

## I/O & Edge-Case Matrix

| Scenario | Steam answer | Result |
|----------|--------------|--------|
| Owned list | 200 `{"response":{"game_count":3,"games":[{"appid":10,...},...]}}` | `Success([card ids of published catalog games])` |
| Games outside the catalog or only in a draft season | appids with no card, or a card without a published card-season | left out of the ids |
| Explicit empty list | 200 `{"response":{"game_count":0,"games":[]}}` | `Success([])` |
| Private library | 200 `{"response":{}}` (also with `game_count` but no `games`) | `Failure(:library_private)` |
| Rate limited / Steam down | 429, 500, 502, 503, 504, timeout, connection failure | `Failure(:steam_unavailable)`, exactly one call made |
| Malformed | no `response` object, `games` not a list | raises `Steam::WebApi::Error` without the key |
| Malformed entries | entries not objects, appid not a positive int4 | entry skipped |
| Rejected key | 401, 403, or no key set | raises `Steam::WebApi::BrokenKey` (no call when no key) |

</intent-contract>

## Code Map

- `app/domains/steam/app/clients/steam/web_api.rb` -- the client. Reuse `get(path, params, connection_without_retry, deadline:)` exactly as `get_player_summary` does (single attempt, `Timeout` bound, key redaction, `BrokenKey` on 401/403). Add an `Unavailable < Error` subclass raised by `get` for `Faraday::TooManyRequestsError`, `Faraday::ServerError`, `Faraday::TimeoutError`, `Faraday::ConnectionFailed` (redacted, `cause: nil`), so existing callers that rescue `Error` keep working. Add `class_attribute :owned_games_deadline` (10.0) and `get_owned_games(steamid:)` returning the appid array, or `nil` when the response has no `games` key; filter entries with `RawValue.integer(min: 1, max: RawValue::INT4_MAX)`.
- `app/domains/steam/app/models/steam/owned_games.rb` -- new `Steam::OwnedGames.call(steam_id:, api: WebApi.new)` with `Dry::Monads[:result]` (module style of `Steam::SignInIdentity` / `Steam::CardMapping`).
- `app/domains/steam/app/models/steam/card_mapping.rb` -- `source_key(appid)` gives `"steam:<appid>"`; read only.
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- new; model after `published_card_season_ids.rb` (card-season with rarity not null in a season with `status: "published"`). Takes `source_keys:`, returns card ids. Steam → Catalog is an allowed packwerk arrow.
- `test/support/steam_api_stubs.rb` -- add `OWNED_GAMES_PATH`, stub helpers for an owned-games answer shaped on Steam's real answer (`game_count`, `games` with `appid`, `playtime_forever`, `playtime_windows_forever`, `rtime_last_played`, ...), a private answer, a failure status, and save/restore `owned_games_deadline` in `stub_steam_api`/`unstub_steam_api`.
- `test/support/catalog_seeds.rb` -- `seed_card_seasons` and friends to seed published and draft cards; reuse, do not change semantics.
- `test/domains/steam/web_api_test.rb` -- existing client tests, pattern for new `get_owned_games` tests (params, retry absence, deadline, broken key, redaction).
- `test/domains/catalog/published_card_season_ids_test.rb` -- pattern for the new catalog query test.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/steam/app/clients/steam/web_api.rb` -- add `Unavailable`, `owned_games_deadline`, `get_owned_games` -- one bounded call with the architecture's parameters.
- [x] `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- add the query -- the one published-card filter shared with the later picker.
- [x] `app/domains/steam/app/models/steam/owned_games.rb` -- add the result-returning entry point -- maps appids to published card ids; rescues only `WebApi::Unavailable` into `:steam_unavailable`.
- [x] `test/support/steam_api_stubs.rb` -- add the owned-games stubs and deadline restore.
- [x] `test/domains/steam/web_api_test.rb` -- `get_owned_games` tests: exact params, appids read, private answer is nil, explicit empty list is `[]`, each of 429/5xx/timeout/connection failure raises `Unavailable` after one call, malformed raises `Error`, 401/403 raise `BrokenKey`, key never in messages.
- [x] `test/domains/steam/owned_games_test.rb` -- every row of the I/O matrix through `Steam::OwnedGames`, with seeded published, draft-only and absent cards.
- [x] `test/domains/catalog/published_card_ids_test.rb` -- published kept, draft-only and unrated dropped, unknown keys ignored, empty input gives `[]` without a query.

**Acceptance Criteria:**
- Given a public library holding two published catalog games, one draft-only game and one unknown appid, when `Steam::OwnedGames` runs, then it returns `Success` with exactly the two published card ids.
- Given any failing Steam answer, when `Steam::OwnedGames` runs, then the result is never `Success([])`.
- Given the suite, when it runs, then no test reaches `api.steampowered.com`.

## Implementation Notes

- `WebApi#get` now raises `Unavailable` (an `Error`) for 429, 5xx, timeouts and connection failures on every path, so a failed import run's recorded message names `Steam::WebApi::Unavailable` instead of `Steam::WebApi::Error`; `test/jobs/steam_import_step_job_test.rb` expects the new class name. Callers that rescue `Error` (sign-in's persona name, the import job's `retry_on StandardError`) behave as before.
- `Catalog::PublishedCardIds` runs one query: cards whose `source_key` is asked and whose id has a rated card-season in a published season, ordered by id.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A non-empty `games` list with no readable appid came back as `[]`, so `Steam::OwnedGames` answered `Success([])` and a sync would erase the library set — `get_owned_games` now raises `Error` when `games` is non-empty and yields no appid; tests in `web_api_test.rb` and `owned_games_test.rb`.
  - `[low]` `[patch]` `Faraday::SSLError` and `Faraday::RequestTimeoutError` (408) raised `Error` instead of `Unavailable` — both added to `UNAVAILABLE`; the failure loops cover 408 and an SSL failure.
  - `[medium]` `[patch]` Every draft-only card-season in the tests was unrated, so the published-season filter was never exercised (confirmed from `seed_card_seasons`, which inserts no rarity) — the draft-only card-season is now rated in both test files; removing the season filter fails three tests.
  - `[low]` `[patch]` The "kept once" test used an unrated second card-season, so deduplication was not exercised — a new test rates the same card in two published seasons and expects its id once.

### 2026-10-30 — Review pass (follow-up)
- verdicts: 1 findings — high 0, medium 0, low 0, false 0, maybe-false 1
- findings:
  - `[maybe-false]` `[defer]` `game_count` is never compared with `games`, so `{"game_count":12,"games":[]}` would give `Success([])` — not a carried row (the first pass's empty-library finding was about unreadable entries). The cited source (review-versions F2) shows `{"response":{}}`, which is read as private; no source shows a positive count with an empty list. A recorded Steam answer of that shape would settle it; if real it is medium. Deferred to the frontmatter `deferred` list.

## Design Notes

`Unavailable` lives in the client because only the client sees Faraday's error classes; `Steam::OwnedGames` turns it into a failure code and lets `Error` and `BrokenKey` raise, since those mean a broken answer or configuration that a later retry will not fix silently and the job's error reporting should surface.

No retry middleware: the import connection retries 4 times with backoff up to a minute, which would hold the import worker's single thread and spend quota; the daily job is the retry.

## Verification

**Commands:**
- `bin/rails test test/domains/steam test/domains/catalog/published_card_ids_test.rb` -- expected: all green
- `bundle exec packwerk check` -- expected: no violations
- `bin/rubocop app/domains/steam app/domains/catalog/app/queries test/support/steam_api_stubs.rb test/domains/steam test/domains/catalog` -- expected: no offenses
- `script/check_planning_references && script/check_file_sizes && bin/rails zeitwerk:check` -- expected: pass

## Auto Run Result

**Summary:** `Steam::OwnedGames.call(steam_id:)` asks GetOwnedGames once (no retry, 10 s deadline, the architecture's parameters) and returns `Success` with the sorted, unique `catalog_cards` ids of the owned games that have a rated card-season in a published season, `Failure(:library_private)` when Steam answers a `response` without `games`, or `Failure(:steam_unavailable)` on a 408, 429, 5xx, timeout, connection or TLS failure. A malformed answer, including a non-empty list with no readable appid, raises `Steam::WebApi::Error`; a rejected or missing key raises `BrokenKey`. Nothing is ever read as an empty library unless Steam lists `games: []`.

**Files changed:**
- `app/domains/steam/app/clients/steam/web_api.rb` -- `Unavailable` error class, `owned_games_deadline`, `get_owned_games`.
- `app/domains/steam/app/models/steam/owned_games.rb` -- new entry point returning the result codes.
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- new published-card filter, shared later with the custom set picker.
- `test/support/steam_api_stubs.rb` -- GetOwnedGames stubs shaped on Steam's answer; deadline restore.
- `test/domains/steam/web_api_test.rb`, `test/domains/steam/owned_games_test.rb`, `test/domains/catalog/published_card_ids_test.rb` -- client, entry point and query tests.
- `test/jobs/steam_import_step_job_test.rb` -- a failed import run's message now names `Steam::WebApi::Unavailable`.

**Review findings:** 4 patches applied (medium 2, low 2), none deferred, none rejected.

**Follow-up review recommended:** true -- two medium findings were patched in this pass (the all-unreadable games list read as an empty library, and the untested published-season filter); the patched guard and tests were verified by the test run only, not by a second review.

**Verification:** `bin/rails test test/domains/steam test/domains/catalog/published_card_ids_test.rb test/jobs/steam_import_step_job_test.rb test/controllers/sessions_controller_test.rb` -- 393 runs, 0 failures; `bundle exec packwerk check` -- no violations; rubocop on the touched paths -- no offenses; `script/check_planning_references`, `script/check_file_sizes`, `bin/rails zeitwerk:check` -- pass. Full suite and system tests not run (no screen touched).

**Residual risks:** every Steam call now raises `Unavailable` (an `Error`) on transient failures, so import run messages recorded from now on name that class; rescuers of `Error` are unaffected. A list with some readable appids and some unreadable ones is read as the readable part.

### Follow-up pass (2026-10-30)

- One independent quick review of the whole change since the baseline. It found every acceptance criterion met and the parameters, error classes, single bounded call, published filter, packwerk arrow and redaction sound.
- Findings: 1, `maybe-false`, deferred (a positive `game_count` with an empty `games` list would read as an empty library; no source shows Steam sends it). Patches: none. Rejected: none.
- Follow-up review recommended: false -- this follow-up pass patched nothing.
- Verification: the reviewer ran the three touched test files (112 runs, 0 failures), rubocop, packwerk, `script/check_planning_references` and `script/check_file_sizes`, all clean; no code changed in this pass.
