---
title: 'Badges and the balance follow a player''s outbid auctions'
type: 'feature'
ticket: '40.5'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '231c45ca83e64d28ad829604df9e8773aa3139f9'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-the-annonce-says-when-the-auction-ends-and-posts-its-state-politely-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player outbid on a running auction has to open the market to learn it, and the balance chip and the badges do not say that PiCoins came back. Epic requirement R4, and the status half of R3.

**Approach:** `Game::Market::OutbidCount` counts the open listings where the player holds a public bid and does not lead. An orange badge shows it on hub menu 04, the MARCHÉ tab and the MES ENCHÈRES chip, refreshed by the private stream's `market` topic beside the existing balance notice. An outbid also posts its line once to a polite status region present on every signed-in page, at most once per listing per 30 s, through the Annonce's throttle module.

## Boundaries & Constraints

**Always:**
- The count is read through the domain's query; a bid counts when its outcome is not `raise` or `voided`; a listing counts while its status is `open`, as the MES ENCHÈRES in-progress group does, so the badge and the chip's list agree; the seller's own listings never count.
- The badge is hidden at zero in the menu entry, the tab and the chip; its number is part of the item's accessible text ("Marché, 2 enchères dépassées", "Mes enchères, 2 dépassées").
- `PlayerStreamJob` recomputes the count for a player named by a `market` notice and updates the three badge slots; the balance figures keep their own notice and are not recreated. Every event that changes who leads or whether a listing is open sends the `market` topic to each player whose count may have moved: both sides of a bid, and every bidder of a listing that sold or was withdrawn.
- The status line is the outbid bell sentence in plain text, posted to a region that is empty at load, polite, present on every signed-in page and kept across navigations; the throttle is a pure module in `app/frontend/lib` with Vitest tests, built on the Annonce's `offer` with a 30 s interval per listing, never dropping the last line.
- Copy in `en.yml` and `fr.yml`; no database id in any id, URL or stream.

**Never:**
- No migration; no new table; no change to how a notice is written; no toast; no second polite region on the Annonce.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- A listing whose end has passed but not yet closed still counts; the close event refreshes the badge.
- The `market` topic also goes to the bidder on every bid, so a raise or a first lead lowers or keeps the count; the bell reload this triggers is cheap and harmless.
- The status line is carried to the browser by an append to a hidden queue inside the region's controller, which reads it, removes it and offers it to the throttle; the sentence is rendered in the viewer's locale by the job.
- Menu, tab and chip badges use the orange alert style the trades badge already has.
- The native app's tab badges are left as they are: the native bar reads only the trades badge.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Outbid on the hub | Another player takes the lead | MARCHÉ badge reads 1, balance shows the released amount available, one status line posted | No error expected |
| Raise | The outbid player raises and leads | Badge disappears | No error expected |
| Ended | The auction closes | Every former bidder's badge falls | No error expected |
| Burst | Outbid twice on one listing within 30 s | One line posted at once, the last one after the rest of the 30 s | No error expected |
| Not involved | Voided, own, cancelled or ended listing | Not counted | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/outbid_count.rb`, `listing_bidders.rb` -- the count and the players to notify
- `app/domains/game/app/queries/game/market/market_notices.rb` -- gains the outbid lines of given listings
- `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/views/player_streams/` -- topic recipients, badges, status line
- `app/helpers/balance_chip_helper.rb`, `app/views/pages/_menu_market*.erb`, `app/views/shell/_tab_bar.html.erb`, `app/views/markets/_chips.html.erb` -- badge slots
- `app/views/shell/_market_status.html.erb`, `app/frontend/controllers/market_status_controller.ts`, `app/frontend/lib/outbid_status.ts`, `annonce_status.ts` -- the region and its throttle
- `config/locales/en.yml`, `fr.yml` -- copy

## Tasks & Acceptance

**Execution:**
- [ ] Count query, bidders query, outbid lines query
- [ ] Stream recipients, job locals, badge and status partials
- [ ] Badge slots in the menu, the tab bar and the chip; region in the layout
- [ ] Throttle module, controller, styles, copy
- [ ] Tests: queries, stream, job, helper views, Vitest, one system test

**Acceptance Criteria:**
- Given player A is outbid while on the hub, then the MARCHÉ badge reads 1 and the balance shows the released amount as available, and when A raises on the Annonce the badge disappears.

## Implementation Notes

Built as planned; nothing was run, only static checks. `MarketNotices.outbid` reads the outbid lines of given listings for the status post; `Annonce`'s `offer` gained an optional interval so the 30 s per-listing throttle reuses it. The existing `market` notice test now expects the three badge updates, and the bid stream tests expect the bidder's own `market` notice. The balance figures were not touched: the existing balance notice already carries the released amount.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npx tsc --noEmit`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
