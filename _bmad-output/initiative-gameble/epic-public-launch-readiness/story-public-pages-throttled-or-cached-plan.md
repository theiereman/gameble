---
title: 'Public pages throttled'
type: 'feature'
ticket: '55'
created: '2026-10-14'
status: done
baseline_revision: 'd6fe23cb75c9f88181fc950939bd21a199569b01'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The pages a shared link opens (a card's page, a public profile and its sets, the library) are read without an account and without limit, so one client can scrape or hammer them.

**Approach:** Throttle GET and HEAD reads of those pages per client address in Rack::Attack, beside the sign-in throttle and keyed the same way (the real address behind Cloudflare): 120 reads a minute, answered 429 beyond. Nothing is cached: the pages carry the session's CSRF token and CSP nonce and differ signed in, so their responses stay `private`.

</frozen-after-approval>

## Verification

**Commands:**
- `bin/rails test test/integration/rate_limit_test.rb` -- expected: the 121st read of public pages from one address within a minute gets 429, another address and other pages are not throttled, a public page's Cache-Control stays private
- `bin/ci` -- expected: green

## Implementation Notes

Oneshot: a second throttle in `config/initializers/rack_attack.rb` and its tests. Decision (facilitator, 2026-10-14, the ticket allowing either): throttling rather than caching, for the reasons in the Intent; the limit of 120 a minute leaves room for Turbo's hover prefetch.

- `config/initializers/rack_attack.rb`: `PublicReadThrottle` counts GET and HEAD of `/:locale/cards…`, `/:locale/brothers…` and `/:locale/library…` (a format extension included) per `ClientAddress.of`, shared with the sign-in throttle; the 429 says « Trop de pages consultées » in the path's locale, and a Turbo Frame request gets its frame back holding the message.
- `config/locales/{en,fr}.yml`: `rate_limit.reading_throttled`.
- `test/integration/rate_limit_test.rb`: tests fill the counter directly where only the limit matters; one test makes the 120 real reads.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 2, low 2, false 0, maybe-false 0

- `medium` patch — `/fr/library.html` renders the library but its segment `library.html` was not counted; the extension is dropped before matching.
- `medium` patch — a throttled Turbo Frame request (library search, card detail, hover prefetch) got plain text and Turbo showed « Content missing »; the responder answers a frame request with its `<turbo-frame>` holding the message.
- `low` patch — tests did not cover other pages staying readable once the shared ones are throttled, POST under a shared prefix, HEAD, brothers paths and the format extension; added.
- `low` patch — header comments paraphrasing the code, against AGENTS.md; cut to the OmniAuth constraint and the Turbo Frame constraint.
