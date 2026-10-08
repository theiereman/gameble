# Reviewer Gate — Accessibility lens, recognizable sets (2026-10-08)

Scope: only the set surfaces and rules added or changed on 2026-10-08 in `DESIGN.md` and `EXPERIENCE.md` (commit 41ac649), cross-checked against the approved mock `mockups/key-collection-sets.html`. Baseline: WCAG 2.2 AA. Points settled by `review-accessibility.md` and now in the spines are not repeated: the focus ring, toasts, the general 44 × 44 phone floor, one h1 per screen, gauges as progress bars, the booster live region for reveals, the reduced-motion rule, overlays under content, and the 10px / VT323 20px readability floor. Where the set surfaces break one of those rules, this review says so. Contrast ratios are computed with the WCAG 2.x formula from the hex tokens.

## Verdict

The tier tokens pass on every surface, and the "never colour alone" rule for tier identity (name plus 1–3 notches) is sound. Four gaps block the build contract:

- Whether a tier is reached is still shown by colour alone.
- The phone celebration changes on an unspecified timer.
- The celebration's screen-reader message has no copy and no timing, and the mock adds a second live region.
- The set search has no label rule and no result announcement.

These are fixable in spine text without changing the approved look. **Ready once the four high findings are written in. The mediums should land before the stories that build these screens.**

Counts: critical 0 · high 4 · medium 8 · low 6.

## Contrast reference (computed)

| Pair | panel `#121a24` | panel-raised `#1b2838` | panel-sunken `#0e141b` | ground | steam-bar | Status |
|---|---|---|---|---|---|---|
| tier-bronze `#c4945e` | 6.46 | 5.50 | 6.83 | 7.08 | 6.42 | pass text and graphics |
| tier-silver `#bcc8d4` | 10.30 | 8.78 | 10.89 | 11.30 | 10.24 | pass |
| gold `#f4c542` | 10.77 | 9.18 | 11.38 | 11.81 | 10.70 | pass |
| lime `#a4d007` (COMPLET) | 9.68 | 8.25 | 10.23 | 10.61 | 9.62 | pass |
| line-deep `#2a6f9a` (unreached ticks and notches, gauge cell frame) | 3.20 | **2.73** | 3.38 | 3.51 | 3.18 | pass 3:1 except on raised |
| line-soft `#1f3346` (mock set-row frame) | **1.35** | 1.15 | 1.43 | — | — | fails as an interactive boundary |

| Pair between marks | Ratio | Meaning |
|---|---|---|
| silver vs gold | 1.05 | identical in greyscale (known; notches and name carry it) |
| bronze vs line-deep (reached vs unreached tick) | **2.02** | the reached state is a hue change below 3:1 |
| silver / gold vs line-deep | 3.22 / 3.36 | the reached state is a colour change only |
| bronze / silver / gold vs accent bar fill | 1.34 / 1.19 / 1.24 | a reached tick vanishes over the fill; only its 1px ink edge shows |
| bronze vs alert `#e8833a` | 1.00 | same luminance, near hue |
| silver vs text `#c7d5e0` | 1.14 | a silver tier word looks like body text |

## High

### H1 — The phone celebration replaces itself on an unspecified timer, and results can vanish before they are read
- **Location:** `DESIGN.md` Result banner › Set celebration ("Several play one after another … On the phone each plays inside the reveal caption plate … and replaces the previous one"); mock panels 4a/4b; `.memlog.md` 2026-10-08 ("results replace each other").
- **Issue:** Nothing says how long each result stays, what stops the chain, or what happens when the player taps "RANGER" or "OUVRIR LE SUIVANT" mid-chain. Content that updates on its own and is not paused fails WCAG 2.2.1 Timing Adjustable (A); past 5 s with three results it also fails 2.2.2 Pause, Stop, Hide (A). Slow readers, magnifier users and anyone looking at the card lose a result for good, because nothing lists it afterwards in the booster. The desktop chain has the same gap.
- **Fix (DESIGN.md, Set celebration, replace the last two sentences):**
  > Results never change on a timer. On desktop they stack, still, under the booster information panel. On the phone the reveal caption plate, grown to at least 60px, shows one result with "1 / 3" and a 44 × 44 "▸" button (accessible name "Résultat suivant") that shows the next one. More than three results become one line, "n PALIERS ATTEINTS". Results stay until the next booster opens.
- **Fix (EXPERIENCE.md, Booster component table, new row):**
  > | Set celebration | Starts once the last card's reveal (or the Tout révéler summary, or a Légendaire's banner) has ended. Never takes focus and never blocks "RANGER" or "OUVRIR LE SUIVANT". Never changes on a timer: on the phone, "▸" moves to the next result. The sets it names lead "EN COURS" in the collection. |

### H2 — The celebration's screen-reader message has no copy and no timing, and the mock adds a second live region
- **Location:** `EXPERIENCE.md` State Patterns › Set tier reached ("announced in the booster live region"), Copy deck › Booster live region (no set line), Accessibility Floor › Booster live region; mock lines 352 and 368 (`<div class="b-plate …" role="status">`).
- **Issue:** (a) The live message has no copy, so builders will read out the banner text "PALIER ARGENT · Roguelike 31/62", which screen readers say as "31 barre oblique 62". (b) The celebration is posted right after the fifth card's reveal message. A builder who replaces the region's text, which is common, drops the card message before it is spoken (4.1.3). (c) The mock makes the reveal caption plate `role="status"`. That is a second live region: every replacement is announced again, and the plate's normal job (the card caption) would be announced twice. (d) "n PALIERS ATTEINTS" does not say which sets.
- **Fix (EXPERIENCE.md, Accessibility Floor › Booster live region, append):**
  > After the last reveal message (or the Tout révéler summary, or a Légendaire's result), the set results are posted once, as one message that lists every result in the order the banners show them, including when the banner folds them into "n PALIERS ATTEINTS". The region appends each message as a new node and never replaces one posted less than 2s earlier. The reveal caption plate and the banners are not live regions.
- **Fix (EXPERIENCE.md, Copy deck › Booster live region, add):**
  > "Palier argent atteint : Roguelike, 31 cartes sur 62." · "Set complet : Dark Souls, 3 cartes sur 3." · "4 paliers atteints : Roguelike, argent ; Metroidvania, or ; Les Pépites, bronze ; Dark Souls, complet."
- **Mock:** remove `role="status"` from `.b-plate`.

### H3 — "Reached" is carried by colour alone in the album gauge and on the ticks
- **Location:** `DESIGN.md` Tier marks, Set album ("each cell … lit in its tier colour once reached"), Set progress row (ticks); `EXPERIENCE.md` Set album ("each with its threshold, reached or not"); mock `.gcell.on` versus `.gcell`, `.tick.on`, and `.gcell:not(.on) .notch i` (a 2px inset ring on a 4px-wide notch fills it entirely, so the "hollow" notches render solid).
- **Issue:** The tier name and notch count say *which* tier; they appear whether or not it is reached. Reached versus unreached differs only by hue (bronze vs line-deep 2.02:1) plus a bold weight, which fails 1.4.1 Use of Colour (A). In greyscale the silver and gold cells look the same reached or not. On the bar, an unreached tick and a reached tick differ by colour only, and a reached tick sits over the accent fill at 1.19–1.34:1.
- **Fix (DESIGN.md, Tier marks, append):**
  > Reached and not reached differ by more than colour. A reached tier has filled notches and a pixel check "✓" before its name, and its name and frame are in the tier colour. A tier not yet reached has hollow notches (at least 6px wide, a 2px `{colors.line-deep}` outline around an empty centre) and its name in `{colors.muted}`. On a progress bar, a reached tick is solid and rises 4px above the track, and a tick not yet reached is a dashed `{colors.line-deep}` line.
- **Fix (DESIGN.md, Set album):** replace "lit in its tier colour once reached" with
  > marked reached as in Tier marks (✓, filled notches, tier-colour frame).

### H4 — The set search has no label rule, no place for its results and no announcement
- **Location:** `DESIGN.md` Collection entry ("the search field 'Chercher un set'"); `EXPERIENCE.md` Collection opening ("a search over every set, applied as the player types"), Copy deck › Collection; mock line 304 (a `<label>` holding only placeholder text; the section carries `aria-label` and has no heading).
- **Issue:** "Chercher un set" is drawn as a placeholder. It disappears once the player types, and nothing in the spine requires a real label (1.3.1, 3.3.2, 4.1.2). Results are said to appear "as the player types", but the spines do not say where: below the field, or in place of EN COURS above it, which would move content behind a keyboard user. No status message gives the result count (4.1.3, AA), and there is no empty-result copy.
- **Fix (DESIGN.md, Collection entry):** replace "then the search field 'Chercher un set' and 'TOUTES LES CARTES ▸' on one line" with
  > then the kicker "CHERCHER UN SET" (an h2 like the others) over the search field, which it labels, with "TOUTES LES CARTES ▸" on the same line. Results appear directly below, under the kicker "RÉSULTATS", as set progress rows.
- **Fix (EXPERIENCE.md, Collection table, new row):**
  > | Set search | A `search` landmark. The field is labelled by "CHERCHER UN SET"; a placeholder never labels it. Applied after 300ms without typing, over set names and kinds. Results appear below the field and never move EN COURS or À DÉCOUVRIR. A polite status line beside the field gives the count once per pause in typing. Focus stays in the field. Esc clears the field when it has text. |
- **Fix (EXPERIENCE.md, Copy deck › Collection, add; zero, one and other forms):**
  > "Aucun set trouvé pour « … »." · "1 set trouvé" · "n sets trouvés"

## Medium

### M1 — The set progress row's text gives the count ambiguously and never the next tier
- **Location:** `DESIGN.md` Set progress row; `EXPERIENCE.md` Hub › Set progress row; mock lines 297 and 301 (the `<a>` text reads "Roguelike THÈME BRONZE 29/62", with the bar and ticks hidden).
- **Issue:** EN COURS is sorted by "cards missing to the next tier", but that number appears only as tick positions, which are hidden from screen readers and hard to judge by eye. "29/62" is spoken as a fraction or "barre oblique". A screen-reader user cannot tell why a set is listed first.
- **Fix (DESIGN.md, Set progress row, append):**
  > Inside the row, the bar and ticks are hidden from assistive technology. The row's accessible name carries the value: "Roguelike, thème, 29 cartes sur 62, palier bronze, argent à 31" (untiered: "Dark Souls, franchise, 2 cartes sur 3"; done: "… complet").
- **Fix (EXPERIENCE.md, Copy deck › Collection, add):**
  > Set row name: "{set}, {kind}, {owned} cartes sur {total}[, palier {tier}][, {next} à {threshold}][, complet]".

### M2 — The album header's semantics are not specified
- **Location:** `EXPERIENCE.md` Set album; Accessibility Floor ("Gauges are progress bars with a text value"); mock line 319 (bar without a role), line 320 (`<ol aria-label="Paliers">` whose items read "BRONZE 16", with no unit and no state), line 335 (`aria-label="Set complet"` on a `<span>`, which ARIA prohibits on a generic element, so many screen readers ignore it).
- **Fix (EXPERIENCE.md, Set album, append):**
  > The header's bar is a progress bar named by the set's name, with the text value "31 cartes sur 62, palier argent" (untiered and done: "3 cartes sur 3, complet"). The tier gauge is a list of three items, read as "Bronze, 16 cartes, atteint" or "Or, 62 cartes, pas encore atteint". The COMPLET stamp is plain text.

### M3 — Heading structure of the album and the collection entry
- **Location:** `EXPERIENCE.md` Accessibility Floor ("each screen has one h1"); mock lines 292/312/330 (the h1 is "COLLECTION" on both the entry and the album; the set's name is an h2; the search section has no heading).
- **Issue:** The entry and every album share the same h1, so the album's identity sits one level down (2.4.2, 2.4.6). A player browsing by headings cannot tell albums apart.
- **Fix (EXPERIENCE.md, Set album, append):**
  > The album's h1 is the set's name (on a public profile: "Roguelike · Léa"), and the top bar's "COLLECTION" is not a heading there. The page title reads "Roguelike · Collection · gameble". On the collection entry the h1 is "COLLECTION", with h2s for EN COURS, À DÉCOUVRIR, CHERCHER UN SET and RÉSULTATS. Toutes les cartes has the h1 "TOUTES LES CARTES".

### M4 — Focus into and out of the album, the back label, and the album grid keys
- **Location:** `EXPERIENCE.md` Focus after each step (only "Sub-view opened (phone) → Its heading" and "Back → the element that opened it"), Set album ("'◀ SETS' returns to the collection"), Interaction Primitives › Keyboard (arrow keys named for "the collection grid" only).
- **Issue:** The album opens from five places (collection, hub, search, card detail, public profile), but "◀ SETS" always goes to the collection, which breaks the spine's own back rule (2.4.3, 3.2.3). EN COURS re-sorts after progress, so the opening row may have moved. The album holds up to dozens of cards; tabbing through 62 slots is not the collection grid's one tab stop.
- **Fix (EXPERIENCE.md, Focus after each step, add rows):**
  > | Set album opened (desktop and phone) | Its h1, the set's name |
  > | Back from a set album | The row of that set wherever the list now puts it, with the scroll restored; if the set has left the list, the list's heading |
- **Fix (EXPERIENCE.md, Set album):** replace "'◀ SETS' returns to the collection" with
  > The back button returns where the album was opened and names it: "◀ SETS" (collection or search), "◀ PONT" (hub), "◀ FICHE" (card detail), "◀ PROFIL" (public profile). The card grid is one tab stop with arrow keys inside, like the collection grid.

### M5 — A missing-card slot does not say it is missing
- **Location:** `EXPERIENCE.md` Accessibility Floor › Card text order; `DESIGN.md` Missing-card slot ("Nothing else"); mock line 322 (slot text "Into the Breach 2018").
- **Issue:** In the album, owned cards and missing slots alternate. A screen reader reads both as a title and a year, so the core point of the album (what is missing) is visual only (1.3.1).
- **Fix (EXPERIENCE.md, Card text order, append):**
  > A missing-card slot reads "Manquante : Into the Breach, 2018".

### M6 — Set names truncate, and the gauge and plate do not reflow at phone and 320px widths
- **Location:** `DESIGN.md` Set progress row, Set album, Set celebration; mock `.set-row .nm` and `.b-plate .nm` (`nowrap; text-overflow: ellipsis`), `.gauge` (three cells in one row, about 420px wide), `.set-name` (VT323, line-height 1.0).
- **Issue:** Hall of fame and studio names will be cut off with "…" in rows and in the celebration plate (1.4.4, 1.4.10). The three gauge cells do not fit a 358px phone column, let alone 320 CSS px at 400% zoom. A two-line VT323 set name at line-height 1.0 runs its lines together.
- **Fix (DESIGN.md, Set progress row, append):**
  > Set names wrap to two lines and never truncate; on the phone the kind and the tier mark move to a second line.
- **Fix (DESIGN.md, Set album, append):**
  > On the phone the three gauge cells share the width, each with its name over its threshold; below 360px they stack. A set name on two lines uses a line-height of at least 1.2.
- **Fix (DESIGN.md, Set celebration, append):**
  > The set name wraps in the plate, which grows rather than cutting it.

### M7 — Reduced motion does not cover the celebration or the stamp
- **Location:** `EXPERIENCE.md` Motion › Reduced motion (exceptions list); `DESIGN.md` COMPLET stamp ("rotated −6°").
- **Issue:** The rule "nothing … rotates" reads as banning the stamp's tilt or leaves a stamp "drop" unspecified. The chained banners are not listed among the exceptions, so builders will reuse the Épique banner's animated entry under ANIMATIONS RÉDUITES.
- **Fix (EXPERIENCE.md, Reduced motion, add an exception):**
  > - **Set celebration:** each result crossfades in over 200ms and stays still. The COMPLET stamp keeps its fixed −6° tilt (a static tilt is not motion) and never drops, bounces or rotates into place.

### M8 — Where the approved mock contradicts the spines
- **Location:** `mockups/key-collection-sets.html`.
- **Items** (the spines win; record them in the mock's header comment so builders do not copy them):
  1. The phone "◀ SETS" uses `.px-btn.sm` at 34px tall, below the 44 × 44 floor (Accessibility Floor › Touch).
  2. In set rows, "/62" is VT323 at 18px (`.ct small` at 0.75 × 24px), below the 20px VT323 floor.
  3. Set rows are links framed in line-soft (1.35:1), but DESIGN requires `{colors.line-deep}` for every interactive boundary.
  4. "TOUTES LES CARTES ▸" is a text link about 18px tall. It needs a 44px hit area on the phone and 24px on desktop (2.5.8).
  5. The plate's `role="status"` (see H2) and the stamp's `aria-label` on a `<span>` (see M2).
  6. The tick notches are overridden to 4 × 6px (see L1).
- **Fix (DESIGN.md, Collection, under the reference line):**
  > Where this mock differs from the rules (back button height, VT323 size of the total, row frame colour, link hit area, live-region role), the rules apply.

## Low

### L1 — Ticks carry the tier with no name, and their notches are tiny
- **Location:** `DESIGN.md` Tier marks ("always with the tier's name"), compared with Set progress row (ticks show notches only); mock `.tick .notch i { height: 6px }`.
- **Fix (DESIGN.md, Set progress row, append):**
  > Ticks are a visual aid hidden from assistive technology; the row's text carries the tiers (see M1). Notches are at least 4 × 8px with 2px gaps wherever they appear.

### L2 — Rotated text at small sizes
- **Location:** `DESIGN.md` Feed entry ("a completed set carries the COMPLET stamp"), Set celebration ("a small COMPLET stamp").
- **Issue:** A pixel font rotated −6° is resampled and blurs at small sizes. Rotating a stamp out of the text flow can also overlap the count under 200% text or 1.4.12 spacing.
- **Fix (DESIGN.md, COMPLET stamp, append):**
  > Rotated text appears only in VT323 at 24px or more; smaller uses (the feed, the celebration plate) show the frame without text next to the word "COMPLET" set straight. The stamp sits in the text flow with at least 6px clear on each side, so its rotated corners never touch the count.

### L3 — Bronze reads as the alert orange, and silver as body text
- **Location:** `DESIGN.md` Colors (tier-bronze vs alert at 1.00:1 and close in hue; tier-silver vs text at 1.14:1).
- **Fix (DESIGN.md, Tier marks, append):**
  > A tier colour never marks anything but a tier: no expiry, warning or body text sits in bronze or silver, and a tier mark is never placed beside an alert-coloured element.

### L4 — Completing a tiered set is named three ways
- **Location:** `EXPERIENCE.md` State Patterns › Set complete ("the album its COMPLET stamp (gold on a tiered set)"), Flow 3 ("SET COMPLET · Roguelike" with "OR lit"); `DESIGN.md` Set album (the stamp is "for an untiered set").
- **Issue:** One event is announced and drawn as "PALIER OR", "SET COMPLET", or both, depending on where the builder reads (3.2.4 Consistent Identification).
- **Fix (EXPERIENCE.md, Set complete):** replace "the album its COMPLET stamp (gold on a tiered set)" with
  > on a tiered set, gold is completion: the celebration reads "SET COMPLET · Roguelike", the gauge shows OR reached, and the album adds the COMPLET stamp. The live message is "Set complet : Roguelike, palier or, 62 cartes sur 62."

### L5 — Title and theme pickers lack semantics and a contrast rule for themes
- **Location:** `DESIGN.md` Title and menu theme pickers; `EXPERIENCE.md` (no behaviour row).
- **Fix (EXPERIENCE.md, Profil et paramètres table, new row):**
  > | Title and theme pickers | Each is a radio group named by its heading. The active option is checked. A locked option stays focusable, with its condition in its accessible name ("Pirates, verrouillé : atteindre l'or du set Pirates"); choosing it shows the condition inline. Every menu theme meets the Colors contrast floor on its own colours, never recolours rarity or tier colours, and stops its animation under ANIMATIONS RÉDUITES. A title always appears as text. |

### L6 — Set feed entries have no copy, and the "selected set" marker is now stale
- **Location:** `DESIGN.md` Feed entry (set tier entry), Set progress row ("the selected set has a 5px accent bar"); `EXPERIENCE.md` Copy deck › Feed, Feed entry filters (no filter covers set entries).
- **Fix (EXPERIENCE.md, Copy deck › Feed, add):**
  > "Léa atteint l'argent du set Roguelike." · "Léa complète le set Dark Souls."
  >
  > The sentence names the tier in words; the notches and stamp are hidden from assistive technology.
- **Fix (DESIGN.md, Set progress row):** replace "the selected set has a 5px accent bar on its left" with
  > the row of the album last opened has a 5px accent bar on its left and `aria-current="true"`.

## Outside this lens (noted, not scored)

- `EXPERIENCE.md` Voice says "No title for the player", yet DESIGN adds a title picker.
- `DESIGN.md` Colors still says gold "belongs to the Légendaire tier … never a general accent" without naming the gold set tier.
- EN COURS has no stated length. If it is long, the search sits far down the page for keyboard and switch users; consider a cap with "TOUT VOIR".
