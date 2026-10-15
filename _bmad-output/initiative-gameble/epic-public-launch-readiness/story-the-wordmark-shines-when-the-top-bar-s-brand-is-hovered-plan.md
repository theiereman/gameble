---
title: "The wordmark shines when the top bar's brand is hovered"
type: 'feature'
ticket: '40'
created: '2026-10-14'
status: done
baseline_revision: '68da482'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The top bar's brand link gives no feedback when the mouse hovers it: its gold wordmark has fixed fills, and the old colour rule was dropped as dead when the wordmark replaced the emblem.

**Approach:** A mouse pointer entering the brand link plays one stepped sweep of the wordmark's diagonal light band, as the author's prototype (canvas "N3 · Navbar, reflet au survol") does: the band leaves its static spot rightward, 4 art pixels every 40 ms, exits past the last letter, re-enters from the left and stops on the static shine. The frames are exported by the pixel-art script and played by CSS steps; a small Stimulus controller starts the sweep once and lets it finish.

**Decisions (author, 2026-10-14):** Only a mouse hovering the brand link sweeps, on a computer: keyboard focus and a touch tap do not, and nothing sweeps under 720px, where the top bar has no brand link (this replaces the ticket's "hovering or focusing", and "on the phone" in its check). No sweep while the booster locks navigation (the link `aria-disabled`).

**Decision (author, 2026-10-14, after the first build):** Every top-bar wordmark sweeps on a mouse hover, link or not: the brand link, the hub's and the public card page's brand, and the phone brand shown under 720px. This replaces "only the brand link" above and the Never rule against animating the hub's and the public card page's brand; the hub showcase's dimmed wordmark stays still.

## Boundaries & Constraints

**Always:** Every frame is pixel art from `script/pixel_art/export.mjs`, never hand-edited: the band is 2 px, a 1 px gap, a 1 px thin band, each lit pixel in its gold tier's lifted colour, exactly as the static shine. At rest the link's wordmark is pixel-identical to `wordmark.svg`. One sweep runs to its end once started; leaving the link does not cut it. Reduced motion (system preference, or the player's setting through `html[data-motion]`) means no sweep, read with `motionReduced()` and mirrored in CSS like the shell's other animations. No `style` attribute in server HTML.

**Never:** Loop, or replay on a timer or on page load. Animate the static wordmarks (the hub's, the public card page's, the showcase's). Change the static wordmark's look, colours or size. Add a JS animation loop (`setInterval`, `requestAnimationFrame`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hover | Pointer enters the brand link | One 22-step sweep (880 ms), ending on the static shine | No error expected |
| Keyboard | Focus lands on the link | No sweep | No error expected |
| Touch | A tap on the link (pen or touch pointer) | No sweep | No error expected |
| Locked | Hover while the booster locks navigation | No sweep | No error expected |
| Re-entry | Hover during a sweep | The running sweep continues, no restart | No error expected |
| Replay | Hover after a sweep ended | A new sweep | No error expected |
| Reduced motion | System preference, or `data-motion="reduced"` | Nothing moves; static shine | `data-motion="full"` overrides the system preference |
| Motion reduced mid-sweep | Setting flips during a sweep | The sweep stops on the rest frame; the next hover works once motion is back | No stuck "playing" state |
| Snapshot or morph | Turbo restores or morphs a page taken mid-sweep | The link connects at rest | No replay on restore |

</frozen-after-approval>

## Code Map

- `script/pixel_art/export.mjs` -- `goldColours(mask, shineStart)` (172) lights `x+y-start` in `[0,2)` or `3`; `wordmarkIcon()` (188) puts the rest start at `middle - 2` = 14; `iconSvg()` (472) run-length paths per fill, reuse its row-run logic; `DESCRIPTIONS` (1152) must name every file or the script throws (1185).
- `app/frontend/images/pixel/wordmark.svg` -- 66 × 9, 132 × 18 CSS px; stays as is for every static wordmark.
- `app/views/shell/_top_bar.html.erb` -- two `link_to home_path, class: "top-bar__brand top-bar__home"` (with and without `:back_button`) get the sweep; the hub `p.top-bar__brand` and `p.top-bar__phone-brand` do not. The link sits inside `data-controller="navigation-lock"`.
- `app/frontend/styles/shell.css` -- `a.top-bar__home` (230), `.top-bar__wordmark` (248), reduced-motion block (1449) and the `html[data-motion="reduced"]` rules after it. Under 720px `.top-bar__home` is `display: none` (1328).
- `app/frontend/lib/motion.ts` -- `motionReduced()`; reuse, do not re-read the media query.
- `app/frontend/controllers/tilt_controller.ts` -- pattern: thin controller over a tested `lib/` module, clean state on connect.
- `app/helpers/shell_helper.rb` -- `pixel_icon(name, class:)` inlines any exported SVG by name; no change.
- `test/integration/shell_test.rb` (105, 159), `test/lib/pixel_art_export_test.rb`, `vitest.config.ts` (`css.include` empties unlisted stylesheets) -- tests to extend.
- Do not touch `_showcase`, `_invitation`, `cards/show`, `hub.css`, `favicon.*`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` -- export `wordmark-sweep.svg`: the wordmark without shine as a base, then one group holding a vertical strip of shine overlays, frame 0 the rest shine and frames 1–22 the sweep, each frame offset 9 rows; add its `DESCRIPTIONS` line; run the script -- one source for both wordmarks keeps them identical at rest.
- [x] `app/frontend/lib/wordmark_shine.ts` + `.test.ts` -- start a sweep on an element unless motion is reduced or one is running; end it on `animationend` or `animationcancel`; clear it on connect -- testable without the DOM, as `tilt.ts`.
- [x] `app/frontend/controllers/wordmark_shine_controller.ts` -- wire `pointerenter` to the lib, only for `pointerType === "mouse"` and only while the link is not `aria-disabled`.
- [x] `app/views/shell/_top_bar.html.erb` -- both brand links render `pixel_icon("wordmark-sweep", class: "top-bar__wordmark")` and carry the controller and actions.
- [x] `app/frontend/styles/shell.css` -- the stepped animation on the strip while the link is sweeping; `animation: none` under both reduced-motion selectors.
- [x] `vitest.config.ts` + `app/frontend/lib/wordmark_shine.test.ts` -- add `shell` to `css.include`; assert the CSS step count and travel match the SVG's frame count, and the reduced-motion rules exist.
- [x] `test/integration/shell_test.rb`, `test/lib/pixel_art_export_test.rb` -- the links carry the controller and sweep icon, the static brands keep `wordmark`; the sweep SVG has 23 frames and its rest frame equals `wordmark.svg`'s shine.

**Acceptance Criteria:**
- Given the desktop top bar off the hub, when the brand link is hovered, then the band steps right from the first third, leaves, re-enters from the left and stops where the static shine sits.
- Given any page, when nothing is hovered, then the link's wordmark looks exactly like before this change.

## Implementation Notes

- `export.mjs`: `iconSvg`'s row runs moved to `rowRuns()`; the shine rule to `shines(x, y, start)`; `WORDMARK_SWEEP` holds the band starts; `wordmarkSweepSvg()` writes the base without shine and 23 shine frames, 9 rows apart. `wordmark.svg` is byte-identical after the export.
- `wordmark_shine_controller.ts` starts on `pointerenter` from a mouse only, never while the link is `aria-disabled`; it clears the sweep on connect, disconnect and when motion turns reduced (`onMotionChange`), since Chrome does not fire `animationcancel` there.
- Verified by the implementer: `bin/rails test` 2510 runs green, vitest 315, export `--check`, tsc, packwerk, zeitwerk; frames inspected frozen in headless Chrome. Not tried with a real mouse.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 0, low 3, false 0, maybe-false 0

- `low` reject — a window narrowed under 720px mid-sweep hides the link, Chrome fires no `animationcancel`, `data-sweeping` stays, and widening the window back replays the sweep once; it takes a resize during an 880 ms sweep, and the fix is a new guard (a timer or a resize listener).
- `low` patch — the motion subscription exists because Chrome fires no `animationcancel` when the reduced-motion rule removes the animation, and nothing said so; a one-line comment states that browser constraint.
- `low` reject — several new comments restate the name they precede (`wordmark_shine.ts`, `export.mjs`, the `shell.css` block); every neighbouring module and controller carries the same comments, and the new ones follow that house style without planning ids.

## Design Notes

Prototype path in wordmark coordinates (band start `x+y`): 18, 22 … 78, then −10, −6, −2, 2, 6, 10, then rest at 14; 22 steps, four of them blank (the band off the word). Read from the prototype file, not guessed.

```css
@keyframes wordmark-sweep { from { transform: translateY(-9px) } to { transform: translateY(-198px) } }
.top-bar__home[data-sweeping] .wordmark-sweep__frames { animation: wordmark-sweep 880ms steps(22, jump-none) }
```

SVG `transform` units are user units (1 art pixel); the inline SVG clips the strip to its viewBox; with the animation gone the strip returns to frame 0, the rest shine. The "Légendaire holo sheen" of the ticket is the retired stepped sweep (DESIGN.md now gives the Légendaire glitter): only its stepped feel is meant.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: all files up to date
- `npm install && bin/rails test` -- expected: green
- `npm run test:js` -- expected: green
- `bundle exec packwerk check && bin/rails zeitwerk:check` -- expected: no offences

**Manual checks (if no CLI):**
- Desktop, `bin/dev`: hovering the brand link plays one sweep ending on the static shine; Tab to it plays none; hovering again mid-sweep does not restart it; with "Animations réduites" on, or the OS reduced-motion setting, nothing moves.

### Pass 2 (quick, follow-up for every top-bar wordmark, 2026-10-14) — high 0, medium 0, low 4, false 0, maybe-false 0

- `low` reject — on the hub, a morph refresh during a sweep copies the server attributes and drops `data-sweeping`, cutting the band short; the hub morphs only when the packs chip's countdown reaches zero (the goal broadcast replaces its panel, it does not refresh the page), so it takes that moment inside an 880 ms sweep, and the fix is a permanent element across morphs.
- `low` patch — nothing checked that the hub showcase's dimmed wordmark stays still once the static-wordmark helper went; `pages_controller_test.rb` asserts it has no controller and no sweep strip.
- `low` patch — the public card page's brand, named by the decision, was not checked; `cards_controller_test.rb` asserts its controller and sweep strip.
- `low` patch — two rewritten comments (the controller's header, the top bar's) ran past their block's width; re-wrapped.
