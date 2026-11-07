---
title: 'The next capsule''s art is ready before the touch'
type: 'feature'
ticket: '4'
created: '2026-11-06'
status: 'built'
baseline_revision: '1c20fb523ae4ce15b9a822f7098852f186d04128'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** With the held capsule opened locally, the cards reveal at once but each face's art is still fetched from the Steam CDN at reveal time, so on a slow network a revealed card shows its art late, and offline it falls back.

**Approach:** While the booster screen is idle and holds a capsule, fetch the covers of the held capsules' cards ahead with the exact request the art worker uses, so the reveal's fetch is served from the browser's HTTP cache; once per capsule token, a few at a time, never during an opening's animations.

## Boundaries & Constraints

**Always:** Reuse `IMAGE_REQUEST` from `app/frontend/lib/card_art/worker_job.ts` so the cache entry matches the worker's fetch. Start in idle time (`requestIdleCallback` with a timeout fallback, or the booster's existing `whenIdle`), skip when `navigator.connection.saveData` is true, ignore every error, abort pending fetches on disconnect. Both reserves' held capsules, plus the answer's `next`, are prepared.

**Never:** No change to the art worker, the renderer or the faces. No storage of images by script (no Cache API here; the offline screen story owns the service worker).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Held capsule shown | screen idle, held capsule with 5 covers | 5 fetches with `IMAGE_REQUEST`, at most 3 at once | No error expected |
| Same token again | held unchanged after a re-render or bank refresh | no new fetch | No error expected |
| Opening running | lock depth > 0 or phase opening | preparation waits for idle | No error expected |
| Data saver | `saveData` true | nothing fetched | No error expected |
| Fetch fails | network error or CORS refusal | ignored, reveal falls back as today | swallowed |

</frozen-after-approval>

## Code Map

- `app/frontend/lib/card_art/worker_job.ts` -- `IMAGE_REQUEST`.
- `app/frontend/lib/opening.ts` -- `OpeningCard.coverUrl`.
- Story 3's held capsule state in `app/frontend/lib/booster*.ts` (read its plan beside this one, `story-a-capsule-opens-and-reveals-at-once-while-its-confirmation-g-plan.md`, and the code it left) and `app/frontend/controllers/booster_controller.ts` (`whenIdle`, wiring; keep it under 400 lines by putting the logic in a new lib module such as `app/frontend/lib/art_prefetch.ts`, unit-tested with an injected fetch).

## Tasks & Acceptance

**Execution:**
- [ ] new `app/frontend/lib/art_prefetch.ts` + test -- per-token once, concurrency 3, saveData, abort
- [ ] wire it from the booster's idle path for every held capsule

**Acceptance Criteria:**
- Given a held capsule, when the screen goes idle, then each of its covers is requested once with the worker's request options.

## Verification

**Commands:**
- `npm run test:js && npm run typecheck && npm run format:check` -- expected: green
- `script/check_file_sizes && script/check_planning_references` -- expected: clean

## Implementation Notes

- `app/frontend/lib/art_prefetch.ts` (`ArtPrefetch`, `heldCapsulesOf`), wired in `booster_opening_parts.ts`; the controller calls `consider()` on each render and `stop()` on disconnect. Wired from `render()` rather than `whenIdle`, since a bank refresh can change the held capsule without an idle pass; the fetches themselves still wait for idle time and a calm screen.

## Review Triage Log

Pass 1 (quick): 1 medium, 1 low.

- medium, patch — the calm check ignored reveal-all and storing, so covers could be fetched between the cards of a reveal-all: it now uses the booster's own `idle(state)`.
- low, rejected — fetches already in flight keep running when an opening starts: at most three small image downloads, and aborting them would only waste them.
