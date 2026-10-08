---
title: 'Legal page'
type: 'feature'
ticket: '3'
created: '2026-10-08'
status: 'built'
baseline_revision: 'fb919801d88dddc123807f319f5372bf4923aa54'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The site states nowhere, as a whole, that it has no affiliation with Steam or Valve, who owns the artwork, its terms of use or what it does with personal data. Each card detail carries its own notice instead, and the public card page's "Mentions légales" is an inert label.

**Approach:** Add a public, locale-scoped legal page holding five sections: legal notice (publisher and host), the no-affiliation and ownership notices, terms of use, privacy notice, and "Support gameble" with the donation link. Link it from the settings list and the public card page footer, add a donation row to the settings, and remove the per-card notice with its tests. The author decided (2026-10-08) on the following. Claude drafts the terms and privacy texts and the author reviews them before commit. The publisher is presented as an anonymous private individual's non-commercial project. The contact e-mail and the host's identity come from configuration, because the production domain and VPS are not chosen yet. Donations go to `https://buymeacoffee.com/theiereman`, linked from both the legal page and the settings.

## Boundaries & Constraints

**Always:**
- The page works signed out, in `fr` and `en`, under `/:locale/legal`. The GET only reads. It has a Pundit policy. All copy lives in `en.yml` and `fr.yml`, and the server HTML has no `style` attribute.
- The ownership notice reads, in French, exactly « Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. »
- The contact e-mail comes from `LEGAL_CONTACT_EMAIL`, and the host's name and postal address from `LEGAL_HOST_NAME` and `LEGAL_HOST_ADDRESS`. They are read once into `config.x.legal`. A missing value hides its line and never fails boot.
- External links (donation) open in a new tab with `rel="noopener"` and say so to screen readers.
- The privacy notice describes only what the app really does: it stores the Steam id and persona name, the game activity (cards, packs, trades, friends, feed entries, reports) and the last-seen time; the session cookie and the motion preference cookie are strictly necessary; there are no analytics, no ads and no real money; Steam/Valve handles sign-in and the persona name; Sentry receives errors with the player id only; Cloudflare sits in front; card images load from Steam's CDN; a deleted account is anonymised. The rights listed are access (by e-mail until the export exists), deletion (from the settings) and a complaint to the CNIL.

**Never:**
- Do not add a cookie banner, analytics or a copyright row on a card.
- Do not hard-code a domain, a contact address or a host.
- Do not put a donation prompt anywhere in the game besides the settings row and the legal page.
- Do not change the public profile or the feed pages.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor FR | signed out, `GET /fr/legal` | 200, French page with the five sections and the exact ownership notice | No error expected |
| Player EN | signed in, `GET /en/legal` | 200, English page | No error expected |
| Contact and host configured | env set | the e-mail is a `mailto:` link; the host's name and address are shown | No error expected |
| Contact and host unset | env empty | those lines are absent and the page still renders 200 | No error expected |
| Card detail | any card | no `.card-detail__notice` and no notice text | No error expected |

</intent-contract>

## Code Map

- `config/routes.rb` -- inside `scope ":locale"`, add `get "legal" => "pages#legal", as: :legal` next to `more`.
- `app/controllers/pages_controller.rb:26-28` -- `more` (`authorize :page, :show?`) is the model for `legal`. `include PublicRead` (`app/controllers/concerns/public_read.rb`) is how `cards_controller.rb:23` lets crawlers and old browsers read a page; apply it to `legal` only if `PublicRead` can be scoped, otherwise skip it.
- `app/policies/page_policy.rb` -- `show? = true` already covers it. `test/policies/page_policy_test.rb` needs no change.
- `config/initializers/public_url.rb` -- the existing pattern for `config.x` read from ENV. The new `config/initializers/legal.rb` is far simpler (`presence`, no validation).
- `config/deploy.production.yml` -- `env.clear` gains the three `LEGAL_*` keys as commented placeholders beside `PUBLIC_URL`, to fill when the VPS is chosen. `config/deploy.staging.yml` has its own `env.clear`.
- `app/views/settings/show.html.erb` -- `ul.settings__list`, with rows `li.settings-row` > `p.settings-row__label` + control. DESIGN.md: "A 'Mentions légales' link closes the list".
- `app/views/cards/_public.html.erb:67-69` -- the footer's inert `span.public-card__legal` becomes a `link_to legal_path`. Update the header comment at l.6-7, which says it is a placeholder.
- `app/frontend/styles/card-detail.css:803-809` -- `.public-card__legal` gets link states and its comment is fixed. Remove `.card-detail__notice` at l.253-256 (keep `.card-detail__description`) and at l.324-328, and the word "notice" in the l.7 comment.
- `app/views/cards/_detail.html.erb:134` (and the l.4 comment) -- remove the notice.
- `config/locales/{en,fr}.yml` -- delete `card_details.notice` (en:789, fr:809). Keep `cards.show.legal`. Add `pages.legal.*` and the `settings.show.support.*` and `settings.show.legal` keys.
- Tests that assert the notice: `test/controllers/cards_controller_test.rb:75,96,118,141` and `test/system/card_detail_test.rb:109`. In `test/controllers/card_preview_tags_test.rb:79-83`, `.public-card__legal` stays but is now a link.
- Test models: `test/controllers/pages_controller_test.rb`, `test/system/settings_test.rb` and `test/system/card_preview_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `config/initializers/legal.rb` -- set `config.x.legal` from the three ENV keys (blank → nil) -- the contact and the host are not known yet.
- [x] `config/deploy.production.yml`, `config/deploy.staging.yml` -- document the `LEGAL_*` keys (commented in production; set the staging values only if obvious, otherwise commented too) -- deployers know where to fill them.
- [x] `config/routes.rb`, `app/controllers/pages_controller.rb` -- add the `legal` route and action -- a public page.
- [x] `app/views/pages/legal.html.erb` (+ CSS in the stylesheet that holds page-level panels, matching DESIGN.md's "plain panel page in the game's tokens") -- render the sections with headings from the locale files, the configured contact and host, and the donation link -- the page itself.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- write the five sections. The French copy is the source and the English mirrors it. Keep it plain and short: terms of about 8-10 short points (free game, no real money, cards are not property and have no value, fair play and no automation, moderation and bans, content belongs to its owners, service without guarantee, changes, French law). Write the privacy notice from the Always list. Use `fr` plural forms with `zero` where needed -- copy reviewed by the author.
- [x] `app/views/settings/show.html.erb` -- add a "SOUTENIR" row (secondary small button linking to the donation URL, new tab), then a muted "Mentions légales" link closing the list -- entry points.
- [x] `app/views/cards/_public.html.erb`, `card-detail.css` -- make the footer label a link -- the public entry point.
- [x] `app/views/cards/_detail.html.erb`, `card-detail.css`, the locales, `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb` -- remove the per-card notice and its assertions, and assert its absence once -- the legal page now carries it.
- [x] `test/controllers/pages_controller_test.rb` -- cover every matrix row. Stub `config.x.legal` and restore it after each test.
- [x] `test/system/settings_test.rb`, `test/system/card_preview_test.rb` (or the system test that opens a public card) -- the legal page opens from the settings and from the signed-out public card footer.

**Acceptance Criteria:**
- Given a signed-in player on the settings, when they follow "Mentions légales", then the legal page opens in their locale.
- Given a signed-out visitor on a public card page, when they follow the footer's "Mentions légales", then the legal page opens.
- Given the settings, when the player looks at the SOUTENIR row, then its link points to `https://buymeacoffee.com/theiereman` and opens in a new tab.
- Given any card detail, when it is opened, then no per-card ownership notice appears.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 8 findings — high 0, medium 4, low 3, false 0, maybe-false 0, rejected 1
- findings:
  - `[medium]` `[patch]` The access right pointed to "the contact address above" while that line is hidden when `LEGAL_CONTACT_EMAIL` is unset — the bullet now carries the `mail_to` itself, or asks the publisher when unset; both tested.
  - `[medium]` `[patch]` "Two cookies only" overstated: localStorage (trade drafts, toasts) and sessionStorage are used, and settings are stored — the notice now names local storage and the stored settings.
  - `[medium]` `[patch]` Older browsers admitted on the public card page were refused on the legal page it links to — `PagesController#public_read?` admits GET/HEAD of `legal` only; tested with an old user agent.
  - `[low]` `[patch]` Rewritten comment lines kept planning ids (story 10.4, CAP-9) — removed.
  - `[low]` `[patch]` New comments stating no external constraint (initializer, CSS section, test) — deleted; accuracy updates to existing header comments kept.
  - `[medium]` `[patch]` `external_links.new_tab` duplicated `card_details.new_tab` and the hand-built store links — both store links use `external_link_to`, the share sheet uses the single key, `card_details.new_tab` removed.
  - `[low]` `[reject]` The plan's system-test command omits `share_card_test.rb`, which holds the footer test — the fix edits the plan; the file was run in verification anyway (green).
  - `[low]` `[patch]` The English legal page test did not pin `config.x.legal` — it now uses `configure_legal`.

## Auto Run Result

- **Summary:** public legal page `/:locale/legal` (publisher and host from `LEGAL_*` config, no-affiliation and ownership notices, terms, privacy notice, donation), reachable from the settings ("Mentions légales" link, plus a SOUTENIR row) and from the public card footer, signed out and in older browsers; the per-card notice is gone. Legal texts drafted by Claude per the author's choice, to be approved by the author before commit.
- **Files:** `config/initializers/legal.rb` (config), `config/deploy.{production,staging}.yml` (documented keys), `config/routes.rb` + `app/controllers/pages_controller.rb` (route, action, `public_read?`), `app/views/pages/legal.html.erb` + `app/frontend/styles/settings.css` (page), `app/helpers/external_links_helper.rb` (external and donation links), `app/views/settings/show.html.erb`, `app/views/cards/{_public,_detail,_share_sheet}.html.erb`, `app/frontend/styles/card-detail.css`, `config/locales/{en,fr}.yml`, tests under `test/controllers` and `test/system`.
- **Review:** 7 patches applied (4 medium, 3 low), 0 deferred, 1 rejected (plan-edit fix).
- **Follow-up review recommended:** true — four medium entries were patched; the unverified risk is the legal copy itself (accuracy of the privacy notice), which the author's review covers.
- **Verification:** `bin/rails test` 1710 runs, 0 failures; system tests (settings, card detail, card preview, share card) 140 runs, 0 failures; i18n-tasks missing/unused clean; rubocop, packwerk, zeitwerk clean.
- **Residual risks:** `LEGAL_CONTACT_EMAIL`, `LEGAL_HOST_NAME`, `LEGAL_HOST_ADDRESS` must be set before opening to the public; "identity known to the host" holds only once the VPS is chosen; the production domain moved to `gameble.net` (author, 2026-10-08), committed separately.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test:system TEST="test/system/settings_test.rb test/system/card_detail_test.rb test/system/card_preview_test.rb"` -- expected: green
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: nothing reported
- `bin/rubocop` and `npm run lint` (if defined) -- expected: no offences
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: no violations
