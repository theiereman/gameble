# Spine Pair Review — gameble, scope: Le Grand Inventaire (2026-11-19)

Scope: the Grand Inventaire addition only. EXPERIENCE.md IA rows (54-56), hub content (93), signed-out visitors (95), Copy deck row (182), landing 04 (231), Collection opening (322), section "Le Grand Inventaire" (356-374), State Patterns (597, 645-647), Responsive (870). DESIGN.md hub layout row (708), section "Grand Inventaire" (1269-1278). `.memlog.md` entries 107-130. Mock `mockups/grand-inventaire-layouts.html`. Also checked against `docs/design-system.md`, which wins over a screen.

## Overall verdict

The main screen is close to a buildable contract. Its behaviour is precise: what counts as found, the boards, ties, names, the visitor, the grid order. Every token it references resolves. One high gap breaks the build: the two signed-out lists send visitors to the landing, although the spec says the screen is open without an account. The sub-surfaces are thinner. Classement des pionniers, the collection tile, the visitor line and the empty lines have behaviour but almost no visual rule. Three placement or naming contradictions (the hub on the phone, the DESIGN hub row, COMPLET against ENTIÈREMENT DÉCOUVERT) would make two builders build different things.

## 1. Flow coverage — thin

Checked the spec, brief and architecture for a requirement behind the feature, and the Key Flows for a flow or an explicit waiver. No source names the Grand Inventaire, a Brotherhood collection or pioneer boards: the feature is UX-led (memlog 107-130).

### Findings
- **[medium]** No spec capability covers the Grand Inventaire, Set de la Confrérie or Classement des pionniers (spec-gameble.md, architecture-gameble.md: no match). The feature adds new reads that architecture has to plan: the Brotherhood copy count summed over all players, two rankings with shared ranks, the viewer's position on a paginated ranking, and a found/total for each rarity and each set. *Fix:* add a CAP to the spec (and an architecture note on the aggregates and their freshness), or record in the memlog that the author keeps it UX-only.
- **[low]** There is no Key Flow and no waiver line, unlike goals ("No Key Flow is needed for goals…", Key Flows intro). *Fix:* add a one-line waiver, or a short flow: a player pioneers a card, sees VOUS on it in the grid, finds themselves on Pionniers · Semaine, opens Classement des pionniers and follows the pinned row.

## 2. Token completeness — strong

Extracted the 13 `{…}` references in DESIGN.md "Grand Inventaire": colors.accent, gold, lime, line-soft, muted, panel, text, text-bright; typography.count-large, count-large-phone, label, number; components.control-border.css. All 13 resolve in the YAML frontmatter. The section correctly adds no new token.

### Findings
- **[low]** "the panel title style" (DESIGN 1274, 1275) is neither a token nor a named style anywhere in DESIGN.md or `docs/design-system.md`. design-system.md fixes panel headings as `--font-kicker`, accent colour, uppercase. *Fix:* say "the panel heading (kicker style, accent)" or reference `{typography.kicker}`.

## 3. Component coverage — thin

Paired every component in EXPERIENCE "Le Grand Inventaire" with a DESIGN rule. Rules exist on both sides for the Head, Sets panel and Pioneer boards ("Panels"), Hub panel, Set de la Confrérie, Found card and Card to discover ("Grid cards"). Classement des pionniers has a DESIGN rule for its pinned row only. Collection tile, Visitor, Layout tabs and Names have no DESIGN rule; Names is fine, since it is the shared name component.

### Findings
- **[medium]** The collection tile has no visual rule (EXPERIENCE 374; DESIGN: none). design-system.md makes it a `TileComponent` (icon + title, a figure, ▸ chevron, auto-fit 280px grid), and the icon is not chosen. *Fix:* add a DESIGN bullet: TileComponent, its icon, the figure "1 204 / 1 500 découvertes".
- **[medium]** Classement des pionniers has no visual rule beyond the pinned row (DESIGN 1277). Missing: the row layout (Chattomètre rows or the board rows?), the period chips (`SegmentedComponent` per design-system.md), the numbered-page control and the page width. *Fix:* one bullet: rows as the board rows, Semaine/Saison as SegmentedComponent, the pager's look, `page--regular` or `page--wide`.
- **[medium]** The visitor's line with its Steam button, and the empty-season, no-discovery and everything-found lines, have no visual rule (EXPERIENCE 372, 645-647; DESIGN: none). *Fix:* name `EmptyStateComponent` for the empty lines, and give the visitor line's place, style and button variant.
- **[medium]** Two words name one state. The Copy deck (182) and the mock tag fully found sets in the Sets panel "COMPLET", but no behavioural or visual rule mentions that tag. The stamp on Set de la Confrérie reads "ENTIÈREMENT DÉCOUVERT", and "COMPLET" is already the player's own set completion (DESIGN 1079). *Fix:* drop "COMPLET" from the panel and copy deck, or specify it and justify the second word.
- **[low]** Names drift across the files. DESIGN uses "Panels" where EXPERIENCE uses "Sets panel" and "Pioneer boards". DESIGN uses "Grid cards" where EXPERIENCE uses "Found card (grid)" and "Card to discover (grid)". The screen is "Grand Inventaire" in State Patterns and the DESIGN heading, "Le Grand Inventaire" elsewhere. DESIGN 1278 says "the collection's copy badge" where DESIGN 618 calls it the "quantity badge". *Fix:* use the EXPERIENCE component names as DESIGN bullet labels, and pick one name for the badge.
- **[low]** The phone tabs CARTES / PIONNIERS / SETS "follow Tabs and filters" (EXPERIENCE 362): `aria-pressed`, never `nav`. They switch whole views, though, which is design-system.md's `.tabs` (`nav.tabs`, tab merged into its panel). *Fix:* say which of the two patterns applies.

## 4. State coverage — thin

For each new surface, checked these states: visitor, empty, no standing, empty filter, pagination and its end, loading and staleness, and the season change.

| Surface | Visitor | Empty | No standing | Empty filter | Pagination | Season change |
|---|---|---|---|---|---|---|
| Grand Inventaire | yes, but missing from the signed-out gate | yes (nothing found, everything found) | yes | by inheritance only | not stated (1 500 cards) | no |
| Set de la Confrérie | yes (no MES DÉCOUVERTES), missing from the gate | no | n/a | by inheritance only | n/a | no |
| Classement des pionniers | yes (no pinned row), missing from the gate | no (empty period page) | yes | n/a | partial (no end, mode unclear) | no |
| Hub panel | n/a (hub is a player's) | yes | n/a | n/a | n/a | no |
| Collection tile | n/a | implicit (0 / total) | n/a | n/a | n/a | no |

### Findings
- **[high]** Both signed-out lists name every screen a visitor may open and send "anything else" to the landing: "Signed-out visitors" (EXPERIENCE 95) and the State Patterns "Signed out" row (597). Neither list names Le Grand Inventaire, Set de la Confrérie or Classement des pionniers. The IA row and the Visitor rule say they are open without an account, and the landing links to the screen. A builder working from the gate redirects visitors, and the landing link breaks. *Fix:* add the three screens to both lists.
- **[medium]** DESIGN's Card not owned is scoped to "signed-in player only, another player's full collection, a set album's missing cards…" (DESIGN 1085). The Grand Inventaire shows it to everyone, visitors included (EXPERIENCE 371). *Fix:* add "the Grand Inventaire and Set de la Confrérie, for every viewer" to that scope.
- **[medium]** A pioneer board has no rule for an empty period while the season is not empty. On Monday at 00:00 UTC the Semaine board has no player; only the season-wide empty line (645) and the viewer's no-discovery line (647) exist. The boards also have no rule for fewer than three ranked players, which the Chattomètre has ("a shorter top 3 shows only its rows", 354). *Fix:* add a state row for a board with nobody in the period (its line, plus the copy in both locales), and add the shorter top 3 rule.
- **[medium]** Classement des pionniers says "Numbered pages that also load by scroll" (368) but leaves open how the two coexist. Does scrolling append the next page? Does the URL change? What does the page number show? It also leaves open the end of the list, an empty period on this page, and where the focus lands after "following it jumps to their page and row". *Fix:* choose one paging model (or describe the hybrid exactly), add a row for the end of the list, and set the focus target to the viewer's row.
- **[medium]** The pinned row is missing from the Accessibility Floor. Its role (link or button) and accessible name ("Vous, 14e, 3 découvertes"?) are not given. Nobody says whether its appearing and disappearing are announced. It covers the last rows unless the scroll padding accounts for it. The boards' semantics (ordered list or table) are not stated either. *Fix:* add a Grand Inventaire line to the Accessibility Floor.
- **[medium]** The Sets panel shows "two of them by name" (364) but does not say which two: the latest fully found? the alphabetical first? It also leaves open what the panel shows when no set is fully found ("ENTIÈREMENT DÉCOUVERTS · 0" with no names, or the line hidden?). *Fix:* state the selection rule and the zero case.
- **[low]** The grid holds every card of the season (about 1 500) and says nothing about paging or loading. It inherits "the search and the Filter zone of Toutes les cartes", but not its paging. *Fix:* say "paged as Toutes les cartes".
- **[low]** The spec does not say what happens when a new season is published. The screen follows "the published season", but the old boards, the Set de la Confrérie of past seasons and any archive view are not covered. *Fix:* one line, e.g. "a new published season resets the screen; past seasons are not shown".
- **[low]** The "Filter empty" state row names Collection as its only surface (616). The Grand Inventaire grid and Set de la Confrérie (MES DÉCOUVERTES with nothing, a search with no result) rely on it implicitly. *Fix:* add both surfaces to that row.

## 5. Visual reference coverage — adequate

The mock is linked inline in both sections, says what it shows (layout A from 720px, layout C on the phone), and says "the spines win". `.working/grand-inventaire-layouts.html` is identical to the promoted copy.

### Findings
- **[low]** The mock shows the three layout candidates only. It has no hub panel, no Set de la Confrérie, no Classement des pionniers, no pinned row, no visitor line and no copy badge ("x37": 0 hits), so those rest on prose alone, which section 3 found thin. *Fix:* say in the link sentence what the mock does not show, or mock the sub-screens before the build.
- **[low]** The new mock is missing from the files' visual-reference lists (EXPERIENCE 24, DESIGN 604). The inline links are enough under the rubric. *Fix:* add it there, or leave as is if those lists are deliberately partial.

## 6. Bloat & overspecification — adequate

The section is lean. It references existing components (Rarity legend, Set album, Filter zone, Card not owned, See-more link) instead of restating them, and it uses a table. The Copy deck row is one ~1,900-character cell, in line with the house style.

### Findings
- **[low]** The hub panel's placement is written four times: hub content (93), the Hub panel row (373), Responsive (870) and the DESIGN hub row (708). Two of the four copies already disagree (section 7). *Fix:* keep the placement in the Hub panel row and DESIGN 708, and point to them from the other places.
- **[low]** The Sets panel row is missing a period: "then by cards missing Each row opens…" (364). *Fix:* "…by cards missing. Each row opens…".

## 7. Inheritance discipline — thin

Checked names against the memlog decisions, the four placement statements against each other, and the screen against `docs/design-system.md`.

### Findings
- **[medium]** The hub content paragraph's phone stack leaves out the Grand Inventaire panel: "kicker, showcase, weekly mission, daily capsule, the feed block…" (EXPERIENCE 93). The Hub panel row (373) and "Hub on the phone" (870) put it right after the showcase. *Fix:* insert "the Grand Inventaire panel" after "showcase" in line 93.
- **[medium]** The DESIGN hub layout row (708), column 900 to 1179px, reads "menu, weekly mission, the Grand Inventaire panel, weekly mission, daily capsule…": the weekly mission appears twice, and the panel comes after it. EXPERIENCE (93, 373) puts the panel right under the menu. *Fix:* "menu, the Grand Inventaire panel, weekly mission, daily capsule, the Chattomètre panel, then set progress".
- **[medium]** The head carries a visible h1 "Le Grand Inventaire" (EXPERIENCE 362, DESIGN 1272 "the kicker; the h1; the count", and the mock draws it). design-system.md says "A screen shows no title at the top of its content… Keep a visually hidden `h1`". AGENTS.md says the screen yields. *Fix:* make the h1 visually hidden, keep the name in the top bar, and start the head with the kicker and the count.
- **[low]** The hub panel specifies "12px padding" (DESIGN 1275). The design-system's `PanelComponent` compact option is 12px by 16px. *Fix:* say "PanelComponent, `padding: :compact`".
- **[low]** The page width is not named. "Equal thirds of the page width from 720px" (DESIGN 1274) means about 300px per panel on `page--regular` (960px) or about 410px on `page--wide` (1280px). design-system.md puts "all cards" grids on `wide`. *Fix:* name `page--wide`.

## 8. Shape fit — strong

The EXPERIENCE section sits under Component Patterns, between Le Chattomètre and Marché, as the other feature subsections do. The DESIGN section sits within Components, after Chattomètre. The State Patterns and Copy deck rows follow the existing format. No section was invented.

## Mechanical notes

- Placement contradictions: EXPERIENCE 93 (phone stack) and DESIGN 708 (duplicate weekly mission, wrong order).
- Signed-out lists not updated: EXPERIENCE 95, 597.
- Name pairs to align: Panels / Sets panel + Pioneer boards; Grid cards / Found card + Card to discover; Grand Inventaire / Le Grand Inventaire; copy badge / quantity badge; COMPLET / ENTIÈREMENT DÉCOUVERT.
- Undefined style name: "panel title style" (DESIGN 1274, 1275).
- Typo: missing period in EXPERIENCE 364.
- Open `[ASSUMPTION]` tags in scope: the rarity cells mirror the Rarity legend (363); read on load (363); the copy count is held today, across editions, x0 shown (370). Memlog 130 accepts the other assumptions.
- Frontmatter `updated: '2026-11-19'` is set in both files.

## Severity counts

Critical 0 · High 1 · Medium 13 · Low 13
