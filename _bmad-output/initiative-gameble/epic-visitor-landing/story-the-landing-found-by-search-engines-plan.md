---
title: 'The landing found by search engines'
type: 'feature'
ticket: '18'
created: '2026-10-22'
status: 'built'
baseline_revision: 'c0978c38'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      Public profile, collection and album pages are indexable without a canonical link, and the paginated ones give duplicate addresses.
    evidence: |-
      The noindex was lifted as the ticket requires; the author's decision gives them no further search work.
    location: >-
      app/views/public_profiles
    severity: low
---

<intent-contract>

## Intent

**Problem:** The landing at the root has the bare title "gameble", no description, no language links, no structured data, and the app serves no sitemap and an empty robots.txt, so search engines cannot present it well.

**Approach:** Give the landing a title and description per language, canonical and hreflang links and structured data on the configured public base; serve a generated sitemap (landing and legal page, both languages) and a robots.txt that points to it and keeps the back-office and private screens out. Public card pages, profiles and the library stay as they are.

</intent-contract>

## Implementation Notes

Oneshot: a head partial, two small controllers and their locale copy. The canonical domain is settled: PUBLIC_URL (https://gameble.net in production) is the base of every absolute link. The root `/` redirects by browser language, so it is the x-default alternate. The structured data is a JSON data block (type application/ld+json), which the enforced script-src does not govern. The legal page gets canonical and hreflang links too, since the sitemap lists it.

The verification of the ticket (public card pages and profiles are not marked noindex) required lifting the `noindex` the public card page and the public profile pages (profile, collection, album) carried; the unavailable-profile, friend-profile and banned pages keep theirs. The static `public/robots.txt` is removed so the generated one is served. Files: `app/controllers/robots_controller.rb`, `app/controllers/sitemaps_controller.rb`, `app/helpers/search_tags_helper.rb`, `app/views/landings/_search_tags.html.erb`, `app/views/layouts/_language_links.html.erb`, `app/views/sitemaps/show.xml.builder`, routes, locales, `test/controllers/search_engines_test.rb`.

Author's follow-up: staging must not be indexed, and production runs the image staging ran, so the switch is the runtime variable SEARCH_INDEXING (`config/initializers/search_indexing.rb`), on only in `config/deploy.production.yml`. Off, the default: robots.txt is `Disallow: /` with no sitemap, /sitemap.xml is 404, every response carries `X-Robots-Tag: noindex, nofollow` (`ApplicationController`), and the landing and legal page omit their search tags. On: the behaviour above.

## Verification

**Commands:**
- `bin/rails test test/controllers test/integration` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`, `npm run test:js`, `npx tsc --noEmit`, `bin/rubocop` -- expected: pass

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 5, false 1, maybe-false 0
- findings:
  - `[low]` `patch` multi-line comments in the new files break the comment policy — stripped from controllers, helper, partials, routes and the test.
  - `[false]` `reject` i18n-tasks health may flag unused keys — ran it: no missing, no unused.
  - `[low]` `reject` no test that the JSON cannot close its script tag — ERB::Util.json_escape is used; not worth a test.
  - `[low]` `patch` crawler files cached an hour might carry Set-Cookie — test now asserts none on robots.txt.
  - `[low]` `reject` the cache ignores Vary — responses do not vary by locale.
  - `[low]` `defer` newly indexable profile pages lack a canonical link — deferred.

## Auto Run Result

Summary: the landing has a title and description per language, canonical, hreflang and x-default links, Open Graph tags and JSON-LD (WebSite and VideoGame); the legal page has canonical and hreflang links; `/sitemap.xml` and `/robots.txt` are generated on PUBLIC_URL (static robots.txt removed); the noindex of the public card page and the public profile pages is lifted.
Verification: controllers, integration, helpers and config tests (1102) pass; landing system tests pass; zeitwerk, packwerk, rubocop, tsc and vitest pass; i18n-tasks has no missing or unused keys (pre-existing normalization and interpolation notes untouched).
Follow-up review recommended: false. Patched: 2 low.
