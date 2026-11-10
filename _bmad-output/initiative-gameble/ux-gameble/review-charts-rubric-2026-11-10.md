# Spine Pair Review — gameble, economy charts (2026-11-10)

Scope: only the chart additions of 2026-11-10. DESIGN.md: `colors.chart-minted`, `colors.chart-destroyed`, `components.chart`, `components.sparkline`, the Marché "Charts" bullets (DESIGN.md:1260-1266) and the Do/Don't row (DESIGN.md:1297). EXPERIENCE.md: the IA row (EXPERIENCE.md:55), the copy deck rows "Bourse de la Confrérie" and "Charts" (185-186), the Marché component rows "Bourse de la Confrérie", "Edition chart", "Chart" (354-356), the back-office "Charts" sentence (364) and Flow 10 (922-929). Checked against spec CAP-34, CAP-36, CAP-38, `market-economy.md` (Charts, Indicators, Average price), architecture AD-51, and `mockups/market-charts.html`. The spines were not edited.

## Overall verdict

The additions are mechanically sound: every token they reference resolves, the colours carry hexes, the three publication kinds, the one-y-axis rule, the gap-not-zero rule, the staff flag and the table fallback all match AD-51 and CAP-38. Two things would make a builder guess or contradict a source: the "VOIR LE TABLEAU" tables are specified as a subset of what is drawn (7 of 30 days, 5 sales, 3 index columns), against "a readable table of what it draws" in CAP-38 and AD-51; and the back-office switch's "what it rests on" is a data requirement nobody defines. State coverage of the new surfaces is thin (staff on the Bourse, empty or partial data, the market not open, loading, the switch's own feedback), and part of the mock's visible copy (table headers, tooltips, back-office titles, tile notes, aria-labels) is not in the deck.

## 1. Flow coverage — adequate

Checked CAP-34 (edition chart), CAP-36 (90-day indicator series), CAP-38 (economy page, publication) against Key Flows. Flow 10 has a named protagonist, numbered steps, a climax and a failure path, and covers CAP-38 and CAP-34's chart. CAP-36's series and the publication switch have no flow beat.

### Findings
- **low** No flow beat shows an administrator publishing a chart, though AD-51 makes the publication switch the one system test (Flow 9, EXPERIENCE.md:916-920). *Fix:* add a step to Flow 9 (Thomas checks the Reactor as staff, flagged, then turns its switch on) or a short Flow 11.
- **low** Flow 10's failure path covers "nothing published" only; the partial case (edition chart published, Bourse not, or the reverse) is untold (EXPERIENCE.md:929). *Fix:* one clause: "only the edition chart published → no link to the Bourse, the card detail shows its chart".

## 2. Token completeness — strong (mechanical), with prose gaps

Every `{path.to.token}` in the additions resolves: `colors.chart-minted` (#f4c542), `colors.chart-destroyed` (#66c0f4), `colors.text-bright`, `colors.text-max`, `colors.muted`, `colors.panel`, `colors.panel-sunken`, `colors.panel-raised`, `colors.line`, `colors.line-soft`, `colors.alert`, `colors.on-alert`, `colors.accent`; `typography.label` (JetBrains Mono 700 11px); `components.chart.{height, height-short, height-index, line, grid, axis-text, point, threshold, floor, tooltip-background, tooltip-border}`; `components.sparkline.height`. Unused but harmless: `chart.series-single`, `chart.bar-end-radius`, `sparkline.line`. AD-51's cost "the `--color-chart-minted` and `--color-chart-destroyed` tokens join DESIGN.md" is met.

### Findings
- **medium** The Colors prose has no entry for the two chart tokens and no contrast figure for them, while `chart-minted` shares the hex of `{colors.gold}` ("never a general accent", only exception the Chattomètre) and `chart-destroyed` the hex of `{colors.accent}` / Rare (DESIGN.md:58-59, 605-622). On the Bourse, the gold minted bars and the gold Légendaire line sit one panel apart. *Fix:* add a Colors bullet like the capsule-origins one: separate roles that share a hex, never used elsewhere, contrast on `{colors.panel}` (about 10:1 and 8:1), and why a minted bar cannot be read as a Légendaire (position above the axis, legend, separate panel).
- **medium** Two new uses of reserved colours are not reflected in their rules: the publication switch "lime when on" (lime is listed for the primary action and a closed set of markers) and the staff flag on an `{colors.alert}` fill (orange "is for alerts only") (DESIGN.md:1265 vs 613-616). *Fix:* either add both to the Lime and Orange bullets as named uses, or give the switch an accent "on" and the flag an outline chip in `{colors.alert}` like the Status chip (market).
- **low** Raw sizes where tokens exist: figures "at 34px" (`{typography.count-large}` is 34.5px, phone 30px), "11px `{colors.muted}`" rarity name and note (`{typography.label}`), table "12px" (`{typography.body-small}`), threshold label "bold 10px" (no token), the Brotherhood's line "13px", tile price "28px" (DESIGN.md:1261-1266). *Fix:* name the tokens (`count-large` / `count-large-phone`, `label`, `body-small`, `body`); add one token for the 28px tile figure and the 10px chart label or reuse `label`.
- **low** The 12px table text is not stated as bold, against the readability rule "every style at 12px and below that carries information is bold" (DESIGN.md:1266, 663). *Fix:* "the table in `{typography.body-small}`".

## 3. Component coverage — adequate

Chart and sparkline have a visual spec (DESIGN.md frontmatter 521-537 and 1260-1266) and a behavioural spec (EXPERIENCE.md:356). The Bourse, the edition chart and the back-office charts have both.

### Findings
- **medium** "Publication switch: the app's toggle" refers to a component that does not exist: DESIGN.md has no toggle in its primitives; the only switch is the landing's Motion switch (`aria-pressed`, a button) and the settings use segmented choices (DESIGN.md:1265; grep "toggle" finds nothing else in DESIGN.md). The mock draws a 44 × 24 sliding knob. *Fix:* define it as a primitive (size, track `{colors.line-soft}` with `{components.control-border.css}`, knob, on and off colours, disabled read-only look for a moderator, focus ring, `role="switch"` + `aria-checked` or `aria-pressed`, accessible name = the chart's name), or say it is a Radio list / Tabs and filters pair "STAFF / PUBLIC".
- **medium** Component names differ between the spines: DESIGN.md names Reactor, Rarity price tiles, Edition chart, Back-office indicators, Staff-only flag, Publication switch, Table view; EXPERIENCE.md names Bourse de la Confrérie, Edition chart, Chart, and no Staff-only flag, Publication switch, Table view or Rarity price tile row (DESIGN.md:1261-1266, EXPERIENCE.md:354-356). *Fix:* use one set in both: Chart, Sparkline, Bourse de la Confrérie (Reactor panel, Rarity price tile, Price index), Edition chart, Staff-only flag, Publication switch; give the last two a behavioural line (the flag's placement: on the chart title row of every staff-only chart; the switch's write, see 4).
- **low** "LA BOURSE DE LA CONFRÉRIE" has no place in the Market screen's visual spec, which lists only the chips and the two actions (DESIGN.md:1247). *Fix:* place it (e.g. at the right of the chip row, before the actions; on the phone under the chips) as a `variant: :link` button, as the IA row already demands.

## 4. State coverage — thin

Walked the four new surfaces. Covered: Bourse with nothing published (no page, no link); each Bourse panel shown only once published; edition chart not published / few sales / no sale / staff while unpublished; a missing value as a gap and "—"; reduced motion; visitor reads the Bourse; moderator sees switches read-only. State Patterns (EXPERIENCE.md:526-611) has no chart row at all.

### Findings
- **medium** Staff on the Bourse is not described: per AD-51 staff always see every chart, so for staff the link always shows and the page always exists, each unpublished panel carrying "VISIBLE PAR LE STAFF" (EXPERIENCE.md:55, 354). *Fix:* add to the Bourse row: "Staff: the link and the page always show; an unpublished panel carries the Staff-only flag on its title row".
- **medium** Market not open or suspended: AD-51 makes the page live "whatever the market's open state", but its only entrance is the market screen, which is the teaser until the first opening (EXPERIENCE.md:55, 78-79). *Fix:* state whether the teaser carries the link once a chart is published (or staff only, before opening), and that a suspended market keeps the link and the page.
- **medium** Empty and partial data on a published chart: a Reactor published with fewer than 30 days of snapshots, a rarity with no typical price (Légendaire with too few sales), an index line that has not started, a headline ratio with nothing minted; none is specified (EXPERIENCE.md:354; the mock's switch row "Légendaire : 9 ventes" shows the case is expected). *Fix:* one rule: the axis always spans the full window, days before the first snapshot are gaps; a tile with no price shows "—" and no sparkline; a rarity with no index draws no line and its end label is absent; a headline with no data shows "—".
- **medium** Loading and failure of the canvas: Chart.js loads on connect after `document.fonts.ready`; nothing says what shows meanwhile or if the script fails (EXPERIENCE.md:356). *Fix:* "The figure reserves its height (`{components.chart.height*}`) and shows nothing until drawn; if it cannot draw, the title and the table stay, the table opened."
- **medium** The publication switch's write has no states: immediate POST or confirmation, feedback, the no-op case, a concurrent change by another administrator, focus after the page refreshes (EXPERIENCE.md:364). Publishing to every player is consequential. *Fix:* "Turning a switch on asks to confirm ('Publier ce graphe pour tous les joueurs ?'); off applies at once; the row then shows its new date; a switch already in that state changes nothing; focus returns to the switch".
- **medium** Back-office indicators without a threshold: three of four have "None at launch" (market-economy.md, Indicators), the spine says "each with its threshold or target dashed", and the days-of-income indicator has one target per rarity while the mock draws Épique only (EXPERIENCE.md:364; mock section C). *Fix:* "no dashed line when there is no threshold"; say whether the income indicator is one chart per rarity, one five-line chart with a target band per rarity, or Épique only.
- **medium** Which card-detail surfaces carry the edition chart: AD-51 says "every surface showing a card's detail", the spine says "the card detail" only; the Annonce and Mettre en vente show the average price too, and Flow 10 is about deciding to sell (EXPERIENCE.md:355). *Fix:* list them: card detail from the collection and from Toutes les cartes, the public card page, the Annonce; say whether Mettre en vente shows it, and that a visitor sees it where they see the card detail.
- **low** Phone: the headline figures' layout (four figures, 2 × 2?) and size (`count-large-phone`) are not given; the mock's phone drops two figures and the circulation chart while the spine keeps the latter (EXPERIENCE.md:354, mock A phone). *Fix:* "four figures two per row at `{typography.count-large-phone}`".
- **low** Tooltip on touch: how a tap tooltip closes, and that a tap does not block scrolling (EXPERIENCE.md:356). *Fix:* one line: a tap elsewhere or a second tap closes it.
- **low** The disclosure's open state: does "VOIR LE TABLEAU" become "MASQUER LE TABLEAU" (EXPERIENCE.md:186). *Fix:* keep one label, state it, or add the second string.

## 5. Visual reference coverage — adequate

The mock is linked in DESIGN.md (1260) and EXPERIENCE.md (354, section A), with "the spines win".

### Findings
- **low** The mock's sections B (card detail) and C (back-office) are not cited at their rows, and section D ("Plus tard") is not said to be out of scope in the spines (later-roadmap.md:15 holds it) (EXPERIENCE.md:355, 364). *Fix:* cite "section B" in the Edition chart row and "section C" in the back-office sentence; add "section D is later (see later-roadmap.md)".
- **low** The mock sets the headline figures and tile prices in VT323 and the average line in `text-bright`, against the spines (JetBrains Mono; `text-max`). The spines win, but earlier mocks name what not to copy. *Fix:* add "its VT323 figures and its regular-weight table are not to be copied".

## 6. Bloat & overspecification — adequate

The additions are compact and mostly tie to decisions. Overspecification is limited to raw pixel sizes (see 2). EXPERIENCE.md's Bourse row restates the windows briefly and points to `market-economy.md`, which is fine.

### Findings
- **low** The Do/Don't row repeats the Charts bullet's one-y-axis rule and the rarity rule already in Do's (DESIGN.md:1297 vs 1260, 1281). *Fix:* keep it (Do/Don't is a scan table) or shorten to the y-axis half.

## 7. Inheritance discipline — adequate

Words match `market-economy.md` ("Réacteur des Briétés", 100-6-Tron, Frappés/Détruits, PiCoins); the three kinds match AD-51; the one-y-axis rule, the gap-not-zero rule, the no-automatic-threshold rule and "the page does not exist for players" match CAP-38 and AD-51.

### Findings
- **high** The table is not what is drawn. The Chart row says "a table of exactly what is drawn (the last 7 days for the Reactor, the last 5 sales for the edition, opening, 30 days ago and today for the index)" (EXPERIENCE.md:356). The Reactor draws 30 days, the edition chart every sale of the 90-day window (mock B draws 15), the index 90 days × 5 rarities. CAP-38 requires "a readable table of what it draws"; AD-51 renders "a `<details>` table of the rows it draws", and the table is the keyboard and screen-reader path, so a screen-reader user would get 7 of 30 days. The sentence also contradicts itself. *Fix:* "the table holds every row the chart draws, newest first (30 days for the Reactor, every sale in the window for the edition, 90 days for the index with one column per rarity)"; if a summary table is wanted for length, add it as a second, labelled view and have the architecture agree, rather than replace the full one.
- **high** "with what it rests on" on each publication switch is a data requirement no source defines (EXPERIENCE.md:364). The mock shows "42 jours de snapshots · 18 400 ventes", "Légendaire : 9 ventes", "212 éditions ont 5 ventes ou plus": three different facts that need queries AD-51 does not list (it names only `EconomySeries`, `EditionSales`, `ChartPublications`), and no copy for them exists. A builder would invent the figures. *Fix:* name the fact per kind and its copy: Reactor "<n> jours de données", rarity prices "<n> ventes pour la rareté la moins vendue (<rarity>)", edition chart "<n> éditions ont assez de ventes"; add them to the copy deck and ask the architecture to add the query (or drop "what it rests on" and keep only "public depuis le <date>" / "staff seulement").
- **medium** Sparkline window: the spine draws a 30-day sparkline per rarity tile (EXPERIENCE.md:354), while `market-economy.md` sets "rarity prices … 90 days" and AD-51's `EconomySeries` returns the rarity prices over 90 days only, the configuration module being allowed only display transforms. *Fix:* draw the sparkline over the same 90 days, or ask AD-51 to add a 30-day slice to `EconomySeries`.
- **medium** "Shown only once one of its charts is published" (IA) is right, but AD-51 shows the link and the page when `ChartPublications.visible_kinds(viewer)` is non-empty, which includes `edition_sales`: publishing the edition chart alone would open an empty Bourse (EXPERIENCE.md:55, AD-51). *Fix:* raise with the architecture: the page's condition is the visible kinds among `reactor` and `rarity_prices`; keep the spine as is.
- **medium** Rounded bar ends and vector point markers against Shapes: "Corners are square; round and angled forms appear only as pixel art" (DESIGN.md:740-742) vs `{components.chart.bar-end-radius}` 4px and Chart.js disc/ring/diamond/triangle/star markers (DESIGN.md:1260-1261). The Do/Don't row adds no exception. *Fix:* either state charts as an exception in Shapes (canvas drawings, not pixel art), or square the bar ends and draw markers from the pixel rarity icons.
- **low** Marker names "disc, ring, diamond, triangle, star" vs the Rarity table's "Circle (solid disc)", "Double circle (a ring inside a ring)" (DESIGN.md:1260 vs 628-634). The mock draws Peu commune as a plain circle on a transparent fill. *Fix:* say "the rarity's shape (see Rarity): a double ring for Peu commune".
- **low** The tile subtitle "prix moyen, en jours de capsules d'un joueur régulier" and the note "revenu médian des joueurs actifs" loosely restate `market-economy.md`: the rarity price is the median of edition averages, the income the median earnings of players who opened a capsule and earned something that day (EXPERIENCE.md:185). *Fix:* have the author confirm the simplification is acceptable, or say "prix typique".
- **low** "Charts draw at once, without animation, when motion is reduced" implies they animate otherwise; AD-51 says "animation off unless the shared motion switch allows it", and the Motion section does not list a chart animation (EXPERIENCE.md:356). *Fix:* either name the animation (duration, stepped) in Motion or say charts never animate.

## 8. Shape fit — strong

Additions sit in existing sections (Colors frontmatter, Components frontmatter, Components / Screens / Marché, Do's and Don'ts; IA, Copy deck, Component Patterns / Marché, Key Flows). Order is preserved.

## Copy coverage (requested lens)

The deck covers the title, the Reactor's name and line, the four headline labels, the legend, the day's-balance tooltip, the tile panel heading, subtitle, sentence and note, sample durations, the index heading, "VOIR LE TABLEAU", "VISIBLE PAR LE STAFF", the edition legend, "GRAPHES PUBLICS" and its subtitle, the switch states, "ALERTE", "CIBLE" and "—". English is given only for the title, "VOIR LE TABLEAU" and "VISIBLE PAR LE STAFF".

### Findings
- **medium** Table headers missing: "Jour", "Frappés", "Détruits", "En circulation"; "Rareté", "Ouverture", "Il y a 30 j", "Aujourd'hui"; "Jour", "Prix de vente", "Prix moyen" (mock A, B). *Fix:* add a "Chart tables" line to the Charts copy row (they become `charts.<kind>` keys per AD-51).
- **medium** Tooltip lines missing beyond "Solde du jour": "Frappés : <n>", "Détruits : <n>", "En circulation : <n>", "<rarity> : <index>", "Vente : <n>", "Prix moyen : <n>" (mock scripts). *Fix:* add them; say the tooltip uses the short series name, the legend the long one.
- **medium** Canvas accessible names ("named by its title and period") have no strings (EXPERIENCE.md:356). *Fix:* add one per chart, e.g. "PiCoins frappés et détruits par jour, 30 derniers jours", "PiCoins en circulation, 30 derniers jours", "Indice des prix par rareté, 90 jours", "Ventes de <card> <season>, 90 jours".
- **medium** Back-office chart titles and subtitles missing: "DÉTRUITS / FRAPPÉS · 30 J GLISSANTS", "alerte sous 40 %", "PICOINS PAR JOUEUR ACTIF · 90 J", "pas d'alerte", "<RARITY> EN JOURS DE REVENU", "cible 1 à 2 jours", "PART DU TOP 1 %"; and the switch row names "Le Réacteur", "Prix en jours de capsules et indice", "Ventes d'une édition" (mock C). *Fix:* add them to the Charts row.
- **medium** Tile note line and duration format: the deck gives three sample durations but no rule, and the note line's content ("≈ 0,003 j", "cible 1 à 2 j", "cible ≈ 40 j") is undefined (EXPERIENCE.md:185, DESIGN.md:1262). *Fix:* state the format (under an hour "<n> min"; under a day "<h> h <mm>"; else "<d,d> j") and the note ("cible <target>" from `market-economy.md`, or "≈ <d,ddd> j").
- **medium** No English for the Brotherhood's line, "LE RÉACTEUR DES BRIÉTÉS" and the tile sentences; the Brotherhood's voice needs an author-approved English (brotherhood-tone.md) more than a literal one (EXPERIENCE.md:185). *Fix:* add the English beside each, as the 2026-11-09 Brotherhood strings would need too.
- **low** Missing smaller strings: the Reactor's "30 derniers jours" and the phone's short "LE RÉACTEUR" / "30 j" / "EN JOURS DE CAPSULES", the edition header subtitle "5 dernières ventes, sans les extrêmes", the date label format ("3 déc."). *Fix:* add, or say the phone keeps the desktop titles.

## Mechanical notes

- All token references in the additions resolve; no colour token lacks a hex.
- "Réacteur des Briétés" is spelled as in `market-economy.md` (not a typo).
- "Reactor" (English) in DESIGN.md sub-bullet vs "LE RÉACTEUR" in EXPERIENCE.md: fine as a working name, but pick one component name (see 3).
- The IA row cites "spec CAP-38" and the Edition chart row "spec CAP-34": consistent with the spines' existing practice.
- `components.chart.grid` has a colour but no width; the mock uses 1px. State "1px" or "2px" with the art-pixel rule in mind.
