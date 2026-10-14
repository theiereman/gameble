---
type: change-proposal
title: "Seasons carry the collection over"
date: 2026-10-14
trigger: _bmad-output/initiative-gameble/forge-season-carryover/forge-season-carryover.md
mode: batch
scope: moderate
status: approved
approved: 2026-10-14, by the author, after one revision (allocation received and seen apart)
---

# Sprint Change Proposal: seasons carry the collection over

## 1. Issue summary

**Problem.** Publishing a season makes a player's earlier cards useless: the collection reads only the published season, so it shows empty, every set is back to 0 % and the total counter reads 0. Nothing is deleted (copies keep their minted rarity and season and stay tradable), but everything the player built stops counting. Lost set progress is what hurts.

**Type.** A new requirement from the product owner, found in use.

**How it was found.** The author, publishing seasons 2 to 4 on staging, then the forge session `forge-season-carryover` (hardened, 2026-10-14), the source of every decision below.

**Evidence.**
- `Game::TierCounts`, `Catalog::CollectionGrid`, `Catalog::SeasonShelf` and the library controller read `Catalog::PublishedSeason` only.
- `Game::SetCompletion::RECORD_SQL` joins holdings on `card_season_id`: only copies minted in the set's own season count for it.
- `plan-collection-season-selector.md` (ready-for-dev) treats the symptom by letting players browse earlier seasons; it does not bring progress back.

## 2. Impact analysis

### Checklist

| Item | Status | Finding |
|---|---|---|
| 1.1 Trigger | [x] | The forge, not a story; the author's own staging publications. |
| 1.2 Problem | [x] | New requirement found in use. |
| 1.3 Evidence | [x] | Above. |
| 2.1 Current epic | [x] | Sets players recognize can finish; its unbuilt stories 5, 7, 8 and 9 absorb the new holding rule at no extra cost. |
| 2.2 Epic changes | [!] | Epic 13 amended (four stories, one added); one new epic; Cosmetics amended. |
| 2.3 Future epics | [!] | Cosmetics (season marks on backs, titles deduplicated), Card catalog (one tile per game). |
| 2.4 Obsolete / new | [!] | `plan-collection-season-selector` obsolete. New epic: Seasons carry over. |
| 2.5 Order | [!] | The holding rule goes in epic 13, before launch. The new epic goes after launch but before production's second season. |
| 3.1 Spec | [!] | CAP-6, CAP-7, CAP-20, CAP-22, a new CAP-23, Constraints, Non-goals, `catalog-and-rarity.md`, `brotherhood-tone.md`, `later-roadmap.md`. |
| 3.2 Architecture | [!] | AD-5, AD-9, AD-10, AD-25. No new table for tiers: a tier row already points to a season's set, so its season is the mark. |
| 3.3 UX | [!] | Collection grid tile, copy badge, card detail editions, set album tier marks, RAPPORT, the new allocation screen, Voice and Tone, card backs. |
| 3.4 Other | [x] | No deployment, CI or infrastructure change. No production data: migration is staging only. |
| 4.1 Direct adjustment | Viable | Effort medium, risk medium. |
| 4.2 Rollback | Not viable | Nothing built contradicts the change except reads of the published season, which are edited, not reverted. |
| 4.3 MVP review | Partly | The holding rule is MVP; the allocation screen and season marks wait until after launch, gated on the second production season. |
| 4.4 Path | [x] | Hybrid, see section 3. |

### Epic impact

| Epic | State | Impact |
|---|---|---|
| Sets players recognize (13) | stories 1 to 3, 11, 12 done; 4 to 10, 13, 14 to do | Stories 5, 7, 8, 9 amended to count any edition; story 15 added (editions in the collection). |
| Space terminal: screens (10) | done | Its grid and card detail are reworked through epic 13, not reopened. |
| The Brotherhood (6) | in progress | Built first discoveries stay per card-season (first of the season). Achievements counting complete sets count a set once across seasons (handled in 13.5). |
| Season preparation (11) | to do | Unchanged. |
| Cosmetics (9) | to do, post-launch | Backs and titles carry season marks; titles deduplicated across seasons. |
| Card catalog (14) | to do | Reads one tile per game, as the collection does. |
| Ready for the public (7) | in progress | Unchanged; the how-it-works screen's seasons panel follows the spec (already one place). |
| `plan-collection-season-selector` | ready-for-dev | Cancelled. |

### Technical impact

- `Catalog`: no schema change. Sets stay one row per season, identified across seasons by kind and key (AD-5 already).
- `Game`: the tier check joins holdings by card, not card-season, and checks only the published season's sets. A new operation, `Game::ReceiveSeasonAllocation`, writes the carried tiers once per player and season. `game_player_states` gains the last season whose allocation the player received and the last one they saw. Every operation that raises quantities receives a pending allocation first.
- Queries: tier counts, collection summary, grid, set progress and public profile read across editions; best minted rarity per card.
- Web: grid tile and badges, card detail editions, album tier marks, the allocation screen.
- Staging: seasons 1 to 4 already hold copies; the new reads apply as is. Nothing in production.

## 3. Recommended approach

**Hybrid: the holding rule now, the season ceremony after launch.**
- **Now, inside epic 13.** Its tier, collection, album and grid stories are not built yet. Writing them edition-aware costs almost nothing; building them on the published season and redoing them later costs two passes.
- **After launch, a new epic "Seasons carry over"**: the allocation screen, the carried tiers and the season marks. Production starts on one season, so none of it is visible until the second production season. The epic is a hard gate before that publication.
- **Cosmetics** (already post-launch) picks up season marks on backs and titles.
- **The season selector plan is cancelled**: every edition shows in the collection, so there is nothing to switch to.

**Alternatives considered.** Building everything before launch (more scope for a moment that cannot happen before the second season). Keeping the selector and adding the rule later (two reworks of the same screens). Rollback (nothing to gain).

**Effort.** Medium: four story amendments and one story in epic 13, a three-story epic after launch, and edits to Cosmetics. **Risk.** Medium: set progress across editions must stay inside the 200 ms p95 opening budget (one join by card instead of card-season). **Timeline.** Epic 13 grows by one story; launch is not delayed beyond that.

## 4. Detailed change proposals

### 4.1 Spec: `spec-gameble/spec-gameble.md`

**CAP-6**, success. Add after "Each set shows owned / total distinct cards…":

NEW: `- A set is the same set from one season to the next (same kind and key). A copy of a game counts for the set whatever season it was minted in. Only the published season's sets earn tiers; a tier earned stays earned, marked with the season it was earned in, and can be earned again in a later season with that season's mark.`
NEW: `- A set's progress is read against the published season's set and may drop when the set grows; it is shown as new cards to find, never as a loss. A game that leaves a set stops counting for that set only.`
NEW: `- The collection shows one card per game: its best minted rarity among the copies owned, the copies owned across editions, and a mark when several editions are held. The total counter counts distinct games across editions and never drops when a season is published.`

Rationale: the forge's locks 1, 3, 4 and 6.

**CAP-7**, success, detail view.

OLD: `- The detail view shows the title, publisher, rarity, genre, release year, short description, minted season, sets, card number, copies owned, and a link to the game's Steam store page.`
NEW: `- The detail view shows the title, publisher, rarity, genre, release year, short description, minted season, sets, card number, copies owned, the editions owned grouped by rarity (folded beyond a few lines), and a link to the game's Steam store page.`

**CAP-20**, success, second bullet. Add at the end: `A back earned on a set carries the mark of each season it was earned in; the player picks which season's mark the active back wears.`

**CAP-22**, success, first bullet. Add: `A title is earned once per set and tier, whatever the seasons; it shows the latest season it was earned in.`

**New CAP-23.**

```
- **CAP-23**
  - **intent:** When a new season is published, a returning player receives the Brotherhood's seasonal allocation: what they unlocked in the season that ended and the sets that follow them into the new one.
  - **success:**
    - At a player's first visit after a publication, before the hub and before any opening, a dedicated screen recaps the season that ended: tiers reached (with that season's mark), card backs, achievements and weekly goal rewards earned during it.
    - The same screen lists the tiers the player still meets in the new season's sets, received at once with the new season's mark, and the tiers to win back.
    - Tiers carried into the new season are never celebrated at an opening or announced in the feed; an opening or a trade celebrates only the tiers it crosses itself.
    - One Brotherhood line heads the screen; the rest is plain copy.
    - A player who joined in the current season sees no allocation.
    - A set shows its latest mark and a count of seasons ("Or · 12 saisons"), the per-season detail on demand. No season chip appears in the collection grid.
```

**Constraints**, Launch scope.

OLD: `- **Launch scope:** CAP-20 and CAP-22 are built after the public launch; every other capability is live at launch.`
NEW: `- **Launch scope:** CAP-20, CAP-22 and CAP-23 are built after the public launch; every other capability is live at launch. CAP-23 is live before the second season is published in production.`

**Constraints**, Card copies. Add: `The minted season is the copy's edition. Draws give only the published season's cards; earlier editions change hands only by trade.`

**Non-goals.**

OLD: `- Brotherhood Pass, seasonal catalog recompute, community-voted themed sets (V3).`
NEW: `- Brotherhood Pass, community-voted themed sets (V3).`

Rationale: seasons are published already (staging seasons 1 to 4, Season preparation epic); the non-goal is stale.

### 4.2 Spec: `spec-gameble/catalog-and-rarity.md`

Add a section after Sets:

```
## Seasons

- **A season is a reprint.** Each publication re-imports every game, recomputes rarities, numbers the cards and rebuilds the sets; games enter or leave the catalog. Nothing a player owns is removed or changed.
- **Editions.** A copy keeps the rarity and season it was minted with. The same game can be held in several editions of different rarities.
- **Sets across seasons.** A set keeps its kind and key from one season to the next; its members follow each season's rules. Any edition of a member game counts for it. Tiers are cut on the published season's set and earned there only.
- **Earned stays earned.** A tier reached in a season keeps that season's mark forever. A tier the player still meets when a new season is published is received again with the new season's mark at the seasonal allocation; one below its threshold is won back by play.
```

### 4.3 Spec: `spec-gameble/brotherhood-tone.md`

OLD: `- **Discreet:** the Brotherhood carries one line, on the weekly goal ("objectif communautaire") only. The feed and every other label carry none.`
NEW: `- **Discreet:** the Brotherhood speaks only at collective moments: the weekly goal ("objectif communautaire") and the seasonal allocation, at most one line per screen. The feed and every other label carry none.`

**Register of the one line** → **Register of its lines**; **Where the satire lives:** `in that line only` → `in those lines only`.

### 4.4 Spec: `spec-gameble/later-roadmap.md`

**V3, Seasons.**

OLD: `- **Seasons:** the catalog and rarities are recomputed per season (e.g. quarterly), and new games enter only at season start. Owned copies keep their minted rarity and season.`
NEW: `- **Seasons:** moved to the MVP rules (`catalog-and-rarity.md`, Seasons). Left for V3: the season cadence (e.g. quarterly).`

**V2, Average sale price.** Add: `Open: whether the average is per game, per minted rarity or per edition (market liquidity against an edition premium).`

### 4.5 Architecture: `architecture-gameble/architecture-gameble.md`

**AD-5**, add a rule after the set identity rule:

NEW: `- A player holds a set's member when they hold, with quantity above zero, a card-season of that member's card in any season. Holdings stay one row per card-season (AD-6): the minted season is the copy's edition. Draws read only the published season.`

**AD-9**, uniqueness list. Unchanged rows; add: `the last season whose allocation a player received and the last one they saw, on their game_player_states row.`

**AD-10**, tier rule.

OLD (first sentence): `- An operation that raises a player's quantities then inserts a set-tier row (unique per player, set and tier) with ON CONFLICT DO NOTHING for each tier whose required count the player now holds, …`
NEW: `- An operation that raises a player's quantities then inserts a set-tier row (unique per player, set and tier) with ON CONFLICT DO NOTHING for each tier of a published-season set whose required count the player now holds, counting any edition of each member (AD-5), …` (rest unchanged). Add: `A tier row's season is its set's season: that is the tier's mark. Sets of earlier seasons earn no new tier.`

**AD-10**, add a rule:

NEW: `- Game::ReceiveSeasonAllocation runs once per player and published season. It inserts the tier rows the player already meets in the published season's sets and publishes one Game::SeasonAllocationReceived; the carried rows publish no Game::SetTierReached or Game::SetCompleted and make no feed entry. Every operation that raises a player's quantities (an opening, an accepted trade, a reward) first receives that player's pending allocation, silently, so it celebrates only the tiers it crosses itself. A player with no holding from an earlier season receives nothing.`
NEW: `- The allocation is received and seen separately: game_player_states holds the last season received and the last season seen. While the published season is not seen, the hub and the booster page redirect to the allocation screen (a GET that writes nothing); the screen's POST receives the allocation if still pending and marks it seen.`

**AD-25**, add: `A set's back is unlocked once; the seasons it was earned in are read from the player's gold tier rows of that set. The active back records the season whose mark it wears. Titles are read from distinct set kind, key and tier across seasons.`

**Achievements (AD-10 handlers).** Add: `Set counts ("first complete set", "three complete sets") count distinct set kind and key.`

**Data model.** `GAME_PLAYER_STATE` note gains "allocation received and seen up to". No other change.

**Capability map.** Add `CAP-23 Seasonal allocation | Game, web layer | AD-5, AD-10, AD-11`.

**Deferred.** Replace `- **Market, seasons after the first, native apps:** later versions; AD-5, AD-6 and AD-7 already carry the season.` with `- **Market and native apps:** later versions. Seasons after the first are carried by AD-5's holding rule and CAP-23's allocation.`

### 4.6 UX: `ux-gameble/EXPERIENCE.md`

- **Voice and Tone:** `The Brotherhood is discreet: one line, on the community goal only.` → `The Brotherhood is discreet: one line at collective moments only, the community goal and the seasonal allocation.`
- **Collection, Copy badge:** add `Copies count every edition. A card held in several editions shows an edition count ("3 éd."); the grid never shows a season.`
- **Collection, grid:** add `One card per game, showing its best minted rarity owned; a missing card shows the published season's face.`
- **Collection, Card detail:** add `"ÉDITIONS": the editions owned grouped by rarity ("Rare : S1, S4 · Épique : S2"), folded beyond three lines.`
- **Collection, Set album:** add `Each tier shows its latest season mark and the number of seasons it was earned in ("Or · 12 saisons"); the per-season list opens on demand. A tier earned before but not met in the current season reads "à reconquérir".`
- **Collection, RAPPORT panel:** `Totals and copies per rarity.` → `Distinct games per best owned rarity, and copies across editions.`
- **New, Seasonal allocation (CAP-23):** a full screen shown once at the first visit after a publication, before the hub: the Brotherhood line, the ended season's unlocks, the sets that follow ("vos sets vous suivent") with their new mark, the tiers to win back, one button to continue. The hub and the booster page lead there while it is unseen; its POST receives the allocation if still pending and marks it seen. Phone: one scrolling column. Accessible: the screen's h1 names the season; the lists are lists.
- **Card backs:** add `A back shows the mark of the season chosen in the picker; the picker lists the seasons it was earned in.`

### 4.7 UX: `ux-gameble/DESIGN.md`

- **Season mark:** a small stamp, "S2" style, laid over an existing back or tier badge; no back redrawn per season.
- **Allocation screen:** a panel page in the shell's tokens; to be designed with the author before the new epic's first story.
- **Card detail panel:** an "ÉDITIONS" row after "copies owned".

### 4.8 Epics and stories

**Sets players recognize (13)**

- Story 5, description, add: `A set's member counts when the player holds it in any season; only the published season's sets earn tiers; set achievements count a set once across seasons by kind and key.` Verify, add: `A copy minted in an earlier season counts toward a published-season theme's bronze; it does not give a tier on that earlier season's set.`
- Story 7, description, add: `Set progress counts every edition.` Verify, add: `After a new season is published on staging, a player's sets in progress keep their progress (less what the grown sets add).`
- Story 8, description, add: `A slot is filled by any edition, showing the best one owned; tier marks show the latest season and the count.` 
- Story 9, unchanged.
- **New story 15, "Every edition counts in the collection"**, after 9. Description: `The grid shows one card per game with its best owned rarity and copies across editions, an edition count when several are held; the total counter and RAPPORT count distinct games across editions; the card detail lists the editions owned grouped by rarity; the public profile reads the same; replaces every collection read of the published season only.` Verify: `On staging with seasons 1 to 4 published, a player holding Hades in S1 Rare and S4 Epic sees one Hades tile at Épique with "2 éd.", a total counter that does not drop at publication, and both editions on the card detail.`

**New epic: "Seasons carry over"** (covers CAP-23; after Ready for the public; gate: before production's second season is published)

1. **The seasonal allocation.** `Game::ReceiveSeasonAllocation`, the received and seen seasons on `game_player_states`, the allocation screen with the ended season's recap and the carried tiers, the hub and booster redirect while unseen, and the silent receipt at the start of every operation that raises quantities. Mock first, with the author. Verify: a friend's trade accepted before the player returns celebrates no carried tier, and the screen still shows at the next visit.
2. **Season marks on tiers.** Album, profile and hub show the latest mark and the season count, the per-season detail on demand, "à reconquérir".
3. **A season change rehearsed.** On a copy of staging with players, publish a season and check: no counter drops, carried tiers are received once, no feed entry for carried tiers, opening p95 under 200 ms.

**Cosmetics (9)**: Done when 2, add `A back earned again in a later season gains that season's mark, not a second unlock.` Done when 3, add `The player picks the season mark the active back wears.` Done when 5, add `A title is earned once per set and tier across seasons.`

**Card catalog (14)**: Notes, add `Reads one tile per game, as the collection does (13.15).`

**Cancel** `plan-collection-season-selector.md`: superseded by 13.15.

**Initiative**: covers CAP-23; Notes, add `Decision (2026-10-14, author): seasons are reprints; any edition counts for a set; earned tiers keep their season's mark; a seasonal allocation screen at each new season (change-season-carryover). The holding rule before launch, the allocation after launch and before production's second season.`

## 5. Implementation handoff

**Scope: moderate.** A backlog reorganization with one new epic and five ticket edits; no MVP goal dropped; the spec, architecture and UX get targeted edits.

| Who | Does what |
|---|---|
| Author (product owner) | Approves this proposal; designs the allocation screen and the season mark with `bmad-ux` before the new epic. |
| `bmad-spec` | Applies 4.1 to 4.4. |
| `bmad-architecture` | Applies 4.5. |
| `bmad-ux` | Applies 4.6 and 4.7 (the grid tile, editions, tier marks before 13.15; the allocation screen before the new epic). |
| `bmad-ticket` | Applies 4.8: amends 13.5, 13.7, 13.8, adds 13.15, creates the new epic, amends Cosmetics and Card catalog, cancels the selector plan, updates the initiative. |
| `bmad-build` | Builds 13.5 onward with the new rule, then the new epic after launch. |

**Success criteria**
1. Publishing a season never lowers a player's total counter, and never empties their collection.
2. A copy of any season counts toward the published season's sets.
3. A tier once earned is never lost and shows its season's mark; one no longer met can be won back with the new mark.
4. A returning player sees the seasonal allocation once per season, with what they unlocked and what follows them.
5. The grid shows no season chip, at any number of seasons.
6. Opening a pack stays under 200 ms p95.

## Approval and handoff log

- 2026-10-14: revised before approval: the allocation is received silently by every operation that raises quantities and seen separately, with the hub and booster redirecting to the screen while unseen, so no carried tier is celebrated and the ceremony is never skipped.
- 2026-10-14: approved by the author. Scope: moderate; routed to the product owner and the developer for the backlog reorganization (`bmad-ticket`, section 4.8), with the document edits of sections 4.1 to 4.7 applied through `bmad-spec`, `bmad-architecture` and `bmad-ux`. Nothing applied yet.
- 2026-10-14: section 4.8 applied through `bmad-ticket`, after an independent check of the draft: epic-recognizable-sets gains R11, Done when 6, entries 5, 7, 8 amended and entry 15 added (13 and 14 after it); new epic-seasons-carry-over (17) with five entries (carried tiers received silently, the allocation screen, season marks on tiers, refactor sweep, a rehearsal on staging), placed after epic 12 (author: built once production is open) and waiting on epics 9 and 13; R5 follows the architecture's rule (no card from an earlier season); the season count on tiers moves from 13.8 to 17.3 (author). Cosmetics Done when 2, 3, 5 amended; Card catalog waits on 13.15; the initiative covers CAP-23; plan-collection-season-selector dropped. Sections 4.1 to 4.7 are still to apply.
- 2026-10-14: sections 4.1 to 4.4 applied through `bmad-spec`: CAP-6, CAP-7, CAP-20, CAP-22 amended, CAP-23 added; Launch scope, Card copies and the V3 non-goal amended; catalog-and-rarity.md gains Seasons; brotherhood-tone.md speaks at collective moments, one line per screen; later-roadmap.md keeps only the season cadence for V3 and opens the per-edition price question; first discoveries joined the spec's open questions. Sections 4.5 to 4.7 are still to apply.
- 2026-10-14: open point settled by the author's pioneer idea: first discoveries stay per card and season, each edition with its own pioneer (spec memlog, later-roadmap.md).
- 2026-10-14: section 4.5 applied through `bmad-architecture` after a three-lens review: AD-5 two measures (games through Game::HeldGames, copies per minted rarity), AD-7 unopened packs redrawn in the published season at publication (author), AD-9 received and seen seasons, AD-10 tier pass by card on published sets, tier row source, the allocation receipt inside OpenPack and AcceptTrade under the bank lock, AD-14 first discoveries kept, AD-25 backs and titles across seasons. The spec follows: CAP-23 eligibility is 'no card from an earlier season', the pioneer's name follows profile visibility. Sections 4.6 and 4.7 are still to apply; tickets 13.5, 13.8, 13.15, 17.1 and a redraw entry are to re-slice.
