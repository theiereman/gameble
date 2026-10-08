---
title: 'Pack reveal island'
type: 'feature'
ticket: '6'
created: '2026-10-02'
status: done
baseline_revision: 'f922b426ea34cf0cd643c3a7eaf2bf95c8fcbfbd'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md', '{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/story-card-component-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Opening a pack lists its cards as text; the reveal — "the best moment of the game" — does not exist (CAP-5; epic 3, R5).

**Approach:** Right after an opening, the result page mounts the reveal, the React island AD-16 allows: the pack's cards lie face down under dust with their seal hidden; wiping a card reveals its rarity seal, flipping it reveals the game, with a flourish that grows with rarity; "flip all" flips the rest quickly but never shortens a legendary's reveal; on a phone the cards come one at a time at the large size. The cards are already in the collection; any later visit, reload or back navigation shows them face up, and nothing resumes.

## Boundaries & Constraints

**Always:**
- Once only: `PacksController#create` sets `flash[:reveal] = pack.token`; `show` mounts `PackReveal` only when the flash names this pack, and that response carries `<meta name="turbo-cache-control" content="no-cache">` (via `content_for :head`) and `Cache-Control: no-store`, so back navigation refetches; every other visit (reload, back, a later link) renders the faces with `CardComponent`. The layout prints only `notice` and `alert` from the flash (the token never reaches the page). Both branches end with "Back to the attic" and, when a pack is available (`Game::BankSummary`), "Open the next pack" (the island gets `openPackUrl` as a prop).
- Data: the pack's cards in order (`card_season_ids.map { views.fetch(id) }` from `Catalog::CardViews`, replacing 3.1's `CardSeasonLabels`; a missing view raises, as in 3.1) and `CardStrings`, plus the reveal's strings, resolved on the server (AD-16). The count comes from the pack (5, or 3 for a bonus). Items, live-region text and progress are keyed by position, never by `card.id` (duplicates share a slug).
- Per card, states `dusty → wiped → flipped`, held in the island only (AD-7). Dusty: the seal (`.card__seal`) hidden whatever the dust level; the back's other tier cues (gems, gold fittings) stay as DESIGN draws them — Assumption, recorded in `pending-approvals.md` for the author (a neutral back until the wipe is the alternative). Wipe: mouse `pointerenter` (`pointerType === "mouse"`), touch `pointerdown`/`pointermove` on the card (`touch-action: none` while dusty only), or keyboard focus; announces the rarity once per card. Flip: click, tap, Enter or Space; a dusty card is wiped instantly, then flipped; announces the title. Flip all: one summary announcement.
- Each card is a `button` (reset: no border, padding or background; ink focus outline) wrapping the 3.5 back and face, the inactive side `aria-hidden`; face down its `aria-label` is 3.5's face-down label (with the rarity once wiped); flipped, the label is removed so the face's text names it, and it becomes `aria-disabled="true"` (focus kept). The 3.5 markup inside is unchanged (the parity projection still holds).
- Timing lives in TypeScript only (`app/frontend/lib/reveal.ts`, a pure state machine and flip-all scheduler, unit-tested with Vitest fake timers; `vitest.config.ts` includes `app/frontend/**/*.test.ts`); each card gets `--reveal-ms` inline. The turn is short and fixed; the tier drives the flourish after it (burst size, hold; rays for gold). Starting values in Implementation Notes, tunable. Flip all: non-gold cards wipe and flip at the steel length, a short stagger apart; a gold card, wiped or not, plays its full length before the next; input ignored while running; flipped cards skipped; timers cleared on unmount. On phone, flip all moves the view to each gold card and holds it, then ends on the last card.
- Dust burst: a fixed set of 2 px spans per card, more per tier, deterministic offsets, CSS `steps()` keyframes on the 2 px grid, no blur/glow/gradient, `pointer-events: none`, removed after the flourish; none with reduced motion.
- Reduced motion: animations off (turn, burst, shimmer), but the scheduler still holds a gold card for its full length in flip all.
- Phone: one query in one place (a CSS custom property read with `matchMedia`, listening for changes) — Assumption `max-width: 600px`, recorded in `pending-approvals.md`; one card at a time at the large size, the others not rendered, a progress mark "n / N"; "next" after a flip moves focus to the new card (which wipes it). Wider screens: small cards side by side, wrapping allowed. A size change redraws the art.
- Each card element carries `data-state` and, once flipped, `data-flipped-at` (`performance.now()`), for tests.
- `PackReveal` is registered lazily like `CardPreview`.

**Never:** no bulk opening; no server call during the reveal; no other island; no reveal on a later visit.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| After opening | redirect from create | island with N dusty cards, seals hidden; token not in the page | — |
| Later / reload / back | revisit, reload mid-reveal, browser back after "Back to the attic" | faces, no island | no-cache |
| Wipe | hover or focus | seal shown, rarity announced once | — |
| Flip | Enter on a wiped card; click on a dusty one | face shown, title announced; dusty one wiped then flipped | — |
| Dust 0 | a card with no dust | seal still hidden until wiped | — |
| Duplicates | five identical gold cards | each flips on its own; flip all holds each gold | — |
| Flip all | one gold among five / no gold / gold already flipped / two golds | gold held its full length (`flippedAt(next) − flippedAt(gold) ≥ gold length`) / quick / skipped / each held | — |
| Leave mid-run | navigate during flip all | no error, timers cleared | — |
| Keyboard only | Tab and Enter | every card wiped and flipped | — |
| Phone | 390 × 844 | one card at a time, large, "1 / 5" … "5 / 5", focus follows "next"; flip all shows each gold | — |
| Bonus | three-card pack | three cards, "1 / 3" | — |
| Reduced motion | emulated | no animation; gold still held in flip all | — |
| End | a pack available / none | "Open the next pack" + "Back to the attic" / only the latter, on both branches | — |
| Art fails | the missing-image fixture | frame and title on the face | 3.5 fallback |
| Resize | across the phone query | layout switches, art redrawn | — |
| Touch slide | real phone | wipes | manual check |

</frozen-after-approval>

## Code Map

- `app/frontend/components/{Card,CardPreview}.tsx`, `app/frontend/lib/card_art.ts`, `app/frontend/styles/card.css`; `app/components/{card_component.*,card_strings.rb}`; `packs/catalog/app/queries/catalog/{card_views,card_view}.rb` (3.5).
- `app/controllers/packs_controller.rb`, `app/views/packs/show.html.erb`, `app/views/layouts/application.html.erb` (flash loop), `test/controllers/packs_controller_test.rb` (rewrite: island props after `follow_redirect!`; faces on a second GET; French titles in `.card__title`).
- `app/frontend/entrypoints/application.ts` (lazy registration), `vitest.config.ts`.
- `test/system/card_preview_test.rb` (CDP reduced motion, island waits), `test/support/game_packs.rb` (`create_pack` with chosen cards and `available_at: 1.day.ago` to control the opened pack).
- `_bmad-output/initiative-gameble/pending-approvals.md`.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/reveal.ts` (+ `reveal.test.ts`), `app/frontend/components/{PackReveal,RevealCard}.tsx`, `app/frontend/styles/reveal.css`, registration, `vitest.config.ts`.
- [x] `app/controllers/packs_controller.rb`, `app/views/packs/show.html.erb`, layout flash, locales.
- [x] `pending-approvals.md` -- back tier cues, phone query.
- [x] `test/` -- controller rewrites; system tests for the matrix (reduced motion by default; one timed gold test without it).

**Acceptance Criteria:**
- Given a signed-in player whose next pack holds a gold card, when they open it, wipe and flip cards with the keyboard, then use flip all, then go back after leaving, then the seals appear only on wipe, the gold card is held its full length, and the page shows faces without the reveal.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `npm run test:js`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- Starting values (tunable): turn 400 ms; flourish steel 200, emerald 350, sapphire 700, amethyst 1100, gold 2400 ms; flip-all stagger 150 ms.
- Besides `--reveal-ms` (the card's whole reveal in its mode: 600 ms for a quick card, turn + flourish otherwise), each card carries `--reveal-turn-ms` and `--reveal-wipe-ms` (dust fading on wipe, 200 ms), so no duration is written in CSS.
- `runFlipAll` chains its timers (each set when the previous fires) rather than setting them all at the start: timers set together can fire with jitter that puts the next card a fraction of a millisecond under the gold length; chained, the gap is never shorter than planned.
- The turn is a stepped `scaleX` on the side wrappers (back narrows, face widens), not a 3D rotation; the hold raises the face one unit; gold rays are eight 2 px bars around the card, blinking. A card mounted after its reveal is over (phone view moving on) shows its face without replaying it.
- The island also takes `atticUrl` and renders both end buttons itself; "Open the next pack" is a plain form posting to `openPackUrl` with the CSRF token from the page's meta tags.
- `Catalog::CardSeasonLabels` (3.1) had no other user and is removed with its test. `DailyBonusesControllerTest`'s bonus-page test is adapted to the reveal.
- Known edge, accepted: if another request from the same session consumes the flash between `create` and `show` (another tab, a prefetch), the reveal is lost and the faces show.
- Not covered by an automated test: the touch slide (manual check on a real phone).

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 3, low 2, false 0, maybe-false 0, rejected 1, deferred 2

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | Burst pixels showed during the turn (`fill-mode: both`) | `forwards`. |
| 2 | medium | patch | On a touch tap the rarity announcement was replaced by the title before being spoken | Live region appends (latest 5); test reads both. |
| 3 | medium | patch | A failed chunk or render left only the heading, no way out | Server "Back to the attic" fallback after the island (hidden once the island draws its end); error boundary with a link to the pack page. |
| 4 | low | patch | Crossing to the phone layout dropped focus and opened on card 1 | Current = focused card, else first unflipped; focus moved only when a card had it (not wiping unasked). |
| 5 | low | patch | The phone flip-all test proved nothing (`visible: :all`) | Two gold cards; asserts each is shown and flipped while held. |
| 6 | low | rejected | The leave-mid-run system test cannot detect live timers | Covered by the Vitest cancel test and the cleanup effect; a system test cannot observe ignored state updates. |
| 7 | low | defer | Another request of the same session can consume the flash before show | Accepted known edge; noted in Implementation Notes. |
| 8 | low | defer | The 3.9 benchmark's result-page figure predates this heavier page | Re-measured in the epic's refactor sweep (3.10). |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && npm run test:js && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
