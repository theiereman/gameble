# Accessibility review of the economy charts (2026-11-10)

Scope: the 2026-11-10 additions to `DESIGN.md` (colours `chart-minted` and `chart-destroyed`, components `chart` and `sparkline`, Marché "Charts" bullets, the Do's and Don'ts row) and `EXPERIENCE.md` (rows "Bourse de la Confrérie" in the entry table and the Marché table, "Edition chart", "Chart", the back-office "Charts" sentence, the two copy deck rows, Flow 10), read against the Accessibility Floor, `review-market-accessibility-2026-11-09.md` (the house standard), AD-51 in `architecture-gameble.md` and `mockups/market-charts.html`. Target WCAG 2.2 AA. Line numbers are those of the working copy on 2026-11-10. Where a mock departs from a spine the spine wins, and the finding says so.

## Overall verdict

The visual layer is sound: every chart mark and every chart text clears its ratio against `panel`, the Reactor does not rely on colour (position above or below zero carries the meaning), the threshold and floor are told apart by dash and label, a missing value is a gap and never 0, and motion is handled. The non-visual path is not yet equivalent. The table that the contract names as "the keyboard and screen-reader path" holds a fraction of what is drawn (7 of 30 days, 5 of the window's sales, 3 of 90 days), the day's balance exists only in a tooltip, and the canvas is named by its title and period, which gives a screen-reader user the chart's subject but never its point, though Flow 10 is entirely about reading that point. Rarity lines in the index are told apart by colour along their whole length, forced colours are not addressed anywhere in the app, and the publication switch has no semantics. All of it is fixable in the documents before the build, with no change to the author's chart choices.

## Verdict per area

| # | Area | Verdict | In one line |
|---|---|---|---|
| 1 | Name and description of the canvas | **thin** | `role="img"` with a static locale key: the title and period, never the takeaway. |
| 2 | The table as equivalent | **broken** | "A table of exactly what is drawn" then "the last 7 days" for a 30-day chart; the balance is in no table. |
| 3 | Tooltip-only information and keyboard | **broken** | "Solde du jour" is only in a tooltip, against the floor's "No information only in a tooltip". |
| 4 | Contrast | **adequate** | Every mark and text passes; the grid fails 3:1 but is not needed once the table is complete. |
| 5 | Colour independence | **thin** | Reactor and edition chart pass; rarity lines rely on colour except at their last point. |
| 6 | Motion | **adequate** | Animation off under the motion switch; no loop, no blink. |
| 7 | Forced colours | **missing** | Nothing in the spines or the app; canvas, swatches and box-shadow edges fail differently. |
| 8 | Zoom and reflow at 320 CSS px | **thin** | The Reactor table and the index's end labels do not fit. |
| 9 | Touch | **thin** | Line and bar charts are fine (index mode); the edition scatter needs a hit on a 10px point. |
| 10 | Publication switch and staff flag | **thin** | "The app's toggle" does not exist as a component; the off track's edge is under 3:1. |
| 11 | "LA BOURSE DE LA CONFRÉRIE" link and page structure | **adequate** | A link, shown only when it leads somewhere; headings are unspecified. |

## Contrast ratios

Computed with WCAG relative luminance from the hex values in `DESIGN.md`'s frontmatter (Python, sRGB). "Needed" is 4.5:1 for text at these sizes and 3:1 for non-text (1.4.11).

| Pair | Where used | Ratio | Needed | Result |
|---|---|---|---|---|
| `chart-minted` / `gold` #f4c542 on `panel` #121a24 | minted bars | 10.77 | 3 | Pass |
| `chart-destroyed` / `accent` #66c0f4 on `panel` | destroyed bars, "VOIR LE TABLEAU" | 8.68 | 3 / 4.5 | Pass |
| `text-max` #ffffff on `panel` | single series, average line, figures | 17.52 | 3 / 4.5 | Pass |
| `text-bright` #e6eef5 on `panel` | the Brotherhood's line, end labels in the mock | 14.94 | 4.5 | Pass |
| `rarity-commune` #8f98a0 on `panel` | index line, point | 5.98 | 3 | Pass |
| `rarity-peu-commune` #3fcf8e on `panel` | index line | 8.78 | 3 | Pass |
| `rarity-rare` #66c0f4 on `panel` | index line | 8.68 | 3 | Pass |
| `rarity-epique` #b47cff on `panel` | index line, edition points | 6.06 | 3 | Pass |
| `rarity-legendaire` #f4c542 on `panel` | index line | 10.77 | 3 | Pass |
| Rarity colours on `panel-sunken` #0e141b | sparklines, tile edges | 6.32 / 9.28 / 9.18 / 6.41 / 11.38 | 3 (decorative) | Pass |
| `muted` #8f98a0 on `panel` | axis text 11px, headers, legend notes | 5.98 | 4.5 | Pass |
| `muted` on `panel` | edition floor, 1px dashed | 5.98 | 3 | Pass (thin, see L8) |
| `alert` #e8833a on `panel` | threshold 2px dashed and its 10px bold label | 6.45 | 3 / 4.5 | Pass |
| `line-soft` #1f3346 on `panel` | grid, x-axis border (zero line in the mock) | 1.35 | 3 if needed | Fails; acceptable only if the table is complete (H1) |
| `text` #c7d5e0 on `panel-raised` #1b2838 | tooltip body | 9.96 | 4.5 | Pass |
| `text-bright` on `panel-raised` | tooltip title | 12.73 | 4.5 | Pass |
| `line` #2a475e on `panel` | tooltip frame against the chart | 1.80 | none (text carries it) | Fine |
| `on-alert` #1d0f03 on `alert` | "VISIBLE PAR LE STAFF" | 6.90 | 4.5 | Pass |
| `lime` #a4d007 on `panel` / on `line-soft` | switch on | 9.68 / 7.16 | 3 | Pass |
| `muted` knob on `line-soft` track | switch off, the knob | 4.42 | 3 | Pass |
| `line-soft` track on `panel`; `line` inset edge on `panel` | switch off, the track's boundary | 1.35 / 1.80 | 3 | Fails (M3) |
| `line-deep` #2a6f9a on `panel` | proposed switch edge | 3.20 | 3 | Pass |
| Minted vs destroyed (gold vs accent) | adjacent bars at zero | 1.24 | none (position carries it) | Fine |
| Peu commune vs rare | two index lines | 1.01 | n/a | Same luminance (M1) |
| Épique vs commune | two index lines | 1.01 | n/a | Same luminance (M1) |
| Commune vs rare / peu commune; épique vs rare | index lines | 1.45 / 1.47; 1.43 | n/a | Close luminance (M1) |
| Gold vs commune / épique / peu commune | index lines | 1.80 / 1.78 / 1.23 | n/a | Close luminance (M1) |

## What already holds

- One y-axis per chart; two measures are two charts on one time axis. This removes the worst reading error of dual axes.
- The Reactor's meaning is carried by position: minted above zero, destroyed below. Gold and blue confirm it, and their legend is written. Red-green colour vision deficiency keeps the blue-yellow axis, so the pair still separates for most users. Tick labels are absolute values (the mock's `Math.abs` callback), so nothing reads "−2 M destroyed".
- The edition chart has one rarity: points by shape and colour, the average a solid stepped line, the floor dashed, all three named in a written legend that carries the floor's value.
- A missing value is a gap and "—", never 0 (spines, AD-51 and `market-economy.md` agree).
- An unpublished chart is not rendered at all for a player: no figure, no JSON, no table. Nothing leaks to assistive technology.
- Charts draw without animation when motion is reduced; nothing loops.
- Every figure comes from the server (AD-51), so the table and the canvas cannot disagree.
- Back-office indicators already have a written reading (what is happening, why it matters, what to do), which is a good text equivalent of their takeaway.

## Findings

Severity is user harm. Part A lists what the contract gets wrong or contradicts. Part B lists what it has not said.

### Part A. Failures of the contract

- **[high] H1. The table is not an equivalent, and the row contradicts itself.** Row "Chart" (`EXPERIENCE.md`:356) says "a table of exactly what is drawn", then lists "the last 7 days for the Reactor, the last 5 sales for the edition, opening, 30 days ago and today for the index". The Reactor draws 30 days, the edition chart every sale in the average-price window (the mock draws 15), the index 90 days per rarity. The same row makes the table "the keyboard and screen-reader path", so a blind or keyboard-only user gets 23 % of the Reactor, a third of the sales and 3 points of a 90-day series. Peaks, dips and the moment the index turned are lost; Flow 10 step 3 ("the last sales climbing above the average") cannot be checked from 5 rows without the earlier ones. The mock's index table also spends a column on "Ouverture", which is 100 by definition. (1.1.1, 1.3.1; floor "No information only in a tooltip".) *Fix:* the table holds every row the chart draws: the Reactor 30 rows with Jour, Frappés, Détruits, Solde, En circulation; the edition chart every sale in the window with Jour, Prix de vente, Prix moyen après la vente; the index 90 rows with one column per rarity (or, if the author wants it shorter, one row per week, stated as such in the caption, and the drawn chart sampled the same way). Drop "Ouverture" from the index table and say "base 100 au premier jour de prix" in the caption. Rewrite the row: "a disclosure holding a table of every value drawn, newest first".

- **[high] H2. The day's balance exists only in a tooltip.** Copy deck `EXPERIENCE.md`:185 has "tooltip « Solde du jour : +<amount> »"; AD-51 lists `balance` among the server's figures; the mock's table has Jour, Frappés, Détruits, En circulation and no balance. A keyboard user cannot open a Chart.js tooltip at all, and a screen-reader user never meets it. This breaks the floor's bullet "No information only in a tooltip (`title`)" in letter and spirit. (1.1.1, 2.1.1.) *Fix:* a "Solde" column in the Reactor table; the tooltip may keep it as a convenience. State once in row "Chart": "a tooltip shows nothing that the table lacks".

- **[high] H3. The canvas name gives the subject, never the point.** Row "Chart": "the canvas being an image named by its title and period"; AD-51: "`aria-label` is a locale key". A static key can only say "Le Réacteur des Briétés, 30 derniers jours". The sighted reader of Flow 10 gets "money still piles up", "Épiques at 143, the steepest rise", "the last sales climbing above the average" at a glance; a screen-reader user gets a title and must reconstruct the trend from a table of numbers, which H1 makes impossible today and slow even once fixed. (1.1.1: a text alternative must serve the equivalent purpose; for a chart that purpose is its takeaway.) *Fix:* keep the title in the visible `<figcaption>` and make the canvas `role="img"` with `aria-labelledby` pointing to the caption and `aria-describedby` pointing to a server-rendered, visible or visually hidden summary sentence composed from `EconomySeries` figures by an interpolated locale key, one per kind. Examples to add to the Copy deck in both languages:
  - Reactor: "Sur 30 jours, 96,3 millions de PiCoins frappés et 54,1 millions détruits ; le solde est positif 30 jours sur 30. Le tableau donne chaque jour."
  - Circulation: "En circulation : de 360 millions à 412,6 millions de PiCoins en 30 jours."
  - Index: "Sur 90 jours, Épique 143, la plus forte hausse ; Légendaire 131 ; Rare 122 ; Peu commune 115 ; Commune 112."
  - Edition: "15 ventes en 90 jours, de 24 200 à 38 900 PiCoins ; les 3 dernières au-dessus du prix moyen de 31 400 ; plancher 22 300."
  - With "peu de ventes": the count and range only, no claim about the average.
  The sentence rules ("la plus forte hausse", "au-dessus") are computed on the server, as AD-51 already requires of every number. AD-51's "aria-label is a locale key" becomes "named by its caption and described by a summary key composed with the series' figures". A sentence that names a trend is checked in a Ruby test of each kind.

- **[medium] M1. Rarity lines are told apart by colour along their whole length.** `DESIGN.md`:1260 puts the rarity shape "on the last point only" and the name and last value "at the line's end". Between day 1 and day 89 the five lines cross and only colour separates them, and the luminances are nearly equal: peu commune vs rare 1.01, épique vs commune 1.01, gold vs peu commune 1.23. For a user with a colour vision deficiency, or in forced colours, a crossing is ambiguous. The end labels help only at the right edge, and at 320 px they do not fit (M6). The Do's row "carry rarity by colour, shape and name together" is met at one point per line. The mock also draws commune and peu commune both as `circle` (spec: disc and ring), and its end labels are all `text-bright`, with no shape. (1.4.1.) *Fix:* give each rarity a dash pattern as well as its colour, ordered by rarity (Commune solid, Peu commune long dash, Rare short dash, Épique dash-dot, Légendaire solid with its star markers every 15 days), or draw the rarity's marker every 15 days instead of the last point only. Put an HTML legend under the chart listing each rarity with its shape icon, name and last value, which is also the narrow-screen and forced-colours fallback. The tooltip's `usePointStyle` (in the mock) keeps the shape in the tooltip.

- **[medium] M2. A sparkline is called decorative, but it carries the 30-day trend.** Row "Chart": "A sparkline is decorative: its value is the figure beside it"; AD-51: `aria-hidden`, no title or table. The figure beside it is today's price; the line shows whether it rose or fell over 30 days, which the tile states nowhere (the mock's note line says "cible 1 à 2 j", a target). A screen-reader user loses the one thing the sparkline adds. (1.1.1.) *Fix:* add a written, server-computed trend to the tile's note line, "+14 % en 30 j" ("+14% over 30 days"), with its spoken form; the sparkline stays `aria-hidden`. Or drop the sparkline. Add the copy to both locales.

- **[medium] M3. The publication switch has no semantics and the off state's edge is under 3:1.** `DESIGN.md`:1265 says "the app's toggle, lime when on", but no toggle component exists in `DESIGN.md`; the only switch is the motion switch, a toggle button with `aria-pressed` (`EXPERIENCE.md`:204). The mock's switch is a bare `<span>` with `box-shadow` edges. The off track (`line-soft` on `panel`, 1.35; its inset `line` edge, 1.80) fails 1.4.11; the knob (4.42) passes, so state is visible but the component's extent is not. A moderator "sees it read-only", with no rule on how. Publishing writes for every player at once, so a mis-press matters. (4.1.2, 1.4.11, 2.5.3, 3.3.4.) *Fix:* a `<button role="switch" aria-checked>` inside the form that POSTs, its accessible name starting with the row's visible chart name ("Le Réacteur"), `aria-describedby` the row's state text ("public depuis le <date>" in a `<time>`, or "staff seulement"); after the POST, focus stays on the switch and the new state text is posted once to a polite status region ("Le Réacteur est public." / "Le Réacteur n'est plus public.", both locales); a failure restores the switch and says so inline. For a moderator: `aria-disabled="true"` with "lecture seule" in the description, never native `disabled` with no reason. Track edge `line-deep` (3.20). Name the component once in `DESIGN.md` ("Switch") so the motion switch and this one share it, or say explicitly that they differ.

- **[medium] M4. Spoken forms of the new figures and of "—" are missing.** The previous review asked for spoken forms of compact amounts; the charts add more: headline figures "412,6 M", "96,3 M"; durations "4 min", "3 h 10", "1,6 j"; the label "DÉTRUITS / FRAPPÉS", which the floor's slash rule would have read "sur" but which means a ratio; the dash "—", which screen readers read as "tiret cadratin", "dash", or nothing at default punctuation levels, leaving an empty-sounding cell; "+<amount>" and a negative balance. (1.3.1, 3.1.) *Fix:* one shared helper emits, for each compact figure, the visible text `aria-hidden` and a visually hidden full form: "412,6 millions de PiCoins", "3 heures 10 minutes", "1,6 jour de capsules"; the headline figures are a `<dl>` (label `dt`, figure `dd`); "DÉTRUITS / FRAPPÉS" is read "Détruits pour cent frappés" ("Destroyed per hundred minted") through hidden text; a missing cell renders `<span aria-hidden="true">—</span><span class="visually-hidden">aucune valeur</span>` ("no value"). Add these to the Copy deck in both locales.

- **[medium] M5. The table's markup is unspecified, and the mock's is wrong.** `DESIGN.md`:1266 gives the look only. The mock builds the header row as a plain `<tr>` of `<th>` without `<thead>` or `scope`, the day column as `<td>`, no `<caption>`, and no unit in any header. (1.3.1.) *Fix:* add to row "Chart": the table has a `<caption>` repeating the chart's title and period (visually hidden, since the summary already shows it), `<th scope="col">` headers with their unit ("Frappés (PiCoins)", "Prix (jours de capsules)", "Indice (base 100)"), the day as `<th scope="row">` in a `<time datetime>`, full figures (never compact) with U+00A0 grouping as `DESIGN.md`:669 requires, newest row first.

- **[medium] M6. Reflow at 320 CSS px fails in two places.** The Reactor table has four columns of full figures: "En circulation" values are eleven characters ("412 634 120") at 12px JetBrains Mono, about 80px, with Jour, Frappés, Détruits and the 12px paddings the table needs about 300px; at 320 px the panel's content box is about 256px. The index reserves `layout.padding.right: 130` for end labels in the mock, leaving a plot about 120px wide for 90 days. (1.4.10.) *Fix:* the table sits in a scroll container named by the caption (`role="region"`, `aria-labelledby`, `tabindex="0"` so a keyboard user can scroll it), or its headers wrap and its figures stack under 360 px; under the 720px breakpoint the index drops end labels for the HTML legend of M1 and uses the full width. Check both at 320 × 640 and at 1280 px at 400 % zoom.

- **[medium] M7. Forced colours are not addressed, and three parts fail differently.** Neither spine nor `app/frontend` mentions `forced-colors`. In Windows High Contrast the page's backgrounds become the system `Canvas` colour, which can be white. (a) The canvas keeps its authored pixels on a transparent background, so gold lines (1.6:1 on white) and `muted` axis text (2.9:1 on white) sit on a white field; on a black theme the chart stays coloured among system colours. (b) Legend swatches are backgrounds (`DESIGN.md`:1260, square swatches by class), which forced colours remove: the legend becomes words with no key. (c) Rarity tile edges and the mock's switch are `box-shadow`, which forced colours drop: the switch disappears. (1.4.11, 1.4.1 in that mode; not a strict AA failure for the canvas, but the floor should say what happens.) *Fix:* add a floor bullet "Forced colours": the `chart` controller listens to `matchMedia('(forced-colors: active)')` and, while it matches, redraws with the system colours read from `CanvasText`, `Canvas`, `Highlight` and `GrayText`, one colour for every series, told apart by the dash patterns of M1 and the marker shapes; legend swatches and rarity marks are inline SVG with `forced-color-adjust: none` or drawn with borders; the switch is native (M3) so the system draws it. The simpler alternative, `forced-color-adjust: none` on the figure with an opaque `panel` background, keeps the dark chart readable but ignores the user's chosen palette; state which one is chosen.

### Part B. What the contract has not said

- **[low] L1. Every disclosure has the same name.** The Bourse page holds at least two "VOIR LE TABLEAU" (three if the circulation chart has its own), the card detail one more. A screen reader's list of buttons reads "Voir le tableau" three times. (2.4.6.) *Fix:* a visually hidden suffix with the chart's title, "Voir le tableau : le Réacteur" ("Show the table: the Reactor"), the visible text first so 2.5.3 holds; on the phone the summary row has a 44px minimum height. Say whether the Reactor's two canvases share one table (as in the mock) or have one each; one table with a "En circulation" column is enough.

- **[low] L2. Tooltips cannot be dismissed and the scatter needs a precise tap.** Chart.js tooltips appear on hover and cover bars; there is no Esc (1.4.13, dismissible). On the phone a tap tooltip stays until another tap. The edition scatter uses Chart.js's default `intersect: true`, so a tap must land on a 10px point (the floor's 44px is for targets; these points are not controls, but a tooltip that never opens is a dead end on touch). *Fix:* Esc and a tap outside the canvas clear the active elements; every kind uses `interaction: { mode: 'nearest', axis: 'x', intersect: false }` (the bars and lines already use `index`, `intersect: false` in the mock). The table remains the complete path (H1), so this stays low.

- **[low] L3. The balance's sign is hard-coded.** "Solde du jour : +<amount>" assumes a positive day; a day where stamps and commissions exceed entrusting (likely once the economy matures) prints "+-1 200" or loses the sign. *Fix:* "Solde du jour : <signed amount>", signed by the shared amount helper, with "−" (U+2212) and a hidden "moins" ("minus"), since some screen readers skip U+2212.

- **[low] L4. The staff flag sits outside the chart's name.** "VISIBLE PAR LE STAFF" is specified as a visual label only. A staff member using a screen reader hears the chart as if it were public. *Fix:* the flag is inside the `<figcaption>`, so it is part of the chart's name; its text is in the markup in its case, not produced by `text-transform`.

- **[low] L5. Page structure is unspecified.** The mock uses `<p class="hd">` for every panel title. *Fix:* "La Bourse de la Confrérie" is the page's h1, "LE RÉACTEUR DES BRIÉTÉS" and "CE QUE COÛTE UNE CARTE" h2, "INDICE DES PRIX" and "EN CIRCULATION" h3; each chart a `<figure>` with its `<figcaption>`; the five rarity tiles a list. "Briétés" is a coined word: leave it without `lang`, but check that `en.yml` gives an English title rather than repeating it.

- **[low] L6. The Bourse link must be a link.** Row `EXPERIENCE.md`:55 says "a link (not a filled button)", and the AGENTS rule maps that to `ButtonComponent` with `variant: :link`. It must render an `<a href>` to the page, never a `<button>`, since it navigates; 44px tall on the phone. Hiding it when no chart is published is right (no link to a 404). Its uppercase text should be in the markup as written in the Copy deck, not produced by CSS, so the accessible name matches the visible label.

- **[low] L7. Mock departures a builder may copy.** Axis ticks at 11px regular (`Chart.defaults.font.size=11`, no weight) where `{typography.label}` is 700 and the floor wants bold at 12px and below; the circulation title drawn inside the canvas at 10px (it belongs in HTML, as a caption); `style` attributes on legend swatches and tiles (forbidden in server HTML by AGENTS); the edition legend's "Une vente" swatch is a square while the point is a triangle; commune and peu commune both `circle`; the phone frame omits the table and the index; Chart.js 4.5.1 from a CDN where AD-51 pins 4.6.1 and forbids `chart.js/auto`-style loading. Add the usual line to the mock reference that these are not to be copied.

- **[low] L8. The floor line is thin.** `{components.chart.floor}` is 1px dashed `muted` (5.98, passes), but a 1px dash at 4px gaps near the 2px average line is hard to see, and a canvas line of one CSS px is the thinnest mark on the page. *Fix:* 2px dashed, the same width as the threshold.

- **[low] L9. Colour words overlap.** Minted gold is also Légendaire and the PiCoin; destroyed blue is also Rare and every link (`accent`), including "VOIR LE TABLEAU" directly under the bars. The written legend resolves it, so no failure; noted so the next chart does not add a third meaning to either colour.

- **[low] L10. Canvas text ignores text-size settings.** Chart.js draws fixed pixel fonts. Browser zoom scales them (1.4.4 holds), but a text-only zoom, Android's font scale or iOS Dynamic Type in the native apps leave axis text at 11px while the rest of the page grows. *Fix:* the controller reads the root font size and scales the chart fonts from rem; or accept it, since the table carries every value.

## Proposed wording for the spines (for the author)

Row "Chart" (`EXPERIENCE.md`:356), replacing its second and third sentences:

> Every chart: a title, the chart, a summary sentence of what it shows (Copy deck, Charts), then "VOIR LE TABLEAU", a disclosure holding a table of every value drawn, newest first, with a caption, column headers carrying their unit and the day as row header. Hover or a tap shows a tooltip with the day and each series' value; a tooltip shows nothing the table lacks, and Esc or a tap outside closes it. The canvas is an image named by the title and described by the summary sentence; the summary's figures and trend words come from the server.

Floor, new bullet after "Gauges":

> **Charts:** a chart's name is its title and its description the summary sentence; its table is the complete text form; a sparkline is hidden and the trend it draws is written beside it. Rarity series carry colour, dash and shape. Compact figures, durations and the missing-value dash have spoken forms (Copy deck, Charts). Under forced colours the chart redraws in system colours, told apart by dash and shape. The publication switch is a switch named by its chart, its state text its description, its change announced once.
