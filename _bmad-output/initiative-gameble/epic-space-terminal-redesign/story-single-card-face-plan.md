---
title: 'Single card face'
type: 'feature'
ticket: '6'
created: '2026-10-05'
status: done
baseline_revision: 'e319f0ad3962253991a2c729bdd0249dda71fda8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
warnings: [oversized]
deferred:
  - summary: >-
      A phone's long press on a card face inside a link may open the link's context menu or a text selection, cancelling the finger's tilt after about 500 ms.
    evidence: |-
      attachTilt handles no contextmenu and .card sets no -webkit-touch-callout or user-select rule; settle it with a long press on a tome face on Android Chrome and iOS Safari.
    location: >-
      app/frontend/lib/tilt.ts (attachTilt)
    severity: medium (unverified)
  - summary: >-
      Every card face registers a non-passive touchmove listener, so a touch scroll starting on a card may wait for the main thread on long pages.
    evidence: |-
      tilt.ts adds touchmove with { passive: false } per card (tome up to 300 faces, AD-27 low-end Android budget); settle it with a performance trace of a touch scroll over the tome on a low-end Android device. Adding the listener only while a finger tilts would not work (Chrome classifies a touch sequence at its start).
    location: >-
      app/frontend/lib/tilt.ts:216
    severity: medium (unverified)
  - summary: >-
      The card face visual baselines were captured with Manjaro's Chromium and may exceed the 1.5 mean-difference tolerance on CI's ubuntu-latest Chrome.
    evidence: |-
      CI's system-test job sets no CHROME_BIN; font rasterisation and 3D resampling can differ between builds. Settle it with the first CI run after the commit.
    location: >-
      test/support/card_baselines.rb, test/fixtures/files/card_faces/
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Cards are still drawn twice (CardComponent and the React `Card.tsx`) with the retired medieval face (metal frame, glyph year, season seal, dust); the face lacks genre, rarity shape and name, and season number; four DESIGN sizes, tilt, glare, holo and foil do not exist; `Catalog::CardView` and its queries still read `dust_tier` (R3; AD-16, AD-27, AD-28).

**Approach:** Rewrite `CardComponent` as the only card face per DESIGN.md (Card face, sizes s/m/l/xl, Rarity icon, Rarity effects), with a `tilt` Stimulus controller over a shared `app/frontend/lib/tilt.ts` (tilt, glare, holo/foil only in the viewport, reduced motion off), its art drawn by the existing `card-art` controller at the new art sizes. The PackReveal island receives each face as server-rendered HTML and draws only the back and the turn; `Card.tsx` and the `CardPreview` island go; the back-office preview shows server faces at each size; nothing reads `dust_tier`.

## Boundaries & Constraints

**Always:**
- DESIGN.md wins over the mocks (`ux-gameble/mockups/key-screens.html` is look reference only, never source). Exact token values from `app/frontend/styles/tokens.css` (`--font-card-title-{s,m,l,xl}`, `--font-card-meta`, `--font-card-meta-xl`, `--font-publisher-{m,l,xl}`, `--color-rarity-*`, `--color-publisher`, `--card-face-bevel`, `--pixel-outline-4`).
- No `style` attribute in server HTML (AD-16); dynamic values are custom properties set by a controller (`element.style.setProperty("--…")`). Listeners, observers and timers removed on disconnect.
- Infinite animations animate only `transform`/`opacity` (never `background-position`); holo and foil run only while the card is in the viewport (`data-in-view`); under reduced motion (`@media (prefers-reduced-motion: reduce)` and `html[data-motion=reduced]`, and `motionReduced()` in JS) tilt, glare, holo and foil are off.
- 3D card stack rule (EXPERIENCE.md, Implementation notes): no `overflow`, `filter`, `opacity < 1`, `clip-path`, `mask`, `mix-blend-mode` or `isolation` on the `.card` root (the tilt layer); effects are clipped inside an inner `.card__effects` box. No 3D transform on a `<button>`.
- All new copy in `config/locales/fr.yml` and `en.yml`, natural case (uppercase by CSS), "vous". Repo text in English.
- Card number format: `S<season> · #<number>` on l/xl, `#<number>` on s/m, digits grouped with U+00A0 (`CardView#number_label`); nil number → no number shown.

**Never:**
- No React card renderer of any kind; the island never builds face markup. No new island.
- Do not drop the `dust_tier` column, its check constraint, the `CardSeason` enum/`SEASON_DATA` entry, `Catalog::Dust`, the write in `PublishSeason` or the draft preview's dust table (story 8.7's contract step). Only reads for display go.
- Do not restyle the home/attic page (story 8.2 runs in parallel), the collection/detail screen layouts (epic-space-terminal-screens), or build the booster choreography, 3D flip, card backs catalogue or rays (8.8, 8.11). No CSP change. Never push or deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Face at a size | `CardComponent.new(card:, size: :s/:m/:l/:xl)` | `.card.card--<size>.card--rarity-<tier>`; title band (title; publisher on m/l/xl only), art box, footer line 1 genre + year, line 2 rarity icon + name + number | unknown size → `ArgumentError` |
| No genre / no number / no publisher | `genre: nil`, `number: nil`, `publisher: nil` | the element is omitted, layout keeps its heights | — |
| Missing art | `card-art` marks `data-art=failed` | canvas hidden, `.card__missing` (pixel picture icon + "Image indisponible") shown, frame/title/footer kept | not cached (filter v2) |
| Art loading | before draw | dark hatched art box | — |
| Pointer over a face | mouse/pen moves over `.card` | eases toward rotateX/rotateY ≤ 10° (16° with `booster: true`), glare follows; `data-tilt="held"` once settled on a target; leave → eases back, attributes removed at rest | reduced motion → nothing |
| Touch | finger held still 150 ms | tilt follows the finger until release; a vertical drag before 150 ms scrolls (`touch-action: pan-y`) | `pointercancel` releases |
| Effects | legendary, default context | holo sheen only; rare/epic none | not in viewport → no animation |
| Effects, booster | `booster: true` | rare holo 45 %; epic holo 70 % + foil 8 %; legendary holo 100 % + foil 22 % | reduced motion → none |
| Pack reveal | opening redirect | island shows backs (seal per tier, island-drawn), each turn reveals the server face HTML; m on desktop, xl on phone | — |

</intent-contract>

## Code Map

- `app/components/card_component.rb/.html.erb` -- rewrite; drop `strings:` and `side:` (rarity name via `t("catalog.rarity.<code>")`, genre via `SetLabel.genre(key)`); `SIZES = %i[s m l xl]`; `ART` in art pixels (half DESIGN's CSS art box): s 50×51, m 72×74, l 94×97, xl 109×112; palette size = `ART[:xl]`. Rarity icon via `helpers.pixel_icon` (`rarity-compact-N` on s/m, `rarity-N` on l/xl, N = `Catalog::Rarity::TIERS.invert`).
- `app/components/card_strings.rb` -- keep rarity names and face-down labels (island, `card_detail_open_label`); remove seasons (`cards.season` key) and `.for(cards)` → `CardStrings.new`; callers `app/views/library/_tome.html.erb`, `app/views/cards/_detail.html.erb`, `app/helpers/card_details_helper.rb`, `packs_controller.rb`.
- `packs/catalog/app/queries/catalog/card_view.rb` -- remove `dust` and `to_props` (no consumer left); `number_label(with_season: true)`. `card_views.rb`, `card_detail.rb` -- drop `dust_tier` column, `dust:` and `.where.not(dust_tier: nil)`.
- `app/frontend/lib/card_art.ts` -- drop `CARD_ART`/`CardSize`; `drawCardArt` takes `paletteWidth/paletteHeight` (default: the art size). `controllers/card_art_controller.ts` -- add `paletteWidth`/`paletteHeight` Number values (0 → art size). `test/system/card_art_test.rb` injects elements at 68×108 with no palette values: keep working.
- `app/frontend/lib/motion.ts` (`motionReduced`), `lib/events.ts` -- reuse. `app/helpers/shell_helper.rb#pixel_icon` -- inline icons.
- `script/pixel_art/export.mjs` -- add `rarity-compact-1..5` (5×5, legend `RARITY[tier]`, h/b/l edges, distinct in grayscale: disc, ring with centre dot, diamond, triangle, star) and `picture` (≈10×8, `c` currentColor: frame, sun, mountain); run it, commit outputs; `--check` test exists.
- `app/frontend/styles/card.css` -- rewrite for the new face; `library.css` uses `--card-small-width/height` for empty slots (rename to m sizes); `card-detail.css`, `entrypoints/application.css` (`.card-preview*`) -- adjust selectors.
- `app/frontend/components/PackReveal.tsx`, `RevealCard.tsx`, `lib/reveal.ts` (+ test) -- `Rarity` type moves from `Card.tsx` to new `app/frontend/lib/card_types.ts` (with `CardStrings` TS type = `CardStrings#to_props`). Reveal states (`dusty/wiped/flipped`) and timings stay; only the dust overlay goes.
- `app/controllers/packs_controller.rb#reveal_props` -> new `app/helpers/packs_helper.rb#pack_reveal_props` (view context, renders `CardComponent` to HTML). `app/views/packs/show.html.erb` -- sizes.
- `app/frontend/entrypoints/application.ts` -- unregister `CardPreview`. Delete `components/Card.tsx`, `components/CardPreview.tsx`, `images/card/dust-*.svg`. Keep `images/card/back-*.svg` and `sprite.svg` (`seal-<tier>` for the island's backs).
- `app/controllers/back_office/cards_controller.rb`, `app/views/back_office/cards/index.html.erb` -- server faces only.
- Tests touching the old face: `test/components/card_component_test.rb`, `test/controllers/{packs,cards,library_set,public_profiles,daily_bonuses}_controller_test.rb`, `test/controllers/back_office/cards_controller_test.rb`, `test/packs/catalog/{card_views,card_detail}_test.rb`, `test/system/{card_preview,card_art,pack_reveal,card_detail,public_profile,tome}_test.rb` (`.card--face`, `.card--small/large`, `.card--dust-*`, `data-pair`, `.card__plate`).

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` + generated `app/frontend/images/pixel/{rarity-compact-1..5,picture}.svg` -- compact rarity shapes and the missing-image icon.
- [x] `packs/catalog/app/queries/catalog/{card_view,card_views,card_detail}.rb` -- no `dust`, no `to_props`, `number_label(with_season:)`; update `test/packs/catalog/{card_views,card_detail}_test.rb` (number_label short form, no dust).
- [x] `app/components/card_component.rb/.html.erb` -- `CardComponent.new(card:, size: :m, booster: false)`. Root `<span class="card card--<size> card--rarity-<tier>[ card--booster]" data-controller="tilt" data-tilt-max-value="10|16">`. Inside `.card__body` (panel): `.card__band` (`.card__title`; `.card__publisher` unless s), `.card__art` (`card-art` controller with url, art width/height, palette = xl; canvas `.card__canvas` aria-hidden; `.card__missing` with `pixel_icon("picture")` and `t("cards.face.image_missing")`), `.card__line` (`.card__genre` if genre, `.card__year`), `.card__line card__line--rarity` (icon, `.card__rarity` name, `.card__number` if number). Then `.card__effects` (aria-hidden): `.card__holo` when legendary or (booster and rare+), `.card__foil` when booster and epic+, `.card__glare`.
- [x] `app/frontend/styles/card.css` -- full rewrite: sizes (s 112×168 frame 3 / m 160×240 frame 4 / l 208×312 frame 5 / xl 240×360 frame 6; body padding = 3/4/5/5; art box CSS = 100×102 / 144×148 / 188×194 / 218×224 fixed; footer line heights 12+14 / 14+16 / 16+20 / 18+24; gaps 2/2/4/4; the title band flexes to the rest), frame = rarity colour + `--pixel-outline-4` + `--card-face-bevel`; band `--color-panel-raised` with 3px rarity tick (inset box-shadow); title uppercase, 2-line clamp; hatched art background; white corner brackets (::before/::after, 8px, 2px stroke, TL and BR); icon 10px (s/m) / 14px (l/xl); `[data-tilt]` root transform `perspective(…) rotateX(var(--tilt-rx)) rotateY(var(--tilt-ry))`, `touch-action: pan-y`; glare = oversized radial-gradient element moved by `translate(var(--glare-dx), var(--glare-dy))`, opacity 0 → 1 under `[data-tilting]`; holo = diagonal band sweeping by `translateX` in steps; foil = oversized rainbow gradient drifting by `translateX` slowly; animations only under `.card[data-in-view]`; per-tier/context opacities from the matrix; reduced-motion blocks.
- [x] `app/frontend/lib/tilt.ts` + `lib/tilt.test.ts` -- pure `tiltTarget(x, y, rect, max)` → `{ rx, ry, glareDx, glareDy }` (rx = −(py−.5)·max, ry = (px−.5)·max) and `attachTilt(element, { max })` → detach fn: pointer (mouse/pen) move/leave, touch hold 150 ms (cancel if moved > 6 px first), rAF easing (factor ≈ .16) that snaps when close; sets `--tilt-rx/--tilt-ry/--glare-dx/--glare-dy`, `data-tilting` while a pointer drives it, `data-tilt="moving"|"held"` (held = settled on a non-zero target), removes all at rest; no-op when `motionReduced()` at pointer start. `app/frontend/lib/in_view.ts` -- one shared `IntersectionObserver`, `observeInView(element, callback) → unobserve`.
- [x] `app/frontend/controllers/tilt_controller.ts` -- value `max` (Number, 10); connect: clear stale attributes/properties (Turbo snapshot), `observeInView` toggling `data-in-view`, `attachTilt`; disconnect: undo all.
- [x] `app/frontend/lib/card_art.ts`, `controllers/card_art_controller.ts` -- palette values as in Code Map.
- [x] Views -- `library/_tome.html.erb` and `packs/show.html.erb` → `size: :m`; `cards/_detail.html.erb` → `size: :xl`; `CardStrings.new` call sites; `library.css`/`card-detail.css` follow.
- [x] `app/helpers/packs_helper.rb`, `packs_controller.rb`, `packs/show.html.erb` -- props `{ cards: [{ rarity, title, faces: { m: html, xl: html } }], cardStrings: CardStrings#to_props, strings, openPackUrl, atticUrl }`, faces rendered with `booster: true`.
- [x] `app/frontend/lib/card_types.ts`, `components/PackReveal.tsx`, `RevealCard.tsx`, `lib/reveal.ts`, `styles/reveal.css` -- RevealCard draws the back itself (`<span class="card-back card-back--<m|xl> card-back--rarity-<tier>" role="img" aria-label>` with `<svg class="card-back__seal"><use href=sprite#seal-<tier>>`), the face side is `dangerouslySetInnerHTML` of `faces[size]` (memoised object); sizes `m`/`xl`; back CSS moves from card.css to reveal.css (no dust).
- [x] `app/frontend/entrypoints/application.ts`; delete `Card.tsx`, `CardPreview.tsx`, `images/card/dust-*.svg`.
- [x] `app/controllers/back_office/cards_controller.rb`, `app/views/back_office/cards/index.html.erb`, `entrypoints/application.css` -- per tier, faces at s, m, l, xl (`data-specimen="<tier>-<size>"`), then each tier at m with `booster: true` (`<tier>-m-booster`); samples get genre keys from `catalog.genres` (one nil), numbers as now (epic nil), uncommon art still the 404 URL; intro/labels rewritten.
- [x] `config/locales/{fr,en}.yml` -- `cards.face.image_missing` ("Image indisponible" / "Image unavailable"); back-office preview copy (sizes s/m/l/xl, booster label); remove `cards.season`, `back_office.cards.index.{dust_label,sides,server,react}` and the old sizes.
- [x] Tests -- rewrite `card_component_test.rb` (each size's parts, publisher absent on s, genre/number/publisher nil, number label short/long, icon per size, effects per tier and booster, tilt max, no `style` attribute anywhere, art values incl. palette); `back_office/cards_controller_test.rb`; `card_preview_test.rb` (every specimen drawn at its art size, missing art placeholder, long title two lines, holo animation only when in view and off under reduced motion, Turbo restore redraws); update the other listed tests; `lib/tilt.test.ts`; new `test/system/card_face_visual_test.rb` (below).

**Acceptance Criteria:**
- Given the repository, when grepping `app packs lib` for `dust_tier`, `dust_tiers`, `\.dust\b`, `Card.tsx`, `CardPreview`, then only `catalog/card_season.rb` (enum, SEASON_DATA), `catalog/dust.rb`, `publish_season.rb`, `draft_preview.rb`, the back-office draft preview and `game_benchmark.rake` remain (writes and draft statistics, story 8.7).
- Given the back-office preview (motion allowed), when the pointer rests over the rare face at 25 %/25 % of each size s, m, l, xl and the tilt holds, then a screenshot of its specimen matches the committed baseline `test/fixtures/files/card_faces/tilted-<size>.png` (mean absolute difference per channel ≤ 1.5, same dimensions) and the card's computed transform is 3D (not `none`).
- Given a freshly opened pack with motion allowed, when card 1 is flipped, its reveal is over and the pointer rests on it, then the revealed face tilts (`data-tilt=held` on `.reveal-card__face .card`), shows its title and matches `revealed-m.png` on desktop and `revealed-xl.png` at 390×844.
- Given any page showing cards (tome, pack result, card detail, public card page, pack reveal, back-office preview), when rendered, then every face is CardComponent markup and no element carries a `style` attribute in the server HTML.

## Implementation Notes

- Footer at size s: Silkscreen 10px with 1px tracking is about 9px per character, so the rarity name and `#<number>` cannot both fit in the s card's 92px line; the rarity name (and a long genre) ellipsize, the number and year stay whole. The mock hides the number and year on s; DESIGN.md and this plan keep them. Open point for the UX owner.
- Default-context legendary holo opacity is 0.6 (the matrix gives no figure outside the booster).
- `tilt.ts` measures the card's layout box once per drive (dropped on release or scroll), so the card's own tilt never moves its target and a resting pointer settles deterministically (needed by the visual baselines).
- A finger's tilt swallows the click that follows its release, so a card inside a link (tome, pack result) does not open after a hold; a quick tap still clicks.
- `packs/show.html.erb` (faces on later visits) renders `size: :m` without `booster`; only the reveal's faces carry `booster: true`.
- `script/card_art/generate.mjs` no longer writes the dust overlays (it was not re-run; backs and sprite are unchanged).
- Visual baselines live in `test/fixtures/files/card_faces/` (tilted-s/m/l/xl, revealed-m/xl), compared by `test/support/card_baselines.rb`; the revealed card is the pack's common card (no infinite effect in the booster), its cover unreachable so it shows the missing image.

- Verify (orchestrator): the matrix audit found no test for the hatched art box or the epic booster opacities; `card_preview_test.rb` now asserts the art box's `repeating-linear-gradient` and epic holo 0.7 / foil 0.08 in the booster.
- `cards/_detail.html.erb` serves both the card detail and the public card page (cards#show); it renders `xl` as planned, DESIGN's public card page size (DESIGN gives `card-l` for the collection detail screen, rebuilt in epic-space-terminal-screens).

- Rebased (orchestrator, 2026-10-06): story 8.2 (hub, sign-in panel; 0b39a97) and a docs commit landed under this work, so the baseline moved from 6155bb4 to e319f0a. `packs_controller#reveal_props` went to `PacksHelper#pack_reveal_props` with 8.2's `backToHub`/`hubUrl`; the `SampleIsland` registration stays gone. The hub showcase (`pages/_showcase.html.erb`), new in 8.2, now renders `CardComponent.new(card:, size: :xl)` (DESIGN card-xl, desktop hub showcase; phone card-l stays transitional per deferred-work.md); `pages_controller_test` and `hub_test` assert `.card--xl`; `card_face_visual_test` opens its pack from hub menu 01 (or the empty showcase on a phone), as `pack_reveal_test` does.

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 8 findings — high 0, medium 1, low 3, false 0, maybe-false 4
- findings:
  - `[medium]` `[patch]` `tiltTarget` reaches only `max` / 2 at an edge (5°, 8° in the booster) where EXPERIENCE.md (Motion, Tilt) asks about 10° and 16° — the plan's formula halved it; `rx`/`ry` now `−(py−.5)·2·max` / `(px−.5)·2·max`, comment and `tilt.test.ts` updated, the six visual baselines regenerated (`UPDATE_CARD_BASELINES=1`) and re-compared.
  - `[low]` `[patch]` `step()` left `data-tilt="moving"` on a card driven but resting (pointer on its centre), with no frame scheduled to clear it — now no `data-tilt` when settled at rest while driven; new `tilt.test.ts` case.
  - `[maybe-false]` `[defer]` a phone long press on a face inside a link may open the context menu or a selection and cancel the finger's tilt after ~500 ms — needs a device test (Android Chrome, iOS Safari); medium if true; deferred-work.md.
  - `[maybe-false]` `[defer]` a non-passive `touchmove` listener on every face may delay touch scrolls starting on cards on long pages — needs a performance trace on a low-end Android; medium if true; the obvious fix (listener only while tilting) does not work in Chrome; deferred-work.md.
  - `[low]` `[patch]` holo and foil animate on reveal faces still face down (`visibility: hidden` does not end the intersection) — `reveal.css` sets `animation: none` on `.card__holo`/`.card__foil` of an unflipped reveal card.
  - `[maybe-false]` `[defer]` the visual baselines, captured with Manjaro's Chromium, may fail on CI's Chrome — settled by the first CI run; medium if true; deferred-work.md.
  - `[low]` `[patch]` `application.ts` kept two blank lines where the `CardPreview` registration was — one removed.
  - `[low]` `[patch]` `script/card_art/generate.mjs` still produced the season seal and glyph symbols nothing reads — their generation and header lines removed, and the 38 symbols stripped from `images/card/sprite.svg` by hand (the script cannot run: its mockup `card-backs.html` is gone, deferred-work.md).

## Design Notes

- Visual regression helper (in the new test or `test/support/`): screenshot the specimen's container with `element.native.screenshot_as(:png)`, compare with ruby-vips (`(a - b).abs.avg`); `UPDATE_CARD_BASELINES=1` writes the baselines instead; on failure save actual and diff under `tmp/screenshots/`. Before shooting: `document.fonts.ready`, art settled (`[data-art]`), `[data-tilt=held]`, and `card.getAnimations({ subtree: true })` empty (glare transition over). Use the rare sample (no infinite effect outside the booster). Fixture covers in the reveal are unreachable: the placeholder is deterministic.
- The pointer: Selenium actions `move_to(element.native, dx, dy)` (offsets from centre). Tilt is off under reduced motion; `pack_reveal_test` emulates it by default, so its new test turns it off.
- Work in the main checkout `/home/teyermann/projets/gameble` (branch `main`); leave every change uncommitted (the orchestrator commits the story once reviewed). Another agent works on story 8.2 in a separate worktree: do not touch the home/attic page.
- `pack_reveal_props` is a view helper so `render(CardComponent.new(...))` runs in the view context; Stimulus connects `card-art` and `tilt` inside the island's injected HTML on its own.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test` -- pass
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- pass (the default `gameble_test` database)

## Auto Run Result

- **Summary:** `CardComponent` is the only card face (title, publisher on m/l/xl, cover drawn by `card-art` with the xl palette, genre, year, rarity icon and name, season number) at the four DESIGN sizes s/m/l/xl, with the `tilt` Stimulus controller over `lib/tilt.ts` (tilt up to 10°, 16° in the booster, glare, touch hold of 150 ms, reduced motion off) and `lib/in_view.ts`, holo and foil per tier and booster running only in the viewport. The pack reveal receives each face as server HTML (`PacksHelper#pack_reveal_props`, m and xl, `booster: true`) and draws only the backs and the turn; `Card.tsx`, `CardPreview.tsx`, the dust images and every display read of `dust_tier` are gone; the back-office preview shows every tier at each size and in the booster. Rebased over story 8.2: the hub showcase renders the xl face.
- **Files:** `app/components/card_component.{rb,html.erb}` (the face), `card_strings.rb` (back strings only); `packs/catalog/app/queries/catalog/{card_view,card_views,card_detail}.rb` (no dust, `number_label(with_season:)`); `app/frontend/lib/{tilt,in_view,card_types,card_art,reveal}.ts`, `controllers/{tilt,card_art}_controller.ts`; `components/{PackReveal,RevealCard}.tsx` (server faces); `styles/{card,reveal,library,card-detail}.css`, `entrypoints/application.{css,ts}`; `app/helpers/{packs,card_details}_helper.rb`, `packs_controller.rb`, `back_office/cards_controller.rb`; views `packs/show`, `library/_tome`, `cards/_detail`, `pages/_showcase`, `back_office/cards/index`; `config/locales/{fr,en}.yml`; `script/pixel_art/export.mjs` + `images/pixel/{rarity-compact-1..5,picture}.svg`; `script/card_art/generate.mjs` + `images/card/sprite.svg` (no season seal or glyphs), `images/card/dust-*.svg` deleted; tests (component, controllers, catalog queries, `tilt.test.ts`, system tests, new `card_face_visual_test.rb`, `test/support/card_baselines.rb`, six baselines).
- **Review:** quick lens, 8 findings — 5 patched (1 medium: tilt range; 4 low: resting `data-tilt`, face-down holo/foil, blank line, dead sprite symbols), 3 deferred unverified (long press on links, non-passive touchmove, baselines on CI), none rejected.
- **Follow-up review:** `false` — first pass, one medium and no high patched.
- **Verification:** `node script/pixel_art/export.mjs --check` (29 files up to date), `bin/rubocop` (no offenses), `packwerk validate && check` (clean), `i18n-tasks missing` (none), `npm run typecheck`, `npm run test:js`, `bin/rails db:test:prepare test`, `CHROME_BIN=/usr/bin/chromium bin/rails test:system` — all pass after the review patches (vitest 126 tests, Rails 1131 runs, system 69 runs with no failure, `pack_reveal_test` included, in two full runs this session; the visual baselines regenerated after the tilt fix and re-compared).
- **Residual risks:** the three deferred items; the s face's footer ellipsizes the rarity name (open point for the UX owner); the hub showcase uses card-xl on the phone too (deferred-work.md).

