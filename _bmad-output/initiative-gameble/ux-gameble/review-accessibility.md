# Reviewer Gate — Accessibility lens

Scope: `DESIGN.md` and `EXPERIENCE.md` (draft, 2026-10-05) as the accessibility contract, cross-checked against `mockups/key-screens.html` (desktop) and `mockups/mobile.html` (phone) and the decisions log (entries from "Update started 2026-10-05"). Contrast ratios are computed with the WCAG 2.x formula from the hex tokens.

## Verdict

The spines have a real accessibility floor (rarity named in words, a named face-down card, inert screens, focus return, a reduced-motion paragraph, 44 px touch targets for the stepper), and the base token contrasts are good. But several guarantees do not hold when checked against the prototypes: the Commune and Peu commune icons are drawn pixel-identical, so "shape + name + colour" fails where names are absent or set in 7 px; the reveal (the core of the game) is never announced to screen readers; and auto-moving and blinking content has no pause control or in-app motion setting (WCAG 2.2.2, Level A). Not ready as a builder contract until the critical and high items below are written into the spines.

## Contrast reference (computed)

| Pair | Ratio | Status |
|---|---|---|
| text `#c7d5e0` on ground / panel / sunken / raised / steam-bar | 12.8 / 11.7 / 12.4 / 10.0 / 11.6 | pass |
| muted `#8f98a0` on ground / panel / raised / steam-bar | 6.6 / 6.0 / 5.1 / 5.9 | pass |
| publisher `#7f8b97` on title band (raised) | 4.29 | **fails 4.5** (13 px VT323) |
| dim `#5d6b78` on ground / panel / raised | 3.5 / 3.2 / 2.7 | **fails** for text |
| disabled-text on disabled-bg | 2.64 | exempt, but carries "RÉSERVE PLEINE" |
| on-lime on primary / primary-hover / lime | 6.2 / 13.2 / 9.9 | pass |
| on-accent on accent (LIVE block, filled states) | 9.1 | pass |
| text-bright on line (secondary button) | 8.3 | pass |
| lime, gold, alert, motto, danger-text on panel | 9.7 / 10.8 / 6.5 / 7.2 / 10.2 | pass |
| rarity colours on panel (commune → légendaire) | 6.0 / 8.8 / 8.7 / 6.1 / 10.8 | pass |
| rarity colours on raised | 5.1 / 7.5 / 7.4 / 5.2 / 9.2 | pass (spine's "5:1 or more" holds) |
| muted at 78 % opacity on sunken (dim feed rows) | 4.35 | **fails** |
| dim at 78 % opacity on sunken | 2.57 | **fails** |
| line `#2a475e` (input / panel border) on panel / input | 1.8 / 2.0 | **fails 3:1 non-text** |
| line-soft on panel (tab, row, segment edges) | 1.35 | **fails 3:1 non-text** |
| accent focus ring on an accent-filled focused element | 1.0 | invisible |
| gold focus ring on a Légendaire gold frame | 1.0 | invisible |
| text / muted / rarity names / LIVE on steam-bar under the vignette (≈0.36–0.45 black at the edges) | ≈4.1–5.2 / 2.5–3.0 / 2.5–3.0 / 3.3–4.2 | **fails** (estimate) |
| lime vs Peu commune jade | 1.10 | hue-only difference |

## Critical

### C1 — Commune and Peu commune icons are the same shape
- **Location:** `DESIGN.md` Colors › Rarity, Rarity icon; `EXPERIENCE.md` Accessibility Floor ("shape and name always accompany it"); both mocks, `inShape()`.
- **Issue:** Rasterising the mocks' shapes at 7 × 7 and 9 × 9 art pixels gives the same silhouette for "circle" and "octagon". Only colour (grey vs jade) and shading tell them apart. Places that show the icon without a readable name: the top-bar rarity counter (icon + number), tray slots, feed thumbnails, missing-card slots at small size, the ticker. The rarity name on `card-s` is Silkscreen 7 px (see H6), so it does not reliably back the icon up.
- **Impact:** Colour-blind players (achromatopsia, low vision, a phone in sunlight) cannot tell tiers 1 and 2 apart in the counter and on small cards. The spine's own rule, "colour never stands alone", is broken.
- **Fix (spine):** Under Rarity icon, add: "The five silhouettes must differ by at least 8 art pixels from each other at 7 × 7 and stay distinct in greyscale. Commune is a hollow ring or a plain square; Peu commune keeps flat-cut corners at 9 × 9 and a different filled shape at 7 × 7." Add a build check that renders the five icons in greyscale at 7 × 7. In the top-bar counter, show the tier initial or a text tooltip-free label on focus, or add a visible legend on the collection RAPPORT panel.

### C2 — The reveal is silent for screen-reader users
- **Location:** `EXPERIENCE.md` Accessibility Floor (face-down card naming), Component Patterns (Face-down card, Tout révéler, Result banner), State Patterns (Cards dealt); desktop mock line ~1607 (only `aria-label` changes).
- **Issue:** After a reveal, only the focused button's accessible name changes. Screen readers do not reliably announce a name change on the focused element. "Tout révéler" reveals cards that are not focused, so nothing is said at all. The polite "booster hint" says how many cards remain, not what was revealed. The Légendaire "SIGNAL LÉGENDAIRE" state is visual only.
- **Impact:** For a blind player, the core moment of the product (what did I pull?) yields no feedback. They have to tab through five cards after every booster.
- **Fix (spine):** Add to the Accessibility Floor: "Every reveal posts one polite message to a dedicated booster live region: 'Carte 2 : Hades — Supergiant Games, 2020, Roguelite. Épique.' 'Tout révéler' posts one summary at the end ('5 cartes : 1 Épique, 1 Rare, 3 Communes') instead of five messages. A Légendaire posts 'Signal légendaire' when the sequence starts and the result when it lands. Focus stays on the revealed card."

### C3 — Moving and blinking content cannot be paused, and there is no in-app motion setting
- **Location:** `DESIGN.md` Activity feed (LIVE ticker), Elevation & Depth (stars, scanlines), Components (blinking LEDs, count-badge pulse, blinking segment, blinking colons, "CLIQUEZ POUR OUVRIR", "◀ ▶" hint); `EXPERIENCE.md` Component Patterns (LIVE ticker "pauses on hover"), Motion › Reduced motion.
- **Issue:** The ticker scrolls for 60 s in a loop. It pauses only on mouse hover, so keyboard and touch users cannot stop it. At least eight blinkers and pulses run indefinitely on the hub. The feed adds entries on its own. The only off switch is the OS `prefers-reduced-motion` setting. WCAG 2.2.2 (Level A) requires a pause, stop or hide control for any auto-moving or blinking content that lasts more than 5 s.
- **Impact:** Players with ADHD, vestibular disorders or low vision, and screen-magnifier users, cannot read the ticker or get rid of the distraction. Many players never set the OS preference.
- **Fix (spine):** (1) The ticker gets a focusable pause/play button next to "LIVE", and it also pauses on focus-within and on touch. (2) The feed gets a "Mettre en pause le direct" toggle that buffers new entries ("3 nouvelles entrées — afficher"). (3) Profil et paramètres gets a "Animations réduites" setting (default: follow the system) that applies the whole reduced-motion profile. (4) Ambient blinkers stop after 5 s, or are limited to state changes.

## High

### H1 — Single-key shortcuts 1–6 without an off switch
- **Location:** `EXPERIENCE.md` Component Patterns (Menu item), Interaction Primitives › Keyboard; desktop mock global `keydown`.
- **Issue:** Single-character shortcuts that work on the whole hub fail WCAG 2.1.4 (Level A) unless they can be turned off or remapped, or work only when the menu has focus. Speech-input users who dictate digits, and anyone typing by mistake, will trigger navigation.
- **Fix:** "Keys 1–6 work only while focus is in the hub menu, or with a modifier. A setting can turn them off." Also announce them in the menu items' `aria-keyshortcuts`.

### H2 — The vignette and scanlines sit above all content
- **Location:** `DESIGN.md` Elevation & Depth › Atmosphere, Components (vignette); desktop mock `.vignette` z-index 89 and `.scanlines` z-index 90, above the ticker (z 20), the top bar and toasts (z 79).
- **Issue:** The inset vignette darkens the screen edges by about 0.36–0.45 black, more in the corners. That is where the top bar, the LIVE ticker, the toasts (bottom centre) and the phone tab bar sit. The documented ratios no longer hold there: muted text and Commune or Épique names in the ticker fall to about 2.5–3.0:1, and the LIVE label to about 3.3–4.2:1 (estimates from the mock's shadow values).
- **Impact:** The status and navigation chrome is the least readable part of the screen for low-vision players.
- **Fix (spine):** "The vignette and star field sit under the content, on the ground layer. They never cover the top bar, ticker, tab bar, toasts or dialogs. Scanlines are at most 11 % black and are excluded from text-bearing chrome, or all contrast figures are checked with them applied." Add: "Every ratio in Colors is measured with every overlay applied."

### H3 — Reduced motion misses many animations and still flashes
- **Location:** `EXPERIENCE.md` Motion › Reduced motion; `DESIGN.md` Elevation & Depth ("Flash and shake exist only inside the booster opening and the trade swap").
- **Issue:** The reduced-motion list leaves out: the trade swap (arcs, tilt, ring, confetti, flash), the daily-booster arc, the back-equip flip, hop and burst, the **shake of a locked back**, the app-start whole-screen flicker, the star-field twinkle and its 1.1 s sideways shift on screen change (a parallax trigger), panel lock-in overshoot, menu row slide and arrow nudge, button lift, filter stagger, toast and dialog rise, feed slide and flash, the count bump, the count-badge pulse, the holo, foil and glow pulse on Légendaire cards outside the booster, the card-back sheen, the canister breathing, and the phone sub-view slides. "Flashes drop to 30 %" still produces a full-screen 0.10–0.15 white flash. The mock also shakes the stage on every reveal (Commune included) and every card landing, which contradicts DESIGN's rule.
- **Impact:** Vestibular and photosensitive players who asked for reduced motion still get shakes, flashes and parallax.
- **Fix (spine):** Rewrite the reduced-motion paragraph as a rule plus exceptions: "Under reduced motion, nothing translates, rotates, scales, shakes, flashes, blinks, sweeps or loops. State changes are opacity crossfades of 150–220 ms. Exceptions: none." List the Légendaire sequence explicitly ("the screen dims for 300 ms, the card fades in, a static banner shows for 1.4 s"), along with the trade swap ("cards crossfade into their new sides") and the locked back (an outline change, no shake). Remove "flashes drop to 30 %" and make it 0. Reconcile DESIGN's shake rule with the per-tier reveal shakes, or remove those shakes.

### H4 — Focus indicator is ambiguous, sometimes invisible, and unprotected from obscuring
- **Location:** `EXPERIENCE.md` State Patterns › Focus ("3px accent outline, gold on cards in grids"); `DESIGN.md` Menu item, Buttons, Tabs ("hover and focus" share one style); mock `:focus-visible` rules.
- **Issue:** (a) Focused menu items, secondary buttons and selected tabs fill with accent, so an accent ring next to them has 1.0:1 contrast and focus looks identical to hover. A mouse resting on another row shows two "focused" rows. (b) A gold ring on a Légendaire card (gold frame, gold glow, gold rays) is 1.0:1. (c) The mock uses 2 px inset rings and, for links, a colour change from muted to accent (1.45:1) plus an underline. The spine's 3 px outline is not what was prototyped. (d) Nothing stops the sticky top bar, the ticker, the phone tab bar or the pinned trade actions from hiding the focused element (WCAG 2.4.11).
- **Fix (spine):** "Focus is a 3 px `{colors.text-max}` ring with a 3 px `{colors.outline}` gap (double ring), separate from hover, on every focusable element including cards. Focus never relies on a colour change alone. Scrolling areas set `scroll-padding` equal to the top bar, ticker, tab bar and pinned actions so the focused element is never covered."

### H5 — Toasts carry essential messages for 2.8 s
- **Location:** `EXPERIENCE.md` Component Patterns (Toast), State Patterns (Opening refused, Not enough copies, One trade per pair, Back locked, Network error), Motion (Toast); mock `notice()` and the Esc handler.
- **Issue:** Errors and refusals ("EXEMPLAIRES INSUFFISANTS", "UN ÉCHANGE À LA FOIS", "DOS VERROUILLÉ" with its condition, network failures) disappear after 2.8 s and cannot be paused or recalled. In the mock, Esc both dismisses the toast and navigates to the hub in the same key press.
- **Impact:** Slow readers, dyslexic players, magnifier users and anyone looking away miss why an action failed.
- **Fix:** "Toasts confirm only. Errors and refusals also appear inline next to the control that failed and stay until the next action. Toasts stay at least 5 s plus 1 s per 10 words, pause while hovered or focused, can be closed with a button, and Esc closes the toast without doing anything else."

### H6 — Pixel fonts at 7–9 px carry essential information; no legible alternative
- **Location:** `DESIGN.md` Typography (micro 8 px, "7 to 10px on cards", card-title-s 9 px with line-height 9 px, label 10 px with 2 px tracking, kicker 3 px tracking), Trade board › Status chip (8 px), Tab bar (8 px labels); the spine's own open point on 7–8 px Silkscreen; the mocks use 7 px for small-card meta and rarity lines and the missing-art label.
- **Issue:** Silkscreen's capitals are about 5/8 of the font size, so at 7–8 px the caps are 4–5 px tall. At 7 px (not a multiple of the font's grid) the glyphs blur together. The rarity name on `card-s`, the trade status chips and the phone tab labels are information carriers at these sizes. Long uppercase, widely tracked strings ("RENVOYER LA CONTRE-PROPOSITION", "ANNULER LES MODIFICATIONS") remove word shape, which is the main cue for dyslexic readers. VT323 at 20 px reads like a 12–13 px regular font, and its line-height is 1.0 (body-small 0.94).
- **Fix (spine):** "No text below 8 px; Silkscreen only at 8 px or multiples of 8 or at 10/12 px as tested; information carriers (rarity name, status chips, tab labels) are at least 10 px. Multi-line VT323 uses a line-height of at least 1.2. Uppercase is applied with `text-transform` over sentence-case source (so screen readers and translations get normal text), and action labels longer than three words get a sentence-case VT323 alternative. Profil et paramètres offers 'Police lisible', which swaps the three pixel fonts for one legible sans (e.g. Atkinson Hyperlegible, OFL) at +2 px, normal tracking, sentence case."

### H7 — Focus management in the booster and trade flows is unspecified, and a double activation exits the reveal
- **Location:** `EXPERIENCE.md` State Patterns (only "Booster inventoried → focus to OUVRIR LE SUIVANT" is specified), Component Patterns (Revealed card: "Desktop: a click opens it in the collection"), State Patterns › Reveal abandoned.
- **Issue:** It is not stated where focus goes after the canister opens (the canister disappears), after "Tout révéler", after "Ouvrir le suivant", after "✕" removes a card from a side, after "PLACER" or "ANNULER" in the picker, after the trade swap, when a phone sub-view slides over or back, or after returning from Steam sign-in. A second click or Enter on a just-revealed card leaves the booster screen. Since "nothing resumes on return", a player with a tremor or a habit of double-clicking skips the remaining reveals.
- **Fix:** Add a "Focus" column or paragraph: "Cards land → focus on card 1; reveal → focus stays on that card; Tout révéler → focus on 'OUVRIR LE SUIVANT' when done; Ouvrir le suivant → focus on the canister; ✕ → the next card of that side or the add slot; picker closes → the add slot or the first placed card; swap ends → the status line (a `tabindex=-1` heading); a sub-view opens → its heading; back → the row that opened it." A revealed card ignores activation for 400 ms after its flip. It opens the detail in a dialog over the booster screen rather than leaving it, or the remaining cards stay face down on return.

### H8 — Feed live region will flood screen readers
- **Location:** `EXPERIENCE.md` Accessibility Floor ("the feed list announces new entries politely"); desktop mock `#fdList aria-live=polite`, a new entry every 5 s.
- **Issue:** A polite region that receives an entry every few seconds, more in production, queues speech without end and interrupts the reading of anything else on the page.
- **Fix:** "The feed is not a live region. A polite status line announces batches at most every 30 s ('4 nouvelles activités') while the feed is not focused, and never while the user is reading a feed entry. The pause toggle (C3) stops announcements too. The ticker is `aria-hidden` and not focusable."

### H9 — Phone touch targets below 44 px in the spine and the mock
- **Location:** `DESIGN.md` Tabs and filters (34 px, explicitly "on the phone, as chip rows"), Buttons (`button-height-sm` 34 px, the small "RÉCUPÉRER"), Trade board › Remove ("small square ✕"), Modal close ✕ (size unstated); phone mock: stepper buttons 44 × 36, remove ✕ 32 × 32 offset −10 px over the card edge, top-bar chips 36 px.
- **Issue:** The spine's own 44 px floor is contradicted for phone chip rows and small buttons. The mock's stepper misses the 44 px height that the spine requires.
- **Fix:** "On the phone, every interactive element has a 44 × 44 px hit area (visual size may be smaller with an invisible extension), with 8 px between adjacent targets: chip rows, small buttons, the stepper (44 × 44), the remove ✕ (44 × 44 hit area, not overlapping the card's own hit area), the modal ✕, links." Add `chip-height-touch: 44px` to the tokens.

## Medium

### M1 — Low-contrast tokens used for information
- **Location:** `DESIGN.md` Colors (dim, publisher), Activity feed (time in dim VT323; "Lower-tier fill entries … 78 % opacity"), Trade board › Status chip ("CLOS" dim, 8 px), Daily booster ("RÉSERVE PLEINE" on a disabled button); `EXPERIENCE.md` Accessibility Floor (exception for dim and publisher).
- **Issue:** Feed timestamps are not repeated elsewhere. "CLOS" is a state (3.2:1 on panel, 2.7 on raised, at 8 px). Dimmed feed rows put muted text at 4.35 and dim at 2.57. The publisher on the title band is 4.29, and on the phone collection it is the only place the publisher is visible. "RÉSERVE PLEINE" exists only as disabled text (2.64).
- **Fix:** Set `publisher` to `#8a96a2` (4.95 on raised, 5.8 on panel). Use `dim` only for decoration. Show feed times and "CLOS" in muted. Dim low-tier feed rows by background only (sunken), never by opacity on text. Add a muted VT323 line under the disabled claim: "Réserve pleine : ouvrez un booster pour récupérer celui du jour."

### M2 — Non-text contrast of controls (WCAG 1.4.11)
- **Location:** `DESIGN.md` Text field (2 px `line` well), Tabs and filters, Settings row segments, Radio list squares, Quantity stepper, Thin progress bar track.
- **Issue:** Field and control boundaries in `line` (1.8–2.0:1) and `line-soft` (1.35:1) do not meet 3:1, so an empty text field or an unselected segment is hard to locate.
- **Fix:** "Boundaries of interactive controls (inputs, unselected tabs and segments, radio squares, stepper) use `{colors.line-deep}` (3.2:1 on panel) or brighter; progress tracks show a 3:1 edge or the value as text."

### M3 — Blink rates are unbounded; the mock blinks at 4–7 Hz
- **Location:** `DESIGN.md` Status LED ("gold blinking fast on a Légendaire signal"), Canister (LEDs orange when armed); mock `ledBlink .25s` (4 Hz), `ledArm .14s` (about 7 Hz).
- **Issue:** The areas are small, so this passes WCAG 2.3.1, but the LEDs carry glows and sit next to the full-screen flash and the shake. Above 3 Hz is the photosensitive danger band (2.3.2).
- **Fix:** "No element blinks or flashes faster than 2 Hz. At most one full-screen flash per sequence and never more than 3 flashes in any second. The opening flash and the Légendaire flash never overlap a reveal flash when 'Tout révéler' chains cards." Keep the warm flash desaturated (not red).

### M4 — Hub cognitive load and structure
- **Location:** `EXPERIENCE.md` Information Architecture › Hub content; `DESIGN.md` Layout & Spacing.
- **Issue:** Around a dozen things move at once on the hub: stars, scanlines, the ticker, the LIVE blink, the gold kicker blink, the showcase float, shadow, rays and holo/glow, the goal LED and current segment, the badge pulse, the countdown colons, the per-second countdown digits, the goal count. All this sits in three columns over a ticker. The spine defines no heading or landmark structure, and no reading order for the three columns.
- **Fix:** Add a "Structure" line per screen: one `h1` (the screen title or "Pont de commandement"), `nav` for the menu, `main` for the showcase, `complementary` for the goal and sets, the ticker hidden. Reading order: menu, daily booster, showcase, goal, sets. "At most two ambient animations run at once outside the booster screen; countdowns update their visible digits every minute when more than an hour remains."

### M5 — Esc does too much
- **Location:** `EXPERIENCE.md` Interaction Primitives › Keyboard, State Patterns › Counter-proposal ("Esc cancels the edit"), Information Architecture ("Esc from any screen" to the hub).
- **Issue:** Esc silently discards a counter-proposal in progress and navigates away from any screen (losing filters and scroll). Users press Esc to dismiss IME candidates, browser find bars and autocomplete. In the mock, one Esc closes the toast and leaves the screen.
- **Fix:** "Esc closes the topmost overlay (dialog, picker, toast) and nothing else. It cancels a counter-proposal only after a confirmation ('Abandonner vos modifications ?'). It returns to the hub only when nothing else consumed it, no edit is in progress and focus is not in a text field."

### M6 — Dialogs, picker and stepper semantics
- **Location:** `DESIGN.md` Dialogs, Card picker, Quantity stepper; `EXPERIENCE.md` Modal, Card picker, Quantity stepper, Keyboard; mocks (`role=dialog aria-label="Fenêtre"`).
- **Issue:** The dialog name, the initial focus and the "✕" name are unspecified, and the mock names every dialog "Fenêtre". In the card picker, the arrows are meant to move through the grid (as in the collection) and also to change a quantity, which conflicts. "4 CARTES AU PLUS" and "COPIÉ ✓" are not stated as announced.
- **Fix:** "Dialogs take `aria-labelledby` from their title row; initial focus goes to the first field or the primary action, never to ✕. The ✕ is named 'Fermer'. The picker grid uses one tab stop with arrows to move. The stepper is a `spinbutton` (Up/Down, +/−, Home/End) reached with Tab from its card. Refusals and 'COPIÉ' are announced politely. The phone bottom sheet keeps its ✕; swiping down is only a shortcut."

### M7 — Reflow, zoom and text spacing
- **Location:** `DESIGN.md` Typography and Layout (all sizes in px; line-height equal to font size on card titles and body; fixed heights for the menu item 50, ticker 32, plate 52, chips 34); `EXPERIENCE.md` Responsive (breakpoint open).
- **Issue:** It is not stated that 400 % zoom on a 1280 px window (320 CSS px) yields the phone layout, that the browser's default font size is honoured, or that user text spacing (line-height 1.5, letter-spacing 0.12 em, word-spacing 0.16 em) does not clip fixed-height rows and two-line card titles.
- **Fix:** "Breakpoints are in CSS px of the viewport, so browser zoom reaches the phone layout; at 320 px wide nothing scrolls horizontally except card rows designed to. Text sizes are set in rem from a 16 px root, with the art pixel kept in px. Rows with text use `min-height`, never `height`; card titles may grow the title band. Verified with the WCAG 1.4.12 text-spacing bookmarklet."

### M8 — Card and media semantics are incomplete
- **Location:** `EXPERIENCE.md` Accessibility Floor; `DESIGN.md` Pixel filter (canvas), Avatars and thumbnails, Segmented gauge, Daily booster countdown, Packs chip.
- **Issue:** The text exposed on a card lacks the number, copies owned, "NOUVEAU" and the reserved count. The mock's collection slot omits publisher, year and genre. Nothing is said about the canvas cover, the thumbnails, the avatars, the decorative rays, or the gauges. The mock rewrites the packs chip's `aria-label` every second with the countdown.
- **Fix:** "A card's text is: title, publisher, year, genre, rarity, number, then state (copies, NOUVEAU, reserved). Cover canvases and thumbnails are `aria-hidden` (the title is the text). Avatars carry `alt=''` next to a visible name. Rarity icons are `aria-hidden` when the name is beside them. Gauges are `role=progressbar` with a text value. Countdowns are not live and their accessible text changes at most every minute ('Prochain booster vers 02 h 00')."

### M9 — Time limits and their wording
- **Location:** `EXPERIENCE.md` Voice ("prêt à minuit (UTC)"), Daily booster, Trade states ("Expire dans n j").
- **Issue:** "Minuit UTC" forces mental arithmetic (it is 01:00 or 02:00 in France). It is not said whether a daily booster that is not collected is lost at the day change. Expiry is shown in days down to the last day, with no warning before a proposal lapses.
- **Fix:** "Times are shown in the player's local time ('prêt à 02 h 00'), with UTC only in a tooltip-free secondary line if needed. The daily panel states whether today's booster lapses at the day change. Under 24 h, expiry is in hours ('Expire dans 5 h'), and the trade list puts it first with the hourglass and the word 'bientôt'."

### M10 — Gestures and touch alternatives on the phone
- **Location:** `EXPERIENCE.md` Interaction Primitives (Swipe, Tilt "under a held finger"), Revealed card, Card detail; `DESIGN.md` Reveal caption plate ("◀ ▶" hint).
- **Issue:** Tap is overloaded on the top card (the first tap reveals, the second stores), so a double tap stores a card before it is seen. The "◀ ▶" hint looks like controls but is not one. A held-finger tilt on grid cards competes with scrolling and the OS long-press menu. The spine does not say that every swipe has a visible button.
- **Fix:** "Every swipe has a visible button: 'RANGER' under the revealed card, ◀ ▶ buttons (44 × 64) in the card detail. A revealed card ignores taps for 400 ms after its flip. Tilt starts only after 150 ms without vertical movement and is off under reduced motion. Long-press is never required." Turn the plate's "◀ ▶" into the 'RANGER' button or remove it.

### M11 — Long sequences cannot be skipped
- **Location:** `EXPERIENCE.md` Tout révéler ("never skips a Légendaire's sequence"), Opening in progress (navigation blocked).
- **Issue:** Navigation is blocked through each sequence, and "Tout révéler" with a Légendaire lasts several seconds. Players who find the effects distressing have no escape other than the OS setting.
- **Fix:** "During an opening or reveal, a 'Passer' control (and Esc) jumps to the end state. Reduced motion shortens every sequence as in H3."

## Low

### L1 — Rare equals the accent colour; jade sits next to lime
- **Location:** `DESIGN.md` Colors (`rarity-rare` = `accent` = `#66c0f4`), Rarity (jade vs lime, 1.10:1).
- **Issue:** Rare-coloured text reads as interactive accent text. Jade and lime differ by hue only, which is weak for deuteranopes. The spine keeps jade off buttons, but the lime "NOUVEAU" tag sits on jade-framed cards.
- **Fix:** Note that rarity-coloured text is never interactive, and keep NOUVEAU's word as its meaning (already so).

### L2 — Hover-only `title` tooltips
- **Location:** Mock badges and the rarity counter.
- **Issue:** Hover-only information is lost on touch and keyboard.
- **Fix:** "No information lives only in `title`."

### L3 — App-start whole-screen flicker
- **Location:** `EXPERIENCE.md` Motion › App start.
- **Issue:** A brightness overshoot of 0 → 1.5 over the whole screen. It is single, so not a seizure risk, but unpleasant.
- **Fix:** List it in the reduced-motion profile and cap the overshoot at 1.1.

### L4 — Pointer-only copy
- **Location:** `EXPERIENCE.md` Cards dealt ("Cliquez une carte…"), canister "CLIQUEZ POUR OUVRIR".
- **Issue:** The copy addresses pointer users only.
- **Fix:** Use device-neutral copy ("Révélez une carte · n restantes") or switch the wording for keyboard use. State that Space as well as Enter activates the canister and face-down cards.

### L5 — Language
- **Location:** `EXPERIENCE.md` Foundation, Accessibility Floor (language), Card detail (Steam description).
- **Issue:** The Steam short description may come in another language than the UI. The English copy and English rarity names do not exist yet.
- **Fix:** "`<html lang>` follows the chosen language. Any text block whose source language differs (Steam description, a player's free text) carries its own `lang`. Game titles are proper names and need none." Writing the English rarity names is a prerequisite for English screen-reader output.

### L6 — State shown by border only
- **Location:** `DESIGN.md` Trade board ("a side being edited gets an accent border"), Settings (selected segment fill).
- **Issue:** The edited state is shown by a border colour only.
- **Fix:** Add the text "EN ÉDITION" to the side header. Segments use `aria-pressed` or radio semantics consistently (the mock mixes both).

### L7 — Links that open new tabs or leave the site
- **Location:** "VOIR SUR STEAM ↗", Steam sign-in.
- **Issue:** Players are not told that a link opens a new tab or leaves the site.
- **Fix:** Accessible names add "(nouvel onglet)". The sign-in button says it opens Steam.

### L8 — Typed delete confirmation
- **Location:** `EXPERIENCE.md` Delete dialog.
- **Issue:** The typed confirmation is not specified for case, paste or language.
- **Fix:** "Case-insensitive, paste allowed, the word localised ('DELETE' in English), the field labelled with the word to type."
