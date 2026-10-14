---
title: "The phone tray's thumbnails in pixel art"
type: 'feature'
ticket: '32'
created: '2026-10-14'
status: built
baseline_revision: '2d934a6'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The phone booster tray (`app/frontend/components/BoosterTray.tsx`) shows each card's raw Steam cover, an `<img>` scaled into 44 × 60 with `image-rendering: pixelated`, instead of the pixel filter's palette-reduced art that the design asks for every thumbnail.

**Approach:** Each filled slot draws its cover on a canvas with the card-art filter (`drawCardArt`, the one the card faces use) at 22 × 30 art pixels, one art pixel being 2 CSS pixels, with the palette computed at the card face's largest art (`CardComponent::PALETTE`, sent in the island's props), so the thumbnail shows the same colours as the card. A cover that fails to load hides the canvas; the slot keeps its frame and rarity icon. A slot leaving the tray aborts its draw.

</frozen-after-approval>

## Implementation Notes

Oneshot: one prop, one canvas, their wiring.

- `BoostersHelper#booster_props` sends `artPalette: CardComponent::PALETTE` (109 × 112), typed in `booster_props.ts` and passed by `BoosterView` to the tray.
- `BoosterTray`'s filled slot draws `slot.coverUrl` on a `<canvas class="booster-tray__cover">` with `drawCardArt` at 22 × 30 art pixels and that palette; the effect's cleanup aborts the draw when the slot leaves (a new pack, the wide layout). `drawCardArt` marks the slot button `data-art` and hides the canvas on a failure, so the frame and rarity icon remain. The cover URL is the face's, so the worker's palette cache serves both.
- CSS: `object-fit` dropped from `.booster-tray__cover`; the canvas keeps 44 × 60 and `image-rendering: pixelated`.
- Test: `boosters_controller_test.rb` asserts the palette prop. No component test: vitest has no DOM and the system tests are disabled (deferred).

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 1, low 2, false 0, maybe-false 0

- `medium` defer — no test asserts the filtered thumbnail or the failed cover: vitest runs in node with no DOM and the system tests are disabled, so the coverage needs test infrastructure; recorded in `deferred-work.md`.
- `low` patch — the rewritten header of `BoosterTray.tsx` kept DESIGN.md, EXPERIENCE.md and story ids; removed.
- `low` patch — the `booster_props` comment was left with a short broken line; reflowed. The one-line comment on `THUMBNAIL` stays: it states the art-pixel scale, as `CardComponent::ART` does.

## Verification

**Commands:**
- `bin/rails test test/controllers/boosters_controller_test.rb` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` -- expected: green
