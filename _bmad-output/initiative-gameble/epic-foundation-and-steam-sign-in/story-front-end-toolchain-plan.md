---
title: 'Front-end toolchain'
type: 'feature'
ticket: '5'
created: '2026-10-02'
status: 'built'
baseline_revision: '4f19c8fa155169d33e46ed6aba7f65ac6e561344'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The app has a plain JavaScript Vite entrypoint and nothing else. AD-16 needs Hotwire (Turbo, Stimulus) for server-rendered pages and React islands in TypeScript mounted with Turbo Mount, each receiving its data and translated strings as props. Without the toolchain no island can be built.

**Approach:** Install Turbo, Stimulus, Turbo Mount, React and TypeScript under Vite; turn the entrypoint into TypeScript; auto-register Stimulus controllers; mount one sample React component on the home page whose data and strings come from Rails as props; add a TypeScript type check to CI and a system test that sees the component rendered in each locale.

## Boundaries & Constraints

**Always:**
- Versions from the Stack table: `turbo-rails ~> 2.0.23`, `stimulus-rails ~> 1.3.4`, `turbo-mount ~> 0.4.4` (gems); npm `@hotwired/turbo-rails` 8.0.23, `@hotwired/stimulus` 3.2.2, `turbo-mount` 0.4.4, `react` and `react-dom` 19.3.0, `typescript` 7.0.2, with `@types/react`, `@types/react-dom` 19.3.0, `@vitejs/plugin-react` 6.1.1 and `stimulus-vite-helpers` 3.1.0. Add each npm package and gem that is not yet in the architecture Stack table to it (AD-20).
- TypeScript is strict; front-end source files are `.ts` or `.tsx`.
- The sample component gets everything through props: its data and every visible string, translated by Rails from `en.yml` / `fr.yml` (AD-16, AD-18). It holds no hard-coded copy and no client-side fetching.
- The page keeps working (renders its server copy) with JavaScript off; the island is an addition.
- The type check runs in CI and in local `bin/ci`.

**Never:**
- No importmap, no jsbundling, no `rails turbo:install` / `stimulus:install` generators (they target importmap or jsbundling and would rewrite the layout).
- No client-side router or global store. No real game island (pack reveal, trade board) yet.
- No change to the layout's structure beyond what loading the entrypoint requires.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Island in French | browser opens `/fr` | the sample component renders its French strings and its data value | No error expected |
| Island in English | browser opens `/en` | the sample component renders its English strings and its data value | No error expected |
| Props from the server | `GET /fr` without JavaScript | the mount element carries the component name and JSON props holding the French strings and the data | No error expected |
| Type error | a `.tsx` file with a type error | `npx tsc --noEmit` exits non-zero | CI fails |

</intent-contract>

## Code Map

- `app/frontend/entrypoints/application.js` -- one comment line today; becomes `application.ts`. `vite_javascript_tag "application"` in the layout resolves either extension.
- `vite.config.ts` -- `RubyPlugin()` only; add `@vitejs/plugin-react`.
- `config/vite.json` -- `sourceCodeDir: app/frontend`; test `autoBuild: true` (`public/vite-test`).
- `package.json` -- `vite` and `vite-plugin-ruby` as devDependencies, `"type": "module"`, a `package-lock.json` exists (CI uses `npm ci`).
- `app/views/layouts/application.html.erb` -- Vite tags in `<head>`; status band and `<main>` from story 1.4.
- `app/views/pages/home.html.erb` -- uses `TextPlateComponent` and `ButtonComponent`; add the island here.
- `config/locales/{en,fr}.yml` -- keys under `pages.home`; i18n-tasks checks both locales, and `raise_on_missing_translations` is on in test.
- `test/controllers/pages_controller_test.rb` -- asserts Vite tags on `/en` with hashed asset names under `/vite-test/assets/application-*.js`.
- System tests -- `test/application_system_test_case.rb` and `test/system/` do not exist; Capybara and selenium-webdriver are in the Gemfile test group. Locally Chromium is at `/usr/bin/chromium` and no `google-chrome` exists; the GitHub runner has Chrome.
- `.github/workflows/ci.yml` -- the `test` job has Node and `npm ci`; the `system-test` job has Node and runs `bin/rails db:test:prepare test:system`. `config/ci.rb` lists local steps.
- Turbo Mount -- gem helper `turbo_mount("Name", props: {...})` renders the mount element; JS side: `new TurboMount()` and `registerComponent(turboMount, "Name", Component)` from `turbo-mount/react` (it runs on Stimulus). Read the installed gem's README for the exact API before wiring.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock` -- add `turbo-rails`, `stimulus-rails`, `turbo-mount` -- Rails helpers
- [x] `package.json`, `package-lock.json` -- add the npm packages of the Always list (runtime ones as dependencies, types, TypeScript and the Vite plugin as devDependencies); a `typecheck` script running `tsc --noEmit` -- one install
- [x] `tsconfig.json` -- strict, `jsx: react-jsx`, bundler module resolution, `noEmit`, Vite client types, includes `app/frontend` -- type check scope
- [x] `vite.config.ts` -- add the React plugin -- JSX transform
- [x] `app/frontend/entrypoints/application.ts` (replacing `.js`) -- import Turbo, start Stimulus, register controllers from `app/frontend/controllers/**/*_controller.ts`, create Turbo Mount and register the sample component -- one entrypoint
- [x] `app/frontend/controllers/.keep` -- the folder Stimulus controllers will live in
- [x] `app/frontend/components/SampleIsland.tsx` -- typed props `{ data: { season: number }, strings: { heading: string; season: string } }`, renders the heading and the season label with the number -- the sample island
- [x] `app/views/pages/home.html.erb`, `config/locales/{en,fr}.yml` -- mount `SampleIsland` with `data: { season: 1 }` and its strings from new `pages.home.island.*` keys, Brotherhood tone -- props from Rails
- [x] `test/application_system_test_case.rb` -- headless Chrome through Selenium; when `CHROME_BIN` is set, use it as the browser binary -- runs locally with Chromium and on the runner with Chrome
- [x] `test/system/sample_island_test.rb` -- the two browser rows of the matrix -- the island really renders
- [x] `test/controllers/pages_controller_test.rb` -- the server-props row -- props without a browser
- [x] `.github/workflows/ci.yml`, `config/ci.rb` -- `npm run typecheck` step in the test job and in local CI -- type errors fail CI
- [x] `architecture-gameble.md` -- Stack rows for the packages not yet listed -- AD-20

**Acceptance Criteria:**
- Given `bin/dev`, when a browser opens `/fr` then `/en`, then the sample island shows its strings in each language, and following the home page's own button (a Turbo visit) leaves it mounted once.
- Given a deliberate type error in a `.tsx` file, when `npm run typecheck` runs, then it fails; reverted, it passes.
- Given the suite, when `bin/rails test`, `CHROME_BIN=/usr/bin/chromium bin/rails test:system`, Packwerk, RuboCop and i18n-tasks run, then all pass.

## Implementation Notes

- Turbo Mount types `registerComponent` as taking `ComponentType` (no props), so a component with required props does not type-check against it. `application.ts` wraps each island in a one-line `island()` helper that widens the type at the registration boundary; the island's own props type stays the contract inside the component.
- `stimulus-vite-helpers` is imported at runtime by the entrypoint, so it is a dependency, not a devDependency.
- The mount element is empty without JavaScript; the home page's server copy (heading, intro, buttons) renders regardless.
- System tests: a third test follows "Report for duty" and checks a window marker survives (a Turbo visit, not a full load) and the island is mounted once.

## Plan Change Log

- Layout: `vite_javascript_tag "application"` does not resolve `application.ts` (Vite Ruby appends `.js`); replaced with `vite_typescript_tag "application"`. Added `vite_react_refresh_tag` after `vite_client_tag`, which `@vitejs/plugin-react` needs in development (no-op in test/production). Both are what loading the entrypoint requires; the layout structure is unchanged.

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The Turbo visit system test counted the island right after the click, so the old page satisfied it before the visit rendered — the test now counts `turbo:load` events onto `body[data-turbo-loads]`, waits for the new render, then asserts one island and the surviving marker.

## Verification

**Commands:**
- `npm ci && npm run typecheck` -- expected: no type error
- `bin/vite build` -- expected: builds
- `bin/rails test` -- expected: all green
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- expected: all green
- `bundle exec i18n-tasks missing` -- expected: none missing
- `bundle exec packwerk check && bin/rubocop && bin/rails zeitwerk:check` -- expected: clean

## Auto Run Result

**Summary:** Turbo, Stimulus (controllers auto-registered from `app/frontend/controllers`), Turbo Mount and React 19 run under Vite with a strict TypeScript entrypoint. A sample island on the home page gets its data and translated strings from Rails as props and renders in French and English. CI and local `bin/ci` run `npm run typecheck`; system tests drive headless Chrome (or `CHROME_BIN`).

**Files changed:**
- `Gemfile`, `Gemfile.lock`, `package.json`, `package-lock.json`, `architecture-gameble.md` -- turbo-rails, stimulus-rails, turbo-mount gems; Hotwire, Turbo Mount, React, TypeScript npm packages; Stack rows
- `tsconfig.json`, `vite.config.ts` -- strict type check, React plugin
- `app/frontend/entrypoints/application.ts` (replaces `.js`), `app/frontend/controllers/.keep`, `app/frontend/components/SampleIsland.tsx` -- the toolchain and the sample island
- `app/views/layouts/application.html.erb` -- `vite_typescript_tag` and `vite_react_refresh_tag`
- `app/views/pages/home.html.erb`, `config/locales/{en,fr}.yml` -- the island mounted with props
- `test/application_system_test_case.rb`, `test/system/sample_island_test.rb`, `test/controllers/pages_controller_test.rb` -- browser and server-props tests
- `.github/workflows/ci.yml`, `config/ci.rb` -- type check step

**Review findings:** 1 patch applied (medium); 0 deferred; 0 rejected.

**Follow-up review recommended:** false — one medium patch.

**Verification:** `npm run typecheck` (clean; a deliberate type error failed it), `bin/vite build`, `bin/rails test` (25 runs, 0 failures), `CHROME_BIN=/usr/bin/chromium bin/rails test:system` (3 runs, 0 failures), i18n-tasks, Packwerk, RuboCop, zeitwerk clean. The implementer also drove `bin/dev`-style servers in a browser: the island renders in both locales and survives a Turbo visit.

**Residual risks:** The CI system-test job has not run on GitHub's Chrome yet. Turbo Mount's types force a cast at registration, so props JSON is not checked against the island's type at runtime. A running `bin/dev` must be restarted to pick up the new gems and packages.
