---
title: 'The Annonce says when the auction ends and posts its state politely'
type: 'feature'
ticket: '40.3'
created: '2026-11-10'
status: 'in-review'
baseline_revision: 'ff100c98f69b131d4a5e003edd4b4e4255117d1f'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-the-annonce-refreshes-live-while-it-is-open-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An auction that ends under a reader or a typist leaves the form on screen until a reload, and the Annonce's one polite status region says nothing of what others do. Epic requirements R6 and R7.

**Approach:** On top of the live refresh, the countdown's end triggers a refresh that swaps the form for "Clôture en cours…" and, once settled, the viewer's outcome; the one polite region of the Annonce is extended, never duplicated, with a pure throttle module in `app/frontend/lib` that posts the latest status line at most every 10 seconds.

## Boundaries & Constraints

**Always:**
- When the countdown reaches zero the Annonce controller closes any open dialog, remembers whether a dialog was open, the field had focus or an amount was typed, drops the field's permanence and clears it, and asks for a refresh through the same signal. The server draws "Clôture en cours…" until the close, then the viewer's outcome; both replace the form.
- When the outcome appears after such an interaction its heading takes focus, the polite region says the auction has ended, nothing typed is submitted, and a server-rendered template's sentence "Votre montant n'a pas été enregistré." is appended when an amount was typed or a dialog was open. Without interaction focus is not moved.
- The polite region of the Annonce is the one already there. The page carries its current status line as server-rendered data ("Prix <amount>, en tête <name>. Fin à <time>.", "Vous êtes en tête" when the viewer leads). After each refresh the line is offered to a throttle: it is posted at most every 10 seconds, a text that arrives meanwhile replaces the waiting one and is posted when the 10 seconds pass, so the last update is never dropped, and an unchanged text is not posted.
- An extension of the end and the end itself bypass the 10 seconds. The end posts the outcome's heading text.
- "ANIMATIONS RÉDUITES" stops the posts about other players' bids and never the end or an extension. A viewer who has bid on the listing gets the status line posted once at the last hour and once at 3 minutes left, from the end time, only while those moments are still ahead.
- The throttle is a pure module in `app/frontend/lib` with its Vitest tests; the controller only holds timers. Copy in `en.yml` and `fr.yml`; the page's own text writes go through `writeText`.

**Never:**
- No second status region; no focus move without an interaction; no markup built in script (the sentence comes from a server-rendered template); no change to the bid form's own live sentence.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The countdown controller raises `ended` once, at the deadline, as a Stimulus event the Annonce root listens to; the refresh after it is the live-refresh signal dispatched on the window.
- The status line is rendered as a hidden element with `data-status-text`, `data-status-ends-at` (ISO time) and `data-status-bidder`, read after each morph by a pure reader in the throttle module's neighbour file. A changed end time with the same viewer is an extension.
- `Game::Market::AnnonceEvents` reports whether the viewer has bid on the listing, from their own bid rows.
- The status text is built on the server from the Copy deck, with the amount through the plain amount text, so the region never composes sentences in script.
- The end posts the outcome heading text read from the page, since the deck's outcome headings already say the auction ended.
- Timers are cleared on disconnect and re-armed after each morph from the page's end time.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| End while typing | Amount typed, auction ends | Heading takes focus, region says it ended, sentence appended, nothing submitted | No error expected |
| End with dialog open | Unusual-maximum dialog open | The dialog closes first, same as above | No error expected |
| End without interaction | Reader only | Closing line then outcome, focus untouched | No error expected |
| Burst of bids | Three bids within 10 s | First posts now, the last text posts at 10 s, the middle one dropped | No error expected |
| Extension | A late bid moves the end | Posted at once, whatever the 10 s | No error expected |
| Reduced motion | Other players bid | No post; the end and an extension still post | No error expected |
| Bidder | Viewer has bid | One post at the last hour, one at 3 minutes | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/lib/annonce_status.ts` (+ test) -- throttle, status-line reader, deadline moments
- `app/frontend/controllers/annonce_status_controller.ts`, `annonce_controller.ts`, `listing_clock_controller.ts` -- timers, end handling, after-morph handling
- `app/views/market/listings/show.html.erb`, `_status.html.erb`, `app/helpers/market_bids_helper.rb`, `market_helper.rb` -- the status data, the sentence template, the wiring
- `app/domains/game/app/queries/game/market/annonce_events.rb` -- the bidder flag

## Tasks & Acceptance

**Execution:**
- [ ] Pure throttle module and Vitest tests
- [ ] Controller wiring: status controller, end handling, after-morph
- [ ] Status data, sentence template, copy
- [ ] Tests: controller, one system test

**Acceptance Criteria:**
- Given an amount typed, when the auction ends, then the outcome's heading takes focus with the not-recorded sentence and nothing is submitted.
- Given the throttle, then the last update is kept, an extension and the end bypass, and reduced motion stays silent about other players.

## Implementation Notes

Built as planned; nothing was run. Details the plan left open: a post inside five seconds of the viewer's own bid is recorded as said and not repeated, so the answer to their own bid is never announced twice; the status line is not drawn when an outcome or the closing line shows, which is how the page tells the controller the auction ended; the end is posted once; the countdown raises its `ended` event only when it started above zero, so a page opened in the closing state does not refresh in a loop.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `npx vitest run` is not run in this batch; `npm run format:check`, `npx tsc --noEmit`, `ruby -c`, ERB through `ERB#src` -- expected: no error
- `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
