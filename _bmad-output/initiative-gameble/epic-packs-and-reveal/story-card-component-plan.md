---
title: 'Card component'
type: 'feature'
ticket: '5'
created: '2026-10-02'
status: done
baseline_revision: '55ca9d310265c7cde281c613a1aa3e1fa7dcbed8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Every screen that shows a card (the reveal, the library, trades, public pages) needs one card with one look, server-rendered and in React, and none exists (epic 3, R6, R7; DESIGN.md, Card face, Card back, Rarity seal, Dust).

**Approach:** Build the card once: markup and CSS rendered identically by a ViewComponent and a React component, with the hand-drawn pixel parts (backs, seals, digits, dust) generated once as static assets from the mockups' own drawing code, so both renderers share one source and the final art can later replace the files. The face draws the filtered Steam art with `pixel-art-filter`. An administrators-only preview page shows both renderers side by side.

## Boundaries & Constraints

**Always:**
- Data: `CardView` (`id`, `title`, `publisher` nil-able, `year`, `season_number`, `rarity` — the `Catalog::Rarity::TIERS` name, e.g. `"sapphire"` —, `dust` 0–4, `image_url`), from `Catalog::CardViews.call(card_season_ids, locale:)` → `{ card_season_id => CardView }`, one query: title per locale from `catalog_card_texts`, `year` from `catalog_cards.release_date`, `publisher` from `catalog_cards.publisher` (not localised), `rarity` and `dust` from the card-season, `season_number` from `catalog_seasons.number`; a card-season without rarity or dust (draft) is left out. `CardView#to_props` and a TypeScript `CardView` type mirror each other (camelCase); story 3.6 consumes both, and replaces 3.1's `CardSeasonLabels` use in `PacksController`.
- Strings: `CardStrings` passed once per island, pre-resolved on the server: rarity names by rarity, face-down labels by rarity ("Face-down card, Sapphire") plus the plain "Face-down card", and "Season %{n}" resolved per card where shown (AD-16; no `%{}` interpolation on the client).
- Pixel assets: `script/card_art/generate.mjs` (Node, no new dependency) runs the drawing functions of `mockups/card-backs.html` and `card-face.html` with a pixel sink and writes pixel-rect SVGs into `app/frontend/images/card/`: one back per tier, one dust overlay per level 1–4, and one sprite of `<symbol>`s for the five seals and the digit and letter glyphs (fixed advance per glyph). The generated files are committed; both renderers reference them through Vite asset URLs; no `id` other than the sprite's symbol ids. The large back: the 80 × 120 back drawn at ×3 (as `mockups/key-screens.html` does) — Assumption, recorded in `pending-approvals.md` until the author decides on a redrawn 120 × 180 back.
- Face (layout A of `card-face.html`): ink 1, brass (3 art px large / 1 small, light top-left, dark bottom-right), ink 1, rarity piping 2 (light top-left), ink 1; art window 104 × 164 art px large / 68 × 108 small (canvas 208 × 328 / 136 × 216 CSS px, inset 16 / 12 px), `{colors.surface-sunken}` when empty or failed; plate at the bottom overlapping the art, preceded by an ink line and a 1-pixel rarity line, title clamped to two lines (full text in the DOM), the publisher on the large size only when present; year tag top left and season seal just above the plate from sprite glyphs, the seal widened for two-digit seasons; the rarity name as visually hidden text (rarity never by colour alone). Legendary: gold frame, a light band sweeping across, blinking sparkles; with `prefers-reduced-motion` no sweep and sparkles shown still. Plate heights in even CSS pixels.
- Back: the tier's back asset; the seal from the sprite in the medallion; a square outline for every tier (the legendary's rounded corners are its corner fittings, in the asset); dust as a real `.card__dust` element, last child, `pointer-events: none`, its background the level's overlay, no element at level 0, `card--dust-N` on the root — so story 3.6 can fade, mask or erase it. The back root is `role="img"` with `aria-label` "Face-down card, <rarity>" when `sealVisible` (React prop, default true) else "Face-down card"; seals and decor `aria-hidden`.
- Both renderers: `CardComponent.new(card:, size: :small | :large, side: :face | :back, strings:)` and `<Card card size side strings sealVisible? />` produce the same element tree and BEM classes (`card`, `card--small|large`, `card--face|back`, `card--rarity-<name>`, `card--dust-N`); `span`s inside, no tabindex, no interactive element, no `overflow`/`transform` on the root (3.6 wraps and flips it); one stylesheet `app/frontend/styles/card.css` on the DESIGN tokens; one art pixel = 2 CSS px; hard ink shadow.
- Art: one helper `app/frontend/lib/card_art.ts` used by a Stimulus `card-art` controller and the React card: calls `renderArt` with an `AbortSignal` aborted on disconnect/unmount; on success shows the canvas; on failure (not on `AbortError`) hides it so frame and title remain; sets `data-art="drawn|failed"`. A Turbo restore visit draws again.
- Preview: `/<locale>/back-office/cards`, administrators only (policy tested), builds five `CardView`s in the controller (no database) whose `image_url` is a bundled sample image under `app/frontend/images/` (same origin, not Steam, not in `public/`) and one with a missing same-origin URL; shows every tier's face and back at both sizes, and one tier's back at each dust level, pairing each server card with its React twin under `data-pair="<rarity>-<side>-<size>[-dust-N]"`. The React side is one `CardPreview` island (a back-office-only Turbo Mount registration, a recorded exception to AD-16's two islands); `Card` itself is imported by 3.6, not registered.

**Never:** no reveal interaction (3.6); no card detail page; no image stored or proxied; no new npm or gem dependency; no Steam URL in the web layer.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Face, small | sapphire card | title, year tag, season seal, sapphire piping, hidden "Sapphire"; no publisher | — |
| Face, large | with / without publisher | publisher line / none | — |
| Long title | 80 characters | two lines shown, full text in the DOM | — |
| Season ≥ 10 | season 12 | seal widened, both digits | — |
| Legendary | gold | gold frame, sweep, sparkles; reduced motion (CDP emulation): no sweep animation, sparkles still | — |
| Back | each tier | its back and seal; `aria-label` with the rarity; plain label when `sealVisible` false | — |
| Dust | levels 0–4 | no element at 0; `.card__dust` with the level's overlay at 1–4 | — |
| Art | bundled sample | canvas drawn, `data-art="drawn"` | — |
| Art fails / aborted | missing URL; disconnect mid-load | canvas hidden, frame and title / canvas left as is | — |
| Same markup | each `data-pair` once islands mounted and art settled | equal normalised projections (tag, sorted classes, role, aria-*, `use href`, collapsed text; `data-*`, style, size and hidden excluded) | — |
| Query | three card-seasons in `fr`; a draft card-season | three `CardView`s with French titles, years, seasons; the draft left out | — |
| Preview access | administrator / moderator / visitor | page / 403 / sign-in | policy |

</frozen-after-approval>

## Code Map

- `_bmad-output/initiative-gameble/ux-gameble/mockups/{card-face,card-backs,key-screens}.html` -- the drawing functions (`seal()`, `dust()`, `corners()`, the back) to run in the generator.
- `packages/pixel-art-filter/src/index.ts` -- `renderArt`.
- `app/components/*`, `app/frontend/components/SampleIsland.tsx`, `app/frontend/entrypoints/application.ts` (Turbo Mount registration), `app/frontend/controllers/*`, `app/frontend/styles/tokens.css`.
- `packs/catalog/app/queries/catalog/card_season_labels.rb` (3.1) -- neighbour query.
- `app/controllers/back_office/*`, `app/policies/back_office/*`, `config/routes.rb`, `test/system/*`.

## Tasks & Acceptance

**Execution:**
- [x] `script/card_art/generate.mjs` and the generated `app/frontend/images/card/*`.
- [x] `packs/catalog/app/queries/catalog/card_views.rb` (+ `CardView`).
- [x] `app/components/card_component.{rb,html.erb}`; `app/frontend/components/{Card,CardPreview}.tsx`, `app/frontend/lib/card_art.ts`, `app/frontend/controllers/card_art_controller.ts`, `app/frontend/styles/card.css`, the sample image.
- [x] back-office preview controller, policy, route, view, locales; `pending-approvals.md` entry for the large back.
- [x] `test/` -- component tests for the server-side rows; query; policy; a system test for the art, reduced motion and the paired markup comparison.

**Acceptance Criteria:**
- Given the preview page as an administrator, when it loads and settles, then every tier's face and back at both sizes and every dust level show in both renderers with equal normalised markup, and the sample art is drawn.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `npm run test:js`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `CardView#id` is the card's slug, not the card-season id: AD-15 keeps database ids out of HTML and props. The preview's samples use `sample-<rarity>`.
- `CardView` lives beside its query (`packs/catalog/app/queries/catalog/card_view.rb`); `CardStrings` is a web-layer class (`app/components/card_strings.rb`), built with `CardStrings.for(cards)`; its `seasons` map is keyed by the season number as a string.
- Generator: the mockups' last `<script>` runs under a stub DOM with a compositing pixel sink; colours per `<path>`, rectangles merged across rows, alpha to two decimals (dust overlays 40–128 KB uncompressed). The legendary seal's sparkles (the plus around each point `seal()` lists) go to the gold back; every other seal pixel, the amethyst's ribbon included, stays in its seal symbol. Seal symbols have the card's 80 × 120 viewBox, so `.card__seal` covers the back.
- Season seal: one seal for both sizes, the mockup's large one (radius 8, 18 × 18), widened by 8 columns (26 × 18) for two digits. The mockup's small seal (radius 7) is one pixel too narrow for "S" and a digit at the fixed glyph advance. Both renderers add `card__season--wide` for two digits.
- Vite: `build.assetsInlineLimit` never inlines `images/card/`, so the sprite URL the server writes (`vite_asset_path`) and the one the React card imports are the same file (the paired comparison checks `use href`).
- `CardPreview` is registered in `application.ts` through `React.lazy`, so its code loads only on the back-office page that mounts it.
- The plate's padding follows the DESIGN text-plate tokens (4 px × 12 px), not the mockup's 4 px sides; titles 12/14 px small, 15/18 px large, publisher 12/14 px; the sweep is a skewed band stepped in art pixels, its colour `--color-gold-light` at the mockup's alphas.
- Not covered by an automated test: `sealVisible: false` (React only; no React test harness in `test:js`) and an abort mid-load (the code returns on `AbortError` without touching the canvas).

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 2, low 4, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | The season seal sat one art pixel low, over the plate's ink line | Confirmed by screenshot pixels. `bottom: calc(100% + 3 * var(--space-unit))`. |
| 2 | low | patch | The season seal sat two art pixels too far from the art's right edge | Confirmed against the mockup's `cx`. `right: var(--space-unit)`. |
| 3 | medium | patch | The amethyst ribbon was generated into the back, not the seal, so 3.6 hiding the seal would leave its tails | Confirmed in the generated SVGs. The generator moves only the gold seal's sparkle points to the back; regenerated. |
| 4 | medium | patch | After a Turbo restore `data-art` stayed "drawn" on a blank canvas, and the test did not wait for the redraw | Confirmed. `drawCardArt` clears the mark and un-hides before drawing; the test stales the mark first and waits for a fresh one. |
| 5 | low | patch | `<use>` content lost `crispEdges` | `.card svg { shape-rendering: crispEdges }`. |
| 6 | low | patch | A missing season string raised on the server but rendered empty in React | `Card.tsx` throws too; server test added. |


## Verification

**Commands:**
- `node script/card_art/generate.mjs && git status --short app/frontend/images/card` -- expected: no change (generated files committed).
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && npm run test:js` -- expected: green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
