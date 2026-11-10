---
title: 'The Annonce refreshes live while it is open'
type: 'feature'
ticket: '40.2'
created: '2026-11-10'
status: 'draft'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-an-outbid-player-sees-a-bell-line-and-the-notice-on-the-annonce-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An open Annonce shows the price, leader, history and end as they were at load; another player's bid, a sale, a cancellation or a withdrawal never reaches it. Epic requirements R2 (the extended panel) and R5.

**Approach:** `ListingStream`, an `AfterCommitBatch` like `LiveStream`, hears the listing events and enqueues `ListingStreamJob` after commit, which sends one refresh signal per touched listing on a public stream named by the listing's token. The Annonce subscribes and refetches itself by morphing through the `live_refresh` controller, which keeps an open dialog, the focused element and the typed amount as they are.

## Boundaries & Constraints

**Always:**
- `ListingStream` hears `BidPlaced`, `AuctionSold`, `AuctionUnsold`, `ListingCancelled` and `ListingWithdrawn`, and adds the listing id of each to one batch per transaction; a later removed-player story adds its own event to the list. The job receives the ids, looks the tokens up, broadcasts once per listing and nothing else, and is enqueued only after commit.
- The stream is named by the token, never a database id: `["market-listing", token]`, one stream for every locale, carrying only a `gameble-event` signal, `listing-updated`, no markup and no amount.
- The Annonce subscribes with `turbo_stream_from`, for visitors and players alike, and its root runs `live-refresh` on that signal. An open dialog holds the refresh until it closes; the focused element and the typed amount stay because the amount field is `data-turbo-permanent`, so unsent text in a permanent field does not hold the refresh.
- After a morph the controller reads again what the page redrew: the field's terms (price, minimum, available, buy-now, own maximum) reach the bid state through a `retermed` event, and the foot is rendered again from that state.
- A viewer's own bid answer panel stays readable: it holds the refresh for a short fixed delay, then lets it through.
- The extended panel ("ENCHÈRE PROLONGÉE", "Une offre vient d'arriver dans les 3 dernières minutes. Fin déplacée à <time>.") shows above the form to every viewer, signed in or not, while the latest extending bid's extended end is still the listing's end; it never moves focus and never replaces the field or the button, and is in the accent colour. The outbid panel of the previous story arrives by this refresh on an open Annonce. The FIN DANS countdown is restarted by the refresh.

**Never:**
- No payload on the stream beyond the signal; no per-viewer content on a public stream; no broadcast inside a transaction; no polling.
- No second subscription mechanism: the signal joins the existing stream signals.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The batch carries listing ids (job arguments), the stream carries tokens; the job asks `Game::Market::ListingTokens` for them.
- The signal is sent as a hand-built turbo-stream tag with an empty template, as the player stream's signals are, through `broadcast_stream_to`.
- `live_refresh` skips fields marked `data-turbo-permanent` when it asks whether text is unsent, since the morph never touches them; nothing else about it changes.
- The hold on the viewer's own answer panel lasts six seconds, set by the foot controller with `data-live-refresh-hold` and lifted by a timer.
- The extended panel's end is shown with the local-time tag, as the history's extension line is.
- Reduced motion has no effect here: the refresh changes no animation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bid elsewhere | B bids while A reads | A's price, leader and history update with no reload | No error expected |
| Typing | A has typed and holds focus | The typed amount and focus stay while the rest updates | No error expected |
| Dialog open | A's unusual-maximum dialog is open | It stays open; the refresh follows once it closes | No error expected |
| Late bid | A bid lands in the last 3 minutes | Every viewer sees the extended panel and the new end | No error expected |
| Close | The auction sells, ends unsold, is cancelled or withdrawn | One refresh per listing | No error expected |
| Many events | Several events in one transaction | One broadcast per listing | No error expected |

</frozen-after-approval>

## Code Map

- `app/models/listing_stream.rb`, `app/jobs/listing_stream_job.rb`, `config/initializers/event_store.rb` -- the batch, the job, the subscription
- `app/domains/game/app/queries/game/market/listing_tokens.rb`, `annonce_events.rb` -- tokens by id, the extended end
- `app/views/market/listings/show.html.erb`, `_events.html.erb`, `app/helpers/market_bids_helper.rb` -- the subscription, the root controllers, the panel
- `app/frontend/lib/stream_actions.ts`, `events.ts`, `app/frontend/controllers/live_refresh_controller.ts`, `annonce_controller.ts`, `annonce_field_controller.ts`, `annonce_foot_controller.ts` -- the signal, the holds, the terms after a morph

## Tasks & Acceptance

**Execution:**
- [ ] Stream, job, token query, subscription
- [ ] Annonce subscription, live-refresh wiring, permanent field, terms after morph
- [ ] Extended panel and its copy
- [ ] Tests: stream and job, query, controller (Vitest), one system test with two sessions

**Acceptance Criteria:**
- Given two sessions on one Annonce, when B bids, then A's price, leader and history update while A keeps typing with focus and an open dialog stays open.
- Given a bid in the last 3 minutes, then every viewer sees the extended panel and the new end.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, ERB through `ERB#src`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit` -- expected: no error
- `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
