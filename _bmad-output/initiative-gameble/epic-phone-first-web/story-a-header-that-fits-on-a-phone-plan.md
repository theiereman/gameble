---
title: 'A header that fits on a phone'
type: 'feature'
ticket: '1'
created: '2026-11-02'
status: done
baseline_revision: 'a311d4a8dccb7b7e899b133bd05a06ab0db8a60c'
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

**Problem:** At 390 px the top-level header crowds a brand, two counters and an avatar, titles clip, the fixed version/legal line overlaps content, and many texts and targets are under 12 px / 44 px.

**Approach:** On phone width the top-level header becomes a G home button and one merged capsule counter (standard and special told apart by icon shape as well as colour, tap opens a popover detail); the page title stays as a visually hidden h1; the header hides on scroll down and returns on scroll up; the version/legal line leaves the fixed layer; small text and targets are raised.

## Boundaries & Constraints

**Always:** Server-rendered ERB with Stimulus; strings in `en.yml` and `fr.yml`; pixel icons through `node script/pixel_art/export.mjs`; keep `navigation-lock` on the header start; reduced motion honoured; desktop header unchanged unless an open question says otherwise.

**Decisions (author, 2026-11-02):** on phone the rarity counter and the player chip are hidden for now (they return with the Me tab, entry 12); no bell slot until entry 10; the merge is phone only and desktop keeps its two chips; the header hides on scroll on every phone screen with a scrollable page.

**Never:** Drill-down headers (entry 2), the bell (entry 10), the tab bar (entry 2), editing `app/frontend/images/pixel/` by hand, adding tests to `test/system/shell_test.rb` or `test/integration/shell_test.rb` (over the size cap).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Merged counter | 3 standard, 1 special | one chip, two distinct icons with counts, tap opens detail with both and the next-capsule countdown | none |
| Empty reserve | 0 and 0 | chip shows zero, detail links to the booster screen | none |
| Scroll | long list, scroll down past threshold then up | header slides away then returns; stays shown when a popover is open | reduced motion: no animation |

</frozen-after-approval>

## Code Map

- `app/views/shell/_top_bar.html.erb` -- header, brand markup duplicated five times; `.top-bar__start` carries `navigation-lock`.
- `app/views/shell/_packs_chip.html.erb`, `_special_chip.html.erb`, `_reserve_chip.html.erb` -- the two capsule chips (same `canister-small` icon), `reserve_chip_controller.ts`, `countdown_controller.ts`; `gameble:bank-changed` carries the counts.
- `app/views/shell/_rarity_counter.html.erb`, `_player_chip.html.erb` -- other header pieces (see open questions).
- `app/views/shell/_version.html.erb`, `app/frontend/styles/shell-status.css` 246-276, `shell-screens.css` 260-272 -- fixed version line and its offsets.
- `app/frontend/styles/shell-top-bar.css` (383 lines), `shell-screens.css` (372): little headroom; new header CSS goes in a new file imported by `application.css`.
- `app/helpers/shell_helper.rb` -- `pixel_icon`, `shell_home_label`; `app/frontend/lib/frame_scheduler.ts` and `events.ts` for a scroll controller.
- Tests: `test/system/shell_test.rb` assertions on `.packs-chip`, `.top-bar__home` will need updating; new tests go in new files.

## Tasks & Acceptance

**Execution:**
- [ ] pixel source + export -- new G and two capsule shape icons -- merged counter and home button
- [ ] `_top_bar.html.erb` + new merged-counter partial -- phone header per intent
- [ ] new `top_bar_scroll_controller.ts` + vitest -- hide on scroll down, show on scroll up
- [ ] new header CSS -- sticky header, phone layout, reduced motion; version line in flow
- [ ] `shell.*` keys in `en.yml` and `fr.yml`; fix broken existing assertions; new system test file at 390x844

**Acceptance Criteria:**
- Given 390x844 on a top-level screen, when it loads, then the header shows no clipped title and no tap target under 44 px.
- Given a long page, when scrolling down then up, then the header hides then returns.
- Given the version line, when scrolled to any content, then it overlaps nothing.

## Review Triage Log

- medium, patch: focus-within kept the header open after a tap; now only keyboard focus (focus-visible) holds it.
- medium, patch: the sticky header was unscoped, so drill-downs got it; now scoped to top-level headers.
- medium, patch: the version line and main padding reserved tab bar room on back-office and public pages; gated on body:has(.tab-bar).
- medium, intent_gap, put to the author instead of a loopback: screens with a top_bar_status (the collection) show no merged counter on phone.
- maybe-false, defer: the raised phone font tokens may overflow fixed-width labels; a capture settles it.
- false: every top-level view renders its own h1. false: the packs chip also refreshes only on the hub.
- low, rejected: duplicate bank-detail id, test name wording, controller attached on desktop.

## Verification

Write the tests but do not run the suites; the orchestrator runs them once in the main tree. Do not commit.

**Commands (run by the orchestrator):**
- `bin/rails test test/helpers test/integration test/controllers` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `script/check_file_sizes && script/check_planning_references` -- expected: pass
- `node script/pixel_art/export.mjs --check` -- expected: pass
- `bin/rails test test/system/<new header test>.rb` -- expected: pass

**Manual checks (if no CLI):**
- 390x844 capture of hub, collection, trades: reduced header, no overlap.

## Code Review

### 2026-11-04 — 0 decision-needed, 2 patch, 3 defer, 17 rejected

- [x] [Review][Patch] The top-level screen predicate is untested beyond the hub and settings: add cases for trades, a screen setting `phone_back`, a signed-out visit and a back-office page [test/controllers/bank_counter_test.rb]
- [x] [Review][Patch] Nothing pins the live update of the merged counter after `gameble:bank-changed` (both counts, button and detail, standard and special): add a vitest for the reserve-chip controller or extend the phone header system test [app/frontend/controllers/reserve_chip_controller.ts]
- [x] [Review][Patch] Behaviour comments break the repo policy: delete them in [app/frontend/lib/top_bar_scroll.ts], [app/frontend/styles/shell-header-phone.css:1] and the class comment of [test/system/phone_header_test.rb]
- [x] [Review][Defer] iOS rubber-band scroll at the page bottom may reveal the header; the header may stay pinned after keyboard focus (`:focus-visible` hold); toasts sit at the header offset while it is hidden — deferred: settle on a real iPhone (the iPhone ticket)
- [x] [Review][Defer] The bank detail's countdown is rendered once and does not follow a bank change — deferred: low, cosmetic, only the counts are live
- [x] [Review][Defer] The collection screen showed the G button without a counter — deferred: already recorded by the build; the screen list has since grown, re-check on the iPhone pass

**Rejected**
- Ticker offset removed: false, `shell-header-phone.css` re-adds the ticker and version offsets.
- Duplicate `#bank-detail` id and nested `reserve-chip` controller: false, `_top_bar` renders either the reserve chip or the packs chip, never both, and the inner controller owns its own targets and listens to the bank event.
- Top-level screens missing (More, Me, Social): false, the predicate now lists own profile, social and library screens.
- `trades` matches every action; `phone_previous` without `phone_back`: false, `phone_back` is set on the trade sub-screens and `phone_previous` only on set pages, outside the list.
- Font tokens raised without overflow check: low, covered by the iPhone ticket and the 390 px capture.
- Unsupported `:popover-open`/`:focus-visible` throws: low, the popover API is required anyway.
- Resize across the breakpoint leaves `data-hidden`: low, no real use.
- Plan inconsistencies (unchecked tasks, "Do not commit"), deferred-work entry shape: edits the plan or negligible.
- `bank-counter__icon` without a rule, popover anchoring, weakened `assert_signed_in`, missing tests for empty reserve/fr/logged-out: low, not worth added complexity.
- Intent Alignment divergences: descriptive only, covered by the deferrals above.
