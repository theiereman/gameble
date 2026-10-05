# Validation Report — gameble

- **DESIGN.md:** `/home/teyermann/projets/gameble/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`
- **EXPERIENCE.md:** `/home/teyermann/projets/gameble/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`
- **Run at:** 2026-10-05

## Overall verdict

The pair is a strong contract for the player-facing game. The token set is complete, every reference resolves, the contrast claims check out, and the booster and trade surfaces are specified down to keys, states and copy. The main gap is the staff side. The back-office (moderation, catalog import, season publish) has no flow, no components and no states, and the spine sends readers to "the previous run", whose content is no longer in the spine. Below that sit about a dozen medium gaps: missing state families (special boosters against the 10-booster cap, the weekly goal lifecycle, data export, trade edge cases), a focus ring that disappears on same-coloured card frames, component names that drift between the two spines, a broken file reference and a stale canister description.

The three extra reviewers move the picture from "complete" to "complete but not yet safe to build from". The accessibility lens found 3 critical issues the rubric could not see from the text alone: Commune and Peu commune icons are pixel-identical at small sizes, the reveal is never announced to screen readers, and moving or blinking content has no pause control or in-app motion setting (WCAG 2.2.2, Level A). It also raises two of the rubric's mediums, the focus ring and the phone touch sizes, to high. The feasibility lens found 2 critical gaps: cover images are built from Steam's legacy path, which silently fails for recent games, and the fluid desktop and phone layouts are still undecided, so there is no layout to port. Its 5 high findings are decisions for `bmad-architecture`, whose final spine predates the redesign. The mockups-vs-spines lens found nothing blocking. It found stale spine text (notched canister caps "to be redrawn", counter-proposal and visibility notes, a contradictory `motto` token), decided copy the spines lack, three mock faults to fix later, and 15 implicit decisions for the author to confirm. Across all four reviewers: **5 critical, 15 high, 50 medium, 60 low**.

## Category verdicts

- Flow coverage — adequate
- Token completeness — adequate
- Component coverage — adequate
- State coverage — adequate
- Visual reference coverage — adequate
- Bloat & overspecification — adequate
- Inheritance discipline — adequate
- Shape fit — strong

## Severity totals

| Reviewer | Critical | High | Medium | Low |
|---|---|---|---|---|
| Rubric walker | 0 | 1 | 14 | 11 |
| Accessibility | 3 | 9 | 11 | 8 |
| Feasibility | 2 | 5 | 12 | 12 |
| Mockups vs spines | 0 | 0 | 13 | 29 |
| **Total** | **5** | **15** | **50** | **60** |

The mockups reviewer sorts by kind (a/b/c/d), not severity; the mapping used here is stated under Reviewer notes.

## Findings by severity

### Critical (5)

**[Accessibility]** — C1 — Commune and Peu commune icons are the same shape (§ DESIGN.md › Rarity icon; EXPERIENCE.md › Accessibility Floor; mocks inShape())
Rasterised at 7 × 7 and 9 × 9 art pixels, "circle" and "octagon" give the same silhouette; only grey vs jade tells them apart. The icon appears without a readable name in the top-bar counter, tray slots, feed thumbnails, small missing-card slots and the ticker, and the rarity name on `card-s` is 7 px Silkscreen. The spine's own rule, "colour never stands alone", is broken.
Fix: Silhouettes differ by at least 8 art pixels at 7 × 7 and stay distinct in greyscale (Commune a hollow ring or plain square; Peu commune keeps flat-cut corners). Add a greyscale render check. Add a visible label or legend for the top-bar counter.

**[Accessibility]** — C2 — The reveal is silent for screen-reader users (§ EXPERIENCE.md › Accessibility Floor, Face-down card, Tout révéler, Result banner, Cards dealt)
Only the focused button's accessible name changes, which screen readers do not reliably announce. "Tout révéler" reveals unfocused cards, so nothing is said at all. The Légendaire signal is visual only. For a blind player, the core moment of the product yields no feedback.
Fix: Every reveal posts one polite message to a dedicated booster live region ("Carte 2 : Hades — Supergiant Games, 2020, Roguelite. Épique."). Tout révéler posts one summary. A Légendaire posts "Signal légendaire" at start and the result on landing. Focus stays on the revealed card.

**[Accessibility]** — C3 — Moving and blinking content cannot be paused; no in-app motion setting (§ DESIGN.md › Activity feed, Elevation & Depth, LEDs, blinkers; EXPERIENCE.md › LIVE ticker, Motion › Reduced motion)
The ticker loops for 60 s and pauses only on mouse hover. At least eight blinkers and pulses run indefinitely on the hub; the feed adds entries on its own. The only off switch is the OS setting. WCAG 2.2.2 (Level A) requires a pause/stop/hide control for anything moving longer than 5 s.
Fix: (1) A focusable pause/play button next to LIVE; pause on focus-within and touch. (2) A "Mettre en pause le direct" feed toggle that buffers entries. (3) An "Animations réduites" setting (default: follow the system). (4) Ambient blinkers stop after 5 s or only mark state changes.

**[Feasibility]** — C1 — Cover URLs built from the old path: recent games get no art or a silent grey placeholder (§ DESIGN.md › Pixel filter; mocks CDN + id + '/library_600x900.jpg')
For apps whose assets moved to hashed paths, the legacy path returns 404 (PEAK) or, worse, 200 with a 300 × 450 grey JPEG (Battlefield 6) that `loadImg` accepts. Recent, popular games — the most desirable cards — are the ones affected.
Fix: Import stores the hashed `library_capsule_2x` URL (fallback `library_capsule`) and refreshes it periodically; the CAP-2 exclusion tests the API asset list; `Catalog` exposes an opaque `image_url`; the filter treats < 300 × 450 or single-channel images as missing. DESIGN.md says "the vertical capsule URL recorded at import".

**[Feasibility]** — C2 — The fluid desktop and phone layouts cannot be coded without guessing (§ DESIGN.md › Layout & Spacing ("Open: max width, breakpoint, tablets"); EXPERIENCE.md › Responsive & Platform; mocks position:absolute stages)
There is no layout to port, only a picture of one. Undecided: short desktop viewports (1366 × 768 leaves ≈650 px; hub centre and 600 px booster stage do not fit), medium widths (hub needs ≈1150 px, booster ≈1300 px), phone landscape (844 × 390 gets the desktop layout), tablets.
Fix: Write concrete rules: phone below 720 px or coarse pointer under 500 px tall; two columns 720–1179; three from 1180; max 1440; fixed top bar and ticker; a fixed logical booster stage (884 × 600) scaled by integer-friendly factors; pick phone-landscape behaviour; tablets follow width rules.

### High (15)

**[Rubric · Flow coverage]** — No flow covers the staff journeys (§ EXPERIENCE.md › IA (Back-office row); State Patterns)
Report → moderator review → ban (CAP-15), the administrator starting and watching a catalog import (CAP-2), and publishing a season have no flow. The Back-office IA row says "Behaviour unchanged from the previous run", but the 2026-10-05 rewrite replaced that run's spine, so a consumer has nothing to extract. "Not staff" and "Banned account" are the only staff-side content.
Fix: Bring the back-office behaviour back into this spine: a Key Flow "Moderator reviews a report and bans" with a failure path, Component Patterns rows (report queue, report detail, ban action, import run and progress, season publish) and states (empty queue, import running, import failed, ban confirmation).

**[Accessibility]** — H1 — Single-key shortcuts 1–6 without an off switch (§ EXPERIENCE.md › Menu item, Interaction Primitives › Keyboard)
Hub-wide single-character shortcuts fail WCAG 2.1.4 (Level A). Speech-input users dictating digits and stray typing trigger navigation.
Fix: Keys 1–6 work only while focus is in the hub menu, or with a modifier; a setting can turn them off; expose `aria-keyshortcuts`.

**[Accessibility]** — H2 — The vignette and scanlines sit above all content (§ DESIGN.md › Elevation & Depth › Atmosphere; mock z-index 89/90 over ticker, top bar, toasts)
The vignette darkens edges by ≈0.36–0.45 black, exactly where the top bar, ticker, toasts and phone tab bar sit. Documented ratios no longer hold there (≈2.5–4.2:1). The status and navigation chrome becomes the least readable part of the screen.
Fix: Vignette and stars sit under the content and never cover chrome, toasts or dialogs; scanlines ≤ 11 % and excluded from text-bearing chrome. Every ratio in Colors is measured with every overlay applied.

**[Accessibility]** — H3 — Reduced motion misses many animations and still flashes (§ EXPERIENCE.md › Motion › Reduced motion; DESIGN.md › Elevation & Depth)
The list leaves out the trade swap, daily arc, back equip, the shake of a locked back, the app-start flicker, star twinkle and parallax shift, lock-in overshoot, toasts, feed, holo/foil/glow, sheen, canister breathing and phone slides. "Flashes drop to 30 %" still flashes the whole screen. The mock shakes the stage on every reveal, contradicting DESIGN.
Fix: Rule plus exceptions: under reduced motion nothing translates, rotates, scales, shakes, flashes, blinks, sweeps or loops; state changes are 150–220 ms crossfades. Spell out the Légendaire, trade swap and locked-back versions. Flashes go to 0. Reconcile or remove per-tier reveal shakes.

**[Accessibility]** — H4 — Focus indicator is ambiguous, sometimes invisible, and can be obscured (§ EXPERIENCE.md › State Patterns › Focus; DESIGN.md › Menu item, Buttons, Tabs)
Accent ring on accent-filled items is 1.0:1 and focus looks identical to hover; gold ring on a Légendaire is 1.0:1; the mock prototyped 2 px inset rings and colour-only link focus (1.45:1); nothing stops sticky chrome from covering the focused element (WCAG 2.4.11).
Fix: A 3 px `{colors.text-max}` ring with a 3 px `{colors.outline}` gap on every focusable element, separate from hover, never colour alone; `scroll-padding` equal to top bar, ticker, tab bar and pinned actions.

**[Accessibility]** — H5 — Toasts carry essential messages for 2.8 s (§ EXPERIENCE.md › Toast, refusal states, Motion)
Errors and refusals ("EXEMPLAIRES INSUFFISANTS", "UN ÉCHANGE À LA FOIS", "DOS VERROUILLÉ", network failures) vanish and cannot be paused or recalled. In the mock, one Esc dismisses the toast and navigates to the hub.
Fix: Toasts confirm only; errors also appear inline until the next action. Toasts last ≥ 5 s + 1 s per 10 words, pause on hover/focus, have a close button; Esc closes the toast and nothing else.

**[Accessibility]** — H6 — Pixel fonts at 7–9 px carry essential information (§ DESIGN.md › Typography, Status chip, Tab bar)
Silkscreen caps are 4–5 px tall at 7–8 px and blur off-grid. Rarity names on `card-s`, status chips and phone tab labels are information carriers at these sizes. Long tracked uppercase labels remove word shape; VT323 line-height is 1.0.
Fix: No text below 8 px; information carriers ≥ 10 px; multi-line VT323 line-height ≥ 1.2; uppercase via `text-transform` over sentence-case source; offer a "Police lisible" setting swapping the pixel fonts for a legible sans.

**[Accessibility]** — H7 — Focus management in booster and trade is unspecified; a double activation exits the reveal (§ EXPERIENCE.md › State Patterns, Revealed card, Reveal abandoned)
Focus destinations after opening, Tout révéler, Ouvrir le suivant, ✕, picker close, swap end, sub-views and Steam return are unstated. A second click on a just-revealed card leaves the booster screen, and nothing resumes on return: a player with a tremor skips the remaining reveals.
Fix: Add a Focus column (cards land → card 1; Tout révéler → OUVRIR LE SUIVANT; ✕ → next card or add slot; swap → status line; sub-view → heading; back → opener). A revealed card ignores activation for 400 ms and opens its detail as a dialog over the booster.

**[Accessibility]** — H8 — Feed live region will flood screen readers (§ EXPERIENCE.md › Accessibility Floor; mock #fdList aria-live)
A polite region receiving an entry every few seconds queues speech without end.
Fix: The feed is not a live region; a status line announces batches at most every 30 s while unfocused; the pause toggle stops announcements; the ticker is `aria-hidden`.

**[Accessibility]** — H9 — Phone touch targets below 44 px in spine and mock (§ DESIGN.md › Tabs and filters, Buttons, Trade board › Remove, Modal ✕; phone mock)
34 px chips and small buttons, a 44 × 36 stepper, a 32 × 32 remove ✕ overlapping the card edge, 36 px top-bar chips contradict the spine's own floor.
Fix: Every phone target has a 44 × 44 hit area with 8 px spacing; add `chip-height-touch: 44px`.

**[Feasibility]** — H1 — Main-thread cost of the pixel filter, worst during the opening (§ DESIGN.md › Pixel filter; AD-17; mocks getArt / medianCut / quantize)
≈2.5–12 ms per image for quantisation alone on desktop, 5–10× on low-end Android, plus the 600 × 900 decode. Five cards filter during the 1.2 s explosion: up to ≈0.5 s of blocking inside the hero animation; on slow links the flip shows the placeholder, repeating the v2-3 bug.
Fix: Web Worker + OffscreenCanvas; lazy with a concurrency cap; one palette per game; start fetching on the open response and never flip before art is ready or failed; optionally store the 32-colour palette at import.

**[Feasibility]** — H2 — The opening protocol (latency, refusal, double trigger) is not specified (§ EXPERIENCE.md › Opening refused, Motion, Implementation notes; AD-7)
If the explosion starts on click, a refusal arrives after the caps have blown, contradicting "nothing opens"; if it waits, the click feels dead. A double click can open two packs, one never shown.
Fix: Request on click; the ARMEMENT charge phase (≈300 ms) masks latency; caps blow only on success, else disarm and toast; lock the trigger and use an idempotency key; define the JSON response (five cards, reserve and availability times, pre-open tier counts).

**[Feasibility]** — H3 — AD-16's "two islands" understates the client work; no contract links islands and chrome (§ AD-16; EXPERIENCE.md › Component Patterns)
The booster island is two choreographies (desktop row, phone pile + tray). The rarity counter, packs chip and badges live in server-rendered chrome; teams will invent ad-hoc globals that AD-16 forbids.
Fix: Islands: booster (layout mode) and trade board. Named Stimulus controllers. A DOM event contract (`gameble:tier-revealed`, `gameble:reserve-changed`, `gameble:toast`, `gameble:trade-badge`). Shared filter, tilt and reduced-motion modules.

**[Feasibility]** — H4 — Screen-change motion and phone slide-overs do not come for free with Turbo Drive (§ EXPERIENCE.md › Motion (screen change, app start, sub-views, blocked navigation))
Turbo swaps the body; cached previews replay lock-ins; the flicker plays on every full load; staggered lock-in adds 0.5–1 s; browser Back cannot be blocked; cached booster/trade snapshots go stale.
Fix: View Transitions through Turbo; permanent atmosphere layers; skip lock-in on previews and cap the stagger at ≈400 ms; flicker once per session; `no-cache` on booster and trade; phone sub-views as URL-advancing Turbo Frames. Spine: "in-app back controls are disabled; browser Back is allowed and loses nothing".

**[Feasibility]** — H5 — The spines add server mechanisms the final architecture does not hold (§ ux-gameble.md › Changes; EXPERIENCE.md; DESIGN.md; architecture-gameble.md)
The architecture (status: final) says 16 colours, steel…gold tiers, proposer-set expiry, two surprises per card. Presence, card backs, NOUVEAU "seen" (a write on a read role), per-season numbers, invitations and three-way visibility have no home.
Fix: Run `bmad-spec` with the change list, then `bmad-architecture` in update mode with the "For the architecture" list, before slicing the redesign epics.

### Medium (50)

**[Rubric · Flow coverage]** — Capabilities with a product promise have no flow (§ EXPERIENCE.md › Key Flows)
The brag from the sharer's side (detail → PARTAGER → link copied → pasted on Discord; CAP-9, the brief's "brag" moment), the weekly goal reached and the rare booster arriving (CAP-12), an achievement unlocking (CAP-17), and exporting data or deleting the account (CAP-14 "each action works end to end").
Fix: Add a short flow for the share and one for the goal reward. Fold achievement unlock and data export into State Patterns rows if a flow feels too heavy.

**[Rubric · Token completeness]** — The focus ring has no token and vanishes on same-coloured frames (§ EXPERIENCE.md › State Patterns "Focus"; DESIGN.md › Colors: Gold)
EXPERIENCE sets focus to "3px `{colors.accent}` … gold `{colors.gold}` on cards in grids". Gold on a Légendaire frame is 1.0:1 and accent on a Rare frame is 1.0:1, so focus vanishes exactly on the cards that matter. Gold-as-focus also breaks DESIGN's rule that gold "is never a general accent".
Fix: Add a `focus-ring` component token (e.g. a 2px `{colors.outline}` gap plus a 3px `{colors.accent-hi}` or `{colors.text-max}` ring with an offset), check it against all five rarity frames, panels and accent fills, and use it in both spines.

**[Rubric · Token completeness]** — Type sizes used in prose have no typography token (§ DESIGN.md › Components: Public card page, Result banner; Typography)
Public page title "Pixelify Sans 38px", description "VT323 22px", Épique banner "small (28px)", card micro lines "7 to 10px" under a single 8px `micro` token, small-card footer at 7px.
Fix: Add `public-title`, `body-large`, `banner-small` and a `micro` ramp per card size (as done for `card-title-*`), and reference them by name.

**[Rubric · Component coverage]** — EXPERIENCE components with no visual spec in DESIGN (§ EXPERIENCE.md › Component Patterns, State Patterns)
Invitation (received and sent rows), the hub's "PROGRESSION DES SETS" panel, Face-down card and Revealed card, the Public profile page, the signed-out hub invitation to sign in, and the booster screen's "RÉSERVE VIDE" replacement for the canister.
Fix: Add short DESIGN entries for each, or state explicitly which existing entry they reuse.

**[Rubric · Component coverage]** — Interactive DESIGN components with no behavioural row (§ DESIGN.md › Components; EXPERIENCE.md › Component Patterns)
Text field (validation, max length, submit on Enter, error line), Radio list, Link, the button family (one-primary rule, press, disabled), Add slot, Remove "✕", Status chip, Stack, the RAPPORT panel (folds on the phone).
Fix: Add rows. A single "Buttons" row can carry the one-primary rule and the pressed and disabled behaviour.

**[Rubric · Component coverage]** — Phone touch sizes contradict the 44px Accessibility Floor (§ DESIGN.md › Tabs and filters, Buttons → Back button, Trade board → Remove)
Tabs and filters are 34px and serve as the phone's chip rows; the Back button is `button-height-sm` (34px); the remove "✕" is a "small square".
Fix: Give each a phone size of `{spacing.touch-min}`, or a 44px hit area around the 34px visual, in DESIGN.

**[Rubric · State coverage]** — Special boosters and the 10-booster cap are undefined (§ EXPERIENCE.md › State Patterns "Goal reached", "Daily booster with a full reserve"; Component Patterns "Booster canister")
The daily booster (spec: "small", "better odds") and the goal reward ("rare booster") land in the same reserve. Nothing says how they look among identical canisters, whether they open first, whether the daily one still has 5 cards, or what happens to a goal reward when the reserve is full.
Fix: Add states for a special booster in the reserve and for a goal reward arriving with a full reserve; add the cap rule for rewards to the spec-change list.

**[Rubric · State coverage]** — The weekly community goal lifecycle is missing (§ DESIGN.md › Community goal panel; EXPERIENCE.md › Component Patterns "Community goal")
The spec's goal is weekly with a target scaling with weekly active players; no spine says "weekly". No state for week end, reset, reached goal on the panel, missed goal, or non-contributor. DESIGN removes any countdown.
Fix: Add rows for goal reached (panel look), week rollover, goal missed and non-contributor, and state where the week boundary is visible, if anywhere.

**[Rubric · State coverage]** — Profil et paramètres has no states for its data actions (§ EXPERIENCE.md › Component Patterns "Settings row", "Delete dialog")
Export in progress, ready, failed; where sign-out lands; where the player lands after deleting the account; the effect of a language switch. CAP-14 requires each action to work end to end.
Fix: Add rows for each.

**[Rubric · State coverage]** — Trade edge cases are missing (§ EXPERIENCE.md › State Patterns, trade rows)
Friend banned or deleted mid-trade; whether the 7-day expiry restarts on a counter-proposal; how reservations move when a counter changes quantities (Flow 2 step 7); a card picker with nothing to place.
Fix: Add four rows.

**[Rubric · Visual reference coverage]** — Broken reference to a retired file (§ EXPERIENCE.md › Inspiration & Anti-patterns)
"Rejected — the medieval archives direction" cites `reconcile-hearthstone-card-back-reference.md`, which the memlog records as retired (git history only).
Fix: Drop the filename or say "(git history)".

**[Rubric · Inheritance discipline]** — Component names drift between the spines (§ EXPERIENCE.md › Component Patterns vs DESIGN.md › Components)
EXPERIENCE claims "(same names)" but: Community goal ↔ Community goal panel; Set progress row ↔ Set row; Trade list ↔ List row; Trade board ↔ Board; Friend profile ↔ Friend profile dialog; Report / Delete dialog ↔ Report and delete dialogs; Face-down / Revealed card ↔ Card face / Card backs.
Fix: Pick one name per component and use it in both spines and in the frontmatter `components` keys.

**[Rubric · Inheritance discipline]** — Canister description is stale against the memlog (§ DESIGN.md › Components: Booster canister)
DESIGN says "Two notched metal caps" and "it is redrawn … (the author reviews it)". The memlog records the notches removed (solid edges, grip ridges kept) and the 2px redraw done and approved in v3-4.
Fix: Describe solid-edged caps with grip ridges, and drop the pending-review sentence.

**[Rubric · Inheritance discipline]** — Spec divergences not listed in ux-gameble.md (§ ux-gameble.md › Changes; spines throughout)
(a) Glossary: the spec says "pack", the spines say "booster", `ux-gameble.md` mixes both. (b) Weekly goal → "community goal". (c) Daily booster size and odds not reflected. (d) The spec's "no affiliation with Steam or Valve" terms constraint has no UX surface.
Fix: Add a pack = booster glossary line and the requested spec change; list (b) and (c); add a Terms/legal surface (IA row, footer link on public pages and in Profil et paramètres).

**[Accessibility]** — M1 — Low-contrast tokens used for information (§ DESIGN.md › Colors (dim, publisher), Activity feed, Status chip, Daily booster)
Feed times in dim, "CLOS" at 3.2/2.7:1 and 8 px, dimmed feed rows at 4.35 and 2.57, publisher at 4.29, "RÉSERVE PLEINE" only as disabled text (2.64).
Fix: Set `publisher` to `#8a96a2`; `dim` for decoration only; times and CLOS in muted; dim feed rows by background, never opacity; a muted line under the disabled claim.

**[Accessibility]** — M2 — Non-text contrast of controls (WCAG 1.4.11) (§ DESIGN.md › Text field, Tabs, Settings segments, Radio list, Stepper, Progress track)
Boundaries in `line` (1.8–2.0:1) and `line-soft` (1.35:1) are below 3:1.
Fix: Interactive boundaries use `{colors.line-deep}` (3.2:1) or brighter; progress tracks show a 3:1 edge or a text value.

**[Accessibility]** — M3 — Blink rates are unbounded; the mock blinks at 4–7 Hz (§ DESIGN.md › Status LED, Canister)
Small areas pass 2.3.1, but they sit next to full-screen flashes and shakes, in the photosensitive band.
Fix: Nothing blinks faster than 2 Hz; at most one full-screen flash per sequence, never 3 in a second; flashes never overlap when Tout révéler chains cards.

**[Accessibility]** — M4 — Hub cognitive load and structure (§ EXPERIENCE.md › IA › Hub content; DESIGN.md › Layout & Spacing)
About a dozen things move at once on the hub; no heading, landmark or reading order is defined.
Fix: A Structure line per screen (h1, nav, main, complementary, ticker hidden; reading order). At most two ambient animations outside the booster; countdowns update per minute above one hour.

**[Accessibility]** — M5 — Esc does too much (§ EXPERIENCE.md › Keyboard, Counter-proposal, IA)
Esc silently discards a counter-proposal and navigates away from any screen; it collides with IME and browser uses.
Fix: Esc closes the topmost overlay only; cancels a counter only after confirmation; returns to the hub only when nothing consumed it and no edit or text field is active.

**[Accessibility]** — M6 — Dialogs, picker and stepper semantics (§ DESIGN.md / EXPERIENCE.md › Dialogs, Card picker, Quantity stepper)
Dialog name, initial focus and ✕ name unspecified (the mock names every dialog "Fenêtre"); picker arrows conflict between grid movement and quantity.
Fix: `aria-labelledby` from the title; initial focus never on ✕; ✕ named "Fermer"; picker grid one tab stop; stepper a `spinbutton`; refusals and COPIÉ announced politely.

**[Accessibility]** — M7 — Reflow, zoom and text spacing (§ DESIGN.md › Typography, Layout; EXPERIENCE.md › Responsive)
Nothing states that 400 % zoom yields the phone layout, that the default font size is honoured, or that user text spacing does not clip fixed-height rows.
Fix: Breakpoints in CSS px; rem text from a 16 px root (art pixel in px); `min-height`, never `height`, on text rows; verify with the 1.4.12 bookmarklet.

**[Accessibility]** — M8 — Card and media semantics are incomplete (§ EXPERIENCE.md › Accessibility Floor; DESIGN.md › Pixel filter, Avatars, Gauges, Countdown)
A card's exposed text lacks number, copies, NOUVEAU and reserved count; canvases, thumbnails, avatars, rays and gauges unspecified; the packs chip label rewrites every second.
Fix: Define a card's text order; canvases and thumbnails `aria-hidden`; gauges `role=progressbar`; countdown text changes at most per minute.

**[Accessibility]** — M9 — Time limits and their wording (§ EXPERIENCE.md › Voice, Daily booster, Trade states)
"Minuit UTC" forces mental arithmetic; whether an uncollected daily booster lapses is unsaid; no warning before a proposal expires.
Fix: Local time ("prêt à 02 h 00"); state whether the daily lapses; hours under 24 h with a "bientôt" cue.

**[Accessibility]** — M10 — Gestures and touch alternatives on the phone (§ EXPERIENCE.md › Interaction Primitives, Revealed card, Card detail; DESIGN.md › Reveal caption plate)
Tap is overloaded on the top card (a double tap stores it unseen); the "◀ ▶" hint looks like a control; held-finger tilt competes with scrolling.
Fix: Every swipe has a visible button (RANGER; 44 × 64 ◀ ▶ in detail); 400 ms tap guard after a flip; tilt after 150 ms without vertical movement; long-press never required.

**[Accessibility]** — M11 — Long sequences cannot be skipped (§ EXPERIENCE.md › Tout révéler, Opening in progress)
Navigation is blocked through each sequence; players distressed by the effects have no escape but the OS setting.
Fix: A "Passer" control (and Esc) jumps to the end state.

**[Feasibility]** — M1 — The 2 CSS px art pixel goes uneven at fractional DPR (§ DESIGN.md › art-pixel, image-rendering: pixelated)
At DPR 1.25 / 1.75 and some Android ratios, columns alternate 2/3 px and outlines blur — hitting the identity's first idea. The mocks hide this with `fit()`.
Fix: Spike on a 125 % Windows laptop; accept, snap backing stores to round(2·dpr), or snap only large cards; record the choice in DESIGN.md.

**[Feasibility]** — M2 — The pixel fonts lack the interface glyphs the copy uses (§ DESIGN.md › Typography; copy "◀ PONT", "TOUT VOIR ▸", "↗", "⇄", "✕", "✓", "◆")
None of the three fonts has ◀ ▶ ▸ ◆ ⇄ ↗ ✕ ✓ or U+202F (the French group separator); they fall back with mismatched metrics, and ◀ ▶ can render as colour emoji.
Fix: Draw them as pixel SVG icons; group digits with U+00A0; note the rule under Typography.

**[Feasibility]** — M3 — The documented CORS fallback can never trigger as coded (§ DESIGN.md › Pixel filter fallback; mocks crossOrigin + try/catch)
With `crossOrigin` set and no ACAO, the load itself fails; the try/catch never runs. `IMGP` caches failures forever.
Fix: Retry once without `crossOrigin` and draw unquantised; do not cache failures for the session; never add headers to image fetches.

**[Feasibility]** — M4 — The continuous-animation and paint budget is unbounded (§ DESIGN.md › Elevation & Depth, Rarity effects; mocks scan, tcgHolo, bFrame rAF loop)
`background-position` animations repaint the main thread; the hub stacks 10+ infinite loops; an rAF loop runs forever on every screen.
Fix: Loops animate only transform/opacity; rAF only while something moves; `content-visibility: auto`; a budget (≤ 6 visible infinite animations on the phone); a low-end Android spike.

**[Feasibility]** — M5 — touch-action: none on large cards traps scrolling on the phone (§ mobile.html .show, .d-card, .pub-card, .z-card)
A drag starting on the showcase or public card does not scroll the page.
Fix: Cards in scrolling content use `pan-y`; tilt follows only horizontal drag or long press; `none` only on the booster stage.

**[Feasibility]** — M6 — The mocks' code is not safe to port into Turbo/Stimulus lifecycles (§ key-screens.html, mobile.html)
53 and 68 `addEventListener`, 0 removals; uncleared intervals; module-level mutable state; unbounded caches. Turbo visits pile them up.
Fix: Implementation notes: mocks are a reference for look and timing, never source; listeners and timers registered in connect() and removed in disconnect(); LRU-bounded caches.

**[Feasibility]** — M7 — i18n inside the islands needs interpolation and plurals (§ AD-16, AD-18)
Pre-translated props cannot hold counts; French and English pluralise 0 differently.
Fix: Scoped key → template maps with one/other forms; a shared `t()` with `Intl.PluralRules`; server-rendered `<time>`; uppercase in CSS.

**[Feasibility]** — M8 — No Content-Security-Policy is defined (§ config/initializers/content_security_policy.rb)
The redesign widens what must be allowed (Steam image hosts, workers, fonts).
Fix: Adopt a policy now (img/connect to Steam hosts, worker-src blob:, self-hosted fonts, nonces), report-only for one release.

**[Feasibility]** — M9 — The 3D pitfall is narrower than the actual rule (§ EXPERIENCE.md › Implementation notes)
Any grouping property (opacity < 1, filter, overflow, clip-path, mask, blend mode…) on or between tilt/flip layers flattens 3D and brings back the mirrored back. One refactor reintroduces the v2-3 bug.
Fix: Extend the note to all grouping properties; add a visual regression test of a tilted, revealed card.

**[Feasibility]** — M10 — Some tokens are not CSS values, and one is ambiguous (§ DESIGN.md frontmatter (panel.border, bevel, card-back.sheen, idle-float, hazard-stripe, pixel outline, blink))
`panel.border: inset 2px` read literally draws a bevel; prose tokens force guessing; the three outline widths will drift.
Fix: Give each token the exact CSS value from the mocks; move prose effects to an Effects section; state the custom-property naming (`--color-*`).

**[Feasibility]** — M11 — Backs, canister, icons, avatars and logo exist only as procedural drawing code (§ mocks backCanvas, canister canvases, iconSVG; DESIGN.md › Card backs)
Production either ships runtime canvas drawing or someone redraws the art by hand and it drifts.
Fix: A one-off export script renders each asset to PNG/SVG under `app/frontend/images/pixel/`; the author reviews the sheet once.

**[Feasibility]** — M12 — Phone shell model and safe areas (§ mobile.html inner scroll; DESIGN.md "tab bar plus the safe area"; epic 1 viewport meta)
Without `viewport-fit=cover`, safe-area insets are 0 on iOS; an inner-scroll app shell breaks Turbo scroll restoration and the iOS URL bar.
Fix: Document scroll, sticky top bar, fixed tab bar with safe-area padding; `viewport-fit=cover`; `dvh` for the booster stage.

**[Mockups]** — b1 — Canister caps described as notched (§ DESIGN.md › Booster canister)
The mock caps have solid, clean edges: crisp outline, light rim, knurled grip, collar, no notches.
Fix: Rewrite the cap description (memlog 260, 261).

**[Mockups]** — b2 — Canister "to be redrawn" is stale; approved anatomy and tokens missing (§ DESIGN.md › Booster canister, components.canister)
The redraw (100 × 150 art px at 2 CSS px) is done and approved. Missing: indicator window, rim bands, gloss, rivets, LED plate, barcode, emblem window. Caps are a steel gradient, not `muted`; the body a slate-blue gradient, not flat `panel-raised`.
Fix: Drop the sentence, describe the approved art, update the tokens or mark them as art (memlog 259, 262).

**[Mockups]** — b4 — The motto token contradicts the goal panel (§ DESIGN.md › Colors (Motto) vs Community goal panel)
Colors says `motto` carries the Brotherhood line; the panel section says `text-bright`; both mocks render it in `#e6eef5`, brass only in dead CSS.
Fix: Remove the `motto` token and its bullet, or say where it is used.

**[Mockups]** — b5 — Counter-proposal note is stale (§ EXPERIENCE.md › State Patterns "Counter-proposal in progress")
"The mock only opened my side" and the `[ASSUMPTION: copy]` are stale: the mocks open both sides with "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez."; the send button stays disabled until each side holds a card; focus goes to my add slot.
Fix: Remove the note and tag; adopt the mock copy and enable rule.

**[Mockups]** — b6 — Visibility labels still marked to write (§ DESIGN.md › Profile and settings; EXPERIENCE.md › Settings row)
The mocks ship VISIBILITÉ DU PROFIL with PUBLIC / AMIS UNIQUEMENT / PRIVÉ (radio group, default PUBLIC) and the three summary lines.
Fix: Write the labels and summary lines in; drop the tag.

**[Mockups]** — b7 — Daily booster with a full reserve lacks its copy (§ DESIGN.md › Daily booster panel; EXPERIENCE.md › State)
State word "RÉSERVE PLEINE" in orange and line "Ouvrez un booster pour récupérer celui du jour.".
Fix: Add the word, colour and line; add "full reserve" to orange's uses.

**[Mockups]** — b8 — Empty showcase lacks its copy (§ DESIGN.md › Showcase; EXPERIENCE.md › "No notable pull yet")
Hatched frame, "OUVREZ VOTRE PREMIER BOOSTER", "Votre plus belle carte s'affichera ici.", button "OUVRIR UN BOOSTER", no rays.
Fix: Add the copy; button colour per c4.

**[Mockups]** — b11 — Phone booster behaviour omitted (§ DESIGN.md › Reveal caption plate, Tray; EXPERIENCE.md › Responsive, Motion)
Pile deal with offsets and tilt; tap/swipe hints; 40 × 54 tray thumbnails with spark burst; plate ticks and Légendaire plate colour; tray zoom overlay; Tout révéler stores in the tray; daily flyer to the BOOSTER tab; tab bar disabled during opening.
Fix: Add to DESIGN (plate, tray, zoom) and EXPERIENCE (Responsive, Motion, Tab bar).

**[Mockups]** — b12 — Phone sizes and type ramp not in tokens (§ DESIGN.md › spacing / typography; Layout)
Buttons 48 (small 44), stepper 44 × 36, ticker 30, PLUS rows 52, set chips 132 × 48; smaller type ramp (screen title 19, showcase 23, public title 30…).
Fix: Add the phone values as tokens or a phone note.

**[Mockups]** — b13 — Card-size rules for trade and phone pickers (§ DESIGN.md › Layout; EXPERIENCE.md › Responsive)
Single-card trade side uses `card-m`; phone pickers `card-s`, `card-xs` only under 372 px; back grid `card-xs`; phone back preview `card-m` (DESIGN says `card-l`).
Fix: Align the size list and the phone rule.

**[Mockups]** — b19 — Approved copy the build needs is missing (§ EXPERIENCE.md › State Patterns, Voice)
Trade toasts, side labels, picker titles and counter, board lines, invite labels, public pitch, PLUS subtitle.
Fix: Record the strings.

**[Mockups]** — c1 — Card detail lacks description, season, sets and copyright (§ Both mocks, card detail)
Contradicts memlog 63, CAP-7 and EXPERIENCE Card detail.
Fix: Add the four facts to both details (mock).

**[Mockups]** — c2 — makePack() still forces a Rare into every booster (§ Both mocks, demo code)
Invisible, but anyone porting the code inherits a per-booster guarantee (contradicts memlog 243).
Fix: Remove the line (mock).

### Low (60)

**[Rubric · Flow coverage]** — Flow 3 has no failure path; Flow 1's climax is conditional (§ EXPERIENCE.md › Key Flows 1 and 3)
Flow 3 (Inès) could fail if she equips the back during an opening, or if the set is completed through a trade. Flow 1's climax ("If it is an Épique…") weakens it as an acceptance anchor.
Fix: Add a one-line failure path to Flow 3, and pin Flow 1's climax to the guaranteed Rare-or-better reveal.

**[Rubric · Token completeness]** — Four colour tokens have no stated role (§ DESIGN.md frontmatter)
`accent-hi`, `accent-press`, `on-alert` and `star` are defined but not referenced in the body.
Fix: Give each a use in Colors, or remove it.

**[Rubric · Token completeness]** — No global contrast target; dark-only never stated (§ DESIGN.md › Colors)
EXPERIENCE's floor implies 4.5:1 text; nothing states 3:1 for non-text UI (focus rings, input borders, gauge segments).
Fix: Add one line to Colors: "Dark only. Text ≥ 4.5:1, UI boundaries and focus ≥ 3:1, except `dim` and `publisher`, which carry redundant information only."

**[Rubric · Token completeness]** — Token-shape oddities a resolver will trip on (§ DESIGN.md frontmatter)
`typography.publisher` has only a `note` and no `fontSize`; easings live under `components.motion`; `hazard-stripe.pattern` embeds `{colors.accent}` inside a composite string.
Fix: Split `publisher` into per-size tokens, move easings to a top-level `motion` group (or note the convention), and give the stripe colours their own keys.

**[Rubric · State coverage]** — Smaller state gaps (§ EXPERIENCE.md › State Patterns)
Succès has no state rows; the share sheet has no state for clipboard refusal; a signed-in visitor on the public card page; a signed-out visitor on the card detail (CAP-18).
Fix: One row each.

**[Rubric · Visual reference coverage]** — Mockups linked only globally, not at the sections they illustrate (§ DESIGN.md › Brand & Style; EXPERIENCE.md › Foundation)
`mobile.html` is not linked at Reveal caption plate, Tray, Tab bar, Responsive & Platform. `key-screens.html` is not cited at Trade board, Friends, Activity feed, Achievements, Profile and settings, Public card page.
Fix: Add one-line "Reference: …, <screen>" pointers at those sections.

**[Rubric · Visual reference coverage]** — ref-01…ref-04 cited only as a range (§ DESIGN.md › Brand & Style)
Nothing says what each shows (hub, booster, collection, rarity scale); ref-04's four-tier scale is superseded.
Fix: Name each at its section, with a note that ref-04's four-tier scale is superseded.

**[Rubric · Bloat & overspecification]** — DESIGN.md carries timings it says live in EXPERIENCE (§ DESIGN.md › Components)
Holo 34 steps / 3.4s, back sheen 5.2s, art fade 600ms, "COPIÉ ✓" 1.6s, count bump 0.5s, ticker 60s, canister breath (duplicated). Prose restates token values ("34px, Silkscreen 10px", "24 × 26px").
Fix: Move the timings to EXPERIENCE Motion, and cite tokens instead of raw values in prose.

**[Rubric · Bloat & overspecification]** — Project history and a prototype selector in EXPERIENCE (§ EXPERIENCE.md › Foundation, Implementation notes)
Foundation carries "replaces the 2026-10-02 medieval direction… Epic 1 must be reworked"; Implementation notes quotes `.screen:not(.on) *`.
Fix: Move the history to `ux-gameble.md` or the memlog; keep the rule ("hide every descendant of an inactive screen") and drop the selector.

**[Rubric · Bloat & overspecification]** — Card backs states product rules (§ EXPERIENCE.md › Card backs)
How backs are earned belongs in the spec once `bmad-spec` absorbs the capability.
Fix: After absorption, shrink it to a pointer plus the UX-only rules.

**[Rubric · Inheritance discipline]** — Sources frontmatter incomplete (§ EXPERIENCE.md and DESIGN.md frontmatter)
EXPERIENCE omits the spec companions (`catalog-and-rarity.md`, `brotherhood-tone.md`) and the brief addendum; DESIGN.md has no `sources`.
Fix: List the companions, or state that the spec's `companions:` are inherited.

**[Accessibility]** — L1 — Rare equals the accent colour; jade sits next to lime (§ DESIGN.md › Colors, Rarity)
Rare-coloured text reads as interactive; jade and lime differ by hue only (1.10:1).
Fix: State that rarity-coloured text is never interactive.

**[Accessibility]** — L2 — Hover-only title tooltips (§ Mock badges and rarity counter)
Hover-only information is lost on touch and keyboard.
Fix: No information lives only in `title`.

**[Accessibility]** — L3 — App-start whole-screen flicker (§ EXPERIENCE.md › Motion › App start)
A 0 → 1.5 brightness overshoot over the whole screen; single, but unpleasant.
Fix: List it in the reduced-motion profile and cap the overshoot at 1.1.

**[Accessibility]** — L4 — Pointer-only copy (§ EXPERIENCE.md › Cards dealt; canister)
"Cliquez une carte…" and "CLIQUEZ POUR OUVRIR" address pointer users only.
Fix: Device-neutral copy; state that Space and Enter both activate.

**[Accessibility]** — L5 — Language (§ EXPERIENCE.md › Foundation, Accessibility Floor, Card detail)
Steam descriptions may differ in language from the UI; English copy and rarity names do not exist yet.
Fix: `<html lang>` follows the chosen language; foreign blocks carry their own `lang`; write the English rarity names.

**[Accessibility]** — L6 — State shown by border only (§ DESIGN.md › Trade board, Settings)
The edited side is shown by an accent border only; segments mix `aria-pressed` and radio semantics.
Fix: Add "EN ÉDITION" to the side header; pick one segment semantic.

**[Accessibility]** — L7 — Links that open new tabs or leave the site (§ "VOIR SUR STEAM ↗", Steam sign-in)
Players are not told a link opens a new tab or leaves the site.
Fix: Accessible names add "(nouvel onglet)"; the sign-in button says it opens Steam.

**[Accessibility]** — L8 — Typed delete confirmation (§ EXPERIENCE.md › Delete dialog)
Case, paste and language are unspecified.
Fix: Case-insensitive, paste allowed, word localised, field labelled with the word to type.

**[Feasibility]** — L1 — One palette per size (§ mocks ARTP)
The same card can show different colours at s and xl.
Fix: Per-game palette (H1).

**[Feasibility]** — L2 — Collection arrow keys hard-code 5 columns (§ mocks ArrowDown:5)
Fluid grids break it.
Fix: Compute rows from offsetTop or the computed grid columns.

**[Feasibility]** — L3 — Esc precedence is spread across components (§ EXPERIENCE.md › Keyboard)
A native dialog and a document-level hotkeys controller both see one Esc.
Fix: Native `<dialog>` everywhere; hotkeys ignore defaultPrevented, open dialogs and form fields; 1–6 need an off switch.

**[Feasibility]** — L4 — LIVE ticker and live updates (§ mock ticker translateX(-50%))
Inserting items mid-loop makes the strip jump.
Fix: Apply incoming items on `animationiteration`.

**[Feasibility]** — L5 — Pixel fonts at sizes off their grid (§ DESIGN.md › Typography)
Silkscreen at 7–14 px and Pixelify 600 render antialiased.
Fix: Self-host subsetted woff2, preload, `font-display: block`; record licences (OFL) as a decision.

**[Feasibility]** — L6 — Hotlinking dependence (§ Steam CDN)
Valve could add referer checks or change hosts.
Fix: Build URLs from import data; one host config value; `referrerPolicy: no-referrer`; never cache covers in storage.

**[Feasibility]** — L7 — Countdowns and pack credit on the client (§ "+1 dans", "PROCHAIN DANS", expiry)
A skewed device clock shows wrong numbers.
Fix: Pass `server_now` and availability times; the server stays the authority.

**[Feasibility]** — L8 — Accessibility details that touch implementation (§ mocks #fx canvas; reveal)
Art and FX canvases are not `aria-hidden`; a reveal only changes the focused card's name.
Fix: aria-hide canvases; send reveals to the polite live region; never draw text into a canvas.

**[Feasibility]** — L9 — The pedestal drifts 6 px (§ mock .pedestal drift 8s)
Breaks the "idle float 2 px at most" rule; the unused 10 px `bob` must not be ported.
Fix: Cap at 2 px or record the scenery exception.

**[Feasibility]** — L10 — allow_browser :modern (§ ApplicationController)
Safari 17.2+ / Chrome 120+ / Firefox 121+; shuts out iPhones on iOS 16.
Fix: State the supported-browser floor in EXPERIENCE.md › Responsive & Platform.

**[Feasibility]** — L11 — The daily-booster arc and Turbo Streams (§ EXPERIENCE.md › Motion (daily))
The arc needs both positions before the stream replaces the DOM.
Fix: Run it from `turbo:before-stream-render` and dispatch `gameble:reserve-changed`.

**[Feasibility]** — L12 — Grid scale (§ Collection grid)
Large publisher sets far exceed the mock's 30 cards.
Fix: Paginate or virtualise beyond ≈60 slots.

**[Mockups]** — b3 — Hazard band turns orange when armed (§ DESIGN.md › Booster canister; EXPERIENCE.md › Motion)
Not in the spine.
Fix: Add.

**[Mockups]** — b9 — Achievements gauge and tiles differ (§ DESIGN.md › Achievements, gauge-segmented)
One segment per achievement (40), 10 px tall; tiles grouped OBTENUS / À OBTENIR; tile bar 4 px in `line-deep`; one column on the phone.
Fix: Amend the gauge rule and tile spec.

**[Mockups]** — b10 — Reveal label under dealt cards (§ DESIGN.md › Rarity icon / Result banner)
"? ? ?" face down, then icon and tier name on reveal; mentioned only in passing.
Fix: Describe it as a component.

**[Mockups]** — b14 — Phone sheets and tab behaviour (§ DESIGN.md › Dialogs; EXPERIENCE.md › Motion, Tab bar)
Grab handle; full-height picker; 240 ms rise (spine 220); sub-view slides 260/200 ms; current tab returns to root.
Fix: Add.

**[Mockups]** — b15 — Phone card detail controls (§ DESIGN.md › Collection (card detail))
44 × 64 ◀ ▶ buttons, position line, actions pinned at the bottom.
Fix: Add.

**[Mockups]** — b16 — Per-screen top-bar contents (§ DESIGN.md › Top bar)
Reserve chip on booster, unique-cards bar on collection, trade note, LIVE chip on the feed; shortened phone titles.
Fix: List them.

**[Mockups]** — b17 — Booster information panel has no spec (§ DESIGN.md › Panels)
Kicker, GRAND CATALOGUE title, bracketed info panel, reserve pips, revealed counter; phone 44 px strip.
Fix: Add a component entry.

**[Mockups]** — b18 — The pixel pedestal is a ringed planet (§ DESIGN.md › Showcase / Shapes)
200 × 200 art px planet with a lit ring.
Fix: Describe it.

**[Mockups]** — b20 — Selected grid card and phone RAPPORT fold (§ DESIGN.md › Collection)
Pulsing 3 px accent frame with `aria-pressed`; fold shows "n cartes · n doublons" and a CARTES UNIQUES row.
Fix: Add.

**[Mockups]** — b21 — Small motion details (§ EXPERIENCE.md › Motion)
Peu commune ring; public card idle float over a breathing shadow; detail re-entry 260 ms with a turn.
Fix: Add to the table.

**[Mockups]** — b22 — Card-back word position (§ DESIGN.md › Card backs)
Words sit at the top or bottom, not only the bottom.
Fix: Say "at the top or bottom".

**[Mockups]** — c3 — Phone tray progress reads "1/5" (§ Phone mock, booster tray)
The decision and EXPERIENCE say "CARTE n / 5".
Fix: Add "CARTE", or the author accepts "n/5" and the spine is amended.

**[Mockups]** — c4 — Two lime primaries on the empty-showcase hub (§ Both mocks, hub)
"OUVRIR UN BOOSTER" and "RÉCUPÉRER" both lime; DESIGN says never more than one per view.
Fix: Make the showcase button secondary, or write the exception into the spine.

**[Mockups]** — c5 — Phone zoom draws rays behind low tiers (§ Phone mock, tray zoom)
Blue rays on Commune, Peu commune and Rare; DESIGN allows no rays below Épique.
Fix: No rays below Épique (mock).

**[Mockups]** — d1 — Reserve countdown at 10/10 (§ EXPERIENCE `[ASSUMPTION]`)
The mock keeps counting; the spine hides it.
Fix: Visible or hidden?

**[Mockups]** — d2 — Card-number threshold (§ DESIGN.md › Card face)
Short "#4 215" on s and m; full form only on l/xl. DESIGN: full form from medium.
Fix: Pick a threshold.

**[Mockups]** — d3 — Missing-card slot label (§ DESIGN / EXPERIENCE collection)
Mock shows "NON OBTENUE" instead of the number.
Fix: Number, NON OBTENUE, or both?

**[Mockups]** — d4 — Copy badge from x1 (§ Collection grid)
The mock badges every owned card.
Fix: From x1 or duplicates only?

**[Mockups]** — d5 — Friend code format (§ Amis)
Mock accepts 3–5 chars, dash, 4; spine says "ABCD-1234".
Fix: Fix the format.

**[Mockups]** — d6 — Sign-out landing (§ Settings)
The mock lands on the public card page of the last pull; spine silent.
Fix: Where does sign-out land?

**[Mockups]** — d7 — Focus styles per element (§ EXPERIENCE › Focus)
Hover fill + 6 px halo on controls, 3 px gold on grid cards, accent with offset on canister and dealt cards.
Fix: Confirm and document per element (see the accessibility H4).

**[Mockups]** — d8 — Pedestal drifts 6 px (§ Hub)
Spine caps bobbing at 2 px (for cards).
Fix: Confirm 6 px for scenery, or cap at 2 px.

**[Mockups]** — d9 — Légendaire glow in showcase and public page (§ DESIGN › Rarity effects)
The mock shows no glow there; the spine says it does.
Fix: Add the glow to the mock, or narrow the spine.

**[Mockups]** — d10 — Ticker and feed thresholds (§ EXPERIENCE `[ASSUMPTION]`)
Ticker sample includes a Rare; feed fills in with dimmed lower tiers.
Fix: Confirm the thresholds.

**[Mockups]** — d11 — 6 px Silkscreen on card-xs (§ DESIGN › Typography)
Below the stated 7 px floor; legibility unchecked.
Fix: Confirm or raise (see accessibility H6).

**[Mockups]** — d12 — Second back button on the booster (§ Desktop booster)
"RETOUR AU PONT" beside "◀ PONT".
Fix: Keep or drop.

**[Mockups]** — d13 — Shorter phone labels and Amis order (§ Phone mock)
"ÉCHANGER", "SIGNALER CE PROFIL", "SUPPRIMER", "CONNEXION STEAM".
Fix: May phone copy differ?

**[Mockups]** — d14 — Asynchronous export (§ Settings)
"PRÉPARATION…" then toast "EXPORT PRÊT".
Fix: Confirm the async export (CAP-14).

**[Mockups]** — d15 — Friend showcase selection (§ EXPERIENCE `[ASSUMPTION]`)
The player's summary takes the three rarest automatically.
Fix: Confirm automatic, or let the player choose.

## Reviewer notes

### Accessibility review (`review-accessibility.md`)

**Verdict (reviewer's words):** The spines have a real accessibility floor (rarity named in words, a named face-down card, inert screens, focus return, a reduced-motion paragraph, 44 px touch targets for the stepper), and the base token contrasts are good. But several guarantees do not hold when checked against the prototypes: the Commune and Peu commune icons are drawn pixel-identical, so "shape + name + colour" fails where names are absent or set in 7 px; the reveal, the core of the game, is never announced to screen readers; and auto-moving and blinking content has no pause control or in-app motion setting (WCAG 2.2.2, Level A). **Not ready as a builder contract until the critical and high items are written into the spines.**

Computed failures worth keeping in view: `publisher` on the title band 4.29:1; `dim` 2.7–3.5:1 for text; `line` and `line-soft` control boundaries 1.35–2.0:1; accent ring on accent fill and gold ring on a Légendaire frame both 1.0:1; chrome under the vignette ≈2.5–4.2:1 (estimate); lime vs Peu commune jade 1.10:1 (hue only).

### Technical feasibility review (`review-feasibility.md`)

**Verdict (reviewer's words):** **Conditional pass: buildable, but not yet without guessing.** The look and motion can be built on the recorded stack (Rails + ViewComponent + Hotwire, two React islands through Turbo Mount, plain CSS tokens); nothing needs a stack change, and the Steam CDN answers `Access-Control-Allow-Origin: *`, so the in-browser pixel filter works. Before the first story starts, two things must be settled: where each cover image comes from, and the fluid layout rules. "There is no layout to port, only a picture of one." Five high findings are decisions the architecture must take; the medium and low findings are spine fixes or build rules.

Evidence: `curl` against six Steam CDN hosts (ACAO `*` on 200s, none on 404s, preflight 405); a Node benchmark of the mocks' `medianCut` + `quantize`; `fc-query` glyph coverage of the three fonts. The review also carries a 14-item "For the architecture" list (AD-17 rewrite, image source, AD-16 islands and event contract, opening endpoint, Turbo motion, layout system, real-time and presence, new domain data, tier names, CSP, island i18n, pixel-art assets, performance budget, housekeeping) and a 12-item Epic 1 rework list (tokens, fonts, attic removal, layout, ButtonComponent, TextPlate, locales, focus style, back-office, sign-in landing, CSP, tickets).

### Mockups vs spines review (`review-mockups.md`)

**Verdict (reviewer's words):** The spines and the approved mocks agree on structure, tokens, motion and almost every behaviour. All 50 colour tokens appear in both mocks; every Motion timing matches the code within rounding. **No divergence blocks the build.** The divergences that matter are spine text that went stale after the v3-3 / v3-4 / mobile-v1-3 rounds (notched canister caps "to be redrawn", the counter-proposal and visibility notes that say "the mock" lacks them, a `motto` token that contradicts the goal panel), decided states without their copy, and phone booster details the spines leave out. The mocks have three real faults: the card detail lacks description, season, sets and copyright; the empty showcase shows two lime buttons; the phone zoom draws rays behind low tiers.

This reviewer sorts by kind, not severity: (a) spine right, mock convenience — 6; (b) fix the spine — 22; (c) fix the mock later — 5; (d) implicit decisions to confirm — 15. For the severity totals, this synthesis maps stale or contradicting spine text, missing decided copy and phone layout rules to *medium*, other (b) omissions to *low*, (c) to *medium* where a builder porting the mock would inherit the fault (c1, c2) and *low* otherwise, and every (d) to *low*. The six (a) items carry no action and are not counted; a5 (dead CSS encoding dropped decisions: `.g-motto`, `.tgl`, `bob`, `.g-time`) must not be ported.

## Mechanical notes

- DESIGN.md frontmatter is valid YAML. 68/68 DESIGN and 7/7 EXPERIENCE token references resolve. All colours are hex. No Mermaid in either spine.
- Broken cross-reference: `reconcile-hearthstone-card-back-reference.md` (EXPERIENCE.md, Inspiration & Anti-patterns), retired per the memlog.
- Dangling reference: "Behaviour unchanged from the previous run" (EXPERIENCE.md, IA, Back-office) points to superseded spine content.
- Name inconsistencies across spines: see Inheritance discipline, first finding.
- Card size conflict: Responsive & Platform puts the phone hub showcase at `card-l`; DESIGN Layout lists `card-xl` for the hub showcase with no phone exception.
- Focus colour: EXPERIENCE uses `{colors.gold}` for focus on grid cards, while DESIGN Colors excludes gold from general use.
- `ux-gameble.md` uses both "pack" and "booster" for the same object within one bullet list.
- Frontmatter: DESIGN.md has no `sources` (optional). Typography weights are YAML integers (700) where the examples use strings ('700'); harmless, but should be consistent.

## Reviewer files

- `review-rubric.md`
- `review-accessibility.md`
- `review-feasibility.md`
- `review-mockups.md`
