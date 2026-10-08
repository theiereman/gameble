---
type: change-proposal
title: "Sets players recognize"
date: 2026-10-08
trigger: _bmad-output/initiative-gameble/forge-card-series/forge-card-series.md
mode: batch
scope: moderate
status: approved
approved: 2026-10-08, by the author, unconditionally
---

# Sprint Change Proposal: sets players recognize

## 1. Issue summary

**Problem.** Tomes (a genre cut into volumes of about thirty games by release date) mean nothing to a player: "Plateforme · vol. 7" cannot be recognized, so nobody feels they are completing it. The collection's set list (kind chips, then a paginated list of set rows) is unreadable, and nobody browses it to see what they are completing. Publisher sets and "best rated of the year" do not fix this.

**Type.** A new requirement from the product owner, after an approach that did not work (tomes).

**How it was found.** The author, playing on staging (2026-10-08), then the forge session `forge-card-series` (hardened), which is the source of every decision below.

**Evidence.**
- `Catalog::SetBuilder` builds three kinds: publisher (5+ games), tome (genre split into volumes of ~30), best of year (top 10). A genre of 900 games gives 30 tomes nobody can tell apart.
- `library/_set_list.html.erb`: kind chips, a "whole season" row, then a paginated list of set rows. Most rows read 0/n.
- The spec lists "Sets built from Steam store tags" as a non-goal; themes are exactly that.

## 2. Impact analysis

### Checklist

| Item | Status | Finding |
|---|---|---|
| 1.1 Trigger | [x] | The forge, not a story; the author's own play on staging. |
| 1.2 Problem | [x] | New requirement after a failed approach. |
| 1.3 Evidence | [x] | Above. |
| 2.1 Current epic | [x] | The Brotherhood (in progress) can finish; its built set completion keeps working on the new sets. |
| 2.2 Epic changes | [!] | One new epic; Season preparation and Card backs rescoped. |
| 2.3 Future epics | [!] | Brotherhood backlog (ticker, achievements), Season preparation, Card backs, Readable codebase. |
| 2.4 Obsolete / new | [!] | Season preparation story 2 (tome genre curation) is obsolete as written. New epic needed. |
| 2.5 Order | [!] | The new epic goes before the public launch and before Season preparation. |
| 3.1 Spec | [!] | CAP-6, CAP-7, CAP-13, CAP-20, new CAP-22, non-goals, open questions; `catalog-and-rarity.md`; `later-roadmap.md`. |
| 3.2 Architecture | [!] | AD-5, AD-10, AD-25, the data model. |
| 3.3 UX | [!] | Hub, Collection, the new album page, ticker, card backs, profile. |
| 3.4 Other | [x] | No deployment, CI or infrastructure change. Staging season 1 gets its sets rebuilt once. |
| 4.1 Direct adjustment | Viable | A new epic, two rescoped epics, no MVP goal dropped. Effort medium-high, risk medium. |
| 4.2 Rollback | Not viable | Nothing is gained by reverting: the set code is replaced, not undone; the filtered grid built on 2026-10-07 is kept. |
| 4.3 MVP review | Partly | Sets stay in the MVP; profile titles and menu themes join the post-launch Card backs epic. |
| 4.4 Path | [x] | Hybrid: direct adjustment for sets and the collection, cosmetics post-launch. |

### Epic impact

| Epic | State | Impact |
|---|---|---|
| Steam catalog | done | Its set kinds are replaced; the import also keeps developers and franchises. Reopened through the new epic, not edited. |
| Collection and sharing | done | Its set library and tome slots are replaced by the new epic. |
| Space terminal: screens | done | "Collection opens on owned cards" (author, 2026-10-07) is **superseded**: the collection opens on sets; the filtered grid built then becomes the secondary view. |
| The Brotherhood | in progress | Built "First discoveries and set completion" keeps its `Game::SetCompleted`. Backlog: the ticker (story 4) shows set completions and tiers; achievements (10, 11) may count sets and tiers. |
| Season preparation | backlog | Story 2 rescoped from "tag-to-tome-genre curation" to "theme list curation". Comes after the new epic. |
| Card backs | backlog, post-launch | Unlock rule becomes "gold on a theme or hall of fame set"; gains profile titles and menu themes. |
| Readable codebase | backlog | Gains the new epic as a dependency. |

### Technical impact

- `Catalog`: new set kinds and builder, theme list with French and English labels in code, card genre from its top theme, `catalog_sets` kind check (expand/contract).
- `Steam`: developers and franchises read from the raw item already stored in `steam_apps.details` (to confirm), kept on the card.
- `Game`: tier rows and a tier event beside the set completion; celebration in the opening response.
- Web: the collection's entry screen, the album page, the hub panel, the filter zone's set group.
- Staging: season 1's sets rebuilt once; old set completions dropped. Nothing in production yet.

## 3. Recommended approach

**Hybrid: direct adjustment now, cosmetics after launch.**
- One new epic, **Sets players recognize**, placed before the public launch: the sets, the tiers and the collection. Changing sets after launch would break published memberships and players' completions; now it costs one rebuild on staging.
- Profile titles and menu themes join the post-launch **Card backs** epic, renamed **Cosmetics**, where the card back unlocks also move to gold tiers. They need the tier events but nothing else, and the MVP does not need them.
- The term stays **set** everywhere (code, spec, UI "SETS"); the forge's "series" is a set.

**Alternatives considered.** Rollback (no gain, see 4.2). Postponing everything after launch (players would complete sets that then disappear). Building cosmetics in the MVP (more scope before launch for a reward the MVP does not need).

**Effort.** Medium-high: about seven stories plus a spike and the refactor sweep. **Risk.** Medium: the data may not cooperate (dirty franchise field, too many UFOs); the spike comes first to find out. **Timeline.** Adds one epic before launch; Season preparation moves after it.

## 4. Detailed change proposals

### 4.1 Spec — `spec-gameble/spec-gameble.md`

**CAP-6**

OLD:
```
- **intent:** A player can browse their collection by set, see their progress in each set, and see which cards are missing.
- **success:**
  - The sets are those defined in `catalog-and-rarity.md`: publisher sets, tomes and "best rated of the year" sets.
  - Each set shows owned / total distinct cards. A card in several sets counts in each. Duplicates are counted per card.
  - An empty slot names the missing game.
```
NEW:
```
- **intent:** A player sees at a glance which sets they are completing, opens one as an album, and sees which cards are missing.
- **success:**
  - The sets are those defined in `catalog-and-rarity.md`: themes, franchises, studios, hall of fame sets and the UFOs. Every card belongs to at least one set.
  - The collection opens on the player's sets in progress, sorted by closeness to their next tier or completion, then a short "to discover" row, then a search over every set.
  - A set opens as an album: owned cards, an empty slot naming each missing game, and its tiers or its completion.
  - Each set shows owned / total distinct cards. A card in several sets counts in each. Duplicates are counted per card.
  - Theme and hall of fame sets have three tiers (bronze, silver, gold); franchise, studio and UFO sets are only complete or not.
  - The grid of every card, with its filters and search, stays reachable from the collection.
```
Rationale: the forge's locked decisions on families, entry screen, album and tiers.

**CAP-7** — success line on the face.

OLD: `- The card face shows the title, publisher, cover, genre, release year, rarity (shape and name) and card number, and no stats.`
NEW: `- The card face shows the title, publisher, cover, genre (its main theme), release year, rarity (shape and name) and card number, and no stats.`
Rationale: tomes gave the genre; themes now do.

**CAP-13** — success, first line.

OLD: `- The feed shows notable pulls, first discoveries of a card, trades and reposts (CAP-19).`
NEW: `- The feed shows notable pulls, first discoveries of a card, trades, reposts (CAP-19), set completions and set tiers reached.`
Rationale: tier rewards are a celebration and a feed line; this also settles the open question "Feed and ticker".

**CAP-20** — success, second line.

OLD: `- More are unlocked by completing a set, contributing to a successful weekly goal, some achievements, and events or seasons. A locked back states its unlock condition.`
NEW: `- More are unlocked by reaching gold on a theme or hall of fame set (one back per such set), contributing to a successful weekly goal, some achievements, and events or seasons. A locked back states its unlock condition.`
Rationale: one back per completed set would mean hundreds of backs with franchises and studios.

**New CAP-22**, after CAP-21:
```
- **CAP-22**
  - **intent:** A player shows their collecting through a profile title and dresses their menus with a rare theme.
  - **success:**
    - Completing a franchise, studio or UFO set, and each tier of a theme or hall of fame set, unlocks a profile title built from one template per kind that needs no grammatical agreement ("Complétiste · Dark Souls"; Apprenti, Adepte, Maître for tiers).
    - The player picks one active title; it shows on their profile, in the feed and in trades.
    - Reaching gold on 3, 10 and 25 sets unlocks a menu theme each: an accent colour applied to the interface, with contrast checked. Only the player sees it.
```
Rationale: the forge's reward locks; scheduled with card backs, after launch.

**Non-goals** — remove: `- Sets built from Steam store tags (later).`

**Open questions**
- Remove "Tome genres, neighbours (CAP-6)".
- "Tag labels" → `**Theme labels:** theme names are curated in French and English with the theme list; other tags are never shown.`
- "Feed and ticker (CAP-13)" → remove (settled above).
- Add: `**Sets on real data (CAP-6):** the minimum size of franchise and studio sets, the reliability of Steam's franchise field, the hall of fame thresholds and the tier percentages are set on staging data; the UFOs stay under about 5 % of the catalog, else the theme list changes.`

### 4.2 Spec — `spec-gameble/catalog-and-rarity.md`

**Card identity, Genre**

OLD: `- **Genre:** the genre of the game's tome (see Sets), shown on the card. The Web API gives no store genres, so the genre comes from the tags. A game in no tome shows no genre.`
NEW: `- **Genre:** the name of the game's main theme (see Sets): the listed theme with the most votes among its 5 most-voted tags. A game in the UFOs shows no genre.`

**Card identity** — add after Tags:
`- **Developers and franchises:** imported with each game from GetItems' basic info, as Steam names them.`

**Sets** — replace the whole section:
```
## Sets

Every card belongs to at least one set; a card can belong to several. A set exists only if a player recognizes it from its name. Five kinds:

- **Themes:** a curated list of about thirty Steam tags kept in code with French and English names (e.g. Souls-like, Metroidvania, Roguelike, Deckbuilder, Cosy, Horror, Zombies, Pirates, Space, Cyberpunk). A game joins every listed theme among its 5 most-voted tags. Broad tags (Action, Adventure, Casual, Indie) are never themes. Tiered.
- **Franchises:** one set per Steam franchise with at least N games in the catalog (N set on real data, 2 or 3).
- **Studios:** one set per developer with at least N games in the catalog. Replaces publisher sets.
- **Hall of fame:** sets drawn from review stats, thresholds set on real data: Les Intouchables (very high score, very many reviews), Les Pépites (very high score, few reviews), Les Mal-aimés (mixed score, very many reviews), Les Phénomènes (the most reviewed). Tiered.
- **The UFOs (Les OVNI):** every game with no listed theme among its 5 most-voted tags. Kept under about 5 % of the catalog by tuning the theme list, never by changing the rule.

**Tiers.** Theme and hall of fame sets have bronze (25 %), silver (50 %) and gold (100 %) of their distinct cards; percentages tuned in playtests. Franchise, studio and UFO sets are complete or not.

**Rewards.** Bronze and silver: a celebration at opening and a feed line. Gold: that set's card back. Complete (franchise, studio, UFOs): a "complete" stamp on the album and a feed line. Profile titles and menu themes: CAP-22.

Tomes, publisher sets and "best rated of the year" sets are retired.
```

### 4.3 Spec — `spec-gameble/later-roadmap.md`

Remove: `- **Sets from Steam store tags.**`

### 4.4 Architecture — `architecture-gameble/architecture-gameble.md`

**AD-5**, third rule.

OLD: `- Rarity, number and set memberships belong to the card-season and never change after publication. A card's genre in a season is the genre of its tome in that season; a card in no tome shows no genre.`
NEW: `- Rarity, number and set memberships belong to the card-season and never change after publication. A card's genre in a season is its main theme in that season; a card in the UFOs shows no genre. A season published with the retired set kinds gets its sets rebuilt once, before the public launch, and its set completions are dropped.`
Rationale: follows the precedent of numbers given once to an older season.

**AD-10**, second rule.

OLD: `- An operation that raises a player's quantities then publishes one `Game::SetCompleted` per set that player completes for the first time, decided by inserting a set-completion row (unique per player and set) with `ON CONFLICT DO NOTHING`.`
NEW: `- An operation that raises a player's quantities then publishes one `Game::SetTierReached` per tier of a tiered set that player reaches for the first time, and one `Game::SetCompleted` per set completed for the first time (gold for a tiered set), each decided by inserting a row unique per player, set and tier with `ON CONFLICT DO NOTHING`.`

**AD-25**, third rule — add: `The unlock rule of a set's back is gold on that set.` Add a sentence to the AD's scope: `Profile titles and menu themes follow the same rules: catalogues in code, unlock rows per player, one active choice on `game_player_states`, granted only by handlers.`

**Data model** — replace `ACCOUNTS_PLAYER ||--o{ GAME_SET_COMPLETION : completes` with `ACCOUNTS_PLAYER ||--o{ GAME_SET_TIER : reaches`; `CATALOG_SET` gains its kind (theme, franchise, studio, hall_of_fame, ufo).

**CAP map** — CAP-6 row unchanged; add `CAP-22 Titles and menu themes | Game | AD-10, AD-25`.

### 4.5 UX — `ux-gameble/EXPERIENCE.md`

- **Hub content (line 52):** `"PROGRESSION DES SETS" (four set progress rows, "TOUT VOIR ▸")` → `"SETS EN COURS" (the player's four sets closest to their next tier, "TOUT VOIR ▸" opening the collection)`.
- **Hub, Set progress row:** → `Opens that set's album.`
- **Hub, LIVE ticker:** `set completions` → `set completions and set tiers reached`.
- **Collection opening (author, 2026-10-07):** replaced by: `Collection opening (author, 2026-10-08, supersedes 2026-10-07): opens on "EN COURS" (the player's sets sorted by closeness to their next tier or completion, plus those they just progressed in), then "À DÉCOUVRIR" (a few sets the player's latest cards touched without progress yet, or popular ones for a new player), then a search over every set. "TOUTES LES CARTES ▸" opens the card grid with the filter zone and the search.`
- **New row, Set album:** `The set's name, kind, owned / total and its tiers (bronze, silver, gold) or its "COMPLET" stamp; its cards in set order, owned cards face up, missing ones as missing-card slots. Opens a card's detail.`
- **Filter zone:** the set group lists set kinds then sets by search, not every set as chips.
- **Booster:** add `Set celebration: a tier reached or a set completed at opening shows a banner after the reveal, announced in the booster live region.`
- **Card backs:** `("Compléter le set Roguelite · vol. 1")` → `("Atteindre l'or du set Roguelike")`; earning: `completing a set` → `reaching gold on a theme or hall of fame set`.
- **Profil et paramètres:** add `Title picker and theme picker, as the back picker (post-launch, CAP-22).`

### 4.6 UX — `ux-gameble/DESIGN.md`

- **Collection, Set progress row:** `The same component lists sets on the hub ("PROGRESSION DES SETS", four sets, "TOUT VOIR ▸")` → `The same component lists the hub's "SETS EN COURS" and the collection's "EN COURS" and "À DÉCOUVRIR"; a tiered set's bar carries bronze, silver and gold marks at its thresholds.`
- **New, Set album:** header with name, kind label, owned / total and tier marks; the card grid in set order with missing-card slots; a "COMPLET" stamp for a completed set. Visual spec to draw with `bmad-ux` before the story.
- **Feed entry:** add the set tier and set completion entries.
- **Card backs / Profile:** title and theme pickers, post-launch.

### 4.7 Epics and stories

**New epic: "Sets players recognize"** (covers CAP-6, CAP-7, CAP-13; after Steam catalog, Space terminal: screens, Brotherhood story 7; before Ready for the public's remaining stories and Season preparation)

1. **Spike: sets on real data.** On staging's import: confirm developers and franchises are in `steam_apps.details`; count games per franchise and studio; draft the theme list and measure the UFOs' share; propose hall of fame thresholds. Output: the numbers the next stories need.
2. **The import keeps developers and franchises**, read from the stored raw item, without a new import.
3. **New set kinds**: themes (top-5 rule, list with labels in code), UFOs, franchises, studios, hall of fame; retire tomes, publishers and best of year; card genre from the main theme; staging season 1 rebuilt once.
4. **Tiers and celebrations**: tier rows, `Game::SetTierReached`, the opening's celebration banner, feed and ticker lines for tiers and completions.
5. **The collection opens on sets**: "EN COURS", "À DÉCOUVRIR", search over sets; the hub's "SETS EN COURS".
6. **The set album**: the album page, tier marks, "COMPLET" stamp, public and friends' profile views of it.
7. **The card grid as the secondary view**: "TOUTES LES CARTES", its set filter by kind and search.
8. **Refactor sweep.**

**Season preparation**, story 2.

OLD: `An administrator curates the tome genres in the back-office before publishing`
NEW: `An administrator curates the theme list in the back-office before publishing` — every Steam tag met listed with its game count; the administrator marks a tag as a theme (with French and English names) or not; the preview shows each theme's size and the UFOs' share; publishing is refused while the UFOs exceed the agreed share. Done-when 2 and 3 of the epic change the same way; its `after` gains the new epic.

**Card backs → "Cosmetics: card backs, titles and menu themes"** (CAP-20, CAP-22, post-launch)
- Done when 2: `Completing a set, …` → `Reaching gold on a theme or hall of fame set, contributing to a successful weekly goal and the listed achievements unlock their backs, once each.`
- Add: `Completing a franchise, studio or UFO set and each tier of a tiered set unlock a profile title; one active title shows on the profile, in the feed and in trades.`
- Add: `Reaching gold on 3, 10 and 25 sets unlocks a menu theme; the player picks one; contrast is checked for each.`
- `after` gains the new epic.

**The Brotherhood**: story 4 (live broadcasts and the ticker) shows set tiers and completions; achievements (stories 10, 11) may use them. No built story changes.

**Readable codebase**: `after` gains the new epic.

**Initiative**: covers CAP-22; a Notes entry: `Decision (2026-10-08, author): sets players recognize replace tomes, publisher and best-of-year sets before launch (change-recognizable-sets); cosmetics after launch.`

## 5. Implementation handoff

**Scope: moderate.** A backlog reorganization with one new epic; no MVP goal dropped; the spec, architecture and UX get targeted edits.

| Who | Does what |
|---|---|
| Author (product owner) | Approves this proposal; settles the spike's numbers (franchise and studio minimum, hall of fame thresholds, tier percentages, theme list). |
| `bmad-spec` / `bmad-architecture` | Apply 4.1 to 4.4 as written. |
| `bmad-ux` | Applies 4.5 and 4.6 and draws the set album and "EN COURS" screen before stories 5 and 6. |
| `bmad-ticket` | Creates the new epic and its stories, rescopes Season preparation story 2 and Card backs, updates `after` links and the initiative. |
| `bmad-build` | Builds the new epic, spike first. |

**Success criteria**
1. Every card of the published season belongs to at least one set; the UFOs hold under about 5 % of the cards.
2. No set is named by a volume number; each set's name is a theme, a franchise, a studio, a hall of fame name or the UFOs.
3. The collection opens on the player's sets in progress; a new player sees "À DÉCOUVRIR" filled.
4. A set opens as an album with its missing cards and its tiers or completion.
5. Reaching a tier or completing a set shows at opening and in the feed.
6. The filtered card grid is still reachable from the collection.

## Approval and handoff log

- 2026-10-08: approved by the author as written, with no conditions. Scope: moderate; routed to the product owner and the developer for the backlog reorganization (`bmad-ticket`), with the document edits of section 4 applied through `bmad-spec`, `bmad-architecture` and `bmad-ux`.
- 2026-10-08: section 4.7 applied through `bmad-ticket`: epic-recognizable-sets (id 13) with 10 entries after a validation pass (the review count kept for the hall of fame, the kind check contracted only after the rebuild, the rebuild split across Catalog and Game); Season preparation story 2 and Cosmetics rescoped; initiative Done when 2 excludes CAP-20 and CAP-22. Sections 4.1 to 4.6 are still to apply.
