---
title: 'The CSP is enforced'
type: 'feature'
ticket: '10'
created: '2026-10-14'
status: done
baseline_revision: 'b40b779b11dc63944cdaf67e3bb298a226b7a42c'
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

**Problem:** The Content-Security-Policy only reports (`Content-Security-Policy-Report-Only`); nothing is blocked, so an injected script or style would run. Staging's reports and the code show two things that enforcement would break: Mission Control Jobs' inline importmap scripts, and the inline `<style>` of the 406 unsupported-browser page that `allow_browser` renders.

**Approach:** Send the policy as `Content-Security-Policy` in every environment, give Mission Control Jobs' requests a script nonce, and move the static error pages' styles into one stylesheet served from `public/`. The throttling half of the ticket was split off at the author's request (deferred-work.md, 2026-10-14).

## Boundaries & Constraints

**Always:** Player and public pages keep `script-src 'self'` with no nonce and no `'unsafe-inline'`. The policy's directives stay as they are except where this plan says otherwise. The development Vite allowances stay. The author runs staging under the enforced policy, with the browser console open, before production is deployed.

**Decisions (author, 2026-10-14):** `font-src` allows `data:` (`'self' data:`), which settles staging's `font-src data:` report on `/fr`. The script nonce applies only to Mission Control Jobs' requests; every other page keeps `script-src 'self'` with no nonce.

**Never:** Throttling or caching of public pages (split off). `'unsafe-inline'` or `'unsafe-eval'` in production. A `style` attribute or `<style>` element in any page the app serves. Editing the Mission Control gem.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player page | GET `/en` | `Content-Security-Policy` header, no `-Report-Only` header; `script-src 'self'` only | No error expected |
| Jobs dashboard | Administrator GET `/back-office/jobs` | `script-src` carries the nonce that the importmap and module `<script>` tags carry; the dashboard's JS runs | No error expected |
| Old browser | GET of a non-public page with an unsupported user agent | 406 page styled by `/errors.css`, no inline style in it | No violation |
| Error pages through ShowExceptions | 404, 422, 500 | Served without a CSP header, as today; styled by `/errors.css` | No error expected |

</frozen-after-approval>

## Code Map

- `config/initializers/content_security_policy.rb` -- `content_security_policy_report_only = true` (end of file) becomes enforced; rewrite the header comment, which states report-only and "enforcement is a later step". Nonce generator: the session id. `content_security_policy_nonce_directives` is `%w[style-src]` outside development.
- `app/controllers/back_office/jobs_base_controller.rb` -- base of every Mission Control controller (`config/initializers/mission_control.rb`). Add a `before_action` that sets `request.content_security_policy_nonce_directives = %w[script-src style-src]` (the `ActionDispatch::Http::ContentSecurityPolicy::Request` setter, which the CSP middleware reads when it builds the header). `importmap-rails` 2.2.3 already puts `request.content_security_policy_nonce` on its importmap, module and modulepreload tags. The gem's layout has no `style` attribute or `<style>` element.
- `public/400.html`, `404.html`, `406-unsupported-browser.html`, `422.html`, `500.html` -- the Rails 8 defaults, each with one inline `<style>` block (404 and 500 identical; check the others and merge any difference). No `style=` attribute in any of them.
- `public/errors.css` -- new: the merged rules; the pages link it as `/errors.css` (absolute, since the 406 is rendered at any path). `ActionDispatch::Static` serves `public/`.
- `app/controllers/application_controller.rb:8` -- `allow_browser versions: :modern, unless: :public_read?` renders the 406 page through the controller, so the CSP header applies to it. The other error pages go through `ShowExceptions`, which sits before `ContentSecurityPolicy::Middleware` (`bin/rails middleware`), so they get no CSP header.
- `test/integration/content_security_policy_test.rb` -- asserts report-only today (`policy` reads `Content-Security-Policy-Report-Only`; "never enforced" test). Turn both around; keep the other directive tests.
- `test/controllers/back_office/hidden_test.rb` -- shows how a staff member is signed in and the jobs paths are reached; reuse its setup for the jobs nonce test.
- Do not touch: `rack_attack.rb` (throttling is split off), `Steam::Cdn::IMAGE_SOURCES`, the frontend's CSSOM writes (`element.style`, React `style` props), which the CSP does not block.

## Tasks & Acceptance

**Execution:**
- [x] `config/initializers/content_security_policy.rb` -- enforce the policy; `font-src :self, :data`; rewrite the comment as the current rule (enforced, nonce on styles, scripts nonced only for Mission Control Jobs) -- the switch itself.
- [x] `app/controllers/back_office/jobs_base_controller.rb` -- add the script nonce for the engine's requests -- keeps the jobs dashboard working without loosening other pages.
- [x] `public/errors.css`, `public/*.html` -- move the inline styles to the stylesheet and link it -- the 406 page is rendered under the policy.
- [x] `test/integration/content_security_policy_test.rb` -- assert the enforced header and the absence of the report-only one; a player page's `script-src` has no nonce -- and `font-src` is `'self' data:` in the directives test -- regression guard.
- [x] `test/controllers/back_office/jobs_csp_test.rb` (or the existing back-office test file that fits) -- an administrator's GET `/back-office/jobs` has a `script-src` nonce equal to the `<script type="importmap">` nonce.
- [x] `test/integration/error_pages_test.rb` -- every `public/*.html` has no `<style>` element and links `/errors.css`; an unsupported user agent on a non-public page gets the 406 page with the enforced header.

**Acceptance Criteria:**
- Given any page of the app, when it is served in production, then it carries `Content-Security-Policy` and no `Content-Security-Policy-Report-Only`.
- Given the build is deployed to staging, when the author walks every screen (visitor, player, staff including `/back-office/jobs`; French and English; phone and desktop), then the browser console shows no CSP violation.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 1, low 2, false 2, maybe-false 0

- `low` reject — `public/errors.css` is served with `max-age` of one year and no fingerprint (`config/environments/production.rb:19`), so a later change could stay cached. No production is deployed yet and entry 54 (themed error pages, same epic, before the refactor sweep) changes this file and names this caching question in its `unknown`; no player meets a stale sheet before then.
- `medium` handled outside the build — entry 10 in `tickets.toml` still describes the throttling half split off at step 1, so marking it done would claim throttling. The entry is narrowed to the CSP and the throttling half becomes its own entry through the ticket tree after this build; no code change.
- `false` — the new `deferred-work.md` entry says `source_plan: none`: that is the format step 1 prescribes for a split made before a plan exists.
- `low` patch — `test/integration/content_security_policy_test.rb` header comment says "nonces on styles only", contradicting the Mission Control script nonce; reworded.
- `false` — `nonce_inline_scripts` also lists `style-src`: required, since setting the request's nonce directives replaces the app-wide list, and outside development `style-src` is already nonced; the name says why the method exists.


## Verification

**Commands:**
- `bin/rails test test/integration/content_security_policy_test.rb test/integration/error_pages_test.rb test/controllers/back_office` -- expected: pass
- `bin/ci` -- expected: green
- `bin/rails zeitwerk:check` -- expected: all is well

**Manual checks (if no CLI):**
- In development, `/back-office/jobs` as an administrator loads with its JS working and no console violation.
- On staging (author): the walkthrough in the second acceptance criterion; Sentry's security reports stop after the deploy except browser-extension noise.

