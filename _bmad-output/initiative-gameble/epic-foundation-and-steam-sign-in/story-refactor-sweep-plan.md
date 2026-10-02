---
title: 'Refactor sweep'
type: 'refactor'
ticket: '10'
created: '2026-10-02'
status: 'built'
baseline_revision: 'ace780f012383a46b317c617f41973107f6bb6e9'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/deferred-work.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The epic closes with work recorded but not done. No plan of stories 1.2 to 1.9 carries a deferred review finding, but `deferred-work.md` holds three items from story 1.1, and the build records list residual risks. Two of them are code fixable now: the Dockerfile installs no Node, so `assets:precompile` (which runs the Vite build) fails and no production image can be built; and the `/` redirect varies by `Accept-Language` without saying so, so an edge cache could serve one language's redirect to everyone.

**Approach:** Install Node from `.tool-versions` in the Docker build stage, run `npm ci` before `assets:precompile`, and keep `node_modules` out of the final image; keep planning folders and build output out of the Docker context. Send `Vary: Accept-Language` on the `/` redirect. Close the CI-Node item (done in story 1.2) and record in `deferred-work.md` every remaining item that needs the production deployment, so each one is either fixed or recorded.

</intent-contract>

## Implementation Notes

Oneshot: a Dockerfile change, one header, and bookkeeping.

- Dockerfile: the build stage downloads Node 24.15.0 from nodejs.org (x64 or arm64, `xz-utils` added), runs `npm ci` after copying `package.json` and `package-lock.json`, and removes `node_modules` after `assets:precompile`. `docker build` succeeds; the image (589 MB) holds `public/vite/assets` and no `node_modules`.
- `.dockerignore`: Vite build output and the planning and agent folders (`_bmad`, `_bmad-output`, `.agents`, `.claude`) stay out of the build context.
- `LocalesController#redirect` sends `Vary: Accept-Language`; a test asserts it.
- `deferred-work.md`: the Dockerfile and CI-Node items are marked resolved; six items that need the production deployment are recorded (Cloudflare real IP for the throttle, TLS behind the proxy, the author's production checks, the ruby-openid internal patch, nonce store atomicity, `?locale=` on unscoped routes).
- Found while running `bin/ci`: `test/integration/rate_limit_test.rb` failed about one run in eight, because Rack::Attack counts in windows aligned on the clock minute and a test crossing a boundary restarted the count. The setup now freezes the clock five seconds into a minute; 15 runs of the file and 5 of the suite passed.
- Also found while running `bin/ci`: with Vite `autoBuild` in test, the 12 parallel workers could each rebuild the assets, one emptying `public/vite-test` while another read the manifest ("can't find entrypoints/application.css in the manifests"). The same race would hit GitHub CI on a cold build. `test/test_helper.rb` now builds once in the parent process before the workers fork. With `public/vite-test` removed first, `bin/rails test` passed 3 times and `bin/ci` passed 3 times in a row.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `assets:precompile` ran vite_ruby's own `npm ci`, which deleted and reinstalled the packages the cached layer had just installed — `VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL=true` on the precompile step.
  - `[low]` `[patch]` The Dockerfile hard-coded Node 24.15.0 instead of reading `.tool-versions` as the intent says, so a bump there would leave the image behind CI — the build stage copies `.tool-versions` and reads the `nodejs` version from it.
  - `[low]` `[patch]` The `Vary` assignment replaced any existing value and its comment claimed it protects against Cloudflare, which ignores `Vary: Accept-Language` — the header is appended, the comment corrected, and the Cloudflare cache rule recorded in `deferred-work.md`.
  - `[low]` `[patch]` A failed Vite build in `test_helper.rb` aborted with no cause on the console — the message now points to `log/test.log`.

## Verification

**Commands:**
- `docker build -t gameble-sweep .` -- expected: the image builds, including `assets:precompile`
- `docker run --rm gameble-sweep ls public/vite/assets` and `... test ! -d node_modules` -- expected: built assets present, no `node_modules`
- `bin/rails test` -- expected: all green, including the `Vary` assertion
- `bin/ci` -- expected: every local CI step passes

## Auto Run Result

**Summary:** The epic's open items are fixed or recorded. The production image now builds (Node from `.tool-versions` in the build stage, Vite assets precompiled, no `node_modules` at runtime). The `/` redirect declares `Vary: Accept-Language`. Two intermittent test failures found by `bin/ci` are fixed: the rate-limit tests crossing a minute boundary, and parallel workers racing on the Vite test build. `deferred-work.md` marks the two Node items resolved and records seven deployment-bound items.

**Files changed:**
- `Dockerfile`, `.dockerignore` -- Node and `npm ci` in the build stage; smaller build context
- `app/controllers/locales_controller.rb`, `test/controllers/locales_controller_test.rb` -- `Vary: Accept-Language`
- `test/test_helper.rb` -- one Vite build before the workers fork
- `test/integration/rate_limit_test.rb` -- clock frozen inside a minute
- `_bmad-output/initiative-gameble/deferred-work.md` -- resolved and recorded items

**Review findings:** 4 patches applied (4 low); 0 deferred; 0 rejected.

**Follow-up review recommended:** false — low patches only.

**Verification:** `docker build` succeeds (image holds 8 built Vite assets, no `node_modules`, no planning folders); `bin/ci` passed on every run after the fixes (6 runs, every step green); system tests 5 runs, 0 failures.

**Residual risks:** Every deferred item left needs the production deployment (see `deferred-work.md`). The GitHub Actions workflow itself has still never run: nothing is pushed.
