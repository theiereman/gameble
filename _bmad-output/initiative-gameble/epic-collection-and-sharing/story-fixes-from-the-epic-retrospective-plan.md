---
title: 'Fixes from the epic retrospective'
type: 'bugfix'
ticket: '7'
created: '2026-10-03'
status: done
baseline_revision: '6b66367fb08aa1b8e9deb965c28b8c8ea2201813'
built_revision: '60929459f506af792b987b56ed19bed68af2e617' # the story's own commit
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/epic-collection-and-sharing-retrospective.md']
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      A persona name is cut to 64 code points, not 64 graphemes, so the cut can split a letter from its combining mark, an emoji from its modifier or a flag's pair.
    evidence: |-
      Pre-existing since story 4.4 (`first(64)`); Accounts::PersonaName.clean keeps the rule. Fix: grapheme_clusters.first(LENGTH).join. Recorded in deferred-work.md.
    location: >-
      packs/accounts/app/models/accounts/persona_name.rb (clean)
    severity: low
  - summary: >-
      The visitor invitation's section has the whole visible sentence as aria-label (read twice by a screen reader), and is a card-detail__ element outside the .card-detail block.
    evidence: |-
      Pre-existing: story 4.5's public_profiles/card.html.erb had the same markup, moved as is to cards/show.html.erb. Recorded in deferred-work.md.
    location: >-
      app/views/cards/show.html.erb (invitation)
    severity: low
  - summary: >-
      An older browser let onto a card's page sees the invitation and "Back to the attic", and both lead to a 406 (Steam callback, attic).
    evidence: |-
      Story 4.5's deferred finding, carried to the card's page now that it is the share link; the decision stays pending in pending-approvals.md ("Older browsers signing in from a shared card"). Recorded in deferred-work.md.
    location: >-
      app/views/cards/show.html.erb, app/controllers/application_controller.rb (allow_browser)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The epic 4 retrospective found: a shared-card URL claims any card for any player ("No longer in X's collection") and carries the owner's name (B2); a card opened from a public profile goes to `/cards/…`, which answers 406 to the older browsers the profile lets in (B1); `PUBLIC_URL` is unchecked, unpinned in `deploy.yml`, untested, and the share system test reads it from the shell (U1–U4); a persona name of zero-width or bidi characters looks blank yet beats the "Brother <code>" fallback (B4). Author's decision (2026-10-03, spec CAP-9, memlog): the shared page shows only the card, never who shared or owns it.

**Approach:** The share link becomes the card's own season-qualified URL (`/<locale>/cards/<slug>/seasons/<n>`): the card page carries the preview tags and the visitor invitation and, like the library, opens to any browser; the old `/brothers/<token>/cards/…` routes redirect to it, and the shared-card action, view and owner lines go. `PUBLIC_URL` is parsed and checked at boot; persona names are cleaned of invisible characters at sign-in and at display.

## Boundaries & Constraints

**Always:**
- Share link = `public_url_for(card_season_path(slug:, number:))` for a holder (still holder only); no token in it. `cards#show` renders the tags (moved from `public_profiles/_share_tags`): `robots noindex`, description, canonical and `og:url` = the season-qualified URL on the public base without query (season-less route included), `og:type/site_name/title/description/locale`, `twitter:card summary`, no `og:image`/`twitter:image`/`image_src`; `<title>` = og:title "<title> — <rarity>" in the URL's locale.
- `cards#show` for a visitor (no `current_player`) adds the invitation after the detail ("Ten packs wait…", Steam button posting `origin: home_path`, so sign-in lands in the attic); none for a signed-in viewer. A holder keeps "You hold n copies" and the share block. Query counts unchanged: player 4, visitor 2.
- `GET /<locale>/brothers/:token/cards/:slug(/seasons/:number)` (same token and number constraints) → 301 to `/<locale>/cards/:slug(/seasons/:number)`, token ignored (no lookup, no query). `PublicProfilesController#card`, `public_profiles/card.html.erb`, the `owner:`/`owner_holds:` locals of `cards/_detail`, `.shared-card*` and `.card-detail__owner*` CSS and the owner locale keys are removed; `brother_card*` route helpers go.
- Older browsers and crawlers: a `PublicRead` concern (`public_read?` true for GET/HEAD) included by `PublicProfilesController`, `CardsController` and `LibraryController` (a card's set links lead to the library), so a profile's tome face (`card_season_path`, unchanged) and what it leads to answer 200 to iOS 16 Safari, Firefox 92, Discordbot, Twitterbot, WhatsApp. The attic (`pages#home`), sessions and every non-GET stay modern-only (406).
- `PUBLIC_URL` (`config/initializers/public_url.rb`): a `PublicUrl` module defined there — `parse(value)`: blank → nil; else an absolute `http`/`https` URL with a host, no userinfo, path empty or "/", no query, no fragment, else raise `PublicUrl::Invalid` (message names PUBLIC_URL, never echoes secrets); returns `"scheme://host[:port]"` (scheme and host lowercased, default port dropped). Missing → raise `PublicUrl::Invalid` when `Rails.env.production?` and `SECRET_KEY_BASE_DUMMY` is blank (the Docker build's `assets:precompile`). Malformed raises in every environment. `config.x.public_url` gets the result. `PublicUrlsHelper` keeps its production guard; comments (helper, `production.rb`, README) say production refuses to boot.
- Tests: `PublicUrl.parse` cases; a production boot in a subprocess (`bin/rails runner`, env with `RAILS_ENV=production`, `SECRET_KEY_BASE`, PUBLIC_URL and DUMMY set explicitly) fails for missing and malformed values, boots with a valid one (prints the normalised base) and with DUMMY and no value; `deploy.yml`'s `env.clear.PUBLIC_URL` present and `PublicUrl.parse` accepts it; `test/system/share_card_test.rb` saves, nils and restores `Rails.configuration.x.public_url`.
- `Accounts::PersonaName.clean(value)` (`packs/accounts/app/models/accounts/persona_name.rb`): non-String → nil; removes `\p{Cc}`, `\p{Cf}`, `\p{Default_Ignorable_Code_Point}` and U+2800; maps `\p{Zs}` to a space; squishes; cuts to 64 characters and strips; nil unless a `[\p{L}\p{N}\p{S}\p{P}]` remains. `SignIn` stores the cleaned name (nil keeps the stored one, as today); `public_profile_title` cleans the stored name too, so rows stored before this fix fall back.
- `deferred-work.md` (story commit): O1 warn-only key added to the 4.4 persona entry, O2, O4, O5 (`og_locale` fetch, `SetLabel` nil publisher), D2, epic 3's B3 reveal failure-path tests (retro action item 7). `pending-approvals.md` (separate `docs:` commit): the Cloudflare rule now `/*/cards/*` (and `/*/brothers/*`); the older-browser entry now names the card and library pages; the `PUBLIC_URL` entry says production refuses to boot; epic file R5 and Done-when 3 still say "opening their public profile" (ticket file, not edited here); library pages opened to older browsers.

**Never:** no image in any preview; no owner or sharer name, line or claim on the card page; no token in a share link; no change to profile show/set pages or their query counts (7/8, 9/10); no ticket or epic file edit; no migration; no Steam call, import, push or deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Share any card | visitor opens `/en/cards/blue-depths/seasons/1` | detail, tags "Blue Depths — Sapphire", invitation, no owner line | — |
| Old shared link | `/en/brothers/<token>/cards/portal/seasons/1`, any token of the format | 301 to `/en/cards/portal/seasons/1` | unknown token: same redirect |
| Profile tome face | visitor (iOS 16 Safari) on a profile tome clicks a face | `/cards/…/seasons/n` 200; its set link → library 200 | attic still 406 |
| Holder | holder on a card | copies, share block with `…/en/cards/portal/seasons/1` | — |
| PUBLIC_URL | `https://Gameble.example/`, `http://h:8080` | `https://gameble.example`, `http://h:8080` | — |
| PUBLIC_URL bad | `gameble.example`, `ftp://h`, `https://h/app`, `https://h?x`, `https://u:p@h` | boot refused in every env | `PublicUrl::Invalid` |
| PUBLIC_URL missing | production / DUMMY build / test | refused / boots / request base | — |
| Persona | `"\u200B\u202E"`, `"\u3164"`, `"\u2066 \u3000"` first sign-in | stored nil; profile "Brother <code>" | — |
| Persona mixed | `"Ga\u200Bbe"`, `"\u202Egabe"`, `"A\u3000B"` | "Gabe", "gabe", "A B" | — |
| Stored invisible | row with `"\u200B"` | profile title "Brother <code>" | — |

</intent-contract>

## Code Map

- `app/controllers/public_profiles_controller.rb` -- remove `card`, `include CardDetailLoading`, the CAP-9 header paragraph; `public_read?` moves to the concern. `show`/`set` untouched.
- `app/controllers/cards_controller.rb` -- `show`, `share_url` (switch to `card_season_path`); include `PublicRead`. `CardDetailLoading` unchanged.
- `app/controllers/library_controller.rb` -- include `PublicRead`. `app/controllers/application_controller.rb` -- `allow_browser … unless: :public_read?` and default `public_read?` false stay; comment names the concern.
- `config/routes.rb:31-36` -- replace the two `brother_card*` routes by `redirect("/%{locale}/cards/%{slug}")` and `…/seasons/%{number}` with the same constraints.
- `app/views/cards/show.html.erb`, `app/views/cards/_detail.html.erb` (drop `owner`, `owner_holds` and their doc lines), `app/views/public_profiles/{card,_share_tags}.html.erb` (delete card; move `_share_tags` to `app/views/cards/_share_tags.html.erb`).
- `app/helpers/public_profiles_helper.rb` -- `shared_card_title`, `og_locale`, `OG_LOCALES` move to `app/helpers/card_details_helper.rb` (`shared_card_title` may be renamed `card_preview_title`); `public_profile_title` uses `Accounts::PersonaName.clean`.
- `app/frontend/styles/card-detail.css:7,39-56,150-175` -- remove owner and `.shared-card` rules; the invitation styled under a card-detail class.
- `config/locales/{en,fr}.yml` -- `public_profiles.card.*`: `og_title`, `og_description` → `card_details.preview.{title,description}`; `invitation`, `sign_in` → `cards.show.{invitation,sign_in}`; `owner_gone` removed, `card_details.owner` removed. `bundle exec i18n-tasks missing` and `unused` clean.
- `config/initializers/public_url.rb`, `app/helpers/public_urls_helper.rb`, `config/environments/production.rb:60-63`, `README.md:19`, `config/deploy.yml:68-71` (comment: required, checked at boot). Docker build: `Dockerfile:71` sets `SECRET_KEY_BASE_DUMMY=1`.
- `packs/accounts/app/operations/accounts/sign_in.rb:46-50` -- `store_persona_name`; keep `PERSONA_NAME_LENGTH` (or move it to `PersonaName`).
- Tests: `test/controllers/public_profiles_card_test.rb` (rework into a card-page preview test, e.g. `test/controllers/card_preview_tags_test.rb`: tags, French, season-less canonical, spoofed Host, the five user agents, redirects, invitation and attic landing, no id), `test/controllers/cards_controller_test.rb` (share URL form, title, query counts 4/2), `test/controllers/public_profiles_controller_test.rb` (tome face href, old browser on profile tome → card → library), `test/system/share_card_test.rb` (visitor sees card only, invitation; public_url reset), `test/helpers/public_urls_helper_test.rb`, new `test/config/public_url_test.rb` (parse cases, production boots, `deploy.yml`'s `PUBLIC_URL`), `test/packs/accounts/sign_in_test.rb`, `test/packs/accounts/persona_name_test.rb`, a helper or request test for a stored invisible name. Helpers: `test/support/library_requests.rb` (`sign_in`, `hold`, `assert_request_queries`).

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/concerns/public_read.rb`, the three controllers, `config/routes.rb` -- concern, card action removed, redirects -- B1, B2.
- [x] `app/views/cards/*`, `app/views/public_profiles/card.html.erb` (delete), `app/helpers/{card_details,public_profiles}_helper.rb`, `card-detail.css`, locales -- tags and invitation on the card page, owner lines gone -- B2.
- [x] `config/initializers/public_url.rb`, `public_urls_helper.rb`, `production.rb`, `deploy.yml`, `README.md` -- boot check -- U1–U3.
- [x] `packs/accounts/app/models/accounts/persona_name.rb`, `sign_in.rb`, `public_profiles_helper.rb` -- cleaning -- B4.
- [x] Tests listed in the Code Map -- every matrix row; `test/system/share_card_test.rb` independent of the shell -- U4.
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- entries above; `pending-approvals.md` -- entries above (docs commit).

**Acceptance Criteria:**
- Given a sharer who never held a card, when a visitor opens that card's link, then the page shows the card with its preview tags and no owner line or name anywhere in it.
- Given iOS 16 Safari signed out on a public profile, when it opens a card from a tome, then it gets 200, not 406.
- Given production with PUBLIC_URL missing or malformed, when the app boots, then it refuses with an error naming PUBLIC_URL.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `npm run test:js`, `bundle exec packwerk validate && bundle exec packwerk check`, `bin/rubocop`, `bin/brakeman --no-pager`, `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `PublicRead` (`app/controllers/concerns/public_read.rb`): private `public_read?` = `request.get? || request.head?`, included by `PublicProfilesController`, `CardsController` and `LibraryController`; `ApplicationController` keeps `allow_browser versions: :modern, unless: :public_read?` and its default `false`. `PagesController`, `SessionsController` and every non-GET stay modern-only (tested: attic, callback and `DELETE /session` answer 406 to iOS 16 Safari).
- Routes: the two old `brother_card*` routes are block-form `redirect`s (Rails' default 301), same token and number constraints, to `"#{config.x.public_url}/<locale>/cards/<slug>(/seasons/<n>)"`, the slug escaped as a path segment; a router-level redirect, so no controller, no lookup and no query run (asserted with `assert_request_queries(0)`), and the query string is dropped. With a configured base the `Location` never takes a spoofed Host or X-Forwarded-Host (tested); without one (development, test) it is a path, completed by Rails from the request.
- `CardsController#share_url` and the tags' URL both use `CardDetailsHelper#card_public_url(view)` (`public_url_for(card_season_path(slug:, number:))`; the controller through `helpers`), so the share link always equals og:url (tested); query counts unchanged (player 4, visitor 2: the invitation reads the already memoised `current_player`).
- Views: `cards/show` sets `<title>` to `card_preview_title(view)` ("Portal — Amethyst"), renders `cards/_share_tags` (moved from `public_profiles/`, description from `card_details.preview.description`) in `:head`, then the detail, then for a visitor `section.card-detail__invitation` (TextPlate + Steam button posting `origin: home_path`). `cards/_detail` lost `owner`/`owner_holds`. `public_profiles/card.html.erb` deleted; `public_profiles/_profile` lost its `heading:` local (always an h1; `show` renders the same markup).
- Helpers: `card_preview_title`, `og_locale` and `OG_LOCALES` moved to `CardDetailsHelper` (`og_locale` still `fetch`, deferred O5). `public_profile_title` shows `Accounts::PersonaName.clean(player.persona_name)` or the fallback.
- Locales: `public_profiles.card.*` and `card_details.owner` removed; `card_details.preview.{title,description}` and `cards.show.{invitation,sign_in}` added (same wording as before) in `en` and `fr`.
- `card-detail.css`: owner and `.shared-card*` rules removed; `.card-detail__invitation` (the old invitation rule, with `margin: var(--space-6) auto 0` since it is no longer in a gapped column).
- `config/initializers/public_url.rb` defines `PublicUrl.parse` (strips surrounding whitespace, `URI.parse`, `URI::Error` → `Invalid`; a host of letters, digits, dots and hyphens or a bracketed IPv6 literal, a port in 1..65535; port dropped when it equals the scheme's default) and `PublicUrl.configure(value, env:, dummy_build:)` (adds the production-missing rule), then sets `config.x.public_url = PublicUrl.configure(ENV["PUBLIC_URL"])`. Both messages are fixed strings naming PUBLIC_URL. `PublicUrlsHelper::MissingPublicUrl` stays as a guard for a configuration changed after boot.
- `Accounts::PersonaName` (`packs/accounts/app/models/accounts/persona_name.rb`, `LENGTH = 64`): also reads the string as UTF-8 (`force_encoding`) and scrubs invalid bytes before cleaning, so a binary-tagged string keeps its characters and none can raise. `SignIn::PERSONA_NAME_LENGTH` is gone (its comment names `Accounts::PersonaName::LENGTH`); non-ASCII characters in its source and tests are `\u` escapes; `store_persona_name` writes the cleaned name when it is non-nil and differs.
- Tests: `test/controllers/public_profiles_card_test.rb` became `test/controllers/card_preview_tags_test.rb` (18 tests: card only and no sharer name, tags, French, season-less canonical, query-string number, spoofed Host, holder/viewer, invitation → attic, redirects for any token incl. banned and unknown, malformed old links 404, no `brother_card*` helpers, five user agents on card + its set link + library + HEAD, attic/sessions 406, no id). New `test/config/public_url_test.rb` (parse cases, `configure`, four production boots in `bin/rails runner` subprocesses with every variable explicit, `deploy.yml`'s `env.clear.PUBLIC_URL`) and `test/packs/accounts/persona_name_test.rb`; additions in `cards_controller_test.rb` (share URL form, title, no token), `public_profiles_controller_test.rb` (tome face href → card → library for iOS 16 Safari; stored invisible names fall back; stored mixed name shown cleaned), `sign_in_test.rb` (matrix names), `share_card_test.rb` (visitor sees only the card and the invitation, no name; `public_url` saved, nilled, restored).
- Docs: `deferred-work.md` (story commit) extends the 4.4 persona-lookup entry with O1 and adds O2, O4, O5 (`og_locale`, `SetLabel`), D2 and epic 3's B3; `pending-approvals.md` (separate `docs:` commit) updates the Cloudflare rule, the `PUBLIC_URL` and older-browser entries, and adds the epic R5 / Done-when 3 reconciliation and the library opened to older browsers.

- Orchestrator: the Write tool had turned the `\u` escapes of the I/O matrix's persona rows into the literal characters (an unclosed U+202E among them); they were written back as escapes, unchanged in meaning.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 32 findings — high 0, medium 3, low 26, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` (blind) The old share-link redirects build `Location` from the request's Host / X-Forwarded-Host (`config.hosts` unset), against the "never the request's Host" rule — the redirects are now block-form, targeting `config.x.public_url` (a path without one), slug escaped; tested with a spoofed Host and X-Forwarded-Host for both forms.
  - `[low]` `[patch]` (blind) `PublicUrl.parse` accepts `https://h:99999` and odd hosts — port must be 1..65535 and the host letters, digits, dots and hyphens or a bracketed IPv6 literal; refused cases added to the test.
  - `[low]` `[reject]` (blind) Right-to-left names are written without `<bdi>`/`dir=auto`, and LRM/RLM are stripped — the intent asks to strip bidi controls; a plain right-to-left name at the end of the title reorders nothing in practice, and `<bdi>` across views and `<title>` (which cannot hold it) is more than a direct correction.
  - `[low]` `[defer]` (blind) The 64-character cut is by code point and can split a grapheme — pre-existing (story 4.4's `first(64)`); recorded in `deferred-work.md`.
  - `[low]` `[patch]` (blind) `SignIn::PERSONA_NAME_LENGTH` is read by nothing — deleted; the comment names `Accounts::PersonaName::LENGTH`.
  - `[low]` `[patch]` (blind) `_profile`'s `heading:` local has only its `:h1` caller and still documents `:h2` — local and doc line dropped, markup unchanged.
  - `[low]` `[patch]` (blind) The card-season's public URL was built in the controller and in the view — one helper, `CardDetailsHelper#card_public_url`; a holder test asserts the share input equals og:url.
  - `[false]` `[reject]` (blind) Library pages lack `noindex` now that crawlers read them — `allow_browser` only turns away known browsers below the modern versions; search crawlers' user agents already got the library before this change, so its indexing is unchanged.
  - `[low]` `[reject]` (blind) No test pins which controllers include `PublicRead` — a future GET action is a deliberate edit to one of three named controllers; a descendants scan is more than a direct correction.
  - `[low]` `[patch]` (blind) Old-link cases untested (season-less zero queries, following the English target) — the redirect tests now follow both forms to a 200 and assert the season-less redirect runs no query.
  - `[low]` `[patch]` (blind) The production-boot subprocess tests read `output.lines.last`, which a later STDOUT log line would break — the runner prints `PUBLIC_URL_BASE=…` and the test matches that line. The "slow" half rejected: four boots (~6 s) are the only test of the boot surface the ticket's Verify names.
  - `[low]` `[defer]` (blind) The invitation's `aria-label` repeats its sentence and its class sits outside the `.card-detail` block — pre-existing markup from story 4.5, moved as is; recorded in `deferred-work.md`.
  - `[low]` `[reject]` (blind) The iOS 16 Safari user agent is copied in a second test file — test-only duplication, part of the deferred D2 helper sweep; moving it to `test/support` is more than a direct correction.
  - `[low]` `[reject]` (blind) The plan's Acceptance Criteria omit `i18n-tasks unused` while its Verification lists it — the fix is an edit to this build's plan; the command was run and is clean.
  - `[low]` `[patch]` (blind) The "no route helper" test had no positive control — it now asserts `respond_to?(:card_season_path)` first.
  - `[low]` `[reject]` (edge) A non-UTF-8 `PUBLIC_URL` fails boot with `ArgumentError`, not naming PUBLIC_URL — boot is still refused; an environment variable with invalid bytes is not met in practice, and an encoding guard is more than a direct correction.
  - `[low]` `[patch]` (edge) Port out of range passes — same fix as the `PublicUrl.parse` row above.
  - `[low]` `[patch]` (edge) Hosts such as `https://a,b` pass — same fix as the `PublicUrl.parse` row above.
  - `[medium]` `[patch]` (edge) The redirect's `Location` follows a spoofed Host or X-Forwarded-Host — same fix as the first row.
  - `[low]` `[reject]` (edge) With `SECRET_KEY_BASE_DUMMY` set at run time and no PUBLIC_URL, every card page is a 500 — the Dockerfile sets the variable only inline on the `assets:precompile` step; setting it on a running server is a misconfiguration that also replaces the secret key base.
  - `[low]` `[reject]` (edge) ZWNJ/ZWJ in Persian or Indic names are stripped — the intent asks to strip zero-width characters; the shaping change is cosmetic, and keeping joiners between letters adds a branch.
  - `[low]` `[patch]` (edge) A binary-tagged UTF-8 name lost its non-ASCII characters through `encode` — now `force_encoding(UTF_8).scrub("")`; `"Gabé".b` test added.
  - `[low]` `[defer]` (edge) The 64-code-point cut splits graphemes — same as the blind row; deferred as pre-existing.
  - `[low]` `[patch]` (edge) `_profile`'s `:h2` documentation is dead — same fix as the blind row.
  - `[low]` `[reject]` (edge) The plan says every malformed value raises an error naming PUBLIC_URL, but invalid bytes raise `ArgumentError` — same as the non-UTF-8 row.
  - `[low]` `[patch]` (intent) The "never held" verify case is tested on the card URL, and the redirected page's tags were not asserted — the redirect tests now follow the old links and assert og:title and og:url there.
  - `[low]` `[reject]` (intent) The `SECRET_KEY_BASE_DUMMY` exemption is keyed on a run-time variable — same as the edge row above.
  - `[false]` `[reject]` (intent) A malformed `PUBLIC_URL` exported in the shell stops the test process — that is the intended check (malformed refused in every environment); U4 was about a valid exported value changing the assertions, now covered (suite green with `PUBLIC_URL=https://shell.example`).
  - `[low]` `[reject]` (intent) "Required by deploy.yml" is a YAML test, and the pending note's "fails its health check" is untested — a container that exits at boot never passes kamal-proxy's health check; testing it needs a deploy, which this story may not run.
  - `[low]` `[reject]` (intent) A player who renames to an invisible-only name keeps the stored visible name — the 4.4 rule keeps the stored name for a blank one; rare, and changing it is a behaviour decision, not a direct correction.
  - `[false]` `[reject]` (intent) The boot subprocesses inherit the rest of the shell's environment — the four variables that decide the outcome are set explicitly; a production boot opens no database connection, so the others do not change what is asserted.
  - `[medium]` `[defer]` (intent) An older browser on a card's page meets the invitation and "Back to the attic", both 406 — story 4.5's deferred finding carried to the card page; pending in `pending-approvals.md`, recorded in `deferred-work.md`.

## Design Notes

- Share URL choice: the plain card URL. It satisfies the decision without leaking the sharer (no token), keeps the tags (moved to the card page) and works signed out; the same change fixes B1 (a profile's face already links there) and O5's "own address has no tags". Cost: the card page opens to older browsers, and so does the library its set links reach (both render the partials the profile already serves them). Old `/brothers/…/cards/…` links redirect, so links pasted from the test LXC keep working.
- `noindex` stays on card pages, as the shared page had it; a holder's own copies and share button stay on the card page, being the viewer's, not the sharer's.
- A persona name that cleans to nothing at sign-in keeps the stored one (4.4 rule for blank names); display-time cleaning makes a stored invisible name fall back. Stripping default-ignorables also drops ZWJ and variation selectors inside emoji sequences (cosmetic).

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: green, with PUBLIC_URL unset and with `PUBLIC_URL=https://shell.example` exported.
- `npm run typecheck && npm run test:js && bundle exec packwerk validate && bundle exec packwerk check && bin/rubocop && bin/brakeman --no-pager && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean.

## Auto Run Result

**Summary:** The share link is now the card-season's own page, `/<locale>/cards/<slug>/seasons/<n>`. It carries no token, owner line or ownership claim (author's decision, spec CAP-9), so a link to any card is harmless. The card page carries the preview tags (title and rarity, no image, `noindex`), its `<title>` is "<title> — <rarity>", and a visitor sees the invitation to play. Story 4.5's `/brothers/<token>/cards/…` links 301 to the card page on the public base, never a forged Host; the token is never looked up. The shared-card action, view, owner lines, CSS and keys are gone. A `PublicRead` concern opens GET and HEAD on the profile, card and library pages to older browsers and crawlers, so a card opened from a profile tome (iOS 16 Safari, signed out) gets a 200, and so do its set links. The attic, sessions and every non-GET still answer 406. `PUBLIC_URL` is parsed and checked at boot:
- accepted: an http(s) URL with a host and a port in 1..65535, no user info, path, query or fragment, normalised to `scheme://host[:port]`;
- a malformed value refuses to boot everywhere;
- a missing value refuses to boot in production, except in the Docker build's `assets:precompile`;
- `deploy.yml`'s value is pinned by a test;
- the share system test no longer reads the shell.

`Accounts::PersonaName.clean` drops control, format and default-ignorable characters (and U+2800), makes spaces plain, and returns nil when nothing visible remains. It runs at sign-in and when the profile title is shown, so a blank-looking name falls back to "Brother <code>".

**Files changed:**
- `app/controllers/concerns/public_read.rb` (new), `app/controllers/{application,cards,library,public_profiles}_controller.rb`, `app/controllers/concerns/card_detail_loading.rb`: older-browser access; the card action is gone.
- `config/routes.rb`: old share links redirect to the card page on the public base.
- `app/views/cards/{show,_detail,_share_tags}.html.erb`, `app/views/public_profiles/{card (deleted),_profile,show}.html.erb`, `app/helpers/{card_details,public_profiles,public_urls}_helper.rb`, `app/frontend/styles/card-detail.css`, `config/locales/{en,fr}.yml`: tags and invitation on the card page, owner lines removed, `card_public_url`.
- `config/initializers/public_url.rb`, `config/environments/production.rb`, `config/deploy.yml`, `README.md`: the boot check.
- `packs/accounts/app/models/accounts/persona_name.rb` (new), `packs/accounts/app/operations/accounts/sign_in.rb`: name cleaning.
- `test/controllers/card_preview_tags_test.rb` (from `public_profiles_card_test.rb`), `test/config/public_url_test.rb`, `test/packs/accounts/persona_name_test.rb` (new); `test/controllers/{cards_controller,public_profiles_controller}_test.rb`, `test/packs/accounts/sign_in_test.rb`, `test/helpers/public_urls_helper_test.rb`, `test/system/share_card_test.rb`.
- `_bmad-output/initiative-gameble/deferred-work.md`: retro items O1, O2, O4, O5, D2 and epic 3's B3, plus this review's three deferrals. `pending-approvals.md` is in a separate docs commit.

**Review:** thorough, four lenses (blind hunter, edge-case hunter, verification gap, intent alignment), 32 findings; the verification-gap lens found no gaps.
- Patched, 10 entries:
  - medium: the old-link redirect followed a forged Host;
  - low: `PublicUrl.parse` port and host checks; dead `PERSONA_NAME_LENGTH`; dead `heading:` local; one card public URL helper; old-link redirect tests; boot-test output marker; positive control on the route-helper test; binary-tagged names; tags asserted after a redirect.
- Deferred, 3: the grapheme cut (low, pre-existing); the invitation's `aria-label` (low, pre-existing); an older browser's invitation and attic link leading to a 406 (medium, story 4.5's pending decision).
- Rejected, 13, reasons in the triage log:
  - RTL `<bdi>`;
  - a `PublicRead` guard test;
  - duplicated user agent;
  - plan i18n wording;
  - non-UTF-8 `PUBLIC_URL` (×2);
  - run-time `SECRET_KEY_BASE_DUMMY` (×2);
  - ZWNJ/ZWJ;
  - deploy health check untested;
  - rename to an invisible name keeps the stored one;
  - and as false: library `noindex`, a malformed shell `PUBLIC_URL`, inherited subprocess environment.
- Orchestrator fix: literal invisible and bidi characters in the source, tests and plan matrix are now `\u` escapes.

**Follow-up review:** false. Patched counts by entry verdict: high 0, medium 1, low 9.

**Verification:** after the patches:
- `bin/rails test`: 1014 runs, 0 failures, both with `PUBLIC_URL` unset and with `PUBLIC_URL=https://shell.example` exported.
- `bin/rails test:system`: 46 runs, 0 failures.
- Clean: `npm run typecheck`, `npm run test:js` (60), `packwerk validate` and `check`, `rubocop` (306 files), `brakeman` (no warnings), `i18n-tasks missing` and `unused`.
- No migration.

**Residual risks:**
- The epic file's R5 and Done-when 3 still describe the old share behaviour (pending approval: reconcile through `bmad-ticket`).
- Opening the library to older browsers is an assumption (pending approval).
- An older browser following a share link still meets a 406 if it signs in (pending).
- Real previews on Discord, X and WhatsApp remain unchecked until a public HTTPS host exists.
- A deploy with a bad `PUBLIC_URL` now fails at boot rather than serving 500s.

**Story commit:** `60929459f506af792b987b56ed19bed68af2e617` (code, tests, plan and `deferred-work.md`); `pending-approvals.md` and this hash in a separate `docs:` commit.
