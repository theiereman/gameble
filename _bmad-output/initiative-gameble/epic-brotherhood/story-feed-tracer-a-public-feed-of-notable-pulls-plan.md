---
title: 'Feed tracer: a public feed of notable pulls'
type: 'feature'
ticket: '1'
created: '2026-10-07'
status: 'built'
baseline_revision: '5f2234259ab0ab5c964a99fd280cd21363c940b5'
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

**Problem:** The Brotherhood has no feed: pulls of Épique or better are not recorded anywhere, and menu 05 and the PLUS row are disabled.

**Approach:** A second handler on `Game::PackOpened` inserts one feed-entry row per notable card of the opened pack (and one filler row for the best card of a pack without any), in the opening's transaction, `ON CONFLICT DO NOTHING`. A public "Fil d'activité" screen (TOUS only) reads them newest first under the `reading` role, each entry shown only if `Game::Visibility` lets the viewer see its player. Menu 05 and the PLUS row become links.

## Boundaries & Constraints

**Always:** AD-10: handler synchronous, writes only new feed rows, publishes nothing, a duplicate never fails the opening, no per-card query loop (3 statements at most). AD-11: GET writes nothing. AD-13: visibility asked at render, nothing stored on the entry. Readable signed out. Newest first. English and French copy. No Brotherhood line on the screen.

**Never:** First discoveries, trades, reposts, the AMIS tab, type filters, the LIVE ticker, broadcasts, live updates (later stories). No stored visibility. No row written by every player.

**Decisions (author away):**
- D1: one row per notable card (pack_id, position unique); a pack with no Épique or better stores its best card as a filler (`notable` false), so the quiet-feed fallback (R4) has rows to draw from.
- D2: the screen shows the newest 30 visible notable entries; when fewer than 10 are visible, fillers complete up to 10, on the sunken panel. Constants tuned in play.
- D3: filters and the AMIS tab are not shown yet (only TOUS exists); the tab is a single selected "TOUS" control.

</frozen-after-approval>

## Code Map

- `packs/game/app/handlers/game/handlers/` -- new `pack_opened_feed.rb` (pattern of `pack_opened.rb`); subscribed in `config/initializers/event_store.rb`.
- `packs/game/app/models/game/feed_entry.rb` -- new, `record_pack` (unique pack+position, `insert_all` DO NOTHING).
- `packs/game/app/queries/game/feed_entries.rb` -- new read: visible entries, fallback.
- `packs/game/app/models/game/visibility.rb` -- reused, unchanged. Catalog::CardViews, CardComponent (size :s), `Catalog::Rarity::TIERS` reused.
- `app/controllers/feeds_controller.rb`, `app/views/feeds/show.html.erb`, `app/frontend/styles/feed.css` (+ import), `config/routes.rb` (`feed`).
- `app/views/pages/_menu.html.erb` + new `_menu_feed.html.erb`, `app/views/pages/more.html.erb`, `app/views/shell/_tab_bar.html.erb` (more is current on feeds), `config/locales/{en,fr}.yml`.
- Migration > 20261007130300, `db/schema.rb` (CI-regenerated).

## Tasks & Acceptance

**Execution:**
- [ ] migration `game_feed_entries` (player_id, pack_id, card_season_id, position, rarity, notable, occurred_at; unique pack+position; index on notable+occurred_at)
- [ ] model, handler, subscription
- [ ] query `Game::FeedEntries`, controller, route, view, css, locales
- [ ] menu 05, PLUS row, tab bar highlight
- [ ] tests: handler, query (visibility, fallback, order), controller (signed out, no write, empty), menu/more, query budget of the hub untouched

**Acceptance Criteria:**
- Given a player opens a pack holding an Épique or better, when a signed-out visitor opens the feed, then the pull appears with the player's name and the card.
- Given enough notable entries, then lower-rarity fillers are not shown; given few, then fillers complete the list and the feed is not empty.
- Given a banned, private or friends-only player, then their entries are not shown to a visitor.
- Given any GET of the feed, then no row is written.
- Given the same pack event handled twice, then no duplicate row and no error.

## Implementation Notes

Implemented directly in this session (no implementation subagent). Concurrency test teardown now also deletes feed entries and weekly contributions (their rows leaked and broke later tests).

## Plan Change Log

## Review Triage Log

- medium, deferred: WINDOW of 90 rows can hide older public pulls when the newest 90 belong to hidden players (visibility is Ruby-side, AD-13); a SQL-side filter or paging is a later story.
- low, rejected: fillers interleaved by time among notable rows is the intended D2 reading (sunken background marks them).
- low, patched: test name promised a statement budget; renamed. Hard-coded #fff in feed.css now uses --color-text-max.
- low, rejected: cards without a CardView are dropped (only drafts, which packs never hold); controller test of banned/friends-only duplicates the query tests; GET-write check by counts is enough with the reading role enforced by ApplicationController.

## Verification

**Commands:**
- `CI=true bin/rails test` (ignore card_face_visual_test.rb), `bundle exec rubocop`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `npm run typecheck`, `npm run test:js`
