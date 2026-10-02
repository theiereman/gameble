---
title: 'Locales and layout shell'
type: 'feature'
ticket: '4'
created: '2026-10-02'
status: done
baseline_revision: 'debfd316530ca133d6082065af3c47efe4a5e4d7'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The app answers in English only, at `/`, with a bare placeholder page. AD-18 requires every page in French and English with the locale as the first URL segment, and AD-16 with DESIGN.md requires a shared layout with the status band, the design tokens as CSS custom properties, the Jost typeface and the base view components.

**Approach:** Put every page route under a required `/:locale` segment (`fr` or `en`). `/` redirects to the locale that best matches the browser's `Accept-Language`, falling back to English. Build the application layout with a status band placeholder, the DESIGN.md tokens, self-hosted Jost, and two ViewComponents (text plate, button). Move all copy into `config/locales/en.yml` and `fr.yml`, and make CI check both.

## Boundaries & Constraints

**Always:**
- Gem versions: `view_component ~> 4.15.0` (Stack table); `http_accept_language ~> 2.1.1`, a new dependency, added to the architecture Stack table (AD-20).
- Every interface string comes from the locale files, in both languages, in the Brotherhood tone (`brotherhood-tone.md`). `<html lang>` matches the locale.
- `/up` stays outside the locale scope. Links built with route helpers carry the current locale.
- Every color, typography and spacing token of DESIGN.md's frontmatter becomes a CSS custom property, named after its token path (`--color-ink`, `--space-3`, `--font-size-body`, `--plate-padding-y`). Components use the properties, never raw values.
- Square corners, hard ink shadow one unit down-right, no blur; visible focus outline in `--color-ink` (EXPERIENCE.md accessibility floor).
- Jost is served from files committed in the repository (latin and latin-ext variable woff2, with its OFL licence).

**Never:**
- No remembered language choice (cookie or player setting): the settings screen comes later. No language switcher.
- No sign-in button, gauge or counters in the status band: it is an empty, labelled placeholder until later stories fill it.
- No Stimulus, Turbo, TypeScript or React (story 1.5). No attic page or room art (story 1.8).
- No font loaded from a third-party host.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| French shell | `GET /fr` | 200; `<html lang="fr">`; French title and copy; the status band and the main region | No error expected |
| English shell | `GET /en` | 200; `<html lang="en">`; English title and copy | No error expected |
| First visit, French browser | `GET /` with `Accept-Language: fr-FR,fr;q=0.9,en;q=0.8` | redirect to `/fr` | No error expected |
| First visit, English preferred | `GET /` with `Accept-Language: en-US,en;q=0.9,fr;q=0.5` | redirect to `/en` | No error expected |
| Unsupported or absent language | `GET /` with `Accept-Language: de-DE` or no header | redirect to `/en` | Fallback to the default locale |
| Unknown locale segment | `GET /de` | 404 | Standard Rails 404 |
| Health check | `GET /up` | 200 | Unchanged |

</intent-contract>

## Code Map

- `config/routes.rb` -- today: `root "pages#home"` and `/up`. Rails 8.1 test env renders 404 for unmatched routes (`show_exceptions = :rescuable`).
- `app/controllers/application_controller.rb` -- only `allow_browser versions: :modern`, which lets requests with no user agent through, so integration tests need none.
- `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb` -- placeholder page with hard-coded English copy.
- `app/views/layouts/application.html.erb` -- generated layout with Vite tags (`vite_client_tag`, `vite_stylesheet_tag "application.css"`, `vite_javascript_tag "application"`); `<html>` has no `lang`.
- `app/frontend/entrypoints/application.css` -- Vite stylesheet entrypoint; Vite resolves `@import` and `url()` relative to it (`sourceCodeDir: app/frontend`).
- `test/controllers/pages_controller_test.rb` -- asserts on `root_path`, `h1 == "gameble"` and hashed Vite asset paths (`/vite-test/assets/application-*.js|css`); update it to the localized routes.
- `config/locales/en.yml` -- generated, with an unused `hello` key; replace with the app's keys.
- `config/i18n-tasks.yml` -- `locales: [en]` with a comment that story 1.4 adds `fr`.
- `config/environments/{test,development}.rb` -- `raise_on_missing_translations = true` (story 1.3), so a missing key fails tests.
- `config/application.rb` -- set `config.i18n.available_locales = %i[en fr]` and `config.i18n.default_locale = :en` here.
- `test/lib/application_operation_test.rb` -- swaps `I18n.backend` in one test; unaffected.
- Font files, already downloaded (fontsource `@fontsource-variable/jost` 5, unicode ranges latin and latin-ext): `/tmp/claude-1000/-home-teyermann-projets-gameble/efe994fb-0e36-41bf-a9e2-ccabe7633861/scratchpad/jost.woff2` (latin), `.../jost-ext.woff2` (latin-ext), `.../OFL.txt`.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` -- Stack table; add the `http_accept_language` row.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock` -- add `view_component` and `http_accept_language` at runtime with a comment and link -- components and browser language
- [x] `config/application.rb` -- available locales `en`, `fr`; default `en` -- one source for the locale list
- [x] `config/routes.rb` -- `scope ":locale", locale: /en|fr/` holding the home page as the localized root; `/` routed to an action that redirects -- locale is the first segment
- [x] `app/controllers/application_controller.rb` -- `around_action` that sets the locale from `params[:locale]`; `default_url_options` carrying it -- every request runs in its URL's locale
- [x] `app/controllers/locales_controller.rb` -- action `redirect`: redirect `/` to the best `Accept-Language` match among the available locales, else the default -- first visit follows the browser
- [x] `app/frontend/fonts/jost-latin.woff2`, `jost-latin-ext.woff2`, `OFL.txt` -- copy the downloaded files -- the font lives in the repository
- [x] `app/frontend/styles/tokens.css` -- every DESIGN.md token as a custom property on `:root`, plus `--shadow-hard` -- AD-16
- [x] `app/frontend/styles/fonts.css` -- `@font-face` for Jost (weights 100–900, `font-display: swap`, unicode ranges from fontsource) -- self-hosted typeface
- [x] `app/frontend/entrypoints/application.css` -- import tokens and fonts; base styles: `body` on `--color-bg` in Jost body size and `--color-ink`; status band; focus outline -- the shell's look
- [x] `app/views/layouts/application.html.erb` -- `lang` attribute, translated title, a `<header>` status band placeholder with a gauge region at left and a counters region at right (each empty, with a translated `aria-label`), then `<main>` -- the shared shell
- [x] `app/components/text_plate_component.rb` (+ template) -- text on `--color-surface`, ink border, plate padding, optional tag -- DESIGN.md text plate
- [x] `app/components/button_component.rb` (+ template) -- `variant: :primary | :secondary`, renders a link when given `href`, else a `<button>`; rust or parchment fill, ink border, hard shadow -- DESIGN.md buttons
- [x] `app/views/pages/home.html.erb` -- translated welcome copy that uses both components, one button of each variant pointing at the current page -- the shell visibly exercises its parts
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- all keys in both languages, Brotherhood tone -- AD-18
- [x] `config/i18n-tasks.yml` -- `locales: [en, fr]` -- CI fails on a key missing in either
- [x] `test/controllers/pages_controller_test.rb`, `test/controllers/locales_controller_test.rb`, `test/components/text_plate_component_test.rb`, `test/components/button_component_test.rb` -- every matrix row, the components' variants, and the existing Vite asset assertions on `/en` -- proof
- [x] `architecture-gameble.md` -- Stack row `http_accept_language | 2.1.1` -- AD-20

**Acceptance Criteria:**
- Given a browser at `/fr` or `/en`, when the page renders, then it uses Jost from the app's own assets, the parchment background and ink text, and the status band shows above the main region.
- Given the locale files, when `bundle exec i18n-tasks missing` runs, then no key is missing in `en` or `fr`; removing one French key makes it fail.
- Given the whole suite, when `bin/rails test`, Packwerk, RuboCop and zeitwerk run, then all pass.

## Implementation Notes

- Component styles (status band, text plate, buttons) live in `application.css` beside the base styles; ViewComponent sidecar CSS is not bundled by Vite.
- Typography tokens become `--font-family-*`, `--font-weight-*`, `--font-size-*`, `--line-height-*` per token name; `rounded.DEFAULT` becomes `--rounded`; `spacing.unit` becomes `--space-unit`. A helper `--font-family-base` holds the Jost stack the per-token families point at.
- `default_url_options` adds `locale` to every helper, so a helper for a route outside the scope (e.g. `rails_health_check_path`) gains `?locale=..`; harmless, noted for later stories.
- Vite also emits `OFL.txt` into the build output (everything under `app/frontend/fonts` is an asset); the licence travelling with the font is acceptable.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `switch_locale` passed any `locale` query value to `I18n.with_locale`, so `GET /?locale=de` or `/?locale[]=fr` raised `I18n::InvalidLocale` (500) — the param is now used only when it is a string among the available locales, else the default; a test shows both requests redirect to `/en`.

## Design Notes

English is the fallback because it is the more widely read of the two for a browser that asks for neither. Matching uses `http_accept_language`'s `compatible_language_from(I18n.available_locales)` so `fr-CA` maps to `fr` and q-values are honoured.

Example route shape:

```ruby
scope ":locale", locale: /en|fr/ do
  root "pages#home", as: :home
end
root "locales#redirect"
```

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `bundle exec i18n-tasks missing` -- expected: none missing in en and fr
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: no offenses
- `bin/rubocop` -- expected: no offenses
- `bin/rails zeitwerk:check` -- expected: all is good
- `bin/vite build` -- expected: builds, with the two woff2 files in the output

**Manual checks (if no CLI):**
- After `bin/vite build`, the built CSS's `@font-face` URLs point to the hashed woff2 files of the build output.

## Auto Run Result

**Summary:** Every page lives under `/fr` or `/en`; `/` redirects to the browser's best match, falling back to English. The layout carries `lang`, a translated title, an empty labelled status band and the main region. DESIGN.md tokens are CSS custom properties, Jost is self-hosted, and the text plate and button ViewComponents exist. All copy is in `en.yml` and `fr.yml` in the Brotherhood tone, and CI checks both.

**Files changed:**
- `Gemfile`, `Gemfile.lock`, `architecture-gameble.md` -- view_component 4.15.0, http_accept_language 2.1.1 (added to the Stack table)
- `config/application.rb`, `config/routes.rb` -- locales and the `/:locale` scope
- `app/controllers/application_controller.rb`, `app/controllers/locales_controller.rb` -- locale per request, `/` redirect
- `app/frontend/fonts/*`, `app/frontend/styles/{tokens,fonts}.css`, `app/frontend/entrypoints/application.css` -- Jost, tokens, base and component styles
- `app/views/layouts/application.html.erb`, `app/views/pages/home.html.erb` -- the shell and a home page that uses both components
- `app/components/{text_plate,button}_component.*` -- DESIGN.md components
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- copy in both languages, both checked
- `test/controllers/*`, `test/components/*` -- matrix rows and component variants

**Review findings:** 1 patch applied (medium); 0 deferred; 0 rejected.

**Follow-up review recommended:** false — one medium patch.

**Verification:** `bin/rails test` (24 runs, 0 failures), `i18n-tasks missing` (none; removing a French key made it fail), Packwerk, RuboCop, zeitwerk and Brakeman clean, `bin/vite build` emits both hashed woff2 files.

**Residual risks:** The page has not been looked at in a browser. The `/` redirect sends no `Vary: Accept-Language`, so a cache in front (Cloudflare) could serve one language's redirect to everyone; set it when the edge cache is configured. Links built for routes outside the locale scope gain a `?locale=` query.
