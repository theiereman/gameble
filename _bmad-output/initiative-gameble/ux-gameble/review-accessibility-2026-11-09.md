# Accessibility review of the 2026-11-09 spec update

Scope: the uncommitted 2026-11-09 diff to `DESIGN.md` and `EXPERIENCE.md` (Chattomètre hub panel and gauge, Semaine/Total tabs, full screen header gauge, See-more link rule, player menu with one badge, five phone tabs, Marché teaser) and `mockups/hub-leaderboard-panel.html`. The bar is `EXPERIENCE.md` Accessibility Floor (lines 632 to 656), `DESIGN.md` Colors and Typography, and WCAG 2.2 AA. Only what changed was judged. The Chattomètre's product rules, and spec consistency that has no accessibility effect, are out of scope.

Severity: **blocker**: as written the spec or its mock would ship a WCAG 2.2 A/AA failure. **should-fix**: a floor contradiction or a gap likely to produce a defect. **note**: a small refinement.

Line numbers are those of the working copy on 2026-11-09.

## Contrast measured

WCAG relative luminance, from the hex values in `DESIGN.md`'s frontmatter.

| Pair | Use | Ratio | Needed | Result |
|---|---|---|---|---|
| `line` #2a475e on `panel` #121a24 | near-empty columns, gauge baseline | 1.80 | 3:1 | **Fails** |
| `dim` #5d6b78 on `panel` | −500, 0, +500 labels; mock's rank numbers | 3.20 | 4.5:1 | **Fails** |
| `accent` on `panel` | columns | 8.68 | 3:1 | Passes |
| `lime` on `panel` | columns, positive index in the mock | 9.68 | 3:1 / 4.5:1 | Passes |
| `gold` on `panel` | columns, title | 10.77 | 3:1 / 4.5:1 | Passes |
| `text-max` on `panel` | "VOUS" marker and label | 17.52 | 3:1 / 4.5:1 | Passes |
| `text-max` on `gold` / `lime` / `accent` | marker where it crosses a column | 1.63 / 1.81 / 2.02 | see P3 | Fine, see P3 |
| `accent` against `lime` / `gold`; `lime` against `gold` | neighbouring heat steps | 1.11 / 1.24 / 1.11 | see P2 | Fine, see P2 |
| `muted` on `panel` | inactive tab, small titles | 5.98 | 4.5:1 | Passes |
| `muted` on `ground` / `backdrop` | See-more link outside the frame | 6.55 / 6.88 | 4.5:1 | Passes |
| `on-accent` on `accent` | selected tab | 9.11 | 4.5:1 | Passes |
| `alert` on `panel` | negative index in the mock | 6.45 | 4.5:1 | Passes |
| `muted` on `steam-bar` | tab label at rest | 5.94 | 4.5:1 | Passes |
| `accent` on `panel-raised` | current tab label | 7.40 | 4.5:1 | Passes |

---

## Blockers

### B1. The near-empty columns and the baseline are below 3:1

- **Where:** `DESIGN.md` 1207 ("rising from a `{colors.line}` baseline", "`{colors.line}` when nearly empty"); mock, every `fill="#2a475e"` rect.
- **Problem:** 1.80:1 on `panel`. These columns are data: they show the bands where almost nobody stands, and the baseline anchors every column to the scale. WCAG 1.4.11 asks 3:1 for graphics needed to understand the content, and `DESIGN.md` 579 asks the same of interface boundaries. No visible text repeats the distribution, so the exception for information given elsewhere does not apply. In the mock, 14 of the 49 columns of the Semaine curve and 18 of the Total curve use this colour, and many are only 2 to 4px tall.
- **Fix:** paint the near-empty step and the baseline in `{colors.line-deep}` #2a6f9a (3.20:1 on `panel`), which keeps the step down from `accent` clearly visible. The full screen's gauge must sit on `panel` too, or be measured again: `line-deep` falls to 2.73:1 on `panel-raised`.

### B2. The scale labels are in `dim`, which the spec keeps for decoration

- **Where:** `DESIGN.md` 1207 ("the −500, 0 and +500 labels in `{colors.dim}`"); against `DESIGN.md` 586 ("never for words a player needs") and floor 651 ("`{colors.dim}` is decorative only"); mock `.sv`, and `.rk` for the rank numbers.
- **Problem:** 3.20:1 for 12px text fails WCAG 1.4.3 (4.5:1). The labels are the only visible scale of the gauge, so they are not decorative. The mock's rank numbers 1 to 3 have the same defect.
- **Fix:** set the labels and the rank numbers in `{colors.muted}` (5.98:1 on `panel`), in `{typography.label}` (11px bold).

### B3. The gauge has no real text alternative, and none at all for a viewer without a marker

- **Where:** `EXPERIENCE.md` 302 (Gauge: "Its accessible name states the viewer's place in words"), 303 (Start of the week), 305 (Full screen: "A visitor sees it without marker"); floor 647; mock `aria-label="Répartition des joueurs sur l'échelle de chance"`, the same on all three gauges.
- **Problem:** three gaps add up to a WCAG 1.1.1 failure.
  1. The mock's name only says what the image is. It gives neither the viewer's place nor the shape of the curve, it does not change between Semaine, Total and last week's verdict, and because `role="img"` hides the SVG's content, the scale and "VOUS" are lost too.
  2. "The viewer's place in words" has no copy in the Copy deck, in French or English, and does not say what "place" means: the index repeats the line above; a share of the players does not.
  3. Four states have nothing to state: a visitor, a viewer with no capsule opened in the period, a private profile, and last week's verdict, where the marker is where the viewer ended and the tab still reads "Semaine". The columns are the only thing a viewer without a marker gets, and they are hidden.
- **Conflict:** floor 647 says "Gauges are progress bars with a text value, except the set celebration's". This gauge is a histogram, so a builder following the floor would use the wrong role.
- **Fix:**
  - Add to floor 647: "and the Chattomètre's, an image named in words".
  - Add a Copy deck row, both languages, one name per state, built from values the server computes. The name carries the period, the scale in words, the viewer's place, and the crowd. For example, "Cette semaine, sur une échelle de moins 500 à plus 500 : vous êtes à moins 187, devant 22 % des joueurs classés. La plupart des joueurs sont autour de plus 10."; without a marker, "Cette semaine, sur une échelle de moins 500 à plus 500, la plupart des joueurs sont autour de plus 10."; for the verdict, begin "La semaine dernière, ".
  - Write signs as words in the name, since some screen reader settings skip U+2212.
  - Apply the same names on the full screen, for the period it shows.

---

## Should-fix

### S1. The Semaine/Total tabs have no defined semantics, and the mock's would be wrong

- **Where:** `EXPERIENCE.md` 301 ("tabs Semaine and Total"), 210 (Tabs and filters: `aria-pressed`); `DESIGN.md` 752; mock `<nav class="chips"><span>`.
- **Problem:** the panel does not say whether these are the existing Tabs and filters chips. The mock's `<nav>` adds a navigation landmark around controls that do not navigate, on a hub whose floor (637) expects one navigation region for the screen, and its spans are not focusable.
- **Fix:** state in row 301 that they are Tabs and filters chips: two `<button>`s with `aria-pressed`, in `role="group"` named "Période du Chattomètre" ("Flukeometer period" or the English copy). No `role="tab"`, no `<nav>`. If the build makes them links that reload a frame, use `aria-current="true"` on the chosen one instead and say so; do not mix the two.

### S2. Switching tab replaces the panel without keeping focus or saying what changed

- **Where:** `EXPERIENCE.md` 301 ("Total switches everything: the curve, the marker, the index and the top 3"), 210 ("keeps focus on the filter"); floor 636.
- **Problem:** if the tabs sit inside the replaced part of the panel, focus falls to `body`, which floor 636 forbids. Even when focus holds, a screen reader user hears nothing of the new index and top 3 (WCAG 4.1.3).
- **Fix:** add to row 301: "The tabs stay outside what is replaced, so focus stays on the chosen tab. A polite status line announces the new reading, 'Total : +38, Moyen à en pleurer'." Reuse the empty-then-filled status region of floor 643, so that repeating a choice is announced again.

### S3. The tabs and the See-more link are too small on the phone in the mock

- **Where:** floor 650 (44 × 44, 8px apart); `DESIGN.md` 752 (`{spacing.chip-height}` 34px, phone hit area `{spacing.chip-height-touch}` 44px); mock `.chips span` (about 24px tall, 6px apart) and `.more` (20px tall).
- **Problem:** the mock is linked as the reference, and it departs from both tokens. The spec adds no size for the See-more link at all, and the rule makes that link a recurring target.
- **Fix:** row 301 follows from S1. In `EXPERIENCE.md` 208 add: "On the phone its hit area is 44px tall, by padding, and clear of the next panel by 8px." Correct the mock's chips.

### S4. "Tout voir" loses its meaning once it sits outside the panel

- **Where:** `EXPERIENCE.md` 208 (See-more link, "'Tout voir', 'Voir tout le classement'", "set outside the panel's frame"); `DESIGN.md` 1207; mock `<a class="more">` placed after `</section>`.
- **Problem:** "Voir tout le classement" names its destination, so it is fine alone. "Tout voir" does not, and the rule now covers every preview, so several identical names can lead to different places (the hub's sets, Moi's Succès, the phone's MES SETS line). Placed outside the panel's `<section>`, the link also leaves the context that WCAG 2.4.4 relies on. The Moi instance already has to carry a badge.
- **Fix:** add to row 208: "Outside the frame by layout only: the link stays inside the panel's named section in the DOM, right after its content. Each instance's accessible name starts with its visible text and names the destination: 'Tout voir, sets en cours', 'Tout voir, succès'. Each goes in the Copy deck." Starting with the visible words keeps WCAG 2.5.3. Give the mock's link the same structure.

### S5. The single badge has no accessible name and no defined content

- **Where:** `EXPERIENCE.md` 402 ("One badge on the avatar, the detail on each line"), 74 ("whose single badge covers what it holds"), 236 (Count badge), 401 ("The MOI tab carries the same badge"); `DESIGN.md` 915.
- **Problem:**
  1. Rule 236 puts "its number" in the item's name, but a sum of unlike things, "Menu du joueur, 3", says nothing a player can act on, and the visual detail is one activation away.
  2. What it sums is not stated. Row 401 still hangs the achievement rewards on the MOI tab, which no longer exists.
  3. Its colour is not stated (orange and violet had separate meanings).
  4. On the phone the avatar may stand without the name. Floor 645's empty alt only holds "next to a visible name", and the 32px avatar is below floor 650.
- **Fix:** in row 402 state the sources (waiting invitations and rewards to claim, the two named if both count), the colour (orange, as "the player must act" in `DESIGN.md` 915, with the number printed), and the name, itemised and hidden at zero: "Menu du joueur, 2 invitations d'amis, 1 récompense à récupérer". Each line's name carries its own detail: "Amis, 3 en ligne, 2 invitations en attente". The button keeps a 44px hit area on the phone and is always named in text. Move row 401's sentence to this badge.

### S6. The index and the mock's figures break the floor's type rules

- **Where:** `DESIGN.md` 1207 ("the index in the display face at 44px"), against floor 651 and `DESIGN.md` 636 ("Figures … are in JetBrains Mono bold, never in VT323"); mock `.big`, `.ix` (VT323, 24px on the +471 figures), `.sv`, `.mk`, `.chips span`, `.nm small`, `.nm em` (12px, not bold).
- **Problem:** the new rule contradicts a floor rule outright, so a builder must pick one. VT323's digits are the reason the floor exists, and here the sign and digits are the value. Separately, 12px meaningful text must be bold.
- **Fix:** set the index in JetBrains Mono bold at `{typography.count-large}` (34.5px, the nearest token to the 33px that `DESIGN.md` 636's × 0.75 conversion gives for 44px), the rows' figures in `{typography.number}`, and the 12px text in `{typography.label}`. If the author wants VT323 for this one figure, it needs a stated exception in floor 651, not silence.

### S7. The gauge's labels are drawn inside the scaling SVG

- **Where:** floor 651 (nothing below 10px), floor 652 (text in rem); mock `svg{width:100%}`, viewBox 308, `.sv` and `.mk` at 12px; `DESIGN.md` 1207 does not say how the labels are built.
- **Problem:** the text scales with the panel's width, not with the user's font size. At a real 320px width the panel's inner width is 256px, a scale of 0.83: the labels render at 9.97px, under the floor, and a raised browser font size does not grow them.
- **Fix:** add to `DESIGN.md` 1207: "The scale labels and 'VOUS' are HTML text positioned over the gauge, in rem; only the columns, baseline and marker line are drawn."

---

## Notes

### N1. Current tab on the PONT sub-screens

`EXPERIENCE.md` 74 keeps PONT current on Fil d'activité and Le Chattomètre. `aria-current="page"` would be false there; use `aria-current="true"` on those two screens and `"page"` on the hub alone, as the set progress row already does.

### N2. Stale tab bar text that decides accessible names

`DESIGN.md` 919 still lists PONT, CAPSULE, COLLECTION, ÉCHANGES, PLUS, and `EXPERIENCE.md` 239 "the four roots", against the new line 74 (PONT, CAPSULE, SETS, ÉCHANGES, MARCHÉ). `EXPERIENCE.md` 236 still describes the two badges on SOCIAL. The tab's label is its name, so update 919, 239 and 236 before the build.

### N3. Player menu pattern

Row 402 does not say what kind of widget the menu is. Reuse the friend row's native popover (Esc or an outside click closes it, focus returns to the opener) and expose its open state. Add the line to row 233, whose list of entries is also out of date.

---

## Checked and fine

- **P1. Five phone tabs:** at 58px tall and 72px wide on a 360px phone (64px at 320px), they exceed floor 650. `{typography.label}` 11px bold fits "ÉCHANGES". Contrast passes at rest and when current, and the current tab also has a fill and a top bar, so it does not rest on colour alone. The ÉCHANGES badge is covered by rule 236.
- **P2. Meaning by colour or height:** heat repeats height, so colour never carries anything alone (WCAG 1.4.1). `accent`, `lime` and `gold` are almost equal in luminance (1.11 to 1.24), which is harmless only because height says the same thing; keep the rule at `EXPERIENCE.md` 302 that both read the same value. In the mock only the 8px columns differ (some `line`, some `accent`). The figures' signs back up their green and orange. Height alone is answered by B3's text.
- **P3. The "VOUS" marker:** 17.52:1 against the panel. Where it crosses a tall column it drops to 1.63:1, but the line always rises above the tallest column and carries its label (mock: top at y 14, tallest column at y 24), so the position stays clear. Keep the line's top above the tallest column when the full screen's gauge is drawn.
- **P4. One marker, columns hidden:** hiding the 49 columns is right, once B3's name exists.
- **See-more link as a link, not a button:** right for navigation. Its colour passes on every background it can stand on, and the focus ring has room outside the frame. "Voir tout le classement" is a sufficient name.
- **Hub panel's title and colours:** `gold` title passes; the selected tab is told apart by a strong fill as well as by `aria-pressed` once S1 is applied.
- **Marché teaser:** nothing to fault yet. Its content and copy are still `[ASSUMPTION]`; it inherits the floor (one h1, main region). If "what is advancing" becomes a bar, floor 647 applies, and any status must be written, as on the roadmap page.
