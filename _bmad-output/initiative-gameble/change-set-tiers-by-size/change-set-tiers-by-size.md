---
type: change-proposal
title: "Set tiers by set size"
date: 2026-10-18
trigger: the author's tier table (2026-10-18, conversation)
mode: batch
scope: moderate
status: approved
---

# Sprint Change Proposal: set tiers by set size

## 1. Issue summary

**Problem.** Tiers fit only one shape of set. Theme and hall of fame sets get bronze (10 %), silver (25 %) and gold (50 %) whatever their size, and franchise, studio and UFO sets get completion only. A 12-card theme gives bronze at 2 cards, silver at 3 and gold at 6, three tiers crowded into a few openings; a 40-card franchise gives nothing between 0 and 40. The number of steps should follow the size of the set, for every kind.

**Type.** A new requirement from the product owner.

**How it was found.** The author's table, 2026-10-18:

| Distinct cards in the set | Tiers | Count |
|---|---|---|
| 3–4 | 100 % | 1 |
| 5–9 | 50 %, 100 % | 2 |
| 10–19 | ⅓, ⅔, 100 % | 3 |
| 20–59 | 25 %, 50 %, 75 %, 100 % | 4 |
| 60–199 | 10 %, 25 %, 50 %, 75 %, 100 % | 5 |
| 200 and more | 10 %, 25 %, 50 %, 75 %, 90 %, 100 % | 6 |

**Author decisions (2026-10-18).**
- Every set kind is tiered by the table: theme, hall of fame, franchise, studio and the UFOs. A set always holds at least 3 games (`Catalog::SetBuilder::MIN_GAMES`), so the table covers every set; a 3- or 4-card set has completion only.
- The tiers below 100 % are named with Greek letters in order: alpha, beta, gamma, delta, epsilon. 100 % stays completion.
- Required counts round up (⅓ of 10 cards is 4).
- The rule applies from the next published season. Published seasons keep their frozen bronze, silver, gold and complete rows; a tier earned stays earned.
- A theme or hall of fame set's card back unlocks on the set's first tier at or above 50 % of its cards (the "back tier"); franchise, studio and UFO sets still have no back, since they change with every season and have no drawn asset.
- Menu themes unlock on 3, 10 and 25 complete sets, any kind, instead of gold on 3, 10 and 25 sets.
- The visual (tier colours, marks, celebration intensity) goes to `bmad-ux` on the rule set here.

**Evidence.**
- `Catalog::Themes::TIER_PERCENTS = { "bronze" => 10, "silver" => 25, "gold" => 50 }` and `Catalog::Themes.tiers`, called only for themes and hall of fame; franchise, studio and UFO sets get `{ "complete" => size }`.
- `Catalog::SetTier::TIERS = %w[bronze silver gold complete]`, and the same four names in three check constraints: `catalog_set_tiers_tier_check`, `game_set_tiers_tier_check`, `game_feed_entries_tier_check`.
- `Game::SetStanding#thresholds` orders tiers by that constant; `#tiered?` tests for a `bronze` key.
- `app/frontend/lib/celebration.ts` types `SetTierName` as the four names; locales hold `bronze`, `silver`, `gold` in the album, celebration, feed and help.

## 2. Impact analysis

### Checklist

| Item | Status | Finding |
|---|---|---|
| 1.1 Trigger | [x] | The author's table, not a story. |
| 1.2 Problem | [x] | New requirement from the product owner. |
| 1.3 Evidence | [x] | Above. |
| 2.1 Current epic | [x] | Sets players recognize (built, not closed) can take the change as new entries. |
| 2.2 Epic changes | [!] | Three new entries in Sets players recognize; Cosmetics rescoped. |
| 2.3 Future epics | [!] | Cosmetics (back, titles, menu themes), Seasons carry over (tiers to win back). |
| 2.4 Obsolete / new | [x] | No epic made obsolete, none new. |
| 2.5 Order | [!] | The new entries go before the next season is published on staging, and before Cosmetics. |
| 3.1 Spec | [!] | `catalog-and-rarity.md` (kinds, Tiers, Rewards), CAP-6, CAP-7, CAP-22. |
| 3.2 Architecture | [!] | Set constants, the tier rule, the tier pass and its events, card backs, titles and menu themes. |
| 3.3 UX | [!] | Tier tokens and marks, the album gauge, the set celebration and its folded line, the copy deck, the card back's earning line, the worked example. |
| 3.4 Other | [!] | Three check constraints widened (expand/contract). The help page's tier sentence. No CI or infrastructure change. |
| 4.1 Direct adjustment | Viable | Three entries in an open epic and a rescope of a backlog epic. Effort medium, risk low-medium. |
| 4.2 Rollback | Not viable | Nothing built is wrong for published seasons; their rows stay. |
| 4.3 MVP review | N/A | The MVP keeps tiered sets; only the cut changes. |
| 4.4 Path | [x] | Direct adjustment. |

### Epic impact

| Epic | State | Impact |
|---|---|---|
| Sets players recognize | built, not closed | Gains three entries: the tier marks designed, the tiers cut by set size, the marks, album and celebration rebuilt. Its built tier pass, feed and celebration keep working on published seasons. |
| Cosmetics: card backs, titles and menu themes | backlog | Done when 2, 5 and 6 rescoped: the back tier, titles per tier of any set, menu themes on complete sets. |
| Seasons carry over | in progress (redraw done) | R2 and Done when 3 gain one line: a tier is identified by its set and name; an earlier season's bronze, silver or gold stays as history and is never listed to win back. |
| The Brotherhood | built | Achievements count complete sets: unchanged, every set still has a complete row. |

### Technical impact

- `Catalog`: one tier table by set size replacing `TIER_PERCENTS`, applied to every kind in `SetBuilder`; `SetTier::TIERS` accepts both families (bronze, silver, gold for published seasons; alpha to epsilon from the next one; complete for both). `catalog_set_tiers_tier_check` widened.
- `Game`: `game_set_tiers_tier_check` and `game_feed_entries_tier_check` widened; `SetStanding` orders a set's tiers by required count, not by name, and a set is tiered when it has any tier below complete; every tier but complete publishes `Game::SetTierReached`; the feed and the celebration rank results by the share of the set a tier stands for, complete highest.
- Web: tier names and marks in the album, set rows, celebration, feed and help, in English and French; the album gauge holds one to six cells.
- Staging: nothing rebuilt; the next published season is cut by the new table.

## 3. Recommended approach

**Direct adjustment.** The change lands as three entries in Sets players recognize, which is built but not closed and already owns tiers, the album and the celebration. Cosmetics is still backlog, so its rescope costs a few edited lines.

- The tiers are cut at publication and frozen with the season, so published seasons need no migration of rows, only checks that accept the new names.
- Greek names say nothing about a share by themselves, so no code orders tiers by name: a set's tiers are ordered by required count, and results across sets by share.
- The visual is designed before it is built, as the first tier banner was (designed, then rebuilt).

**Alternatives considered.** Renaming the published rows to Greek letters (rewrites frozen history and the feed's past lines, for nothing a player asked). Keeping bronze, silver and gold and adding a fourth and fifth metal (the author chose Greek letters; metals run out at six).

**Effort.** Medium: one design session and two builds. **Risk.** Low-medium: the tier name is matched on in a few places (`tiered?`, the celebration's types, the feed's check); the review should search for every literal. **Timeline.** The next season published on staging waits for the second and third entries.

## 4. Detailed change proposals

### 4.1 Spec — `spec-gameble/catalog-and-rarity.md`

**Sets, kinds.** Drop the trailing `Tiered.` from the Themes and Hall of fame bullets (every kind is tiered now).

**Tiers.**

OLD:
```
**Tiers.** Theme and hall of fame sets have bronze (10 %), silver (25 %) and gold (50 %) of their distinct cards; at the published odds, 100 % would need every Légendaire of the set, which packs alone never give. Percentages tuned in playtests. Franchise, studio and UFO sets are complete or not.
```
NEW:
```
**Tiers.** Every set is tiered by its number of distinct cards when the season is published (author, 2026-10-18; supersedes bronze 10 %, silver 25 %, gold 50 % for themes and hall of fame only):

| Distinct cards | Tiers before completion | Then |
|---|---|---|
| 3–4 | none | complete (100 %) |
| 5–9 | alpha 50 % | complete |
| 10–19 | alpha ⅓, beta ⅔ | complete |
| 20–59 | alpha 25 %, beta 50 %, gamma 75 % | complete |
| 60–199 | alpha 10 %, beta 25 %, gamma 50 %, delta 75 % | complete |
| 200 and more | alpha 10 %, beta 25 %, gamma 50 %, delta 75 %, epsilon 90 % | complete |

Each tier needs that share of the set's distinct cards, rounded up. A tier's name gives its rank in its set, not a share: gamma is 75 % of a 30-card set and 50 % of a 100-card one. At the published odds, completing a large set needs every Légendaire of it, which packs alone never give. Seasons published before 2026-10-18 keep their bronze, silver, gold and complete tiers.
```

**Rewards.**

OLD:
```
**Rewards.** Bronze and silver: a celebration at opening and a feed line. Gold: also that set's card back. Complete, for every kind (a theme or hall of fame set completes at 100 %, after gold): a celebration, a "complete" stamp on the album and a feed line. The tiers and completions one opening reaches make one feed line, naming the highest. Profile titles and menu themes: CAP-22 of the spec.
```
NEW:
```
**Rewards.** Every tier: a celebration at opening and a feed line. A theme or hall of fame set's first tier at or above 50 % of its cards (its back tier: gamma from 60 cards, beta from 20 to 59, beta ⅔ from 10 to 19, alpha from 5 to 9, completion below; gold in earlier seasons) also unlocks that set's card back. Complete: also a "complete" stamp on the album. The tiers and completions one opening reaches make one feed line, naming the highest, ranked by the share of its set the tier stands for. Profile titles and menu themes: CAP-22 of the spec.
```

### 4.2 Spec — `spec-gameble/spec-gameble.md`

**CAP-6**, success.

OLD: `- Theme and hall of fame sets have three tiers (bronze, silver, gold); franchise, studio and UFO sets are only complete or not.`
NEW: `- Every set has one to five tiers before completion, named alpha to epsilon, more for a larger set (table in catalog-and-rarity.md); a set of 3 or 4 cards is only complete or not.`

**CAP-7**, success, second line.

OLD: `- More are unlocked by reaching gold on a theme or hall of fame set (one back per such set), …`
NEW: `- More are unlocked by reaching a theme or hall of fame set's back tier, its first tier at or above half its cards (one back per such set), …` (rest unchanged)

**CAP-22**, success.

OLD: `- Completing a franchise, studio or UFO set, and each tier of a theme or hall of fame set, unlocks a profile title built from one template per kind that needs no grammatical agreement ("Complétiste · Dark Souls"; Apprenti, Adepte, Maître for tiers). A title is earned once per set and tier, whatever the seasons; it shows the latest season it was earned in.`
NEW: `- Each tier of a set and its completion unlock a profile title built from a template that needs no grammatical agreement: the tier's letter for a tier ("Gamma · Roguelike"), "Complétiste" for completion ("Complétiste · Dark Souls"). Titles earned on bronze, silver or gold in an earlier season keep Apprenti, Adepte and Maître. A title is earned once per set and tier, whatever the seasons; it shows the latest season it was earned in.`

OLD: `- Reaching gold on 3, 10 and 25 sets unlocks a menu theme each: …`
NEW: `- Completing 3, 10 and 25 sets, of any kind, unlocks a menu theme each: …` (rest unchanged)

Rationale: the author's decisions above. The title template for Greek tiers is this proposal's recommendation; the author confirms or changes it at approval.

### 4.3 Architecture — `architecture-gameble/architecture-gameble.md`

**Set constants.** `tier shares` → `the tier table by set size`.

**Tiers.**

OLD:
```
  - Tiers: `theme` and `hall_of_fame` sets have `bronze`, `silver` and `gold`; the other kinds have only `complete`; `gold` and `complete` complete the set. `PublishSeason` writes each set's tiers as rows (set, tier, distinct cards required, rounded up from the shares); …
```
NEW:
```
  - Tiers: every set is tiered by its distinct card count at publication, from the table in `Catalog` (`catalog-and-rarity.md`): zero to five tiers named `alpha` to `epsilon` in order, then `complete` at 100 %. Seasons published before the table keep `bronze`, `silver`, `gold` and `complete`; the tier checks accept both families and no row is renamed. A tier name gives a rank within its set, never a share: readers order a set's tiers by required count, and rank tiers of different sets by required count over the set's cards. `PublishSeason` writes each set's tiers as rows (set, tier, distinct cards required, rounded up from the shares); …
```
(rest unchanged)

**Tier pass rule.**

OLD: `Each new row publishes exactly one event: `bronze`, `silver` or `gold` publishes `Game::SetTierReached`, `complete` publishes `Game::SetCompleted`. A tiered set has a `complete` row too, at 100 % of its cards, after `gold` at 50 %.`
NEW: `Each new row publishes exactly one event: `complete` publishes `Game::SetCompleted`, any other tier `Game::SetTierReached`. Every set has a `complete` row, at 100 % of its cards, after its other tiers.`

**Card backs.**

OLD: `A set's back unlocks on gold on that set, once; the seasons it was earned in are read from the player's `gold` tier rows of that set, …`
NEW: `A set's back unlocks on that set's back tier, once: in each season, the first of the set's tiers whose required count is at least half its distinct cards (`gold` in seasons published before the table). The seasons it was earned in are read from the player's rows of that tier of that set, …`

**Titles and menu themes.**

OLD: `…; a menu theme when the player's distinct set kinds and keys with a `gold` row reach its count.`
NEW: `…; a menu theme when the player's distinct set kinds and keys with a `complete` row reach its count.`

**New rule (data).** The three tier checks (`catalog_set_tiers`, `game_set_tiers`, `game_feed_entries`) are widened expand/contract: the wider check added unvalidated, validated in a second migration, then the narrow one dropped.

### 4.4 UX — `ux-gameble/DESIGN.md` (rules for `bmad-ux` to draw)

- **Tier tokens and marks:** a mark for each of alpha to epsilon, the Greek letter as the shape (α β γ δ ε), never colour alone, legible in greyscale at the row's size; the bronze, silver and gold marks stay for earlier seasons' tiers (feed history, allocation recap, titles).
- **Set album:** the gauge has one cell per tier before completion (zero to five), each with its threshold in cards, then the COMPLET stamp; a 3- or 4-card set shows only the stamp.
- **Set celebration:** the ribbon names the tier ("PALIER GAMMA"); the juice rises with the tier's rank in its set, the back tier at least at today's gold level; the folded line shows the reached tiers' marks, not a fixed bronze/silver/gold row.

### 4.5 UX — `ux-gameble/EXPERIENCE.md`

- Copy deck, Capsule live region: `"Palier argent atteint : Roguelike, 16 cartes sur 62."` → `"Palier bêta atteint : Roguelike, 16 cartes sur 62."`; `"Palier or atteint : Roguelike, 31 cartes sur 62."` → `"Palier gamma atteint : Roguelike, 31 cartes sur 62."`
- Copy deck, Collection: tiers `"BRONZE", "ARGENT", "OR", "COMPLET"` → `"ALPHA", "BÊTA", "GAMMA", "DELTA", "EPSILON", "COMPLET"`, earlier seasons' `"BRONZE", "ARGENT", "OR"` kept.
- Copy deck, Set celebration: ribbons `"PALIER ALPHA"` to `"PALIER EPSILON"`, `"SET COMPLET"` (`"ALPHA TIER"` … `"SET COMPLETE"`).
- Card backs, Earning: `gold on a theme or hall of fame set (that set's back)` → `the back tier of a theme or hall of fame set, its first tier at or above half its cards (that set's back)`.
- Accessibility, set celebration: the example name follows the live region's.
- Worked example (Inès): `"PALIER OR · Roguelike 31/62" plays; the album shows OR lit.` → `"PALIER GAMMA · Roguelike 31/62" plays; the album shows GAMMA lit, and Roguelike's back unlocks.` (62 cards: alpha 7, beta 16, gamma 31, delta 47, complete 62.)
- Copy for the help page's tier sentence: the table in plain words, in place of "bronze at 10 %, silver at 25 %, gold at 50 %".

### 4.6 Epics and entries (for `bmad-ticket`)

**Sets players recognize** gains three entries, in this order:

1. **Greek tier marks designed** (`bmad-ux`): sections 4.4 and 4.5, with a mock of the album gauge at 1, 3 and 5 tiers and of the celebration at alpha, the back tier and complete.
2. **Set tiers cut by the set's size**: the tier table in `Catalog` for every kind; both tier families accepted in the model and the three checks (expand/contract); tiers ordered by required count in `SetStanding`, the feed and the celebration; `Game::SetTierReached` for any tier but complete; tier names in `en.yml` and `fr.yml`; the help page's tier sentence. Done when: a season published in a test cuts a 3-, 7-, 12-, 40-, 100- and 250-card set into 1 to 6 tiers with the rounded-up counts; a published season's bronze, silver and gold rows still read, celebrate and show in the feed unchanged.
3. **Tier marks, album and celebration rebuilt for Greek tiers**: after 1 and 2; builds the design.

The next season published on staging waits for entries 2 and 3.

**Cosmetics: card backs, titles and menu themes**
- Done when 2: `Reaching gold on a theme or hall of fame set, …` → `Reaching a theme or hall of fame set's back tier (its first tier at or above half its cards; gold in earlier seasons), …`
- Done when 5: `Completing a franchise, studio or UFO set and each tier of a tiered set unlock a profile title; …` → `Each tier and the completion of any set unlock a profile title; …`
- Done when 6: `Reaching gold on 3, 10 and 25 sets unlocks a menu theme; …` → `Completing 3, 10 and 25 sets unlocks a menu theme; …`
- `after` link on Sets players recognize: needs also "the tier table by set size".

**Seasons carry over**: R2 and Done when 3 gain `A tier is identified by its set and its name; bronze, silver and gold earned in earlier seasons stay as history and are never listed to win back.`

**Initiative** Notes: `Decision (2026-10-18, author): set tiers cut by set size for every kind, alpha to epsilon then complete, from the next published season (change-set-tiers-by-size).`

## 5. Implementation handoff

**Scope: moderate.** Three entries in an open epic and a backlog rescope; no MVP goal changes; targeted spec, architecture and UX edits.

| Who | Does what |
|---|---|
| Author (product owner) | Approves this proposal; confirms the title template for Greek tiers (4.2, CAP-22). |
| `bmad-spec` / `bmad-architecture` | Apply 4.1 to 4.3 as written. |
| `bmad-ux` | Applies 4.4 and 4.5 and draws the marks, the gauge and the celebration (entry 1). |
| `bmad-ticket` | Adds the three entries to Sets players recognize, rescopes Cosmetics and Seasons carry over, adds the initiative note. |
| `bmad-build` | Builds entries 2 and 3. |

**Success criteria**
1. A season published after the change gives every set its tiers from the table: 3- and 4-card sets completion only, 200-card and larger sets six steps.
2. Every required count is the share rounded up.
3. Tiers earned in published seasons still show, celebrate in their history and appear in the feed as bronze, silver and gold.
4. No code orders tiers by name; a set's tiers read in order of required count.
5. The album, celebration, feed and help name the Greek tiers in English and French, with a mark that never relies on colour alone.

## Approval and handoff log

- 2026-10-19: approved by the author as written, with one change to CAP-22's title template (section 4.2): titles keep named ranks, one per tier ("Adepte · Roguelike"), and "Complétiste" for completion ("Complétiste · Dark Souls"); titles earned on bronze, silver or gold in earlier seasons keep Apprenti, Adepte and Maître. Every other author decision of section 1 stands. Scope: moderate; routed to the product owner and the developer for the backlog changes, with the document edits applied directly.
- 2026-10-19: second author decision, overriding the proposal: no Greek letters. The tiers before completion are named by the ranks themselves, in order Novice, Apprenti, Adepte, Expert, Maître (English Novice, Apprentice, Adept, Expert, Master; stored keys `novice`, `apprentice`, `adept`, `expert`, `master`), then complete; a 30-card set has Novice 25 %, Apprenti 50 %, Adepte 75 %, then complete. A tier's title is its rank ("Adepte · Roguelike"). No α β γ δ ε mark anywhere: the design entry draws one mark per rank, never colour alone, legible in greyscale. Ribbons read "PALIER ADEPTE". Earlier seasons' bronze, silver and gold, and their titles Apprenti, Adepte and Maître, are unchanged. Every section below was applied with the ranks in place of alpha to epsilon.
- 2026-10-19: sections 4.1 and 4.2 applied: `catalog-and-rarity.md` (Themes and Hall of fame lose "Tiered.", Tiers table by set size with the rank names, Rewards with the back tier); `spec-gameble.md` CAP-6, CAP-22 (rank titles, menu themes on complete sets) and the card backs line, which is CAP-20, not CAP-7 as section 4.2 says; the CAP-20 open question names the back tier. Recorded in the spec's `.memlog.md`.
- 2026-10-19: section 4.3 applied to `architecture-gameble.md`: AD-5 (the tier table by set size; both tier families; order by required count; the three tier checks widened expand/contract, as a new AD-5 rule), AD-10 (one event per row, complete or any other tier), AD-25 (the back tier; titles rendered from the rank, Complétiste, or Apprenti, Adepte, Maître for bronze, silver, gold; menu themes on `complete` rows); Deferred lines follow. Recorded in the architecture's `.memlog.md`.
- 2026-10-19: sections 4.4 and 4.5 applied as rules and copy only: `DESIGN.md` (ranked tiers rule over Set celebration, the ribbon example, ticks at the set's own thresholds, the folded line showing reached marks, Set progress row, Tier marks, Set album, set backs); `EXPERIENCE.md` (live region, Collection and Set celebration copy in fr and en, a "Comment ça marche, tiers" row with the table in plain words, feed lines naming the rank, picker and locked back examples, state rows, folded line motion, card back earning, accessibility example, the worked example with Novice 7, Apprenti 16, Adepte 31, Expert 47, complete 62). Nothing drawn: the marks, colours and juice by rank are entry 13.21. Recorded in the UX `.memlog.md`.
- 2026-10-19: section 4.6 applied: epic-recognizable-sets gains entries 21 "Rank tier marks designed" (hitl), 22 "Set tiers cut by the set's size" and 23 "Rank marks, album and celebration rebuilt for ranked tiers", all three in the refactor sweep's `after`; its R5 and Notes record the change. epic-card-backs Done when 2, 5 and 6 amended and its initiative `after` on epic 13 needs also the tier table by set size (13.22); epic-seasons-carry-over R2 and Done when 3 gain the history line; `initiative-gameble.md` gains the note. Every section of the proposal is now applied; next are entries 13.21, then 13.22 and 13.23, before the next season is published on staging.
- 2026-10-19: third author decision: titles merge across tier families. Bronze, silver and gold from earlier seasons give the same titles as the Apprenti, Adepte and Maître tiers (`bronze` counts as `apprentice`, `silver` as `adept`, `gold` as `master`): one title per set and rank, earned by either. Applied to `spec-gameble.md` CAP-22, `architecture-gameble.md` AD-25 and `epic-card-backs.md`'s note.
