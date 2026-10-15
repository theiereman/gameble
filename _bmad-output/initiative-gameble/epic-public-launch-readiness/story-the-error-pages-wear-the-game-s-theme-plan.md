---
title: 'The error pages wear the game''s theme'
type: 'feature'
ticket: '54'
created: '2026-10-15'
status: done
baseline_revision: 'bac8e2dac9ba292460870f3c9a272853e3985529'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The five static error pages in `public/` (400, 404, 406 unsupported browser, 422, 500) are still Rails' defaults: white, Rails' own illustration and English copy, nothing that reads as gameble.

**Approach:** Redraw them in the space terminal theme (dark ground, starfield, the gold wordmark, VT323 and Space Mono, square corners) with the app's plain voice and a link back to the home page, one file per page and locale, served in the request's language; they stay static files in `public/` that load only files from `public/`, with no inline style or script and no Vite asset.

**Decisions (author, 2026-10-15):**
- One file per locale (`404.fr.html`, `404.en.html`…). The language is the path's first segment when it is a known locale, else the browser's `Accept-Language` as the redirect of `/` reads it, else the default locale. The exception pages and the 406 page both follow it.
- A script copies the fonts and pixel art the pages use from `app/frontend/` into `public/errors/` and stamps every asset URL the pages and stylesheet use with `?v=<first 8 hex of the file's SHA-256>`; a test fails when a copy differs from its source or a stamp from its file.
- When the app itself is down, the proxy's own page answers: serving these pages then is out of scope. Without the stylesheet a page still reads in order.

## Boundaries & Constraints

**Always:** Every asset is linked by absolute path (the 406 page is rendered at any path). Pages hold no `<style>`, no `style=`, no `<script>`. The stylesheet is plain CSS an old browser understands (no nesting, no `:has`, no container queries), since the 406 page is shown to exactly those browsers. Copy follows EXPERIENCE.md, Voice and Tone: plain sentences, "vous", no exclamation mark, "gameble" in lower case, narrow no-break space before « : ; ? ! » in French, an error says what happened and what to do. The 404 keeps no CSP header and the 406 keeps the enforced one, as today.

**Never:** No Brotherhood line. No change to the CSP, the browser versions allowed, or which errors reach which status. No runtime drawing and no hand edit of `app/frontend/images/pixel/`. No change to the year-long cache header of `public/`. No proxy error pages.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| French 404 | GET `/fr/no-such-page`, detailed exceptions off | 404, `404.fr.html`, `lang="fr"`, link to `/fr` | No error expected |
| English 404 | GET `/en/no-such-page` with `Accept-Language: fr` | `404.en.html`: the path wins | No error expected |
| No locale in path | GET `/no-such-page`, `Accept-Language: fr-FR` | `404.fr.html` | No error expected |
| Neither | GET `/no-such-page`, no or unknown `Accept-Language` | default locale's page | No error expected |
| Old browser | GET `/fr` with an IE 11 user agent | 406, `406-unsupported-browser.fr.html`, enforced CSP, no violation | No error expected |
| Server error | an action under `/en` raises | `500.en.html` | No error expected |
| Phone | 360 px wide | no horizontal scroll, link at least 44 px tall | No error expected |

</frozen-after-approval>

## Code Map

- `public/400.html`, `404.html`, `406-unsupported-browser.html`, `422.html`, `500.html` -- Rails 8 defaults linking `/errors.css`; replaced by `<status>.fr.html` and `<status>.en.html` (406: `406-unsupported-browser.<locale>.html`), the unsuffixed files deleted.
- `public/errors.css` -- Rails' default rules; rewrite in the theme. Colour values come from `app/frontend/styles/tokens.css` (`backdrop #05070a`, `steam-bar #171a21`, `line #2a475e`, `accent #66c0f4`, `text #c7d5e0`, `text-bright #e6eef5`, `muted #8f98a0`, `gold #f4c542`, `primary #7aa60a`, `primary-hover #beee11`, `on-lime #0f1a03`); `public/` cannot import Vite's tokens.
- `app/frontend/fonts/vt323-latin-400-normal.woff2`, `space-mono-latin-{400,700}-normal.woff2`, `OFL-VT323.txt`, `OFL-SpaceMono.txt` -- the fonts and licences to copy; `app/frontend/styles/fonts.css` has the `@font-face` shape.
- `app/frontend/images/pixel/wordmark.svg` (gold, 132 × 18), `starfield.svg` (480 tile, CSS px) -- pixel art to copy; `app/views/shell/_atmosphere.html.erb` and `app/frontend/styles/shell.css` show how the app lays the starfield.
- `actionpack` `ActionDispatch::PublicExceptions#render_html` -- already serves `public/<status>.<I18n.locale>.html` before `<status>.html`; only the locale is wrong, since the exception leaves the controller's `around_action :switch_locale` first.
- `app/controllers/application_controller.rb:8` -- `allow_browser versions: :modern, unless: :public_read?`; its default `block:` renders `public/406-unsupported-browser.html`. Give it a block rendering the locale's file.
- `app/controllers/locales_controller.rb` -- `http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale`; outside a controller the gem's `HttpAcceptLanguage::Parser.new(header)` gives the same.
- `config/environments/production.rb:19` -- `public/` cached a year, unfingerprinted; leave it.
- `script/pixel_art/export.mjs` -- reference for a node script with a `--check` mode; do not extend it (its stray-file check covers its own folder).
- `test/integration/error_pages_test.rb` -- keep every case, adapt to the new file names and assets.

## Tasks & Acceptance

**Execution:**
- [x] `app/models/error_page.rb` (or a better-fitting web-layer home) -- the error page locale for a request (path's first segment, else `Accept-Language`, else default) and the exceptions app wrapping `ActionDispatch::PublicExceptions` in that locale -- one rule for both error routes.
- [x] `config/application.rb` -- `config.exceptions_app` resolves to it at request time.
- [x] `app/controllers/application_controller.rb` -- `allow_browser` renders `406-unsupported-browser.<locale>.html` with the same rule, status 406, no layout.
- [x] `script/error_pages/build.mjs` -- copy the fonts, licences and pixel art into `public/errors/` and rewrite every `?v=` stamp in `public/*.html` and `public/errors.css`; `--check` exits 1 on any difference. Run it.
- [x] `public/errors.css` -- the theme: starfield on the backdrop, a slim top bar on `steam-bar` with a 2 px `line` rule and the wordmark linking home, a centred panel with the status code in VT323, the uppercase label, the sentence in Space Mono, the home link as the primary button; square corners; phone layout from 360 px.
- [x] `public/*.{fr,en}.html` -- ten pages on one structure with the copy in Design Notes, `lang`, a `<title>` naming gameble and the error; delete the five unsuffixed pages.
- [x] `test/integration/error_pages_test.rb` -- the ten pages; no style or script; every linked asset exists under `public/` and its stamp matches; copies match their sources; each matrix row.

**Acceptance Criteria:**
- Given any of the ten pages served by the app on a phone and a desktop, then it reads as gameble in the game's theme, and the author approves the look.
- Given `node script/error_pages/build.mjs --check` after a source font or pixel file changes, then it exits 1 until the script is run.

## Review Triage Log

### Pass 1 (quick, 2026-10-15) — high 0, medium 0, low 2, false 2, maybe-false 0

- `false` — acceptance criterion "the author approves the look" unmet: not a defect of the diff; it is the plan's manual check, asked of the author at presentation.
- `false` — the matrix's Phone row has no test: it cannot be asserted with system tests disabled; the stylesheet gives the home link 44 px (48 px under 720 px) and the plan's manual check covers it.
- `low` reject — on IE 11 the 406 page falls back to monospace (woff2 only) and its panel is not centred (flexbugs #3); the page still reads in order, the browsers `allow_browser :modern` blocks in practice (older Safari, Chrome, Firefox) read woff2 and centre correctly, and the fix adds woff copies and layout branches.
- `low` patch — new comments against AGENTS.md's one-line rule in `app/models/error_page.rb`, `public/errors.css` and `test/controllers/back_office/hidden_test.rb`; cut to one line each where they state a constraint, deleted elsewhere, the test's parameter renamed `locale_prefix`; the stylesheet's stamp moved with it (`build.mjs` rewrote the ten pages).

## Implementation Notes

- `ErrorPage` (`app/models/error_page.rb`) holds the locale rule; `config.exceptions_app` and `allow_browser`'s `block:` use it. The path is read from `action_dispatch.original_path`, set by `ShowExceptions` before it rewrites the path to the status.
- `script/error_pages/build.mjs` copies three latin font files, two licences, `wordmark.svg` and `starfield.svg` into `public/errors/` and stamps `?v=` on every URL; `--check` also fails on a stray file; `--root` lets the test run it on a copy.
- The hidden back-office answers with the 404 of the address's locale: `test/support/hidden_back_office.rb` and `test/controllers/back_office/hidden_test.rb` compare against it.

## Design Notes

Copy (English mirrors it with the same rules):

| Page | Label | Sentence |
|---|---|---|
| 404 | PAGE INTROUVABLE / PAGE NOT FOUND | « Cette page n'existe pas ou a été déplacée. Vérifiez l'adresse ou revenez à l'accueil. » |
| 500 | ERREUR DU SERVEUR / SERVER ERROR | « Un problème est survenu de notre côté. Réessayez dans quelques minutes. » |
| 422 | MODIFICATION REFUSÉE / CHANGE REJECTED | « Votre modification n'a pas pu être enregistrée. Rechargez la page et réessayez. » |
| 400 | REQUÊTE INVALIDE / BAD REQUEST | « Votre navigateur a envoyé une requête que gameble ne comprend pas. Revenez à l'accueil et réessayez. » |
| 406 | NAVIGATEUR NON PRIS EN CHARGE / BROWSER NOT SUPPORTED | « gameble demande un navigateur récent. Mettez votre navigateur à jour pour continuer. » |

Button « RETOUR À L'ACCUEIL » / "BACK TO HOME", linking `/<locale>`.

## Verification

**Commands:**
- `node script/error_pages/build.mjs --check` -- expected: exit 0
- `bin/rails test test/integration/error_pages_test.rb` -- expected: pass
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

**Manual checks (if no CLI):**
- The author opens `/fr/no-such-page`, `/en/no-such-page` and the 406 at phone and desktop widths and approves the look.
