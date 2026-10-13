---
title: 'The persona lookup keeps one deadline and reports a broken Steam key'
type: 'bugfix'
ticket: '27'
created: '2026-10-13'
status: 'built'
baseline_revision: '15e235688305dba6f26baf097fd8d69d47244daf'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** `Steam::WebApi#get_player_summary` gives its connection separate 5 s open and read timeouts, so a Steam slow to connect and to answer holds a sign-in about 10 s (a trickled body, longer); and a missing or rejected Steam key is a plain `Steam::WebApi::Error`, which `SessionsController#persona_name` only logs as a warning, so every profile silently keeps the « Brother » fallback name.

**Approach:** The persona lookup runs under one total deadline of 5 s covering connect, TLS and read; past it the lookup raises `Steam::WebApi::Error` like any other failure. A missing key, or an answer of 401 or 403, raises `Steam::WebApi::BrokenKey` (a subclass of `Error`, so the catalog import still treats it as a failure), and the sign-in reports it through `Rails.error.report`, then goes on with the stored or fallback name. Verify: a stub slow to connect and to answer, each phase under the deadline but together over it, ends at the deadline and the player is signed in with no persona name; a rejected or missing key reports one error and the sign-in succeeds.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `packs/steam/app/clients/steam/web_api.rb` -- add `BrokenKey < Error`; `get` raises it for a missing key and for a 401 or 403 (redacted, no cause, as now); add a `player_summary_deadline` class attribute (5.0, like `retry_interval`, so tests shrink it) and run the summary request under it with `Timeout.timeout(..., Faraday::TimeoutError)` inside `get`'s rescue, so an expired deadline becomes `Error`; drop the summary connection's per-phase timeouts; update the comments (one deadline, broken key), dropping the planning ids of the comment blocks touched.
- [x] `app/controllers/sessions_controller.rb` -- `persona_name` reports a `Steam::WebApi::BrokenKey` with `Rails.error.report` and returns nil; other Steam failures still log a warning; its comment says so.
- [x] `test/support/steam_api_stubs.rb` -- a stub of GetPlayerSummaries slow to connect then slow to answer (two short sleeps, each under the shrunk deadline); `stub_steam_api` saves and restores `player_summary_deadline`.
- [x] `test/packs/steam/web_api_test.rb` -- the slow stub ends at the deadline with `Error` and the answer phase never completes; 401 and 403 and a missing key raise `BrokenKey`, key redacted; the catalog connection's 403 also raises `BrokenKey`; replace the "waits five seconds at most" options test with the deadline default.
- [x] `test/controllers/sessions_controller_test.rb` -- the slow stub signs the player in with no persona name, no error reported; 401, 403 and a missing key each report exactly one `BrokenKey` and the sign-in succeeds keeping the stored name; 403 leaves the "no error reported" failure list.

**Acceptance Criteria:**
- Given Steam slow to connect and slow to answer, each under the deadline but together over it, when a player signs in, then the lookup ends at the deadline, the player is signed in with the stored or fallback name, and nothing is reported.
- Given Steam answers 401 or 403 to the persona lookup, or no key is configured, when a player signs in, then one `Steam::WebApi::BrokenKey` is reported to error tracking, without the key in its message, and the player is signed in with the stored or fallback name.
- Given Steam answers 503 or the connection fails, when a player signs in, then nothing is reported (a warning is logged) and the sign-in goes on, as today.

## Implementation Notes

Oneshot: two small source changes (the client's deadline and key error, the controller's rescue) plus their tests and stub helper, about 100 lines.

- Net::HTTP (net-http 0.9.1, Faraday's adapter) has only per-phase timeouts (open, read per chunk, write); a total deadline needs `Timeout.timeout` around the request. Its exception class is `Faraday::TimeoutError` and it is raised inside `get`'s rescue, so it leaves as a redacted `Steam::WebApi::Error`. The connection is per `WebApi` instance and the controller builds one per sign-in, so an interrupted socket is never reused.
- The deadline is 5 s in total, the bound the old comment promised and the old timeouts broke.
- Decision (settled while planning, unattended; the author may revisit): no boot check of the Steam key in production. A boot check calls Steam, so it would stop a deploy (the Kamal health check, every container restart) whenever Steam is down or slow, or while a rotated key is being replaced, and it would still miss a key revoked after boot. The error reported at each sign-in, through the error tracking that already works, catches a missing key and a key revoked at any time; error tracking groups the repeats into one issue.
- The catalog import shares `get`, so a 401 or 403 there also raises `BrokenKey`; it is an `Error`, so the import jobs' handling is unchanged.
- Built: `get` takes `deadline:` (nil for the catalog calls, so no Timeout there); the three catalog callers now pass their params as an explicit hash, since the new keyword would otherwise swallow them. The existing catalog test for a 403 and the missing-key test now expect `BrokenKey`.
- The deadline tests sleep 80 ms twice under a 100 ms deadline (about 0.1 s each, no real seconds); the answer phase never being reached is the assertion, not a measured duration.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Both deadline tests asserted `phases == [ :connected ]`, so a process descheduled past the deadline during the first 80 ms sleep would leave `phases` empty and fail a working deadline in a loaded parallel run — patched: both now assert `assert_not_includes phases, :answered`, the claim the test makes.
  - `[low]` `[patch]` The missing-key sign-in test covered only a first sign-in (no stored name to keep) and did not assert the redirect — patched: the redirect is asserted, and a second test signs in with a name, then without a key, and keeps "Gabe" with one `BrokenKey` reported.
  - `[low]` `[reject]` A `player_summary_deadline` of 0 runs `Timeout.timeout` unbounded, and the summary connection no longer has per-phase timeouts — only tests set the attribute, always to a positive value; a guard would add a branch for a value nobody sets.
  - `[low]` `[reject]` Execution checkboxes unticked while the plan was in review — the fix is an edit of this plan; ticked at finalization as bookkeeping.

## Verification

**Commands:**
- `bin/rails test test/packs/steam/web_api_test.rb test/controllers/sessions_controller_test.rb` -- expected: all pass, the deadline tests well under a second
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: all pass

## Auto Run Result

- **Summary:** The sign-in persona lookup runs under one total deadline of 5 s (`Steam::WebApi.player_summary_deadline`, `Timeout.timeout` around the request inside `get`'s rescue), replacing the separate 5 s open and read timeouts; an expired deadline is a plain redacted `Steam::WebApi::Error`, logged as a warning. A missing key or a 401/403 answer raises `Steam::WebApi::BrokenKey < Error`, which the sign-in reports through `Rails.error.report` before going on with the stored or fallback name. No boot check of the key (reason in Implementation Notes).
- **Files changed:**
  - `packs/steam/app/clients/steam/web_api.rb` -- `BrokenKey`, the deadline attribute and Timeout in `get`, catalog callers pass explicit params hashes, summary connection without per-phase timeouts, comments updated (planning ids dropped from the blocks touched).
  - `app/controllers/sessions_controller.rb` -- `persona_name` reports a `BrokenKey`.
  - `test/support/steam_api_stubs.rb` -- `stub_slow_player_summary`; the deadline saved and restored.
  - `test/packs/steam/web_api_test.rb` -- deadline default, slow stub cut at the deadline, a timely answer, 401/403/missing key raise `BrokenKey`; the catalog 403 and missing-key tests expect `BrokenKey`.
  - `test/controllers/sessions_controller_test.rb` -- slow Steam signs in with no name and no report; 401, 403 and a missing key each report one `BrokenKey` and keep the stored name (and a first sign-in without a key goes on nameless); 403 left the unreported failure list.
- **Review:** quick lens, 4 findings; 2 patches applied (timing-robust deadline assertion, missing-key test keeping the stored name), 0 deferred, 2 rejected (deadline of 0 never set outside tests; plan checkbox bookkeeping). Patched by verdict: high 0, medium 0, low 2.
- **Follow-up review recommended:** false (no high or medium patched).
- **Verification:** `bin/rails test` 2380 runs, 0 failures; `npm run test:js` 229 tests in 25 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 695 files, no offenses. The deadline tests take about 0.1 s each.
- **Residual risk:** `Timeout.timeout` interrupts Net::HTTP from a timer thread; the connection is built per sign-in so a cut socket is never reused, but an interrupt landing inside a library's ensure block is the known Timeout hazard. A broken key reports once per sign-in until fixed; error tracking groups the repeats.
