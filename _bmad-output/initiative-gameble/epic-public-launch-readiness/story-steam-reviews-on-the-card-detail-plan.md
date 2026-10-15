---
title: 'Steam reviews on the card detail'
type: 'feature'
ticket: '33'
created: '2026-10-14'
status: done
baseline_revision: '5716e67'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who finds a card on its detail sees nothing of how the game fared on Steam, though the card-season keeps the source's review count and share of positive reviews, both frozen at publication (`catalog_card_seasons.review_count`, `rating`).

**Approach:** `Catalog::CardDetail` reads the card-season's review count and rating; the card detail (`cards/_detail`) shows them as one more fact, « Avis Steam » / "Steam reviews", reading "93 % positive · 12,345 reviews" in each locale's number format, placed last before the store link's actions. A card-season with no review count shows no such fact. The card face, the visitor's shared card page (`cards/_public`) and its link preview stay as they are (author, 2026-10-12: on the card detail only).

</frozen-after-approval>

## Implementation Notes

Oneshot: two columns read, one fact row, its copy and tests.

- `Catalog::CardDetail` reads `review_count` and `rating` and returns `steam_reviews`, a `SteamReviews(count:, positive_percent:)`, or nil without a review count (`rating` is never null).
- `cards/_detail` shows « Avis Steam » / "Steam reviews" as the last fact, through `CardDetailsHelper#card_detail_steam_reviews`: `number_with_delimiter` and `number_to_percentage` in the locale's format ("93% positive · 12,345 reviews", « 93 % positifs · 12 345 avis » with no-break spaces), the share rounded down.
- `cards/_public`, the share tags and the card face are untouched.
- Tests: `card_detail_test.rb` (nil by default, the two values), `cards_controller_test.rb` (both locales, singular, the round-down, the visitor's page without it).

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 0, low 2, false 0, maybe-false 0

- `low` patch — `number_to_percentage(..., precision: 0)` rounds 99.5 up to "100% positive" though some reviews were negative; the share is rounded down (`floor`), tested at 99.8.
- `low` patch — the comment on `SteamReviews` restated the field; removed. The edited `CardDetail` header kept CAP-7 and AD-15; removed. The helper's comment stays, as every method of `CardDetailsHelper` carries one, and now says why the share is rounded down.

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb test/packs/catalog` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` -- expected: green
