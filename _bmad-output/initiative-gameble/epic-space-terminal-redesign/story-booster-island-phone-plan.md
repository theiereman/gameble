---
title: 'Booster island, phone'
type: 'feature'
ticket: '12'
created: '2026-10-06'
status: 'built'
baseline_revision: '264d96c3d0ca82768e984d2930d39b4f7f6ef66d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Under 720px the booster island shows its desktop row, wrapped (story 8.11 left the phone mode to this story). DESIGN.md and EXPERIENCE.md ask, on the phone, for a pile, one `card-xl` card at a time, tap to reveal, swipe / tap / "RANGER" to store it in a tray, a reveal caption plate hosting the Épique and Légendaire banners, and a card zoom. Two 8.11 deferrals also land here: dealt cards stay `card-m` between 720 and 899px (DESIGN.md asks `card-s`), and before the answer the screen says 5 cards even when the next pack is a 3-card daily bonus.

**Approach:** The one `Booster` island (AD-16) gets a layout — `phone` (< 720px), `narrow` (720–899px), `wide` (≥ 900px) — read from two `matchMedia` queries and carried as `data-layout` on `.booster` (CSS sizes the stage from that attribute, not from its own media queries, so markup and faces never disagree). The phone layout draws the information strip, the canister, the pile, the caption plate with "RANGER", the tray and the zoom; `narrow` deals `card-s` faces (an `s` face joins the answer); a width crossing a breakpoint rebuilds the island in place, keeping the pack and what was revealed, never replaying. The next pack's size comes from the server (a new `Game::NextPackSize`) in the props and in the answer's bank.

## Boundaries & Constraints

**Always:**
- Everything story 8.11 binds still holds (its plan's Boundaries: AD-16 faces only from the answer's server HTML, `gameble:*` events only, AD-23 protocol untouched, AD-18 copy through props and `t()`, AD-25 standard back, AD-27 transform/opacity only, timers and listeners removed on unmount, reduced motion read through `motionReduced()` at each step, navigation lock during the opening and each reveal, browser Back never blocked).
- AD-27 on the phone: portrait column, nothing scaled (the card is always `card-xl` 240×360; a short screen scrolls); `touch-action: none` only on the pile area (the stage's card area and the canister) — the strip, the plate, the tray and the actions keep the page's panning, and `.card` faces inside the pile override their `pan-y`; at most six infinite animations at once on a phone view (only the top pile card runs its sheen, holo, foil and rays; cards under it and stored cards run none; no blinking swipe cue).
- Phone interactions (EXPERIENCE.md Booster, Cards, Interaction Primitives, Focus after each step): only the top card of the pile takes input; one activation (tap, Enter, Space) reveals it; a revealed top card ignores activation for `REVEAL_GUARD` (400ms), then a tap, a swipe or "RANGER" stores it (never a visit to the card page from the pile); a revealed card's tilt under a finger held still 150ms (lib/tilt.ts) is never mistaken for a swipe. Focus: cards landed → top card; a card revealed → stays on it; card stored → the next top card, or "Ouvrir le suivant" (or the island's "Retour au pont" at reserve 0) after the last; zoom closed → its tray slot.
- The caption plate never covers the card: it sits between the card and the tray, the Épique banner and the Légendaire banner ("Légendaire !" with title · year, plate on `--color-plate-legendaire`) play inside it; the desktop overlay banner never shows in the phone layout. One full-screen flash per sequence at most, as on desktop.
- The rebuild on a width change: applied at once while the island is idle (sealed, empty, or dealt with nothing running); while an opening, a reveal, Tout révéler, a store or the sink/dock runs, it waits and is applied the moment the island turns idle. It never sends a request, never replays a deal or a reveal, and keeps the answer, the revealed flags and the counts. Into the phone layout, every revealed card is stored in the tray (by position order), the pile holds the face-down ones; out of it, stored cards show revealed in the row. If focus was inside the island, it lands on the equivalent control (top card / first face-down card, else the open button, else the island's back link).
- Pack size before the answer: the canister's label, CARTES PAR BOOSTER, "Cartes révélées : — / N", the phone's "N cartes" use the size of the pack the next opening will open (`bank.nextPackSize`, falling back to `packSize` when null); after the answer, the answer's card count, as now.

**Never:**
- No change to the opening exchange's semantics or error codes; additions to the answer are display data only (`faces.s`, `bank.nextPackSize`). No new endpoint, no global store, no router, no canvas engine, no mock code copied, no rarity promise.
- No landscape layout, no orientation lock, no manifest work (the PWA manifest is not wired; out of scope). No card backs beyond Standard. No change to the collection, card detail, profile or trade code (stories 10.3/10.4 run in other worktrees). Do not change `Game::BankSummary`'s hash (its whole-hash tests stay as they are).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Phone open | 390×844, ≥1 pack, tap canister | strip "Saison 1 · Grand catalogue" + mini pips + status chip; canister with "Touchez pour ouvrir" and "5 cartes"; one POST; cards land as a pile (bottom first, 1.5× stagger), `card-xl` faces; tray of N empty slots "Carte 0 / N"; hint "Touchez la carte pour la révéler"; focus top card | refusals as desktop (inline reason + toast + live region) |
| Phone reveal | tap / Enter on top face-down card | tier reveal (Légendaire jump ≤ 50px and inside the stage); plate pops (320ms, 380ms Légendaire) with icon, tier, title · year; hint "Glissez la carte pour la ranger · ou touchez-la" hidden behind the plate; live region and top-bar count as desktop | art wait as desktop |
| Store | revealed top card: swipe (\|dx\| > 64, dy < −64 or dy > 90), tap after 400ms, or "RANGER" | card shrinks into its slot (260ms), slot pops, sparks for Épique+; "Carte n / N"; focus next top card; after the last: INVENTAIRE COMPLET, hint done, focus "Ouvrir le suivant" (back link at reserve 0) | short drag (< thresholds): springs back, stays revealed; activation < 400ms after flip: ignored |
| Tilt hold | finger held still 150ms on revealed top card, then moved | card tilts, not stored, not dragged | — |
| Tout révéler (phone) | some in pile | each top card revealed then stored in order (Légendaire in full), one summary | input ignored while it runs |
| Zoom | tap / Enter on a filled tray slot | dialog: `card-xl` face, title, rarity · year line, "Voir la fiche" (primary, visits the card page), "Fermer", tip "Maintenez la carte pour l'incliner", rays from Épique up | Esc, Fermer or scrim: closes, focus back on the slot; slots inert while anything runs |
| Rebuild | dealt at 1400px with 2 revealed, resized to 390 | pile of 3 face-down, tray with the 2 revealed, no request, no replay; back to 1400: row of 5, 2 revealed | change during a reveal: applied after it ends |
| Narrow | 720–899px, opening | dealt cards and slots at `card-s` 112×168 with `faces.s`; crossing 900px swaps to `card-m` in place | — |
| Bonus next | only a 3-card bonus pack available | canister label "… 3 cartes", CARTES PAR BOOSTER 3, "— / 3", phone "3 cartes" | none available: `packSize` (5) |
| Next on phone | all stored, "Ouvrir le suivant" | tray clears, canister docks, next opening (new key); next size from the answer's `bank.nextPackSize` | reserve 0: "Réserve vide" disabled |
| Reduced motion (phone) | emulated | crossfades only, no pile tilt animation, no loops, plate shows without pop, store is an instant move | — |

</intent-contract>

## Code Map

Server:
- `packs/game/app/queries/game/next_pack_size.rb` (new) -- `Game::NextPackSize.call(player, now: Time.current)` → the card count of the pack `Game::OpenPack` would open now (`Pack.where(player_id:).available(now)` — same scope and order as `open_pack.rb` L68 / `pack.rb` L40 — `.pick(Arel.sql("cardinality(card_season_ids)"))`), nil when none. Test in `test/packs/game/` (regular 5, bonus oldest → 3, none → nil, future pack ignored). Packwerk: root package already depends on `packs/game`.
- `app/helpers/boosters_helper.rb` L11-29 -- props `bank` gains `nextPackSize` (keep `packSize: Game::Pack::SIZE` as fallback). Update `test/controllers/boosters_controller_test.rb` L69-71 (exact bank hash) and add a bonus-next case.
- `app/helpers/packs_helper.rb` -- `REVEAL_SIZES = %i[s m xl]` (comment: s in the row 720–899px, m from 900px, xl on the phone); answer `bank` gains `nextPackSize: Game::NextPackSize.call(player, now:)`. Update `test/controllers/packs_controller_test.rb` L365, L377 (`%w[s m xl]`), L378-383, L388 (`json_integers`), L402.
- `config/locales/{fr,en}.yml` `boosters.island.*` -- new keys (Design Notes, Copy). The helper passes `boosters.island` whole, so they reach the props; `config/i18n-tasks.yml` already ignores the subtree for unused.

Client (read 8.11's plan Design Notes first; the structure summary below is from the current code):
- `app/frontend/components/Booster.tsx` (1181 lines) -- state with mirroring refs (`bank`, `phase` `sealed|empty|opening|dealt`, `answer`, `revealed[]`, `revealedAt[]`, `revealingAll`), `revealing` Set, `legendaryRunning`, `opening`, `lockDepth`, timers via `wait`/`later` cleared on unmount; `lock`/`unlock` (346-358), `announce` (362), `requestFocus` + every-render focus effect (372-384), effects `animate`/`settle`/`stageShake`/`stageFlash`/`spark`/`ring`/`burst`/`blast` (388-480), banner (484-507), `refuse` (518), `retract` (537), `blowAndDeal` (577-620, deal measured with `getBoundingClientRect` of the canister button and each slot's `.booster-card__frame`, `dealKeyframes` on `__travel`), `fadeAndDeal` (623), `open` (633-695), `artReady` (699), `mark` (709), `revealTier` (723), `revealLegendary` (775), `revealStill` (839), `complete` (860), `reveal` (865), `revealAll` (884), `activateCard` (913, desktop visit), refresh-at-zero (939-953), JSX (982-1180: `section.booster` › `aside.booster__info` + `div.booster__stage` › `.booster__shake` › dim, fx, zone/canister, result head, `ol.booster__deal` of `BoosterCard face={card.faces.m}`, hint; banner; flash; live region). `packSize` used at L152, 238, 965-966, 996, 1073. No resize/matchMedia handling yet. Add: `layout` state + the two queries, the pending rebuild applied at idle, `stored[]` (phone), the phone deal/reveal/store/revealAll branches, `bank.nextPackSize`. Keep one `reveal` path: the phone differences (plate instead of overlay banner, lift fitted, jump `min(LEGENDARY_JUMP_PX, headroom × 0.6)`) are branches inside it, not a copy. If the file grows past ~1500 lines, move the phone-only pieces into components below.
- `app/frontend/components/BoosterCard.tsx` -- takes `face` (pick `faces.s|m|xl` by layout in the parent), gains phone props (`depth` in the pile → pose custom properties via React `style`, `top`, `inert` when not top, stored → not rendered in the pile); its hit button's name on a revealed phone card is `faceUpStore`. Holo/foil/sheen/rays only on the top card in the phone layout (CSS on `[data-top]`).
- New `app/frontend/components/BoosterStrip.tsx` (phone info strip), `BoosterPlate.tsx` (caption plate + RANGER + the hint line it replaces), `BoosterTray.tsx` (label "Carte n / N", N slots 44×60: empty `span`, next empty outlined, filled `button` with the cover thumbnail from `card.coverUrl` (`image-rendering: pixelated`) and the rarity icon), `BoosterZoom.tsx` (native `<dialog>` + `showModal()`, `cancel` event for Esc, scrim click closes, focus returned to the slot; second render of `faces.xl`). Reuse `lib/dialog.ts` (`openDialog`/`takeOpener`) only if it fits React; otherwise mirror its behaviour.
- `app/frontend/lib/booster.ts` + `booster.test.ts` -- add pure, tested: `layoutFor(phone: boolean, narrow: boolean)`, `faceSize(layout)` (`xl|s|m`), `pilePose(depth)` (y = 5·d px, scale 1 − 0.02·d, rotate (d odd ? +1.4 : −1.4)·min(d, 2)°), `pileOrder(count)` (bottom first: [n−1…0]), `topOfPile(revealed, stored)`, `swipeStores(dx, dy)` (|dx| > 64 or dy < −64 or dy > 90), `SWIPE_START = 10`, `storedAfterRebuild(revealed, stored, layout)`, phone timings: `PHONE_DEAL_STAGGER = DEAL_STAGGER × 1.5`, `STORE_MS = 260`, `SLOT_POP_MS = 260`, `PLATE_POP_MS = 320`, `PLATE_POP_LEGENDARY_MS = 380`, `SPRING_BACK_MS = 260`, `RESTACK_MS = 200`, `PHONE_ALL_HOLD` (Épique+ `scaled(320)`, else `scaled(150)`), `TRAY_SPARKS = 10`.
- `app/frontend/lib/opening.ts` + test -- `faces: { s; m; xl }`, `bank.nextPackSize: number | null`; `isCard` checks every face string.
- `app/frontend/lib/swipe.ts` -- existing `swipeStep` (card detail); do not change its threshold; the booster uses its own `swipeStores`. `app/frontend/controllers/sub_view_controller.ts` L138-170 shows the touch-pointer press/drag/release pattern and the `[data-tilting]` check to copy.
- `app/frontend/lib/tilt.ts` -- `HOLD_MS = 150`, sets `[data-tilting]` while driven, swallows the click after a hold; read-only.
- `app/frontend/styles/booster.css` -- layout by `.booster[data-layout]`: `narrow` slots/faces `--card-s-*`; `phone`: strip, stage bands (card bottom-aligned above the 52px plate band, tray 60px at the bottom, min-height 510px, page scrolls when shorter), pile absolute stack at `card-xl`, plate (panel bg, 6px left bar in tier colour, inset border; Légendaire `--color-plate-legendaire`), RANGER (secondary, 44px), tray, zoom dialog (scrim rgba(4,7,10,.88), card-xl, rays 520×520 from Épique up), actions row under the stage; `touch-action: none` on `.booster[data-layout=phone] .booster__pile` and its `.card`; replace the L983 `@media (max-width: 719px)` stage rule; reduced-motion rules for the new pieces. `card.css` L20-21 defines only `--card-m-width/height` on `:root` (160×240); add `--card-s-width/height` (112×168) and `--card-xl-width/height` (240×360) beside them. `tokens.css` L45 has `--color-plate-legendaire`.
- `app/views/boosters/show.html.erb` -- unchanged unless the fallback needs a phone tweak.
- Tests: `test/system/booster_test.rb` (helpers `open_screen`, `open_canister`, `assert_dealt`, `card(n)`, `hit(n)`, `state`, `assert_announced`, `assert_focus`, `revealed_at`, `reduce_motion`, `PHONE = [390, 844]`; rewrite the phone test at L573-587), `test/system/card_detail_test.rb` L70 `swipe(dx)` (synthetic touch PointerEvents, pointerId 7) to copy, `test/system/card_face_visual_test.rb` L63-89 (revealed case) + `test/support/card_baselines.rb`, `test/application_system_test_case.rb` (`SCREEN_SIZE`, `resize_to` via `page.driver.browser.manage.window.resize_to`).

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/next_pack_size.rb` + test -- the next pack's size -- deferral (bonus pack size).
- [x] `app/helpers/boosters_helper.rb`, `app/helpers/packs_helper.rb`, their controller tests -- `nextPackSize` in props and answer, `faces.s` -- deferrals.
- [x] `config/locales/{fr,en}.yml` -- new `boosters.island.*` keys -- AD-18.
- [x] `app/frontend/lib/booster.ts`, `opening.ts` + tests -- pure layout, pile, swipe, rebuild helpers, timings, types.
- [x] `app/frontend/components/Booster.tsx`, `BoosterCard.tsx`, new `BoosterStrip.tsx`, `BoosterPlate.tsx`, `BoosterTray.tsx`, `BoosterZoom.tsx` -- layouts, phone flow, rebuild, pack size.
- [x] `app/frontend/styles/booster.css`, `card.css` (size custom properties) -- phone and narrow layouts, touch-action, loop budget, reduced motion.
- [x] `test/system/booster_test.rb` -- new system tests (below); `test/system/card_face_visual_test.rb` -- a phone revealed case (390×844, screenshot the top pile card's frame after its reveal, settled) writing `test/fixtures/files/card_faces/revealed-xl.png` with `UPDATE_CARD_BASELINES=1`, checked by eye, then passing without it; update the file header.
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- mark resolved: the `card-s` deal entry, the phone mode entry, the pre-answer pack size entry (each with what was done); add entries for anything deferred here (at least: phone gestures checked only with synthetic pointer events in headless Chromium — check on an iOS Safari and an Android Chrome device).

System tests to add (phone at 390×844 unless said; reduced motion as the file's setup does, except where named):
1. Phone flow: strip, "Touchez pour ouvrir", "5 cartes"; open; pile of 5 `.card--xl` faces with the top card focused; tap reveals (plate shows tier, title · year; the plate's box does not intersect the card's box); RANGER stores the first, a tap after 400ms the second, a swipe (synthetic touch pointer events) the third; "Carte 3 / 5"; focus on the next top card after each; a short drag springs back and stores nothing; after the fifth, INVENTAIRE COMPLET and focus on "Ouvrir le suivant".
2. Zoom: a filled slot opens the dialog (title, "Voir la fiche", "Fermer", tip); Esc closes it with focus back on the slot; "Voir la fiche" visits the card page.
3. Tout révéler on the phone stores every card in the tray, one summary announced.
4. With motion: a Légendaire on the phone shows "Légendaire !" inside the plate, never over the card (no `.booster__banner` overlay), SIGNAL LÉGENDAIRE during the sequence.
5. Rebuild: dealt at 1400 with two revealed → resize to 390: pile of 3, tray with 2, one request only; back to 1400: 5 slots, 2 revealed, no `data-revealed-at` changed.
6. Narrow: at 800×900 the dealt faces are `.card--s` and each slot is 112px wide.
7. Bonus next: only a bonus pack available → the canister label and the counter say 3 before the answer.
8. Loop budget: on the phone at rest, after the deal and after an Épique reveal (motion on), `document.getAnimations()` running with infinite iterations ≤ 6.

**Acceptance Criteria:**
- Given a phone viewport, when a player opens a booster, reveals and stores five cards, and opens one in the zoom, then each step behaves as the matrix says and focus follows EXPERIENCE.md's focus table.
- Given cards dealt on one side of 720px (or 900px), when the width crosses it, then the island shows the same pack in the other layout without a request or a replayed animation.
- Given the full suite, when run, then every Verification command passes.

## Implementation Notes

Built in two runs (the first was cut off after the server side, the locales, the pure helpers and `BoosterCard`'s pile props; the second checked that work against the Code Map, kept it and finished the island, the stylesheet, the tests and the notes).

Decisions:
- "Ranger" sits inside the caption plate, on its right (44px tall in the 52px plate): DESIGN.md puts it "under" the plate, but the stage's bands (card, 8px, 52px plate, tray) leave no row for it at 510px.
- The phone's stage is a three-row grid (pile, plate band, tray; 8px gaps, 6px under the tray); the canister zone spans it. The plate band sits above the stage's dim (z-index 6, so a Légendaire's "Légendaire !" is not dimmed) and under the pile's cards (z-index 20 − depth, so a stored card flies over it to the tray).
- With about 16px above the large card, the reveal's swell (its scales) is damped to a quarter on the phone (`phoneSwell`, tested) so the card never grows over the plate; the Légendaire's jump is `phoneJump(headroom)` as planned (about 9px). Noted in deferred-work.md.
- The swipe lives in `components/useCardSwipe.ts` (React pointer handlers on the top card's slot, pointer capture, `[data-tilting]` appearing during the gesture makes it a tilt; a mark already there at the press does not count, since a mouse tilts the face on hover). A click within 300ms of a drag's end is the drag's own and never stores the card.
- On the phone the booster is complete (INVENTAIRE COMPLET, focus "Ouvrir le suivant") once the last card is stored, not revealed; "Ouvrir le suivant" enables once every card is revealed, as on desktop. A rebuild with every card revealed sets INVENTAIRE COMPLET in either layout.
- `gameble:bank-changed` keeps its four fields: the island strips `nextPackSize` from its bank before dispatching.
- `Booster.tsx` ends at about 1600 lines: the phone's presentational pieces (`BoosterStrip`, `BoosterPlate`, `BoosterTray`, `BoosterZoom`), the swipe hook and the desktop information column (`BoosterPanel`, the strip's counterpart) moved out; the store, Tout révéler's phone branch and the rebuild stay in the island, which owns the refs they drive.
- The tray's cover thumbnail hides itself when it does not load (the fixtures' covers never do), keeping the slot's frame and icon.

Verification: `node script/pixel_art/export.mjs --check` (82 files up to date); `bin/rubocop` no offenses; packwerk validate and check clean; `i18n-tasks missing` none (`unused` clean too); typecheck ok; Vitest 166 passed; `bin/rails db:test:prepare test` 1216 runs, 0 failures; `bin/rails test:system` 100 runs, 0 failures (a first run had 11 errors and 2 failures from editing the frontend while it ran: Vite rebuilt mid-suite and lost its fonts; rerun clean). `booster_test.rb` alone 32 runs clean; `card_face_visual_test.rb` twice clean after writing `revealed-xl.png` (looked at: the tilted Tin Soldier face, xl). The tilt-hold test was checked to fail with the tilt guard removed. Manual: headless Chromium screenshots at 390 × 844 and 360 × 740 (rest, dealt pile, Épique with its plate, Légendaire sequence, tray half full, zoom) and 800 × 900 (narrow deal) under `tmp/screenshots/booster-phone-*.png`: nothing scaled, no sideways scroll, the plate under the card, at most six loops (rest 3, dealt 1, Épique 3, zoom open 6).

Files touched beyond the Code Map: `app/controllers/boosters_controller.rb` (`@next_pack_size`), `app/frontend/components/BoosterPanel.tsx`, `app/frontend/components/useCardSwipe.ts`, `_bmad-output/initiative-gameble/deferred-work.md`.

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` On the phone the Légendaire's impact keyframes (centre-origin swell on `__lift`, plus the `:focus-visible` 8px hover lift after a keyboard activation) push the card's top edge 5–13px above the stage, over the strip, for about 360ms — real (16px headroom, `phoneJump` counts neither the swell nor the hover lift), but transient, Légendaire-only, and a fix needs the stage geometry reworked; the small phone headroom is already recorded in deferred-work.md ("a taller stage on taller phones would give the jump its room").
  - `[low]` `[reject]` The pile cards' inline `zIndex: 20 - depth` puts the cards under a Légendaire above `.booster__dim` (z 5), so their 5–20px edges stay undimmed during the sequence — real, cosmetic and Légendaire-only; lowering the pile's z-index would send a stored card under the plate band (z 6) during its flight to the tray, so the fix is more than a direct correction.
  - `[low]` `[patch]` "Tout révéler" could start while a store was running (no `storing` term in `revealAllDisabled`, no `storingRef` check in `revealAll`), skipping the in-flight card's store in the loop and letting its `requestFocus("card")` land mid-run — fixed: the button is disabled while storing and `revealAll` returns early when `storingRef.current` is set.
  - `[low]` `[patch]` `BoosterPlate`'s `storeBusy` comment claimed it covered the 400ms guard, while the island passes `busy` (no guard term) — fixed: the comment now says what it carries and that the island ignores a press during the guard.
  - `[low]` `[reject]` The zoom line (`%{rarity} · %{year}`) and the phone plate line (`bannerLine`) leave a trailing " · " for a card with no year — real but unlikely (catalogue cards carry a Steam release year; the desktop banner from 8.11 already uses the same `year ?? ""` pattern), and the fix adds a branch to the copy.
  - `[low]` `[patch]` `RESTACK_MS` was exported but unused (booster.css hard-codes the 200ms restack transition) — fixed: the constant is deleted (no test referred to it).

## Design Notes

**Phone layout** (DESIGN.md Booster information panel, Reveal caption plate, Tray, Card zoom; mock `mobile.html` 356–490, 981–1026 for look only): the strip (44px: left the kicker "Saison 1 · Grand catalogue" ellipsised, mini pips (10 × 8px in an 84px row) and "+1 dans <clock>" / "Réserve pleine"; right the status chip: 8px light + state word); the stage (min-height 510px): canister 200×300 centred near 44 % of the stage height with "Touchez pour ouvrir" and "N cartes" under it, or the empty state; once dealt, the pile (card bottom edge 8px above the plate band), the plate band (52px; the hint line sits there while no plate shows), the tray (bottom 6px, centred, gap 6px: "Carte" over "n / N", then the slots); under the stage, the actions row: "Ouvrir le booster/le suivant/Réserve vide" (primary) and "Tout révéler", then the island's "Retour au pont" link and the reason line. The revealed counter row is not shown on the phone (the tray carries the count). The live region and the counts are the same as desktop.

**Pile deal**: same blast; each card travels from the canister centre to its pile pose (`pilePose(depth)`, depth 0 = top = lowest unstored position), bottom card first, `PHONE_DEAL_STAGGER` apart; the end keyframe is the pile pose (travel layer) so no snap. After a store, the remaining cards re-pose (`RESTACK_MS`, ease-spring). z-index 20 − depth.

**Store**: the revealed top card's `__travel` (or a dedicated `__float` layer between travel and hover that also carries the swipe drag) animates to the slot's centre (measured with `getBoundingClientRect`) scaled to 44/240, fading at the end, `STORE_MS`; then the card leaves the pile (`stored[i] = true`, tray slot filled), slot pops (`SLOT_POP_MS`), Épique+ sparks (`TRAY_SPARKS`) at the slot. Swipe drag: starts after `SWIPE_START` px on a touch/pen/mouse pointer on the revealed top card, follows the finger (translate dx, dy, rotate dx × 0.05°), released → `swipeStores` ? store : spring back (`SPRING_BACK_MS`); a gesture during which `[data-tilting]` appeared is a tilt, never a swipe; pointer capture and cancel handled; listeners removed on unmount.

**Rebuild**: `layout` state; `pendingLayout` ref set by the media listeners; `applyLayout()` runs when idle (checked after `unlock()` to depth 0 and at the end of open/revealAll/store/retract). Apply = set `stored` per `storedAfterRebuild`, `setLayout`, bump a `stageKey` that remounts the stage's card subtree (fresh elements without inline WAAPI transforms; dealt cards render at their rest pose with `data-dealt`), restore focus.

**Copy** (`boosters.island.*`, fr / en, natural case): `strip_title` "Saison %{number} · Grand catalogue" / "Season %{number} · Grand catalogue", `strip_title_plain` "Grand catalogue", `canister_hint_touch` "Touchez pour ouvrir" / "Tap to open", `canister_facts` one "%{n} carte" other "%{n} cartes" / "%{n} card(s)", `hint_tap` "Touchez la carte pour la révéler" / "Tap the card to reveal it", `hint_swipe` "Glissez la carte pour la ranger · ou touchez-la" / "Swipe the card to store it · or tap it", `store` "Ranger" / "Store", `face_up_store` "%{card}, %{rarity}. Ranger la carte." / "%{card}, %{rarity}. Store the card.", `tray` "Cartes rangées" / "Stored cards" (the tray's accessible name), `tray_label` "Carte" / "Card", `tray_count` "%{n} / %{total}", `tray_slot` "%{card}, %{rarity}. Agrandir." / "%{card}, %{rarity}. Enlarge.", `zoom_line` "%{rarity} · %{year}", `see_card` "Voir la fiche" / "See the card", `close` "Fermer" / "Close", `zoom_tip` "Maintenez la carte pour l'incliner" / "Hold the card to tilt it". Strings typed in `BoosterStrings`.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails db:test:prepare test` -- 0 failures, 0 errors
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- 0 failures, 0 errors (known flaky: card_detail_test phone Back leg, tome_test art: rerun alone and record)

**Manual checks:**
- Headless Chromium screenshots at 390×844 and 360×740 (rest, pile dealt, a revealed Épique with its plate, tray half full, zoom open) and 800×900 (narrow deal) under `tmp/screenshots/booster-phone-*.png`, looked at: nothing scaled, no sideways overflow, the plate never over the card.

## Auto Run Result

**Summary.** The booster island gains its phone mode and a narrow layout: three layouts (`phone` < 720px, `narrow` 720–899px, `wide` ≥ 900px) read from two media queries and carried as `data-layout`; on the phone the information strip, the canister ("Touchez pour ouvrir", "N cartes"), a pile of `card-xl` faces (top card only takes input), tap to reveal, a tap after the guard / a swipe / "Ranger" to store into the tray ("Carte n / N"), the caption plate hosting the tier and the Épique / Légendaire banners (never over the card), Tout révéler storing each card, and the card zoom (native dialog, Voir la fiche / Fermer, Esc back to the slot); a width crossing 720 or 900px rebuilds the island in place once idle (no request, nothing replayed). The narrow layout deals `card-s` faces (new `s` face in the answer). Before the answer the screen counts the next pack's size (`Game::NextPackSize`, `bank.nextPackSize`), so a daily bonus pack first in line says 3.

**Files changed.**
- `packs/game/app/queries/game/next_pack_size.rb` (+ test) — the next pack's card count.
- `app/controllers/boosters_controller.rb`, `app/helpers/boosters_helper.rb`, `app/helpers/packs_helper.rb` (+ controller tests) — `nextPackSize` in the props and the answer, `faces.s`.
- `config/locales/{fr,en}.yml` — `boosters.island.*` phone copy.
- `app/frontend/lib/booster.ts`, `opening.ts` (+ tests) — layout, pile, swipe, rebuild helpers, phone timings, types.
- `app/frontend/components/Booster.tsx`, `BoosterCard.tsx` — layouts, phone flow, store, rebuild, pack size.
- New `BoosterStrip.tsx`, `BoosterPlate.tsx`, `BoosterTray.tsx`, `BoosterZoom.tsx`, `BoosterPanel.tsx`, `useCardSwipe.ts` — the phone pieces, the desktop information column, the swipe.
- `app/frontend/styles/booster.css`, `card.css` — narrow and phone layouts, touch-action, loop budget, reduced motion, card size properties.
- `app/views/boosters/show.html.erb` — the next pack size in the props.
- `test/system/booster_test.rb`, `test/system/card_face_visual_test.rb`, `test/fixtures/files/card_faces/revealed-xl.png` — phone, rebuild, narrow, bonus-next, loop-budget tests and the xl baseline.
- `_bmad-output/initiative-gameble/deferred-work.md` — three 8.11 entries resolved, three new entries.

**Review.** Quick lens, 6 findings, all low: 3 patched (Tout révéler during a store, the `storeBusy` comment, the unused `RESTACK_MS`), 3 rejected (the Légendaire's transient overflow above the phone stage — covered by the existing headroom deferral; undimmed pile edges during a Légendaire; a trailing " · " for a card without a year). Nothing deferred from the review.

**Follow-up review recommendation:** false (patched: high 0, medium 0, low 3).

**Verification.** After the patches: `node script/pixel_art/export.mjs --check` ok; `bin/rubocop` no offenses; packwerk validate + check clean; `i18n-tasks missing` none; typecheck ok; Vitest 166 passed; `bin/rails db:test:prepare test` 1216 runs, 0 failures; `CHROME_BIN=/usr/bin/chromium bin/rails test:system` 100 runs, 0 failures. Matrix audit: every row covered by a passing system test (phone flow, zoom, Tout révéler + next on phone, Légendaire plate, tilt hold, rebuild, rebuild during a reveal, narrow, bonus next, loop budget; reduced motion is the file's default setup).

**Residual risks.** Phone gestures verified only with synthetic pointer events in headless Chromium (deferred: real iOS Safari / Android Chrome check); tray thumbnails skip the pixel filter (deferred); the phone stage leaves ~16px above the card, so the Légendaire's jump is small and its impact briefly crosses the stage's top edge (deferred entry on the headroom); `Booster.tsx` is ~1600 lines.

