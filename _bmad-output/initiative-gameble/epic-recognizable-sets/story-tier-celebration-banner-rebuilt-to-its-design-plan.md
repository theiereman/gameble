---
title: 'Tier celebration banner rebuilt to its design'
type: 'feature'
ticket: '17'
created: '2026-10-17'
status: 'built'
baseline_revision: 'e4847af41d8814f0b1bcc22d7dd520ca825fcb6c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/set-celebration.html'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The booster's set celebration still draws entry 5's first build (hazard ticks around the tier title, a left colour bar), which the author rejected; DESIGN.md "Set celebration" and EXPERIENCE.md (copy deck, Capsule > Set celebration, Reveal abandoned, Motion, reduced motion, accessibility) now draw "M1 · Jauge puis ruban".

**Approach:** Rebuild `BoosterCelebration` and its CSS to the spines: a panel with the set's name and count, a gauge that fills to the count before the capsule then crosses the tier tick in the tier colour, then a tier ribbon wiping onto the top edge, with juice by tier; each result is a link to the set's album (the folded line to the collection), and coming back from that album shows the results still. The spines win over the mock (`ux-gameble/mockups/set-celebration.html`) on conflict.

## Boundaries & Constraints

**Always:**
- Keep entry 5's behavior: which results (one per set, highest tier), when (hand complete, no banner showing), order (highest tier, then name), fold above three, cleared when the next capsule opens, one live-region announcement, never takes focus, never blocks RANGER / OUVRIR LA SUIVANTE, nothing changes on a timer, phone "▸" (button "Résultat suivant") keeps focus and wraps.
- Each result is one `<a>` (whole banner its target) to `library_set_path(kind, key)`; the folded line to `library_path`. Its accessible name (`aria-label`) is the result's live message plus the hint sentence ("… 16 cartes sur 62. Voir le set." / "… Voir les sets en cours."); everything decorative inside is `aria-hidden`. `data-turbo-prefetch="false"`.
- Clicking a celebration link first names the pack and the celebration in the screen's history entry; a restored hand (`props.opened`) whose URL carries that mark shows its results at once in their final state (no entrance, no new announcement). A new opening drops both marks.
- Gauge: count before = (lowest `required` among this set's rows in `setTiers`) − 1, floored at 0; count after = the result's `required` (entry 5's figure); this capsule's share at least 1.5 % of the bar wide. Tiered result: ticks at 10/25/50 % (fixed positions, as `.set-row__tick`), a tier at or below the result's tier solid and raised, above it dashed with hollow notches; ticks this opening crossed light as the fill passes them, lower first. SET COMPLET: no ticks, the bar turns lime.
- Motion, juice, sizes and colours exactly as DESIGN.md "Set celebration" and EXPERIENCE.md Motion state (stacked results 180 ms apart; ≤ 0.9 s each; then still). Reduced motion (both `prefers-reduced-motion` with `html:not([data-motion="full"])` and `html[data-motion="reduced"]`, as the file's existing pattern): a 200 ms opacity crossfade of each result in its final state, no gloss, glint, spark or glow.
- Folded line: accent ribbon "n PALIERS ATTEINTS" with no leading mark, the four tier marks (lit in tier colour when any result reached that tier, hollow otherwise), sub-line "dont <set> <TIER>" naming only the highest result, hint "EN COURS ▸" bottom-right, no gauge.
- Phone: the result plate as DESIGN.md "Phone" says; the "1 / n" + "▸" column only with more than one non-folded result; "▸" brings the next result in with its entrance.
- Every new string in `en.yml` and `fr.yml` under `boosters.island.celebration`. English announcements read "cards out of" (copy deck).
- Pixel icons only through `script/pixel_art/export.mjs` (add an `album` icon, 7 × 6 at 2×, from the mock's grid) and passed to the island as HTML from the server.

**Never:**
- No change to which tiers are recorded, the events, the feed, the ticker or `Game::*` tier logic; no migration.
- No celebration on a restored hand without the mark (card-detail returns stay as entry 5); no auto-focus, no timers that change content, no loops.
- No `style` attribute in server HTML (React `style` with CSS custom properties in the island is fine: it is set through CSSOM). No planning ids or explanatory comments in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Silver crossed | Roguelike silver required 16, total 62 | gauge 15/62 → 16/62, silver tick lights, bronze tick solid, gold dashed; ribbon "PALIER ARGENT" with 2 notches; link `/fr/library/theme/roguelike`, name "Palier argent atteint : Roguelike, 16 cartes sur 62. Voir le set." | — |
| Double crossing | bronze 1 and silver 1 rows for one theme of 3 | one result PALIER ARGENT, before 0, both ticks light, bronze first | — |
| Set complete | franchise complete 3/3 | lime bar, no ticks, ribbon "SET COMPLET" led by ✓, stamp frame after the name | — |
| Gold + complete together | gold 31 and complete 62 rows | SET COMPLET, before 30 | — |
| Folded | 4 sets: silver, gold, bronze, complete | one banner "4 PALIERS ATTEINTS", all four marks lit, "dont Dark Souls COMPLET", link `/fr/library` | — |
| Folded, partial | 4 bronze results | only the bronze mark lit | — |
| Return from album | click a result, Back | capsule dealt face up, results shown still, no announcement | — |
| Return from card detail | hand complete, open a card, Back | no celebration (entry 5) | — |
| Restored URL kept after a new opening | open next capsule | marks dropped from the URL | — |

</intent-contract>

## Code Map

- `app/frontend/components/BoosterCelebration.tsx` -- rewrite: desktop `<ul>` of linked banners (index → `--i`), phone plate (link + optional step column), folded banner; sparks as `<i>` with `--dx/--dy/--k` from a pure helper; props gain `still`, `inProgressUrl`, `icons` (`next`, `check`, `album` HTML), `onLeave` (called on link click). Drop the old header comment and hazard ticks.
- `app/frontend/lib/celebration.ts` (+ `celebration.test.ts`) -- `CelebrationResult` gains `url`, `before`, `crossed: SetTierName[]`; helpers: gauge fractions (from/to with the 1.5 % floor), tick states (solid / crossed / pending with each crossed tick's light delay from the fill timing 80 ms + 380 ms, 45 % then the rest), folded marks lit, folded sub-line parts, link names; spark offsets (deterministic). `CelebrationStrings` gains `setHint`, `foldedHint`, `openSet`, `openInProgress`, `foldedLead`, and `tiers.complete`. Tests for every matrix row that is pure.
- `app/frontend/lib/opening.ts` (+ `opening.test.ts`) -- `OpeningSetTier.url: string`, checked in `isSetTier`.
- `app/frontend/lib/booster_page.ts` (+ `booster_page.test.ts`) -- a second query mark for "celebration shown"; `withPack`/`rememberPack` set it on demand, drop it with the pack (null); a reader for the current location.
- `app/frontend/components/Booster.tsx` -- initial `celebration` from `restored` when the mark is present (`celebrationAnnounced` already true, `still`); `still` false for a live opening; pass `onLeave` = `rememberPack(token, celebration)`; `rememberPack(null)` at a new opening (line ~504) drops both. `app/frontend/components/BoosterView.tsx` (~line 234) passes the new props.
- `app/frontend/lib/booster_props.ts` -- `inProgressUrl`, `celebrationIcons`.
- `app/helpers/boosters_helper.rb` -- `inProgressUrl: library_path`, `celebrationIcons` (`arrow-small-right`, `check`, `album` via `pixel_icon` with a celebration class). `app/helpers/packs_helper.rb#pack_set_tiers` -- add `url: library_set_path(kind:, key:)`.
- `script/pixel_art/export.mjs` -- `album` icon (grid `######.`, `#....##`, `#.##.##`, `#....##`, `#.##.##`, `######.`, text colour) and its DESCRIPTIONS line; run `node script/pixel_art/export.mjs`, then `--check`.
- `app/frontend/styles/booster.css` (lines ~969-1090 replace the old celebration block and its keyframes) and `booster-layouts.css` (phone block ~319-356, reduced-motion blocks ~666 and ~702) -- the new banner. Tokens exist in `tokens.css` (tier-bronze, tier-silver, gold, lime, on-gold, on-lime, on-accent, outline, panel-raised, panel-sunken, line-soft, line-deep, text-max, text-bright, muted, focus-ring-*). Art shades (spark light/dark per tier) as listed in DESIGN.md, local custom properties scoped to `[data-tier]`. The phone band row already grows (`minmax(52px, auto)`); keep `flex: 1 1 100%` under 1260px.
- `config/locales/{en,fr}.yml` `boosters.island.celebration` -- new keys; French plural keys keep `zero`.
- Tests: `test/controllers/packs_controller_test.rb` (~431, ~464 expected hashes gain `url`), `test/controllers/boosters_controller_test.rb` (tiers now include complete; new props `inProgressUrl`, `celebrationIcons`).
- Don't touch: `Game::*`, `pack_set_tiers` ordering, `celebrationResults` ordering and fold rules, the announcement text in French, `app/views/packs/show.html.erb`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs`, `app/frontend/images/pixel/album.svg` (generated) -- album icon.
- [x] `app/helpers/packs_helper.rb`, `app/helpers/boosters_helper.rb`, `app/frontend/lib/opening.ts`, `app/frontend/lib/booster_props.ts` -- album URL per result, in-progress URL, icons.
- [x] `app/frontend/lib/celebration.ts`, `app/frontend/lib/booster_page.ts` -- pure gauge/tick/folded/link-name/spark helpers; the celebration mark in the URL.
- [x] `app/frontend/components/BoosterCelebration.tsx`, `Booster.tsx`, `BoosterView.tsx` -- the rebuilt banner, links, still mode on return.
- [x] `app/frontend/styles/booster.css`, `booster-layouts.css` -- the design, motion and reduced motion.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- copy.
- [x] Tests: `celebration.test.ts` (each tier, double crossing, complete, folded lit marks and sub-line, link names fr and en-style, gauge floor), `booster_page.test.ts` (mark set, kept, dropped), `opening.test.ts` (url required), Ruby tests above.

**Acceptance Criteria:**
- Given an opening that crosses a theme's silver, when the hand completes on desktop, then one banner shows under the counter with the ribbon "PALIER ARGENT", the set's name and "16/62", a gauge with its three ticks, the hint "VOIR LE SET ▸", and the live region speaks once.
- Given that banner, when the player activates it and then goes Back from the album, then the capsule shows its cards face up and the same banner still, and the album's back button read "◀ CAPSULE".
- Given four results on the phone, when the hand completes, then the plate shows the folded line as one link to the collection, with no "1 / n" column.
- Given the change, when the checks run, then `bin/rails test`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` and `node script/pixel_art/export.mjs --check` pass.

## Implementation Notes

- Tick lights follow the plan's fill formula (`fillReaches`), so the crossed tick's sparks and the count roll land when the fill passes the tick (e.g. about 355 ms for Roguelike silver), not at the mock's fixed 440 ms; SET COMPLET keeps 440 ms.
- The celebration mark is set only by a result's link and dropped only with the pack (`rememberPack(null)` at a new opening); a card-detail visit made after an album return keeps it, so Back from that card shows the results still too. A live celebration followed by a card detail still celebrates nothing on return.
- The folded line carries no sparks, glosses or glints: the spines list none for it (the mock had them).
- The stamp frame and ribbon wipe start fully clipped (`inset(-4px calc(100% + 4px) -4px -4px)`) so the tilted frame's outline leaves no sliver before it prints.
- Matrix audit: the return-from-album and return-from-card rows had no test (no DOM harness); the restored hand's decision moved into a pure `restoredCelebration(setTiers, marked)` in `lib/celebration.ts`, tested both ways.
- Verified the final, mid-entrance, reduced-motion and still states by rendering the component to static HTML with the real stylesheets and screenshotting it in headless Chromium (harness deleted afterwards).

- After review: the result's own tier now always lands at 440 ms (`LANDS_AT`: tick lit, its sparks, count roll from 380 ms), superseding the first note; only a lower tick of a double crossing lights at its fill-pass time, capped under 440 ms. The mark is not written on modifier or non-primary clicks.

## Plan Change Log

## Review Triage Log

### 2026-10-17 — Review pass
- verdicts: 7 findings — high 0, medium 0, low 6, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` New explanatory comments (JSDoc, CSS blocks, icon comment, helper comments) break AGENTS.md's no-comment rule — every comment line the diff introduced deleted; pre-existing comments the diff touched kept short and accurate.
  - `[false]` `[reject]` Folded marks light tiers crossed in a set although the set's result names a higher tier — DESIGN.md lights a mark "when one of the results reached it" and the memlog says "those reached lit"; a set that went gold and complete in this opening did reach gold (a gold row exists), so lighting gold is what the spine draws.
  - `[low]` `[patch]` The result's own tick (count roll, sparks) landed at the fill-pass time (~355 ms) instead of EXPERIENCE.md's 440 ms — own tier now lands at `LANDS_AT` 440 ms; a lower crossed tick keeps its fill-pass time, capped below; tests updated.
  - `[low]` `[reject]` The fill steps 6 times per keyframe segment (12 in all) where EXPERIENCE.md says 6 — the approved mock (`set-celebration.html`, `fill-new`/`fill-old`) uses the same 0/45/100 % keyframes with `steps(6)`, so the build matches the rendering the author approved; changing it needs restructured keyframes for an invisible difference.
  - `[low]` `[patch]` Ctrl/Cmd/Shift/middle clicks that open the album in a new tab wrote the celebration mark on the capsule's URL — `leaveForAlbum` returns early on `defaultPrevented`, non-primary button or any modifier, as `previous_screen_controller.ts#back`.
  - `[low]` `[reject]` Desktop focus ring follows the link box and leaves out the ribbon straddling the top edge — the approved mock draws the same (`.link:focus-visible` outline on the panel, `.m1-head` at −8/−12px); widening the ring needs a pseudo-element outline for a few pixels of ribbon; rarely met.
  - `[low]` `[patch]` `ROLL_LEAD` exported but unread, `resultCount` unused outside its test — both deleted with the assertion that only exercised `resultCount`.

## Design Notes

- **Count before the capsule:** the answer carries tier thresholds, not the player's held count, and entry 5 shows the threshold as the count. Taking "lowest crossed threshold − 1" as the start keeps the answer and its replay stable with no new query, and always crosses every tick this opening reached. Flag for the author: a capsule that brought several members shows a shorter fill than it really added.
- **Return mark only from the celebration:** the spines add "back from an album its celebration opened shows the results still"; card-detail returns keep entry 5's "a pack shown again celebrates nothing". The mark rides the history entry the way `?pack=` already does, so no server change.
- **Link name via `aria-label`:** the visual content is decorative and split (ribbon, name, count, hint); one label gives exactly the copy deck sentence.

## Verification

**Commands:** (run from the worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-a3a58af03e854aceb`, never the main checkout; every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1317`, already created and loaded; no system tests; do not commit)
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1317 bin/rails test` -- expected: green
- `npm run test:js`, `npm run typecheck` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: green
- `node script/pixel_art/export.mjs --check` -- expected: no drift

**Manual checks (if no CLI):**
- System tests are disabled; the author approves the banner on staging, phone and desktop (the ticket's verify).

## Auto Run Result

**Summary:** the booster's set celebration is rebuilt as "M1 · Jauge puis ruban": a panel with the set's name and rolling count, a gauge that fills to the count before the capsule then crosses the tier tick in the tier colour, a tier ribbon wiping onto the top edge, juice by tier, reduced motion as one crossfade. Each result links to its set's album (folded line to the collection); Back from that album shows the capsule with its results still and unspoken. Which results, when, their order, the fold and the live-region message keep entry 5's behavior.

**Files changed:**
- `app/frontend/components/BoosterCelebration.tsx` -- rewritten: linked banners, ribbon, gauge and ticks, sparks, folded line, phone plate.
- `app/frontend/lib/celebration.ts` (+ test) -- results carry url, before, crossed; gauge, tick timing, juice, folded marks, link names, `restoredCelebration`.
- `app/frontend/lib/booster_page.ts` (+ test) -- the `celebration` mark beside `pack` in the history entry.
- `app/frontend/components/Booster.tsx`, `BoosterView.tsx`, `lib/booster_props.ts` -- still results on return, the guarded mark on link click, new props.
- `app/frontend/lib/opening.ts` (+ test) -- `url` on each set tier.
- `app/frontend/styles/booster.css`, `booster-layouts.css` -- the design, motion, phone plate, reduced motion, still state.
- `app/helpers/packs_helper.rb`, `app/helpers/boosters_helper.rb` -- album URL per tier row, in-progress URL, ▸ ✓ album icons.
- `script/pixel_art/export.mjs`, `app/frontend/images/pixel/album.svg` -- album icon (generated).
- `config/locales/en.yml`, `fr.yml` -- hint, link-name and folded sub-line copy; English "cards out of".
- `test/controllers/packs_controller_test.rb`, `boosters_controller_test.rb` -- new fields and strings.

**Review:** one quick pass, 7 findings: 4 patched (all low: comments removed, own tier lands at 440 ms, modifier-click guard, dead code), 0 deferred, 3 rejected (folded marks — false, the spine lights tiers reached; 12-step fill and focus ring around the link box only — low, both as in the approved mock).

**Follow-up review recommended:** false (patched: high 0, medium 0, low 4).

**Verification:** `bin/rails test` 2672 runs, 0 failures; `npm run test:js` 376 passed; `tsc --noEmit`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `node script/pixel_art/export.mjs --check` clean. The implementer screenshotted the entrance, final, reduced-motion and still states in headless Chromium.

**Residual risks:** the count before the capsule is the lowest crossed threshold − 1 (the answer has no held count), so a capsule that added several members shows a short fill; the real Turbo round trip (result → album → Back) and the look on a device are unchecked (system tests disabled); a long ribbon title could touch the "VOIR LE SET ▸" hint in the 300px column; after an album return, a card-detail return also shows the results still (the mark stays until the next opening). The author approves the banner on staging, phone and desktop.
