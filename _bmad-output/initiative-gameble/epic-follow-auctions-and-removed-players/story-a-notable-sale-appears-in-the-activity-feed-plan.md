---
title: 'A notable sale appears in the activity feed'
type: 'feature'
ticket: '40.13'
created: '2026-11-10'
status: 'in-review'
baseline_revision: 'ee385caffd1868936402b29b20042aabb8201400'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-a-notable-sale-is-recorded-as-a-feed-entry-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Sale entries exist but the feed neither draws them nor lets a player filter to them. Epic requirements R9 and R10 (the display half).

**Approach:** `FeedItems`, the entry partial and the feed sentence draw a sale as "<name> a acheté <card> pour <amount>." with the tag VENTE, `LiveStream` broadcasts it on `AuctionSold`, the feed gains the VENTES filter, and the ticker kinds still exclude it.

## Boundaries & Constraints

**Always:**
- The sentence names the buyer through `PlayerNameComponent` and the amount through `PicoinAmountComponent`; the entry's price is read from the listing and carried on `FeedEntries::Entry`.
- The VENTES filter is a `sales` choice of `FeedsController::FILTERS` and shows in the page chips and in the type sheet; AMIS keeps a friend's purchase because the buyer is the entry's player.
- `LiveStream` hears `AuctionSold`, naming the listing in its notice; `LiveFeedJob` finds the entry by listing id and broadcasts it with no viewer, so a private buyer's name has no link and a public one does.
- `LiveStream::TICKER_KINDS` stays without `sale`: no ticker shows it.
- Copy in `en.yml` and `fr.yml`.

**Never:**
- No change to which sales enter the feed. No viewer-specific markup in a broadcast. No inline `style`.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The sale tag is a plain text tag in the accent colour, like the trade tag without its icon, since no pixel art may be added by hand.
- The VENTES filter shows always, before and after the market opens; an empty filter says the feed's usual empty line.
- The live strip and the landing's LIVE feed list sales like every other entry (they are not tickers); the hub ticker and its queue never do.
- The buyer's name links when the page's viewer may see the buyer's profile; a feed page render passes the signed-in player, the landing's cached fragment and the broadcast pass no viewer.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Épique sale, public buyer | Viewer allowed on the buyer's profile | Row under TOUT and VENTES, name linked | No error expected |
| Private buyer | Viewer not allowed | Row with the name, no link | No error expected |
| Ticker | A sale settles | Hub ticker queue gets nothing | No error expected |
| Friends tab | A friend bought | Row shown | No error expected |
| Broadcast | A sale settles | One prepend per locale, after commit | No error expected |

</frozen-after-approval>

## Code Map

- `app/models/feed_items.rb`, `app/helpers/feed_helper.rb`, `app/views/feeds/_entry.html.erb`, `app/views/shell/_live_strip_body.html.erb`, `app/frontend/styles/feed.css` -- the drawing
- `app/controllers/feeds_controller.rb`, `app/views/feeds/_filters.html.erb` -- the VENTES filter
- `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb` -- the broadcast
- `app/domains/game/app/queries/game/feed_entries.rb`, `new_feed_entries.rb` -- the price on the entry
- `config/locales/en.yml`, `fr.yml` -- copy

## Tasks & Acceptance

**Execution:**
- [ ] Price on the feed entry; sentence, tag and viewer-aware name
- [ ] VENTES filter and its sheet entry
- [ ] Live broadcast on `AuctionSold`, ticker exclusion kept
- [ ] Copy in both locales
- [ ] Tests: helper, live stream, job, controller, one system test

**Acceptance Criteria:**
- Given an Épique sale, then it shows under TOUT and VENTES with a linked name for an allowed viewer, a private buyer's name without a link, and the hub ticker never shows it.

## Implementation Notes

Built as planned; nothing was run. `FeedEntries::Entry` gained `price`, filled by `FeedEntries.priced` from the listing's final price for the page readers and `NewFeedEntries`. A sale with no readable price is skipped by `FeedItems`. The feed entry partial takes an optional `viewer` local, the signed-in player by default and none for the broadcast and the landing's cached fragment.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, YAML parse and en/fr parity, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
