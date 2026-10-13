---
title: "The hover light becomes a studio reflection on the card's varnish"
type: 'feature'
ticket: '47'
created: '2026-10-13'
status: 'built'
baseline_revision: '0eca469120178c9e03f4b56ee96ed23510718701'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The Légendaire's glitter runs one infinite twinkle per flake (up to 40 on a card-xl), which breaks the architecture's budget of at most six infinite animations at once on a phone view.
    evidence: |-
      architecture-gameble.md line 308 sets the budget; the author's glitter spec gives each flake its own period and delay, so the code follows the latest explicit decision. Only the author can settle it: amend the budget, or twinkle fewer flakes.
    location: >-
      app/frontend/styles/card.css (card-glitter-twinkle rule), app/frontend/lib/glitter.ts
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The round glare (`.card__glare`) that follows the pointer on a tilting card is not the light the author wants. On the mockup « G · Retenu » he chose a varnish that reflects a studio: two strip lights and a faint bright ceiling, white, glossier with the rarity, plus a light iridescence on the Légendaire.

**Approach:** Remove the glare. Every card face always shows the reflection, static at rest (flat-card position, full strength, from CSS defaults; no JS for a card nobody touches). While the tilt moves, `tilt.ts` derives the reflection's pointer-dependent values from the **displayed, eased tilt** (never the raw pointer) through a pure function and writes them as custom properties; `card.css` draws the stepped gradients with the per-rarity gloss. Entering and leaving are equally smooth: a per-frame easing drives the tilt toward the pointer (factor 0.08 per frame, settling in about 600 ms), then back to flat (0.075, about 650 ms), and the reflection rides it. Nothing jumps, nothing fades.

On the Légendaire the iridescence replaces the holo sweep and the foil drift: they leave the card face (default and booster); instead the Légendaire gets glitter: small seeded flakes, tiny mirrors that flash when the eased tilt faces their random normal and otherwise twinkle in steps while the face is in view (never under reduced motion). The iridescence is static (no hue cycle), its position shifting with the tilt.

Decisions by the author (2026-10-13, mockup and precisions relayed by the orchestrator): defaults intensity 0.5, steps 7, travel 2.5, width 2, ceiling 0.25, iridescence 1, rest 1, enter 0.08 and leave 0.075 per frame, iridescence opacity 0.21 × fresnel, about 28 flakes per 200 × 300; the reflection is always visible; under reduced motion the static rest reflection stays, nothing moves; the booster's other Légendaire extras (rays, glow, banner) stay.

## Boundaries & Constraints

**Always:** the model below, exactly; effects stay inside `.card__effects` (the `.card` root gets no overflow, filter, opacity < 1, mask, mix-blend-mode or isolation; custom properties on it are fine); sizes scale by working in % of the gradient line and in shares of `--card-height`; the booster keeps using `attachTilt` through the tilt controller; server HTML carries no `style` attribute.

**Never:** no planning ids in code; no new system tests and do not run system tests; do not edit `tickets.toml`; do not change the booster's rays, glow or banner.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Rest | no pointer ever | no inline property; reflection drawn from CSS defaults = `reflection(0, 0)` | none |
| Enter | mouse enters at a corner from rest | first frames write `--tilt-*` and `--reflection-*` moving gradually from rest values toward the pointer's (no jump on the first write) | none |
| Hold | pointer still | tilt and reflection settle on the pointer's values, `data-tilt="held"` | none |
| Leave | pointer leaves | tilt and reflection ease back together to rest; at rest every inline property, `data-tilt` and `data-tilting` are removed | none |
| Touch | finger held 150 ms | same as mouse; quick tap and early drag unchanged | none |
| Reduced motion | motion reduced when a pointer starts | nothing written; reflection stays static | none |
| Detach | controller disconnects | every property and mark removed | none |
| Glitter at rest | Légendaire face connects, in view | its flakes are built once from the card's seed (same layout on every render), levels from tilt (0, 0); non-flashing flakes twinkle | no seed → fixed default seed |
| Glitter tilted | eased tilt (dx, dy) near a flake's normal | that flake `data-flash` (flash > 0.25), level 0.5 + 0.5 × flash quantised to quarters, no twinkle | none |
| Glitter still | out of view / reduced motion / face-down or non-top phone booster card | no twinkle; glints static at 0.18 | none |

</intent-contract>

## Code Map

- `app/frontend/lib/tilt.ts` -- `Tilt` becomes `{ rx, ry }` (drop `glareDx/glareDy`, `GLARE_PROPERTIES`, `placeGlareUnderPointer`, `glarePlaced`, `SNAP_PIXELS`). Release targets `REST`; settling at rest removes all properties (the "glare stays at rest" rule of plan-glare-fades-in-place goes: the reflection now returns with the tilt). `write()` writes the reflection of `current`. `EASE` (0.16) splits into `EASE_ENTER = 0.08` while a pointer drives the card and `EASE_LEAVE = 0.075` after it lets go, the same for the booster's 16° and the 10° elsewhere. Keep hold/touch/scroll/click logic as is.
- `app/frontend/lib/tilt.test.ts` -- update to the new shape; tests listed in Tasks.
- `app/frontend/controllers/tilt_controller.ts` -- `reset()` lists the property names; import an exported list from `tilt.ts` instead.
- `app/frontend/styles/card.css` -- replace the glare section and its reduced-motion entries; add `--card-gloss` per rarity class and rest defaults on `.card`; update the header comment (the only infinite animation left on a face is the glitter's stepped twinkle).
- `app/components/card_component.html.erb` / `card_component.rb` -- replace `<span class="card__glare">` by the reflection layers; `iridescent?` true for the legendary rarity in both contexts (constant like `HOLO`); comment says reflection, not glare.
- `test/components/card_component_test.rb` -- lines ~100 and ~118 assert `.card__glare`.
- `test/system/card_preview_test.rb:139` -- asserts the glare's `display: none` under reduced motion; change it to assert the strips layer is still displayed (edit only, do not run).
- Holo and foil leave the card face: `card_component.rb` `HOLO`, `FOIL`, `holo?`, `foil?`; the `.html.erb` spans; `card.css` holo/foil rules, keyframes, the `.card--booster.card--rarity-legendary` opacity rules and reduced-motion entries; `booster.css:738-741` and `booster-layouts.css:220-226` stop `.card__holo`/`.card__foil` animations: retarget them to the flakes' twinkle (`.card__flake-glint`; a face-down card and a non-top phone card keep still); `tilt_controller.ts` comment (in-view gates the twinkle).
- `test/system/card_preview_test.rb:121-149` -- the holo test becomes the glitter twinkle test (a non-flashing flake glint animates `card-glitter-twinkle` in view, `none` out of view and under reduced motion; booster legendary has flakes; no holo/foil anywhere; rare/epic have no iridescence and no glitter). Edit only, do not run.
- `app/frontend/styles/tokens.css` + DESIGN.md frontmatter `colors` -- add the seven iridescence hues as tokens (`iridescence-1` … `iridescence-7`).
- New `app/frontend/lib/glitter.ts` (+ `glitter.test.ts`) -- pure `flakeField(seed, width, height)` and `flakeFlash(flake, dx, dy)` / `flakeLevel(flash)`, plus `attachGlitter(container, { seed, width, height })` returning `{ update(dx, dy), detach() }` that builds the flake spans (styles through CSSOM, which the CSP allows; never HTML `style`).
- `tilt.ts` gains an option `onTilt?: (dx, dy) => void`, called with the eased tilt's (dx, dy) on every write and with (0, 0) when it settles at rest or detaches.
- `tilt_controller.ts` -- on connect, when the face holds a `.card__glitter`, attach glitter (size from the computed `--card-width`/`--card-height`, which hold even while the face is hidden), call `update(0, 0)`, and pass `update` as `onTilt`; detach on disconnect.
- Untouched readers of `[data-tilting]`: `BoosterZoom.tsx`, `sub_view_controller.ts`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/tilt.ts` -- export `TRAVEL = 2.5`, `type Reflection = { strip, fresnel, horizon, hue }`, `reflection(dx, dy, aspect)`, `REST_REFLECTION = reflection(0, 0, …)` and `TILT_PROPERTIES` (all six names). `dx = ry / (2·max)`, `dy = −rx / (2·max)` of the current tilt; `aspect` = width / height of the last measured box (kept across release, default 2/3). Write `--reflection-strip: <n>%`, `--reflection-fresnel: <n>`, `--reflection-horizon: <n>` (unitless share of the card's height), `--reflection-hue: <n>%`. Normalise −0 to 0. Header comment updated.
- [ ] `app/frontend/lib/tilt.test.ts` -- `reflection`: rest values (30 %, 0.8, −0.32, 50 %); a corner's strip, fresnel (capped at 1.4), horizon and hue; hue shift from the tilt. A test reading `app/frontend/styles/card.css` (node fs) that the `.card` rest defaults equal `REST_REFLECTION`. `attachTilt`: entering from rest writes reflection values that move gradually and monotonically from rest toward the pointer's over the first frames (first write is not the pointer's value; the first frame covers `EASE_ENTER` of the way); leaving eases them back with the tilt (each frame `EASE_LEAVE` of the way) and removes every property at rest; reduced motion and detach leave none.
- [ ] `app/frontend/lib/glitter.ts`, `glitter.test.ts` -- the field is deterministic for a seed and differs between seeds; count scales with the area (28 at 200 × 300); flakes on the 2 px grid within 8 px of the edges; normals within ±0.45; about a third crosses; flash 1 at the normal, 0 beyond 0.14; level quarters; `update` toggles `data-flash` and the level.
- [ ] `app/frontend/lib/tilt.ts` -- `onTilt` option; a test that it receives the eased (dx, dy) and (0, 0) at rest.
- [ ] `app/frontend/controllers/tilt_controller.ts` -- reset with `TILT_PROPERTIES`; glitter wiring.
- [ ] `app/frontend/styles/card.css` -- the layers in Design Notes.
- [ ] `app/components/card_component.rb`, `.html.erb`, `test/components/card_component_test.rb` -- layers and tests: ceiling and strips on every tier, iridescence and `.card__glitter[data-glitter-seed]` on the legendary only (seed from the card's season number and number, a public value, never a database id), default and booster; no `.card__holo`/`.card__foil` on any tier; booster still `data-tilt-max-value='16'`.
- [ ] `app/frontend/styles/booster.css`, `booster-layouts.css` -- retarget the still rules as in Code Map; comments updated.
- [ ] `test/system/card_preview_test.rb` -- the assertions above, and the file's header comment.
- [ ] `app/frontend/styles/tokens.css`, `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- tokens; Rarity effects: replace "Under the pointer, every card gets a soft glare…" with the reflection (always on every card, author's decision of 2026-10-13; glossier with the rarity; slides opposite the tilt; Légendaire iridescence); the table row and the Holo/foil sentence: the Légendaire's animated effect is now its glitter (flakes that flash with the tilt and twinkle at rest) over a static iridescence in its reflection (author, 2026-10-13), not a holo sweep and foil, in the booster and everywhere else (keep rays, glow, banner); "Only the Légendaire shines" stays true of that animated effect; the Do/Don't row at line ~871 likewise.
- [ ] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- Motion: the tilt line (line ~316) says the reflection rides the eased tilt in and out; Reduced motion: in the rule's list of things that stop, the holo becomes the Légendaire's glitter twinkle; exceptions: the reflection stays, still, at its rest position.
- [ ] `_bmad-output/initiative-gameble/deferred-work.md` -- new section: the card face baselines (`test/fixtures/files/card_faces/*.png`) predate the reflection and must be regenerated (`UPDATE_CARD_BASELINES=1`) when system tests are rebuilt.

**Acceptance Criteria:**
- Given any card at rest, when the page loads, then its strips, echo and ceiling show at the flat position (and the Légendaire's iridescence), with no inline style.
- Given a Commune and a Légendaire, when both are tilted alike, then the Commune's strips are broader and dimmer, the Légendaire's tighter and brighter.
- Given a Légendaire in view, when it rests or is hovered, then its flakes twinkle, flash as the tilt faces them, and its iridescence slides with the tilt without a jump; no holo sweep or foil drift remains, in the booster or elsewhere.
- Given reduced motion, when a pointer moves over a card, then the card does not tilt and the reflection stays at rest, visible.
- Given the booster, when a revealed card is hovered, then it tilts (16°) and reflects as elsewhere.

## Design Notes

Model (the prototype's 200 × 300 card; % are of the gradient line, so they hold at every 2:3 size):

```
tilt2 = min(1, (dx² + dy²) / 0.5);  fresnel = 0.8 + 0.6·tilt2
strip  = 30 − dx·T·55 − dy·T·30                    (% along 118°)
horizon = −0.32 − dy·T − 0.2·dx·T·aspect           (× card height, along 174°)
hue    = 50 + (dx·0.6 + dy·0.3)·T·100              (% background-position-x)
```

CSS, per rarity `--card-gloss` 0.2, 0.4, 0.6, 0.8, 1 (common → legendary); finish = 0.5 + 0.5·g; curve = 0.8 + 1.4·g; light = `var(--color-text-max)` mixed to transparent (`color-mix`), alpha via `calc` and `pow()`:

- `.card__reflection` base: `position: absolute; inset: 0; pointer-events: none`. Order inside `.card__effects` (now its only children): `--ceiling`, `--iridescence` (legendary only), `--strips`. Each layer has its own opacity (no wrapper), always visible.
- Strips (two backgrounds, echo on top), 118°: main centre c = `--reflection-strip`, half h = (40 + 28·(1 − g)) %, 7 hard rings each side of width h/7, ring k (1 = core) alpha = peak·((8 − k)/7)^curve, peak = 0.065·finish·fresnel; transparent beyond c ± h. Echo at c + 48 %, half 0.35·h, 4 rings, alpha 0.6·peak·((5 − k)/4)^curve.
- Ceiling, 174°, positions as `calc(<share> * var(--card-height))`: alpha 0.0425·finish from 0 to the horizon, then 7 bands of 0.85/7 card height with alpha 0.0425·finish·(1 − k/8)^1.4, then transparent.
- Iridescence: `mix-blend-mode: screen`; background the 7 hue tokens as hard stops repeated 3 times (21 equal stops) at 118°, `background-size: 300% 100%`, `background-position: var(--reflection-hue) 50%`; `mask-image` the main band shape with half 1.15·h, 7 rings, alpha ((8 − k)/7)^curve (black, alpha only); `opacity: calc(0.21 * var(--reflection-fresnel))` (the prototype's 0.42 halved by the author).
- Glitter (prototype `flakeField`): seeded mulberry32 (`seed + 0x6D2B79F5` step), count = round(28 × w·h / 60000); per flake in draw order: x = round((8 + r·(w − 16)) / 2)·2, y likewise with h, nx = (r − 0.5)·0.9, ny = (r − 0.5)·0.9, cross = r < 0.35, colour = [white, white, white, gold, gold, violet, blue][floor(r·7)], period = 2.4 + r·3.6 s, delay = −r·6 s. Colours as tokens: white `--color-text-max`, gold `--color-rarity-legendaire-hi` (#fff3c4), violet `--color-iridescence-2` (#c9a6ff), blue `--color-iridescence-3` (#9ac8ff).
- flash = max(0, 1 − hypot(dx − nx, dy − ny) / 0.14)^1.5; level = 0.5 + 0.5 · round(flash·4)/4; `data-flash` when flash > 0.25.
- Markup built by `attachGlitter` inside `.card__glitter` (absolute, inset 0, last in `.card__effects`): `.card__flake` (2 × 2 px at left/top px, `mix-blend-mode: screen`, `opacity: var(--flake-level)`, colour by modifier class) > `.card__flake-glint` (the 2 × 2 px pixel in the colour; crosses add four 2 px arms by `box-shadow` at 60 % of the colour; opacity 0.18). `.card__flake[data-flash] .card__flake-glint { opacity: 1 }`; `.card[data-in-view] .card__flake:not([data-flash]) .card__flake-glint { animation: card-glitter-twinkle var(--flake-period) steps(1) var(--flake-delay) infinite }`; keyframes 0, 44 % 0.18; 48 % 0.6; 50 % 1; 52 % 0.6; 56 %, 100 % 0.18.
- Reduced motion: remove the glare, holo and foil entries; glints `animation: none`, static at 0.18 (flashing ones too); the other reflection rules are untouched (they do not move without the tilt).

## Implementation Notes

Full route: about 600 lines across tilt.ts, a new glitter module, card.css, the component and the docs. The scope grew during the build, all by the author through the orchestrator: an always-visible reflection driven by the eased tilt, enter/leave factors 0.08/0.075, the Légendaire's iridescence at 0.21 × fresnel, then glitter in place of a hue cycle and of the holo/foil.

- `tilt.ts`: `Tilt` is `{ rx, ry }`; `reflection(dx, dy, aspect)`, `leaning`, `reflectionOf`, `REST_REFLECTION`, `TILT_PROPERTIES`, `EASE_ENTER`/`EASE_LEAVE`, and the `onTilt` option. The aspect comes from the last measured box, 2/3 by default. Entering eases from rest; the old jump that placed the glare at once is gone.
- `glitter.ts`: the seeded field (mulberry32, like the prototype), `flakeFlash`, `flakeLevel`, `glitterSeed`, and `attachGlitter`, which builds the flakes through CSSOM. The tilt controller sizes the field from the computed `--card-width`/`--card-height`.
- `card.css`: one shared stepped band (`--band`) feeds both the strips and the iridescence's mask. Every alpha is computed with `color-mix`, `calc` and `pow()`. The twinkle selector puts `:where()` around the flake so the booster's still rules (loaded later) win on equal specificity.
- Stylesheet tests read `card.css`, `booster.css` and `booster-layouts.css` through `?raw` imports. `vitest.config.ts` lists them in `css.include`, because Vitest otherwise empties imported stylesheets; node `fs` would need `@types/node`.
- The glitter seed is season number × 1,000,000 plus the card number (public values); a missing value counts as 0. `--card-rarity-hi` is gone, since only the holo used it.
- After the subagent returned, I added `glitterSeed` and the stylesheet tests (twinkle in view, still under reduced motion, still on face-down and lower phone booster cards), so the matrix's glitter rows are covered by tests that run.
- The subagent loaded `tokens.css` and `card.css` in headless Chromium: every gradient, mask and animation parses, and the computed values match the model. The system tests were edited, not run.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` Each glint runs its own infinite twinkle, so a phone view can show far more than the architecture's six infinite animations (40 on a card-xl Légendaire, 18 on a card-m). — Real. The author's glitter spec (per-flake period 2.4 to 6 s, negative delay) requires an animation per flake, so the code follows the latest explicit decision, and only the author can settle the conflict with architecture-gameble.md line 308. Recorded in the plan's `deferred` and in deferred-work.md, and flagged in the hand-off. I also reworded the booster-layouts comment so it no longer suggests a budget.
  - `[low]` `[patch]` On a face-down booster card and a lower phone card, flakes that flash at rest kept opacity 1 instead of the matrix's static 0.18. — Patched: the still rules in booster.css and booster-layouts.css (the glint rule split out) now set `opacity: 0.18`, and the stylesheet test asserts it.

## Verification

**Commands:**
- `npm run test:js` -- all pass
- `npm run typecheck` -- clean
- `bin/rails test` (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w747`) -- 0 failures
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- clean

**Manual checks:**
- In the library, every card shows two diagonal strips and a faint ceiling; hovering a corner tilts the card smoothly and slides them opposite the pointer; leaving eases both back; a Commune's strips are broader and duller than a Légendaire's, whose strip shows pastel hues sliding with the tilt; with ANIMATIONS RÉDUITES at OUI the reflection is still and visible.

## Auto Run Result

**Summary:** The round hover glare is gone. Every card face always shows a studio reflection on its varnish: two stepped diagonal strip lights (a main one and a narrow echo) and a faint stepped ceiling. The reflection is white and gets glossier with the rarity (`--card-gloss` 0.2 to 1). At rest the stylesheet's defaults draw it, with no JS. While a card tilts, `tilt.ts` computes it from the eased tilt (never the raw pointer), easing in at 0.08 and out at 0.075 per frame, so nothing jumps and nothing fades. The Légendaire adds a static pastel iridescence (screen blend, masked by the main strip, 0.21 × fresnel) and seeded glitter flakes that flash when the tilt faces them and twinkle in steps while in view. Its holo sweep and foil drift are gone from the card face, in the booster too. Under reduced motion nothing moves and the rest reflection stays visible.

**Files changed:**
- `app/frontend/lib/tilt.ts`: tilt `{ rx, ry }`; `reflection`/`reflectionOf`/`leaning`, `REST_REFLECTION`, `TILT_PROPERTIES`, `EASE_ENTER`/`EASE_LEAVE`, the `onTilt` option; at rest every property is cleared.
- `app/frontend/lib/glitter.ts` (new): the seeded flake field, flash and level, `glitterSeed`, `attachGlitter`.
- `app/frontend/lib/tilt.test.ts`, `app/frontend/lib/glitter.test.ts`: pure functions, entering and leaving with no jump, rest defaults read from card.css, `onTilt`, glitter field, flash and update, still rules in the stylesheets.
- `app/frontend/controllers/tilt_controller.ts`: resets `TILT_PROPERTIES`; wires glitter to the tilt.
- `app/frontend/styles/card.css`: rest defaults, gloss per rarity, the ceiling, strips and echo, iridescence and glitter layers, reduced motion; glare, holo and foil removed.
- `app/frontend/styles/booster.css`, `booster-layouts.css`: face-down and lower phone cards keep their glitter still at 0.18.
- `app/frontend/styles/tokens.css`, `ux-gameble/DESIGN.md`: the seven iridescence tokens; Rarity effects, the table and the Do/Don't row.
- `ux-gameble/EXPERIENCE.md`: the tilt line, the reduced-motion list and its exception.
- `app/components/card_component.rb`, `.html.erb`, `test/components/card_component_test.rb`: the reflection layers, iridescence and glitter (seeded from season and number) on the Légendaire; HOLO/FOIL removed.
- `test/system/card_preview_test.rb`, `test/support/card_baselines.rb`: edited for glitter and reflection, not run (system tests disabled).
- `vitest.config.ts`: lets the stylesheet tests read card.css and the booster stylesheets.
- `deferred-work.md`: stale card-face baselines; the phone animation budget.

**Review:** quick lens, 2 findings. Patched 1 low (flashing flakes held at 0.18 on still booster cards). Deferred 1 medium (the per-flake twinkle against the six-animation phone budget: the author's call). Rejected none.

**Follow-up review recommended:** false. Patched: high 0, medium 0, low 1.

**Verification:**
- `npm run test:js`: 28 files, 273 tests pass.
- `npm run typecheck`: clean.
- `bin/rails test`: 2413 runs, 0 failures.
- `bin/rails zeitwerk:check`: all good.
- `bundle exec packwerk check`: no offenses.
- `bin/rubocop`: no offenses.
- The implementing agent loaded the real stylesheets in headless Chromium: every gradient, mask and animation parses, and the computed values match the model.

**Residual risks:**
- The hover feel has not been checked in the running app with a real pointer.
- The card-face baselines are stale until system tests return.
- `pow()` and `color-mix()` need a current browser; an old one drops the reflection layers silently and shows a plain card.
- The phone animation budget above is deferred.

