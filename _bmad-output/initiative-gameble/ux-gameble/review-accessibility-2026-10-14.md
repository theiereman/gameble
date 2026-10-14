# Reviewer Gate — Accessibility lens, visitor landing (2026-10-14)

Scope: the landing added to `DESIGN.md` and `EXPERIENCE.md` on 2026-10-14 (uncommitted diff), read against the rest of both spines (tokens, Colors, Motion, Reduced motion, Accessibility Floor), and the reference render `mockups/landing.html` (markup, CSS, JS; the grey REVUE toolbar, note pins and edit outlines are ignored). Baseline: WCAG 2.2 AA plus the house floor (44 × 44 phone targets 8px apart, 10px / VT323 20px readability, `{colors.dim}` decorative only). Points settled by `review-accessibility.md` and `review-accessibility-2026-10-08.md` are not repeated unless the landing brings them back. Ratios use the WCAG 2.x formula on the hex tokens. Each finding says whether the gap is in the **spine**, **mock only**, or **both**.

## Verdict

The landing's structure is sound: one h1 and one h2 per module, a named reveal demo with its own polite region, a side gauge built as a navigation landmark, roadmap statuses written in text, and the lamp and moving cards kept out of the accessibility tree. Two gaps block the build. First, the power-on rule ("about an eighth of it enters the view") leaves a whole module invisible once it is taller than about eight viewports, which happens at 400% zoom. Second, a signed-out visitor cannot reach the "Animations réduites" setting, so the lamp sweep, the self-updating feed, the blinking LIVE marker and the rotating rays cannot be paused on the page. That brings back the old C3 finding. **Not ready until both critical findings and the three high findings are written into the spines. The mediums should land before the landing's build story.**

Counts: critical 2 · high 3 · medium 5 · low 7.

## Contrast reference (computed)

| Pair | Ratio | Status |
|---|---|---|
| `{colors.dim}` `#5d6b78` on ground / on panel | 3.51 / 3.20 | decorative only: sweep mode word, slot "?" |
| `{colors.muted}` on the side gauge plate (`#0e141b` at .92 over ground) | 6.32 | pass: the spine's fix of the mock's dim numbers is right |
| `{colors.dim}` on the side gauge plate (mock) | 3.38 | fails as the markers' only visible text (fixed in the spine) |
| `{colors.text-bright}` over a lit card, lamp inner disc (veil 0) | 1.17 – 1.39 on bright art (white, accent, gold) | **fails** |
| same, ring r1–r2 (veil .9 × .42) | 2.21 – 3.35 | **fails** |
| same, ring r2–r3 (veil .9 × .74) | 5.91 – 7.86 | pass |
| same, full veil `rgba(5,7,10,.9)` | ≥ 13.9 | pass |
| `{colors.accent}` "TROUVÉ" tag on panel-sunken | 9.18 | pass |

## Critical

### C1 — A module taller than about eight viewports never powers on, so its content stays invisible (spine and mock)
- **Location:** `EXPERIENCE.md` Component Patterns › Landing › Module ("Powers on once, when about an eighth of it enters the view"); Motion › Landing module power-on; mock `IntersectionObserver(..., { threshold: 0.12 })` and `html.js .module .rv { opacity: 0 }` (every h2, intro and panel is `.rv`).
- **Issue:** An IntersectionObserver ratio is a share of the target's area. When a module is taller than the viewport divided by 0.12 (8.3 viewports), the ratio can never reach 0.12, and the module's title and content stay at opacity 0. At the reflow test size (1280 × 720 at 400%, a 320 × 180 CSS px viewport), that limit is 1 500px. Modules 02 and 05 in one column at 320px, and most modules once English copy or user text spacing is applied, are taller than that. A low-vision zoom user gets blank space where the content should be (1.4.10 Reflow, 1.4.4 Resize Text). A keyboard user also tabs onto invisible links (2.4.7). The spine sentence "The content is in the page from the start; power-on is only an animation" holds for screen readers but not for sighted users.
- **Fix (EXPERIENCE.md, Landing › Module, replace the first sentence):**
  > Powers on once, when its top edge passes 85% of the viewport height, whatever the module's height (a fixed position, never a share of the module), and at once when the module holds keyboard focus, is the target of a jump (side gauge, in-page link, URL fragment) or is above the viewport on load. Content is never held invisible for more than the power-on itself (about 0.6s); without JavaScript, or if the observer is missing, modules are on from the start.
- **Fix (Motion › Reduced motion › Landing):** keep "modules fade in over 180ms", and add "under the same trigger".

### C2 — Signed out, nothing on the landing can pause what moves, blinks or updates (spine; brings back C3)
- **Location:** `EXPERIENCE.md` Motion › Reduced motion ("Applies when 'ANIMATIONS RÉDUITES' is OUI in Profil et paramètres, or … SYSTÈME (the default) and the system asks for it"); Accessibility Floor › Moving content ("stops with 'ANIMATIONS RÉDUITES'"); Component Patterns › LIVE ticker ("the only way a keyboard user stops it"); Landing › Lamp field, Live feed list, Moving cards; mock lines 1490–1504 (03 countdown every 1s; feed and "Boosters ouverts aujourd'hui" every 8s).
- **Issue:** The house fix for C3 was the "Animations réduites" setting in Profil et paramètres. A visitor has no account, so the landing has only the OS `prefers-reduced-motion` setting, which many people never set and cannot change on a shared machine. Content that runs for more than 5s next to other content, with no control on the page:
  - the lamp sweep, which moves forever (it wanders once every card is found) beside the h1, and on the phone behind it;
  - the live list, which adds an entry every 8s, and the "Boosters ouverts aujourd'hui" figure;
  - the LIVE marker's 1s blink;
  - the 03 countdown;
  - the rays turning behind the Épique and Légendaire moving cards (48s loop), the Légendaire glitter, the star twinkle and the scroll drift `[ASSUMPTION]` of the star layers.

  This fails 2.2.2 Pause, Stop, Hide (A) on the first screen. The scroll-driven moving cards and parallax are a vestibular trigger (2.3.3, AAA, which the house floor already serves) with no visitor switch.
- **Fix (DESIGN.md Landing › Top bar, and EXPERIENCE.md Landing, new row):**
  > | Motion control | A toggle button "Animations réduites" (`aria-pressed`) in the landing's top bar, before the Steam image, first in the tab order after the wordmark (a pixel icon with its name on the phone, 44 × 44). On: the whole Reduced motion profile, landing form included, at once. Its state is kept for the visitor in a first-party cookie, so the server renders the reduced form on the next visit. At sign-in it becomes the account's initial setting (OUI when on, else SYSTÈME). Off and no cookie: the system preference applies, read in CSS (`@media (prefers-reduced-motion: reduce)`) so the reduced form holds from the first frame. |
- **Fix (Reduced motion, first sentence, append):** "For a visitor without an account: the landing's toggle when set, otherwise the system."
- **Fix (Landing › Live feed list):** see M2. The list also pauses while hovered or while focus is inside it.
- **Fix (Landing › Lamp field):** "The lamp's own sweep stops at rest on the last card found once every card is found (no wandering), and it never runs for more than 30s without a pointer."

## High

### H1 — Moving cards can hide the focused element and the text, are gated by width rather than by pointer, and block scrolling on touch (spine and mock)
- **Location:** `DESIGN.md` Landing › Moving cards; `EXPERIENCE.md` Landing › Moving cards ("Desktop only (from 720px)"), Accessibility Floor › Landing (`[ASSUMPTION]` "a keyboard or touch user scrolls past a card that covers text"), Responsive › Landing on desktop; mock `.near` (`position: fixed; z-index: 40`), `.nc` (`pointer-events: auto; touch-action: none`), cards placed from −5% to +6% of the width from each edge.
- **Issue:**
  - **Focus (2.4.11 Focus Not Obscured, AA):** a `card-l` is 208 × 312. Near the edges it covers the start of the 1120px column, where every heading, link and button is left-aligned. When Tab scrolls a link into view, the scroll-driven card can rest on top of it, and the spine has no rule that clears a focused element.
  - **Zoom (1.4.10, 1.4.4):** "Desktop" is decided by width. At 200% zoom on a 1440px screen the viewport is 720 CSS px, the cards keep their CSS size, and they cover about a third of the column all along the page.
  - **Touch:** tablets from 720px get the cards. `touch-action: none` makes a finger that lands on a card drag it instead of scrolling the page, and touch exploration finds an aria-hidden card instead of the link under it.
  - **Pointer:** a click aimed at a link under a card grabs the card instead.

  Dragging is only acceptable without an alternative (2.5.7) if the cards never sit over content in a way scrolling cannot clear. That is the `[ASSUMPTION]` that needs closing.
- **Fix (DESIGN.md Moving cards and EXPERIENCE.md Landing › Moving cards, replace "Desktop only (from 720px)"):**
  > Only with a fine pointer that hovers (`(hover: hover) and (pointer: fine)`) and from a viewport width where a card overlaps the content column by at most 48px (about 1440 CSS px, so zoom past 133% removes them). A card fades out (150ms, instant under reduced motion) while keyboard focus is inside the page content (`:focus-visible` within main), and never rests over a focused element. It lets pointer events through except on its own visible box, and never sets `touch-action: none`. Scrolling always moves a card relative to the content (1.5 to 1.9 times the scroll), dropped cards included, so a covered line is cleared without dragging.
- **Fix (Accessibility Floor › Landing):** replace the `[ASSUMPTION]` sentence with a pointer to that rule.

### H2 — On the phone the hero text sits over lamp-lit card art at 1.2 to 3.4:1 (spine and mock)
- **Location:** `DESIGN.md` Landing › Lamp field ("On the phone the field spreads behind and around the text, which gets a soft `{colors.ground}` text shadow to stay legible"), Layout › Landing on the phone; `EXPERIENCE.md` Responsive › Landing on the phone; mock phone card positions (`fy` .6 to .99 of the whole hero: behind the line and the button) and `text-shadow: …, 0 0 12px var(--ground)`.
- **Issue:** The lamp opens the veil to 0 in its inner disc and to .38 in the next ring. Over a bright cover, `{colors.text-bright}` falls to 1.17–3.35:1 (table above), below 1.4.3 (AA) and against the spine's own rule: contrast is measured "with every overlay applied". A 12px blurred halo is not a background and cannot be counted. On the phone the lamp always sweeps, so the background behind the h1 and the line keeps changing.
- **Fix (DESIGN.md Lamp field, replace the last sentence):**
  > On the phone the field spreads behind and around the text, but the lamp never opens the veil behind the hero copy: the copy's box (kicker, hook, line, button, plus 8px) keeps the full veil `{components.lamp.veil}`, and no card is placed so that its lit part falls under that box. Text contrast is measured over the brightest cover with the lamp at its worst position.

### H3 — The Steam image's accessible name does not contain its visible words (spine; app-wide, set by the landing copy deck)
- **Location:** `EXPERIENCE.md` Copy deck › Landing › Top bar (Valve's image, accessible name "Se connecter avec Steam (ouvre Steam)"), Accessibility Floor › Links and sign-in; `DESIGN.md` Steam sign-in; mock `aria-label` on both `.steam` links.
- **Issue:** Valve's image shows the text "Sign in through STEAM", in English, untranslated by rule. Its accessible name starts with French words that are not in the image. A speech-input user who says "click Sign in through Steam" gets no match: 2.5.3 Label in Name (A), on the page's only sign-in path, which also appears in the top bar, the final call, the sign-in panel and the public page.
- **Fix (Copy deck, Top bar and 09):**
  > Valve's image: `alt=""`, and the link's name is a visually hidden text that starts with the image's words, `<span lang="en">Sign in through Steam</span> : se connecter avec Steam (ouvre Steam)`, in every place the image appears.

## Medium

### M1 — Side gauge: the mock's names break Label in Name, and the focus target after a jump, the tab position and the target width are open (both)
- **Location:** `EXPERIENCE.md` Landing › Side gauge; Copy deck › Side gauge (`[ASSUMPTION]`); Interaction Primitives › Keyboard; mock `#readout-list` (`aria-label="Mission"` over the visible text "00", `aria-current="true|false"`, `min-height: 24px`, about 21px wide, the `<nav>` placed before `<main>`).
- **Issue:** (a) In the mock, `aria-label` replaces the visible "00" with "Mission" (2.5.3, A). The copy deck's form "00 · Mission" passes, but it is still marked `[ASSUMPTION]` against the mock. (b) Nothing says where focus goes after a jump, so a screen-reader or keyboard user stays on the gauge, far from the module that just scrolled into view (2.4.3). (c) The ten links come before main in the DOM: ten tab stops before the hero's action. (d) Each marker is about 21px wide. 2.5.8 passes only through the spacing exception.
- **Fix (Side gauge row, append):**
  > Each marker's name starts with its visible number ("00 · Mission"; settle the copy deck and drop the `[ASSUMPTION]`). A jump moves focus to the module's h2 (`tabindex="-1"`, its `scroll-margin` keeping it clear), instantly under reduced motion. `aria-current="location"` on the current marker only. The gauge follows main in the DOM and is placed with CSS, and each marker is at least 24 × 24.

### M2 — The live list updates under the reader with no pause and no stated announcement rule (spine)
- **Location:** `EXPERIENCE.md` Landing › Live feed list ("a new entry slides in at the top and the oldest leaves. Not a live region"), Accessibility Floor › Feed and ticker (the app's batched status line), Open questions (arrival rate); mock `renderFeed` rewrites the whole `<ol>` every 8s, and the reduced-motion form keeps updating.
- **Issue:** 2.2.2 (A) for auto-updating content (see C2). A screen-reader user reading the list in browse mode loses their place when every row shifts. The spine does not say whether the Floor's 30s status line runs on the landing.
- **Fix (Live feed list row, append):**
  > New entries are inserted as one node at the top and the last node removed; the list is never re-rendered. Updates pause while the list is hovered, while focus is inside the module, and under the motion control (C2), and buffered entries arrive together when it resumes. No status line on the landing: the module is a sample, and the full feed is one link away. The "Boosters ouverts aujourd'hui" figure follows the same pause.

### M3 — The 01 rarity row cannot be swiped sideways on the phone when the finger starts on a card (spine)
- **Location:** `EXPERIENCE.md` Interaction Primitives › Tilt ("Cards in scrolling content keep vertical panning (`touch-action: pan-y`)"); Landing › Rarity cards ("On the phone the row scrolls sideways"; "one tab stop"); `DESIGN.md` Layout › Landing on the phone.
- **Issue:** The cards fill most of the 01 row. Under the house tilt rule they accept only vertical panning, so a horizontal swipe that starts on a card is lost, and the Rare, Épique and Légendaire cards cannot be reached by touch. The one tab stop also stays on desktop, where the row does not scroll: an empty stop (2.4.3, minor).
- **Fix (Rarity cards row, append):**
  > In the phone's sideways row the cards do not tilt and use `touch-action: pan-x pan-y`. The row is a tab stop only while it overflows. The same applies to the 06 roadmap row.

### M4 — Link purpose: "Embarquer sur le pont" and "Découvrir" do not say where they lead, and one destination has two names (spine)
- **Location:** `DESIGN.md` Landing › Hero, Public card page; `EXPERIENCE.md` Copy deck › Landing (Hero, 09 hub link "Visiter le pont sans compte" `[ASSUMPTION]`), Copy deck › Public page, Open questions › Landing final call.
- **Issue:** The hero's lime button, the page's most prominent action, opens the signed-out hub. Its in-world name gives no hint that it means "look around without an account", next to a Steam image that does sign in (2.4.4 A, 2.4.6 AA). "Découvrir" has no object, and its context on the public page is not designed. The signed-out hub is named "Embarquer sur le pont" on the hero and the public page but "Visiter le pont sans compte" in 09, which goes against 3.2.4 (AA).
- **Fix (Copy deck):**
  > Hero and public page: visible "Embarquer sur le pont", accessible name "Embarquer sur le pont, visiter le jeu sans compte". Public page: "Découvrir gameble" (or that accessible name). 09's hub link uses the same visible text and name as the hero's.

### M5 — Examples read as real events and real progress to a screen reader (both)
- **Location:** `EXPERIENCE.md` Accessibility Floor › Landing ("an example that carries meaning (a set row, the collection bar) has a text name starting 'Exemple : '"); `DESIGN.md` Landing › 02 tiles, 05 panels; mock 02 tiles ("Hollow Knight · Hugo Première découverte", "Nina a reposté Hades", "Inès complète Dark Souls"), 05 goal ("Semaine 41 Atteint …") and achievement rows ("Premier booster obtenu"), none prefixed.
- **Issue:** Module 04 shows the real feed in the same sentence forms. A screen-reader user cannot tell the 02 and 05 illustrations from live data, or "obtenu" rows from their own achievements (1.3.1). The spine names only two of the examples.
- **Fix (Accessibility Floor › Landing, replace the example clause):**
  > Every example on the landing (02's four tiles, 03's illustrations, 05's six visuals) is either hidden from assistive technology or named as one block starting "Exemple : " (for instance "Exemple : Hugo a fait la première découverte de Hollow Knight"). Only 04 and the goal panels carry real data.

## Low

### L1 — Module labels are outside the headings, and some heading-like lines are paragraphs (both)
- **Location:** `DESIGN.md` Landing › Module header, 07 (recruiting line), 08 (support panel); `EXPERIENCE.md` Accessibility Floor › Landing; mock `section[aria-labelledby]` on every module and on 04's two inner boxes.
- **Issue:** The side gauge says "Concept", but the h2 says "Chaque carte est un jeu Steam.", so the two names a screen-reader user hears never match. 07's "Nous recrutons…" (VT323 28px) and 08's support line (VT323 36px) look like headings but are paragraphs (1.3.1). In the mock every labelled `<section>` becomes a region landmark, about thirteen in all, which clutters the landmarks list.
- **Fix:** Make the module label part of the h2's accessible name (`aria-labelledby` naming the "01 · Concept" span and the title). Make 08's support line an h3. Only main, the gauge's nav, the top bar and the footer are landmarks: modules are `<section>` elements without an accessible name.

### L2 — External and new-tab links lack their hidden copy (spine)
- **Location:** `EXPERIENCE.md` Copy deck › Landing (07 button, 08 "Soutenir", footer); Accessibility Floor › Links and sign-in.
- **Issue:** Only "Voir le projet" is said to name its new tab. "Soutenir" (08 and footer) and "Code source" leave gameble for another site in a new tab, and the copy deck gives no text for it (2.4.4; the Floor's own rule).
- **Fix (Copy deck):** add the hidden suffixes "(GitHub, nouvel onglet)" for "Voir le projet" and "Code source", and "(site de dons, nouvel onglet)" for both "Soutenir" links.

### L3 — Language of parts (spine)
- **Location:** `EXPERIENCE.md` Accessibility Floor › Language; Copy deck › Landing ("LIVE", "Repost").
- **Issue:** On a French page, "LIVE" and "REPOST" are read with French pronunciation (3.1.2, AA). Game titles are proper names and exempt.
- **Fix:** add to the Floor: "The interface's English words ('LIVE', 'REPOST') carry `lang="en"`."

### L4 — Under reduced motion the lamp freezes on "2 / 6" and the pointer no longer steers it (spine and mock)
- **Location:** `EXPERIENCE.md` Motion › Reduced motion › Landing ("the lamp stays still on the first card, with the first two cards already found"); mock `manual = !c.still && …`.
- **Issue:** No content is lost: the field is decoration and hidden from assistive technology, and in full motion the auto sweep finds every card without a pointer. But a reduced-motion visitor gets a counter that never moves and four cards no one can find.
- **Fix:** "Under reduced motion the lamp jumps, without travelling, to the pointer's position while the pointer is over the field, and a card under it is found. Without a pointer it rests on the first card."

### L5 — Decorative words in the lamp readout sit in the field's fade (spine and mock)
- **Location:** `DESIGN.md` Landing › Lamp field (readout; "The field fades out over its bottom 18%"); mock `.hf__read` placed below the slot inside the masked `.hf`, sweep mode in `{colors.dim}`.
- **Issue:** The readout ("JEUX RETROUVÉS 2 / 6") falls inside the 82–100% mask fade, so its muted and white text loses contrast. That is acceptable only as decoration. The sweep mode is in `{colors.dim}` (3.51:1).
- **Fix:** state "The readout is decorative, like the field, and sits above the fade."

### L6 — Phone targets below the house floor (mock only)
- **Location:** mock `.btn--sm` "Révéler" at 34px on the phone (`{spacing.button-height-sm-phone}` is 44px), footer links wrapping with a 4px row gap (`{spacing.touch-gap}` is 8px), and the top bar wordmark link about 24px tall on the phone.
- **Fix:** none in the spine (the Touch rule covers it). Note these in the mock's header comment so builders do not copy them.

### L7 — Visible text clipped at narrow widths (mock only)
- **Location:** mock `.mini__row` (`white-space: nowrap; overflow: hidden`, 02 "Contribuez" example), `.tag` and `.chip-gold` (nowrap).
- **Issue:** At 320 CSS px, "Inès complète Dark Souls" is cut without an ellipsis (1.4.10, 1.4.12).
- **Fix:** let these lines wrap. Note it in the mock's header comment.

## Checked and holding

- Heading order: hero h1, nine h2s, h3s inside, with no skipped level.
- The reveal demo: a real button, a polite region that exists from load, focus kept, crossfade under reduced motion.
- The 02 and 04 goal gauges are progress bars with `aria-valuetext`.
- Roadmap statuses are in text, with a hidden status on mixed items.
- The lamp field, the moving cards and the gauge's track are `aria-hidden` and hold nothing focusable.
- Links on the phone are 44px tall.
- The Steam image has a 44px hit area.
- The focus ring follows `{components.focus-ring.css}`.
- `<html lang>` follows the URL locale.
- The mock's reduced-motion form follows `prefers-reduced-motion`, without JavaScript too.
