---
title: 'Request-test helpers shared'
type: 'refactor'
ticket: '36'
created: '2026-10-13'
status: done
baseline_revision: 'd24977f28ef19afe83a370d8fbea155d8eed2a13'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The `hold` helper is still copied in about 20 test files (game pack unit tests, trades, reposts, shell, the trades system test) beside LibraryRequests#hold.
    evidence: |-
      `grep -rn "def hold" test` lists the copies with differing signatures (reserved:, gained_at:, player: defaults); the epic 4 retrospective item D2 named them with the sign-in copies, and this ticket covers the sign-in helpers only.
    location: >-
      test/packs/game/*_test.rb, test/controllers/{trades,reposts}_controller_test.rb, test/integration/shell_test.rb, test/system/trades_test.rb
    severity: low
  - summary: >-
      The `hold` comment in test/support/library_requests.rb still names a planning id (AD-26).
    evidence: |-
      Pre-existing line outside this diff's hunks; planning ids remain in many test comments and belong to the repo-wide sweep already deferred in deferred-work.md.
    location: >-
      test/support/library_requests.rb:5
    severity: low
---

<intent-contract>

## Intent

**Problem:** About 36 request tests and 21 system tests each carry their own copy of the Steam sign-in mock (`OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(...)`), of OmniAuth's test-mode setup and teardown, and, in the request tests, of a `sign_in` that posts to `/auth/steam` and follows the redirect. `test/support/library_requests.rb` holds a shared `sign_in` that only the library tests use.

**Approach:** One support module, `SteamSignIn` (`test/support/steam_sign_in.rb`), holds OmniAuth's test mode for the including test, the Steam mock, and the request sign-in; every test file uses it and drops its own copy. Test-only: no app code changes.

## Boundaries & Constraints

**Always:** Keep every test's behaviour (origin, the player signed in, the requests made); never weaken an assertion (the shared `sign_in` asserts the session holds the player, stronger than the copies that asserted nothing or only presence). Name models only inside methods, never in a class body. English only, no planning ids in code.

**Never:** No app code change. Not included in `ActiveSupport::TestCase` or `ActionDispatch::IntegrationTest` globally: `test/integration/steam_open_id_test.rb` runs the real OpenID flow with test mode off. Not the `hold` copies (out of this ticket). No new system test; system tests are not run (disabled).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sign a fixture player in | `sign_in(player)` | POST `/auth/steam` with origin `sign_in_origin` ("/en" unless the test overrides it), follows the redirect, asserts `session[:player_id] == player.id` | assertion fails |
| Sign a new steam id up | `sign_in_new_player(steam_id)` | same flow, asserts a player id is in the session | assertion fails |
| A sign-in expected to be refused (banned, forged) | `mock_steam_sign_in(steam_id)` then the test's own POST | only the mock is shared; the test asserts the refusal itself | n/a |
| A test case defaulting to French | `def sign_in_origin = "/fr"` in the test class | its sign-ins post origin "/fr" as before | n/a |

</intent-contract>

## Code Map

- `test/support/steam_sign_in.rb` -- new. `self.included(test_case)` adds `setup { OmniAuth.config.test_mode = true }` and a teardown deleting `mock_auth[:steam]` and turning test mode off (pattern of `test/support/hidden_back_office.rb`). Methods: `mock_steam_sign_in(steam_id)`, `sign_in(player, origin: sign_in_origin)`, `sign_in_new_player(steam_id, origin: sign_in_origin)`, `sign_in_origin` returning "/en".
- `test/support/library_requests.rb` -- drop `sign_in` and the comment lines about the Steam mock and test mode; its includers include `SteamSignIn` too (a plain module cannot forward `included` hooks).
- Request tests with a local `sign_in` copy: `test/controllers/{accounts,authorization,boosters,daily_bonuses,feeds,friends,invitations,packs,pages,presence,reports,reposts,settings,trades}_controller_test.rb` (authorization, presence are `*_test.rb`), `test/controllers/back_office/{bans,cards,dashboard,history,import_runs,players,reports,seasons}_controller_test.rb`, `test/controllers/back_office/{hidden,jobs}_test.rb`, `test/integration/{player_stream_tag,shell}_test.rb`.
  - `/fr` default: trades and all ten back-office files → `def sign_in_origin = "/fr"`.
  - `player = @player` default (friends, presence, settings) and accounts' `steam_id = @player.steam_id` → bare `sign_in` calls become `sign_in(@player)`.
  - steam-id signatures: packs `sign_in(player.steam_id)` → `sign_in(player)`; packs `sign_in(NEW_STEAM_ID)` and accounts `sign_in(steam_id)` (a released id signing up again) → `sign_in_new_player(...)`.
  - feeds turned test mode on inside `sign_in`: now the hook does.
- LibraryRequests includers (OmniAuth boilerplate only): `test/controllers/{cards,collection_seen,friend_profiles,library,public_profiles}_controller_test.rb`, `test/controllers/{library_set,card_preview_tags}_test.rb`.
- Inline mocks in request tests → `mock_steam_sign_in`: `authorization_test.rb` (two refused sign-ins), `card_preview_tags_test.rb` (posts to the form's action), `test/integration/rate_limit_test.rb` (setup), `event_store_metadata_test.rb` (setup), `content_security_policy_test.rb` (whole in-test sign-in → `sign_in(accounts_players(:player))`, ensure block dropped).
- `test/controllers/sessions_controller_test.rb` -- tests the sign-in itself: keep `mock_steam(uid)` for raw and forged claimed ids and `sign_in_with_steam` (asserts the callback redirect); `mock_steam("https://steamcommunity.com/openid/id/#{x}")` calls and `mock_steam(CLAIMED_ID)` become `mock_steam_sign_in(...)`; OmniAuth lines leave setup/teardown.
- System tests (`test/system/*_test.rb`, the 21 files with a mock line): mechanical only -- require and include `SteamSignIn`, mock line → `mock_steam_sign_in(x.steam_id)`, drop the OmniAuth test-mode and delete lines (and blocks left empty). Their local browser `sign_in` helpers (visit and click) are a different flow and stay; they shadow the module's request `sign_in`.
- Untouched: `test/integration/steam_open_id_test.rb`, `test/packs/steam/sign_in_identity_test.rb` (no request sign-in).

## Tasks & Acceptance

**Execution:**
- [x] `test/support/steam_sign_in.rb` -- create the module -- one home for the Steam sign-in.
- [x] `test/support/library_requests.rb` -- remove `sign_in`, update its header comment -- no second copy.
- [x] every request-test file in the Code Map -- `require_relative` the support file, `include SteamSignIn`, delete the local helper and the OmniAuth setup/teardown lines (remove blocks left empty), adapt calls as listed -- shared helper.
- [x] `test/controllers/sessions_controller_test.rb` -- as in the Code Map.
- [x] the 21 system test files -- mechanical replacement as in the Code Map; check syntax with `ruby -c`.

**Acceptance Criteria:**
- Given the test tree, when grepping `test/` for `OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/`, then the only hit is `test/support/steam_sign_in.rb`.
- Given the test tree, when grepping for `OmniAuth.config.test_mode =`, then hits are only the support module and `steam_open_id_test.rb` (if any there).
- Given the full suite, when run in parallel twice, then it passes with the baseline's 2386 runs and at least the baseline's 25635 assertions.

## Implementation Notes

- `SteamSignIn` holds a private `sign_in_with_steam_id` shared by `sign_in` and `sign_in_new_player`.
- `library_requests.rb` lost its `sign_in`; its header comment no longer names an epic.
- `sessions_controller_test.rb`: `mock_steam(uid)` stays for the forged claimed ids (`https://evil.example/...`); `CLAIMED_ID` became unused and was removed; the setup mocks with `mock_steam_sign_in(STEAM_ID)`.
- `content_security_policy_test.rb`: the in-test sign-in became `sign_in(accounts_players(:player))`, which also asserts the session (stronger than before); its `ensure` block went with the module teardown.
- Copies that asserted nothing (boosters, feeds, friends, invitations, presence, trades) or only a present id (daily bonuses, reports, reposts, settings) now assert the signed-in player's id; all pass.
- In `back_office/{cards_controller,hidden}_test.rb`, `def sign_in_origin` sits below the class constants.
- System tests: 20 files changed mechanically, syntax-checked with `ruby -c`, not run (disabled). Their browser `sign_in` helpers (visit and click) stay and shadow the module's request `sign_in`.
- Verification: `bin/rails test` twice, 2386 runs, 25726 and 25723 assertions, 0 failures (baseline 2386 runs, 25635 assertions); `npm run test:js` 243 passed; zeitwerk, packwerk, rubocop (698 files) clean.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 1, false 0, maybe-false 0 (2 plan-bookkeeping findings rejected as plan edits)
- findings:
  - `[low]` `[reject]` Two execution tasks left unchecked in the plan — the fix edits this build's plan; the boxes were ticked at finalize as bookkeeping.
  - `[low]` `[reject]` The plan says 21 system files; the baseline has 20 (the diff changes all 20) — the fix edits this build's plan; Implementation Notes already say 20.
  - `[low]` `[defer]` `test/support/library_requests.rb:5` still names AD-26 — pre-existing, outside the changed lines; part of the repo-wide planning-id sweep already in deferred-work.md.

## Design Notes

`sign_in_origin` is a method, not a keyword default per file, so a test case that signs in in French says it in one line and the calls stay `sign_in(player)`. The hooks are installed by `included` as `HiddenBackOffice` does; a module-level include from `LibraryRequests` would hook the module, not the test case, hence the separate include.

## Verification

**Commands:**
- `bin/rails test` (twice) -- expected: 0 failures, 0 errors, 2386 runs, assertions >= 25635
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: pass
- `for f in test/system/*_test.rb; do ruby -c $f; done` -- expected: Syntax OK (system tests are disabled and not run)

## Auto Run Result

**Summary:** One support module, `test/support/steam_sign_in.rb` (`SteamSignIn`), now holds OmniAuth's test mode, the Steam mock (`mock_steam_sign_in`) and the request sign-in (`sign_in`, `sign_in_new_player`, `sign_in_origin`); every request and system test uses it, and no test file keeps its own copy. Test-only; no app code changed.

**Files changed:**
- `test/support/steam_sign_in.rb` -- new shared module.
- `test/support/library_requests.rb` -- its `sign_in` removed.
- 32 controller tests and 5 integration tests -- local `sign_in` copies, inline mocks and OmniAuth setup/teardown replaced by the module; `/fr` cases use `sign_in_origin`.
- 20 system tests -- mechanical replacement of the mock line and the OmniAuth setup/teardown (not run: system tests are disabled).

**Review:** quick lens; 0 patches; 1 deferred (planning id in a pre-existing comment), 1 deferred out of scope (the `hold` copies); 2 rejected (plan bookkeeping, fixes would edit this plan). Follow-up review: false (no patched entries).

**Verification:** `bin/rails test` twice in parallel: 2386 runs, 25726 / 25723 assertions, 0 failures, 0 errors (baseline 2386 runs, 25635 assertions, 0 failures). `npm run test:js` 243 passed; `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` (698 files) clean; `ruby -c` OK on every system test.

**Residual risks:** the 20 system test files are syntax-checked only; when system tests are rebuilt, the module's teardown now runs alongside theirs (independent OmniAuth resets).
