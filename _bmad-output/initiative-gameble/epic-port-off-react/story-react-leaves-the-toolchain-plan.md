---
title: 'React leaves the toolchain'
type: 'chore'
ticket: '4'
created: '2026-10-26'
status: 'built'
baseline_revision: '753912c05633dbf70f0c031480d8192c4aa36fd6'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Both screens now run on Stimulus, yet React, react-dom, their types, Turbo Mount (gem and npm), `@vitejs/plugin-react` and its `react()` plugin, `vite_react_refresh_tag`, the `react-jsx` compiler option and the development policy's `'unsafe-inline' 'unsafe-eval'` scripts are still installed and loaded, the architecture's Stack table still lists them, and a few tests, comments and AGENTS.md still speak of islands.

**Approach:** Remove each listed piece (`npm uninstall` for the packages, the Gemfile line and `bundle install --local` for the gem), drop the development script allowances since nothing else needs them (the Vite client and entrypoints are module scripts from `'self'` or the dev server, Mission Control Jobs nonces its inline importmap, and exception pages are rendered outside the policy middleware), delete the Stack rows AD-31 names, drop the tests' negative Turbo Mount assertions, and reword the leftover "island" mentions outside the booster's system test, which the epic keeps as it stands.

</intent-contract>

## Implementation Notes

Oneshot: about forty hand-edited lines across ten files plus the two regenerated lockfiles; every change is a removal or a rewording.

Touch: `package.json` and `package-lock.json` (via `npm uninstall react react-dom turbo-mount @types/react @types/react-dom @vitejs/plugin-react`), `Gemfile` and `Gemfile.lock`, `vite.config.ts`, `tsconfig.json`, `app/views/layouts/_head.html.erb`, `config/initializers/content_security_policy.rb` (and its header comment), `app/views/layouts/application.html.erb:4`, `app/frontend/lib/booster_motion.ts:1`, `test/controllers/packs_controller_test.rb` (`ISLAND` and its three asserts), `test/controllers/back_office/cards_controller_test.rb:32`, `test/system/settings_test.rb:9` (comment), `AGENTS.md` (project description), `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` (Stack rows: React, Turbo Mount, turbo-mount npm, react-dom, `@types/react`/`@types/react-dom`, `@vitejs/plugin-react`).

Leave: `test/system/booster_test.rb` (its comment and test name say "island"; the epic keeps the file unchanged), `test/lib/post_deploy_hook_test.rb` (sample commit subjects), history under `_bmad-output`.

- Built as planned. `npm uninstall` removed react, react-dom, scheduler, csstype, turbo-mount, `@types/react`, `@types/react-dom` and `@vitejs/plugin-react` from `package-lock.json`; it also renames the lockfile's root `name` to the checkout's folder (package.json has no `name`), so that line was put back to `gameble` (`bin/setup`'s `npm install` in `bin/ci` does the same in a worktree). `bundle install --local` dropped turbo-mount from `Gemfile.lock` (spec, dependency, checksum).
- Development script policy: `'unsafe-inline' 'unsafe-eval'` dropped, the Vite host kept. Checked live: a development server with `bin/vite dev` served `script-src 'self' http://localhost:3136`, and headless Chromium loaded `/en/how-it-works` with the Vite client connected and no refused script. Mission Control Jobs nonces its inline importmap per request; the Rails and web-console exception pages are rendered by middleware outside the policy's, so they carry no policy.
- `packs_controller_test.rb`'s `ISLAND` and the back-office card catalogue's Turbo Mount check only guarded against a React island; removed with Turbo Mount.
- AGENTS.md: the islands sentence is gone and the stack reads "Stimulus controllers on every screen"; the rule against React stays.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Without `'unsafe-inline'`, web-console's in-view `console` script is refused in development: development nonced no directive, and the helper tags its inline script with the request's nonce — development now nonces `script-src` (styles stay un-nonced, Vite injects them inline); checked live: the header carries `'nonce-…'` on `script-src`, the Vite client connects and no script is refused.

### 2026-10-27 — Author decisions
- Accepted: development `script-src` carries a nonce in place of `'unsafe-inline'` and `'unsafe-eval'`, keeping web-console's in-view console.
- Asked: rename the remaining "island" wording in `test/system/booster_test.rb` (a comment and a test name) in the refactor sweep.

## Verification

Run from the worktree with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react CHROME_BIN=/usr/bin/chromium`; system test files one at a time; `git checkout db/schema.rb` if a run rewrites it.

**Commands:**
- `rtk proxy grep -n -E '"(react|react-dom|@types/react|@types/react-dom|turbo-mount|@vitejs/plugin-react)"|node_modules/(react|react-dom|@types/react|@types/react-dom|turbo-mount|@vitejs/plugin-react)"' package.json package-lock.json; grep -n turbo-mount Gemfile.lock` -- expected: no match.
- `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_markup_apis`, `npm run build` or `bin/vite build` -- expected: pass.
- `bin/rails test test/integration/content_security_policy_test.rb test/controllers/packs_controller_test.rb test/controllers/back_office/cards_controller_test.rb` -- expected: pass.
- `bin/rails test test/system/<file>.rb` for `booster`, `booster_screen`, `trade_board`, `trades`, `card_preview`, one at a time -- expected: pass.

## Auto Run Result

**Summary:** React leaves the toolchain. Removed react, react-dom, `@types/react`, `@types/react-dom`, turbo-mount and `@vitejs/plugin-react` (npm), the turbo-mount gem, Vite's `react()` plugin, `vite_react_refresh_tag`, the `react-jsx` compiler option and the development policy's `'unsafe-inline' 'unsafe-eval'` scripts (development nonces scripts instead, for web-console), the six Stack rows, the tests' Turbo Mount guards and the "island" wording outside the booster's system test.

**Files changed:**
- `package.json`, `package-lock.json` — the six packages and their own dependencies (scheduler, csstype) gone; root `name` kept `gameble`.
- `Gemfile`, `Gemfile.lock` — turbo-mount gone.
- `vite.config.ts`, `tsconfig.json`, `app/views/layouts/_head.html.erb` — React plugin, `jsx` option and refresh tag gone.
- `config/initializers/content_security_policy.rb` — development scripts: Vite host only, nonced.
- `test/controllers/packs_controller_test.rb`, `test/controllers/back_office/cards_controller_test.rb` — Turbo Mount assertions gone.
- `app/views/layouts/application.html.erb`, `app/frontend/lib/booster_motion.ts`, `test/system/settings_test.rb` — comments without islands or React.
- `AGENTS.md` — the islands sentence gone; the rule against React kept.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` — Stack rows for React, Turbo Mount, turbo-mount, react-dom, the React types and `@vitejs/plugin-react` gone.

**Review:** quick lens, 1 finding (low, patched: web-console's in-view console in development). Nothing deferred or rejected.

**Follow-up review recommended: false** (patched: high 0, medium 0, low 1).

**Verification:**
- No match for the six package names in `package.json`/`package-lock.json`, nor turbo-mount in `Gemfile.lock`.
- `bin/ci` passed twice (3201 runs, 0 failures; rubocop, packwerk, i18n-tasks missing, typecheck, `script/check_markup_apis`, bundler-audit, brakeman, schema build and round trip, seeds). `npm run test:js`: 64 files, 708 tests. `bin/rails zeitwerk:check` clean. `RAILS_ENV=test bin/vite build --force` built.
- System tests, one file at a time: `booster` 43, `booster_screen` 6, `trade_board` 2, `trades` 13, `card_preview` 5, `settings` 13 — 0 failures.
- Development live check: `bin/vite dev` and `bin/rails server`, headless Chromium on `/en/how-it-works`: Vite client connected, no refused script.

**Residual risks:** `test/system/booster_test.rb` still says "island" in a comment (line 45) and a test name (line 655), left because the epic keeps that file unchanged; `test/lib/post_deploy_hook_test.rb` mentions "booster island" in sample commit subjects (data, left).

