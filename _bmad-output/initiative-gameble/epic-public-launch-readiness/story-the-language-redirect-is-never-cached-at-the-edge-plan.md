---
title: 'The language redirect is never cached at the edge'
type: 'bugfix'
ticket: '26'
created: '2026-10-13'
status: done
baseline_revision: '769b063f4b7d94d2d901e04e86b9fac1100523d6'
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

**Problem:** `LocalesController#redirect` answers "/" with a redirect whose target depends on `Accept-Language`, and marks it only with `Vary: Accept-Language`; Cloudflare's cache ignores `Vary`, so if the redirect were ever cached at the edge every visitor would be sent to the first visitor's language.

**Approach:** The root redirect also sends `Cache-Control: private, no-store`, so no shared cache (Cloudflare included) stores it, and keeps `Vary: Accept-Language`. Verify: the root redirect answers with `Cache-Control: private, no-store` and `Vary: Accept-Language`; a French and an English browser each land on their own locale.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/locales_controller.rb` -- set the response's cache control to private and no-store (Rails renders `private, no-store` from `response.cache_control` `private: true, no_store: true`; its `no_store` helper alone renders only `no-store`), keep the `Vary: Accept-Language` merge, and replace the two-line comment pointing at deferred-work.md with one line naming the external constraint (Cloudflare's cache ignores `Vary`).
- [x] `test/controllers/locales_controller_test.rb` -- the redirect answers `Cache-Control: private, no-store` (exact directives) along with `Vary: Accept-Language`, for a French and for an English browser, each still landing on its own locale.

**Acceptance Criteria:**
- Given a browser preferring French, when it requests "/", then it is redirected to "/fr" and the response carries `Cache-Control: private, no-store` and `Vary: Accept-Language`.
- Given a browser preferring English, when it requests "/", then it is redirected to "/en" with the same two headers.

## Implementation Notes

Oneshot: a header on one action plus its tests. "/" is the only response chosen from `Accept-Language` (`LocalesController` is the only reader of `http_accept_language`); every other page carries its locale in the URL, so no other response needs this.

Built: `LocalesController#redirect` calls a private `keep_out_of_shared_caches`, which replaces the response's cache control with `private: true, no_store: true` (Rails renders `private, no-store`) and keeps the `Vary: Accept-Language` merge; its one-line comment names Cloudflare's ignored `Vary`. One test replaces the old Vary-only test and asks, for a French and an English browser, that each lands on its own locale with exactly the `no-store` and `private` directives and `Vary: Accept-Language`. Files: `app/controllers/locales_controller.rb`, `test/controllers/locales_controller_test.rb`.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The older test "the redirect tells caches it depends on the browser language" duplicated the new test's French `Vary` assertion — deleted it; the new test asserts `Vary` for both a French and an English browser.

## Verification

**Commands:**
- `bin/rails test test/controllers/locales_controller_test.rb` -- expected: all pass
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: all pass

## Auto Run Result

- **Summary:** the root redirect to a locale now answers with `Cache-Control: private, no-store` along with `Vary: Accept-Language`, so no shared cache, Cloudflare included, stores a redirect chosen from one visitor's language; a French and an English browser each still land on their own locale.
- **Files changed:**
  - `app/controllers/locales_controller.rb` -- a private `keep_out_of_shared_caches` sets the cache control to private, no-store and merges `Vary: Accept-Language`; one-line comment on Cloudflare ignoring `Vary`.
  - `test/controllers/locales_controller_test.rb` -- a French and an English browser each land on their locale with exactly `no-store` and `private` and `Vary: Accept-Language`; the older Vary-only test it covers is removed.
- **Review:** quick lens, 1 finding; 1 patch applied (duplicate test removed), 0 deferred, 0 rejected. Patched by verdict: high 0, medium 0, low 1.
- **Follow-up review recommended:** false (no high or medium patched).
- **Verification:** `bin/rails test` 2361 runs, 0 failures; `npm run test:js` 225 tests in 24 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 693 files, no offenses.
- **Residual risk:** none known in code; whether Cloudflare's cache rules (once set up) honour `no-store` on this path is checked at the edge when production goes up.
